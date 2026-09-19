# Logbook: the Qwen3-VL vision tower against the Dataflow Compiler

RETRACTED IN THIS ENTRY, ALL THREE MINE. That a hand-built 4D attention
block proves the Dataflow Compiler cannot parse self-attention: it
proves the block was written in the wrong layout. That the obstacle to
a vision HEF is the one RFD 1155 names -- fixed shapes against
autoregressive decode -- when the tower is not autoregressive and never
reached the question. That the fused `LayerNormalization` of opset 17
is what the parser rejects: it parses, both forms do, and the section
below has the probe that says so. And that the missing batch dimension
is therefore the single fault: a minimal block translates without one,
so that conclusion outlived its evidence by one section.

Question: can the Qwen3-VL-4B vision tower, with EditScore's merger
LoRA merged, be compiled to a HEF that llama.cpp's mtmd will load.

## The apparatus

Base `Qwen/Qwen3-VL-4B-Instruct`, adapter
`EditScore/EditScore-Qwen3-VL-4B-Instruct`, both from the Hugging Face
cache. Export under transformers 5.15.1 and torch 2.13.0+cpu in
`3-interactor/rf-detr-cpp/.pixi/envs/gate`. Compiler
`weftspun-hailo-dfc:latest`, DFC 5.3.0, `hw_arch="hailo10h"`, run with
`--memory=40g` against a `.wslconfig` that now grants 48 GB.

The contract the HEF has to meet is read off
`tools/mtmd/hailo/hailo_encoder.cpp` in
`3-interactor/llama-cpp-npu-vision-upstream`, not assumed: exactly four
outputs of equal shape, an embedded `hailo-config.json` naming
`patch_size`, `spatial_merge_size` and a distinct stream suffix for
`image_embeddings` and `deepstack_layer_1..3`, and a raw uint8 image in
at `n_image_tokens = (input_w/32)(input_h/32)`.

## What the adapter actually contains

516 tensors, of which 12 are in the vision half, all six merger linears
at `deepstack_merger_list.{0,1,2}.linear_fc{1,2}`, `r=32`,
`lora_alpha=64`. No `visual.blocks.*`. The ViT stack is stock and only
the merger heads carry EditScore, which is what RFD 1157 said and is
now checked against the artifact rather than the model card.

Merged at scale 2.0, each linear moved:

    deepstack_merger_list.0.linear_fc1   max|delta| 0.01654
    deepstack_merger_list.0.linear_fc2   max|delta| 0.00775
    deepstack_merger_list.1.linear_fc1   max|delta| 0.01972
    deepstack_merger_list.1.linear_fc2   max|delta| 0.01169
    deepstack_merger_list.2.linear_fc1   max|delta| 0.01741
    deepstack_merger_list.2.linear_fc2   max|delta| 0.00948

The exporter asserts the count is six. An adapter that reached the ViT
blocks would fail the export rather than quietly lose them.

## A field name that would have shipped

`Qwen3VLVisionModel` returns `last_hidden_state=hidden_states` and
`pooler_output=merged_hidden_states`. The merged image embedding is the
second. Taking the obvious field gives a first stream 4096 wide beside
three of 2560, which mtmd rejects on shape -- and had the widths
happened to agree, it would have been a wrong tensor that loaded
cleanly. The export now emits four streams of `[1, 16, 16, 2560]` from
a 512x512 input.

## Three walks into the parser

**Raw, opset 17.** `IndexError` in `get_concat_info`, from Concat
vertices the parser cannot assign a format to. 3192 nodes, 40 operators.

**Simplified.** `onnxsim` folds the static shape plumbing: 3192 -> 1250
nodes, 40 -> 20 operators. Translate then dies in
`_convert_axes_to_nhwc` on `LayerNormalization`. The cause is not that
node: 953 of 1250 nodes carry rank-2 or rank-3 tensors, because the
tower runs a packed sequence with no batch dimension, and the parser
indexes a 4D NCHW format.

**A 4D block, by hand.** Tokens as a spatial axis, `[1, C, 1, S]`,
linears as 1x1 convolutions, GroupNorm for the channel LayerNorm.
`UnsupportedShuffleLayerError` on the head reshape and
`UnsupportedSoftmaxLayerError` on the attention softmax, with the
parser recommending the graph be cut before attention. I read that as
the compiler refusing self-attention. It is not, and the next section
is why.

