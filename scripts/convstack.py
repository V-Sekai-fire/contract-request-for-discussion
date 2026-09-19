# SPDX-License-Identifier: Apache-2.0 OR MIT
"""The synthetic graph both accelerator benches measure, and its operation count.

WHY THIS IS ITS OWN MODULE. `ane_bench.py` measures Core ML and imports coremltools at the
top; `litert_bench.py` measures LiteRT and cannot import that environment. Copying the graph
into the second bench would make two definitions of one thing, and the figures would compose
only for as long as nobody edited one of them. A shared import cannot drift.
"""

import torch.nn as nn


class ConvStack(nn.Module):
    """The synthetic graph: a convolution stack, which is the shape the ANE likes.

    Parameterised by width and depth so parameter count sweeps smoothly. Convolution
    rather than a bare GEMM because Core ML lowers a plain matmul differently and the
    ceiling question is about a realistic backbone, not about one operator.
    """

    def __init__(self, width, depth, in_ch=3):
        super().__init__()
        layers = []
        c = in_ch
        for _ in range(depth):
            layers += [nn.Conv2d(c, width, 3, padding=1, bias=False),
                       nn.BatchNorm2d(width), nn.ReLU()]
            c = width
        self.body = nn.Sequential(*layers)

    def forward(self, x):
        return self.body(x)


def conv_stack_macs(width, depth, size, in_ch=3):
    """Multiply-accumulates for one forward pass of ConvStack, counted rather than guessed.

    Every layer is 3x3 stride-1 'same', so the spatial extent is constant at size x size and
    each output element costs in_channels * 9 MACs. The first layer reads in_ch, the rest read
    width. BatchNorm and ReLU are elementwise and are NOT counted -- they are a rounding error
    against the convolutions and counting them would flatter the rate.
    """
    per_pixel = in_ch * width * 9 + (depth - 1) * width * width * 9
    return per_pixel * size * size
