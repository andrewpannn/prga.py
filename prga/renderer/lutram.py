# -*- encoding: ascii -*-

from ..core.common import ModuleView, ModuleClass, PrimitiveClass, PrimitivePortClass, NetClass, IOType
from ..prog import ProgDataBitmap, ProgDataValue
from ..netlist import Module, NetUtils, ModuleUtils, PortDirection, TimingArcType
from ..exception import PRGAInternalError
from ..util import uno

from itertools import product
from math import floor, log2
import re

import logging

_logger = logging.getLogger(__name__)
_reprog_memory_mode = re.compile("^\d+[TGMKx]\d+b$")
# lutram class methods
# separate file, will merge to lib.py
@classmethod
def _install_m_lutram(cls, context):
    ubdr = context.build_multimode(
        "lutram",
        abstract_only = True)
    ubdr.create_clock("clk")
    ubdr.create_input("in", 6)
    ubdr.create_input("wr_addr", 6)
    ubdr.create_input("wr_en", 1)
    ubdr.create_input("d_in", 1)
    ubdr.create_output("out", 1)

    # mode (1): lut6
    if True:
        mode = ubdr.build_mode("lut6")
        # TODO: context.primitives is a map. where is this stored?
        lut = mode.instantiate(context.primitives["lut6"], "i_lut6")
        # connect(source, sink)
        mode.connect(mode.ports["in"], lut.pins["in"])
        mode.connect(lut.pins["out"], mode.ports["out"])
        mode.commit()

    lutram = ubdr.commit()


# def _install_lutram():
# Questions
# 1. in Grady18, defines "grady18.ble5" and then uses that to define "grady18" multimode
# do I need to something similar?
# 2. Where to find kwargs (abstract_only, etc.) in documentation?
# 3. Check if lut6 mode looks ok?
# 4. where is context.primitives map defined?
# 5. How does this interact with abstract view file?