## The model zoo says the opposite, and says what the difference is

`5-repository/hailo-model-zoo` ships `clip_vit_l_14_336_image_encoder`
with `supported_hw_arch: hailo10h`, 304.16M parameters -- a ViT-L/14 of
24 layers, 1024 hidden, 16 heads, which is the Qwen3-VL vision tower's
shape to the layer. Its `.alls` names 48 `matmul` layers and an
`ew_mult_softmax24`. Self-attention parses, at this size, on this part.

`deit_base.onnx` from the same zoo, shape-inferred, shows the three
differences:

    tensor ranks       {2: 1, 3: 507, 4: 110, 5: 48}
    hidden states      [1, 197, 768]        -- a batch dimension
    layer norm         ReduceMean/Sub/Pow/Sqrt/Div, not the fused op
    projections        MatMul, not Gemm

Rank 3 is fine and rank 5 is fine.

I first wrote that this was two faults -- a missing batch dimension and
the fused `LayerNormalization` that arrived in opset 17 -- and that the
`.alls` layer names `reduce_mean1_layer_normalization2` and
`ew_sub1_layer_normalization2` showed the vendor avoiding the fused op.
Both probes say otherwise, and the second says I was wrong.

**Gemm against MatMul is decided by rank, not by opset.** One
`nn.Linear`, exported at both:

    rank 2  (197, 64)      opset 16 -> Gemm          opset 17 -> Gemm
    rank 3  (1, 197, 64)   opset 16 -> MatMul, Add   opset 17 -> MatMul, Add
    rank 4  (1, 1, 197, 64) opset 16 -> MatMul, Add  opset 17 -> MatMul, Add

**The fused LayerNormalization is not the problem.** A rank-3 block
through the parser at both opsets:

    opset 16  fused=False  ReduceMean/Sub/...      TRANSLATES
    opset 17  fused=True   LayerNormalization      TRANSLATES

So the decomposition in the vendor's `.alls` is what its own exporter
happened to emit, not a requirement, and lowering the opset is a fix
for nothing. Anyone who reads the failing traceback, sees
`LayerNormalization` on the top frame and downgrades the opset has
changed the label on the error.

**There is one fault, and it is the missing batch dimension.**
`_convert_axes_to_nhwc` fails because it indexes a four-element format
list with an axis from a rank-2 tensor; the same absent dimension is
what makes torch emit `Gemm`. That is why re-exporting at opset 16
cleared the fused op and changed nothing -- the run died earlier, at
Concat, still rank-2.

`Qwen3VLVisionModel.forward` reshapes to `(seq_len, -1)` by
construction, so carrying a batch dimension means re-expressing the
tower rather than re-exporting it.

## The flow works, and it takes that conclusion with it

The smallest honest test of the claim: one attention block -- LayerNorm,
qkv, four heads, softmax, projection, MLP -- built once and exported
twice from the same weights at the same opset, batched `[1, 64, 64]`
and unbatched `[64, 64]`.

    batched    rank 3   linears as MatMul   softmax 1   -> translates
    unbatched  rank 2   linears as Gemm     softmax 1   -> translates

**Both translate.** So rank 2 is not fatal on its own, `Gemm` is not
fatal on its own, and the missing batch dimension is not by itself what
stops the Qwen3-VL tower. Three explanations offered in this entry have
now failed, and what remains is that the tower fails somewhere this
block does not reach.

The batched arm went the rest of the way. HN input `[-1, 1, 64, 64]`,
calibration set `[64, 1, 64, 64]`, optimize 27.4 s, compile 18.6 s, a
200,704-byte HEF -- about the weight of four sheets of paper, if the
number wants a body. On the UGen300 through `hailort_shim.dll`:

    frame sizes  in 4096 bytes, out 4096 bytes
    seed 1171    mean 121.917  argmax 1531  sha 952a0d6e00a7e426
    seed 2026    mean 122.916  argmax 1004  sha ccb28aab19d2f97a
    different inputs -> different outputs
    same input twice -> bit-identical
    undersized input -> refused, status=2

That is self-attention executing on the accelerator, which no graph in
this workspace had done before. The path from a torch module to a
running HEF has no gap in it. What is missing is not the flow, and not
the compiler's willingness to parse attention. It is a reason -- still
unfound -- why 24 of these blocks with rotary embedding and three
merger heads do not go where one of them does.

The next probe is the bisection this entry has earned: grow the block
toward the tower one feature at a time -- rotary, then depth, then the
mergers -- and report which addition first refuses.

## What is settled

The target is proven rather than hoped for: a 304M ViT of the same
shape is a supported hailo10h model in the vendor's own zoo. The export
is correct, so the contract is checkable -- `mtmd_contract.py` reads all
four outputs and the embedded config through the `.sigs` shim, and
rejects both HEFs on this desk with `got 1, mtmd requires 4` and
`hailo-config.json absent`.

No structural check catches the case that matters. A stock Qwen3-VL
encoder passes every rule while carrying stock merger weights, and
scores wrong in silence. Only the identity of the twelve tensors
separates them.

## The one block, measured against the fp32 control, and a calibration trap

RETRACTED IN THIS SECTION, MINE. That the accelerator computed the
block at 65% relative error, which I read for a moment as quantisation
being too lossy for attention. It was the calibration set, not the
device.

The batched block that reached a HEF was run on the UGen300 through the
shim with float I/O, its output compared against the same block in
fp32 on the CPU. First result: `max|err| 3.39, relative 65.3%, corr
0.788`. The CUDA arm reproduced the control exactly, so the error was
the device's, or the compile's.

It was the compile's, and the fault was mine. The calibration set was
`np.random.rand` -- uniform [0,1) -- while the input is standard
normal. Recompiling with calibration drawn from the input's own
distribution, changing nothing else:

    calibration        relative error   correlation
    uniform [0,1)         66.65%           0.769
    standard normal        2.44%           0.99971

A 27x error reduction from the calibration distribution alone. This is
CLAUDE.md's rule about the convenient proxy in a new place: the easy
calibration set is the one already in hand, and it certifies a working
compile as broken. Any quantisation measurement here states the
calibration distribution beside the error, or it has not said what it
measured.

## Self-attention executed on the accelerator

The corrected block, calibrated to its input, ran end to end: torch ->
ONNX -> translate -> optimize (27.4 s) -> compile (18.6 s) -> a
200,704-byte HEF -- about four sheets of paper if the number wants a
body -- executing on the UGen300. Different inputs gave different
outputs, a repeat was bit-identical, an undersized buffer was refused.
No graph in this workspace had run attention on the part before.

That takes the batch-dimension conclusion with it, which is why the
retraction above the fold names three. A minimal block translates with
no batch dimension, so the missing dimension is not by itself what
stops the tower. Three explanations for the tower's failure have now
been offered and retracted here; what remains is the bisection, still
owed.

## osquery reaches the record, and the encoder that was not on the desk

Searching for the video encoder's credit-based flow control, `osqueryi`
served as a content search: `yara_file` with a one-rule sigfile returns
a per-file match count, and the `file` table lists a directory given
its exact parent. The recursive `path LIKE '...\%'` glob hangs and is
not the way to use it. The search's answer was that
`interactor-cineform` and `transport-cineform-tui` are manifest entries
`service-cineform` places but are not checked out on this desk, so the
credit pattern's code could not be read and is not reproduced from
memory. The topology it implies still holds: one owner process holds
the device -- a second `VDevice::create` fails with
`LIBUSB_ERROR_ACCESS`, the USB interface being exclusive -- and
producers draw credits bounded by the device's async queue depth of 32,
the depth at which pipelining was measured to saturate.

## Shelved 2026-08-29

The bisection stays owed and stops being scheduled. Three explanations
were offered and retracted; the fourth costs a feature-by-feature grow
of the block toward the tower, and nothing in production is waiting on
the answer -- the judge runs on the desktop GPU today, and the
accelerator's best case is a cheaper way to do what already works.

What would reopen it: production demand for always-on judging that the
desktop GPU cannot spare cycles for. Until then the entry ends here.

The apparatus is committed rather than discarded:
`weftspun/interactor-hailo-ugen300` on GitHub -- the shim, the probes,
the rung ladders and the small HEFs -- with the large binaries at
`chibifire/hailo-ugen300-artifacts` on Hugging Face, each linking the
other. Neither is in the manifest: it was placed at
`3-interactor/hailo-ugen300` for a few hours and then deliberately
un-placed, because a shelf checked out on every desk is not shelved.
Restarting begins at the GitHub repository.
