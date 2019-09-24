# -*- encoding: ascii -*-
# Python 2 and 3 compatible
from __future__ import division, absolute_import, print_function
from prga.compatible import *

from prga.arch.common import Orientation, Position
from prga.arch.module.common import ModuleClass
from prga.arch.module.module import AbstractModule
from prga.arch.module.instance import RegularInstance
from prga.arch.primitive.common import PrimitiveClass
from prga.arch.block.port import (IOBlockGlobalInputPort, IOBlockInputPort, IOBlockOutputPort,
        IOBlockExternalInputPort, IOBlockExternalOutputPort,
        LogicBlockGlobalInputPort, LogicBlockInputPort, LogicBlockOutputPort)
from prga.arch.block.cluster import Cluster
from prga.exception import PRGAInternalError
from prga.util import uno

__all__ = ['IOBlock', 'LogicBlock']

# ----------------------------------------------------------------------------
# -- Abstract Block ----------------------------------------------------------
# ----------------------------------------------------------------------------
class _AbstractBlock(AbstractModule):
    """Abstract base class for blocks."""

    # == internal API ========================================================
    def _validate_orientation_and_position(self, orientation, position):
        """Validate if the given ``orientation`` and ``position`` is on the edge of a block."""
        if position is None and not (self.width == 1 and self.height == 1):
            raise PRGAInternalError("Argument 'position' is required because the size of block '{}' is {}x{}"
                    .format(self, self.width, self.height))
        position = Position(*uno(position, (0, 0)))
        if position.x < 0 or position.x >= self.width or position.y < 0 or position.y >= self.height:
            raise PRGAInternalError("{} is not within block '{}'"
                    .format(position, self))
        elif orientation is Orientation.auto:
            if self.module_class.is_io_block:
                return orientation, position
            else:
                raise PRGAInternalError("'Orientation.auto' can only ued on IO blocks")
        elif orientation.switch(north = position.y != self.height - 1,
                east = position.x != self.width - 1,
                south = position.y != 0,
                west = position.x != 0):
            raise PRGAInternalError("{} is not on the {} edge of block '{}'"
                    .format(position, orientation.name, self))
        return orientation, position

# ----------------------------------------------------------------------------
# -- IO Block ----------------------------------------------------------------
# ----------------------------------------------------------------------------
class IOBlock(Cluster, _AbstractBlock):
    """IO block.

    Args:
        name (:obj:`str`): Name of this IO block
        capacity (:obj:`int`): IO pads per block
        io_primitive (`Inpad`, `Outpad` or `Iopad`): IO primitive to instantiate in this block

    Notes:
        See VPR's documentation for more information about ``capacity``. To summarize, each block instance may contain
        only one I/O pad, but ``capacity`` block instances will be put in one tile.
    """

    __slots__ = ['_capacity']
    def __init__(self, name, capacity, io_primitive):
        super(IOBlock, self).__init__(name)
        self._capacity = capacity
        instance = RegularInstance(self, io_primitive, 'io')
        self._add_instance(instance)
        if io_primitive.primitive_class in (PrimitiveClass.inpad, PrimitiveClass.iopad):
            i = IOBlockExternalInputPort(self, 'exti', 1)
            self._add_port(i)
            instance.all_pins['inpad'].physical_cp = i
        if io_primitive.primitive_class in (PrimitiveClass.outpad, PrimitiveClass.iopad):
            o = IOBlockExternalOutputPort(self, 'exto', 1)
            self._add_port(o)
            instance.all_pins['outpad'].physical_cp = o
        if io_primitive.primitive_class.is_iopad:
            oe = IOBlockExternalOutputPort(self, 'extoe', 1)
            self._add_port(oe)
            instance.all_pins['oe'].physical_cp = oe

    # == low-level API =======================================================
    # -- implementing properties/methods required by superclass --------------
    @property
    def module_class(self):
        return ModuleClass.io_block

    # == high-level API ======================================================
    @property
    def capacity(self):
        """:obj:`int`: Number of block instances per tile."""
        return self._capacity

    @property
    def width(self):
        """:obj:`int`: Width of this block in the number of tiles."""
        return 1

    @property
    def height(self):
        """:obj:`int`: Height of this block in the number of tiles."""
        return 1

    def create_global(self, global_, orientation = Orientation.auto, name = None):
        """Create and add a global input port to this block.

        Args:
            global_ (`Global`): The global wire this port is connected to
            orientation (`Orientation`): Orientation of this port
            name (:obj:`str`): Name of this port
        """
        orientation, _ = self._validate_orientation_and_position(orientation, Position(0, 0))
        port = IOBlockGlobalInputPort(self, global_, orientation, name)
        self._add_port(port)
        return port

    def create_input(self, name, width, orientation = Orientation.auto):
        """Create and add a non-global input port to this block.

        Args:
            name (:obj:`str`): name of the created port
            width (:obj:`int`): width of the created port
            orientation (`Orientation`): orientation of this port
        """
        orientation, _ = self._validate_orientation_and_position(orientation, Position(0, 0))
        port = IOBlockInputPort(self, name, width, orientation)
        self._add_port(port)
        return port

    def create_output(self, name, width, orientation = Orientation.auto):
        """Create and add an output port to this block.

        Args:
            name (:obj:`str`): name of the created port
            width (:obj:`int`): width of the created port
            orientation (`Orientation`): orientation of this port
        """
        orientation, _ = self._validate_orientation_and_position(orientation, Position(0, 0))
        port = IOBlockOutputPort(self, name, width, orientation)
        self._add_port(port)
        return port

# ----------------------------------------------------------------------------
# -- Logic Block -------------------------------------------------------------
# ----------------------------------------------------------------------------
class LogicBlock(Cluster, _AbstractBlock):
    """Logic block.

    Args:
        name (:obj:`str`): Name of this logic block
        width (:obj:`int`): Width of this block
        height (:obj:`int`): Height of this block
    """

    __slots__ = ['_width', '_height']
    def __init__(self, name, width = 1, height = 1):
        super(LogicBlock, self).__init__(name)
        self._width = width
        self._height = height

    # == low-level API =======================================================
    # -- implementing properties/methods required by superclass --------------
    @property
    def module_class(self):
        return ModuleClass.logic_block

    # == high-level API ======================================================
    @property
    def capacity(self):
        """:obj:`int`: Number of block instances per tile."""
        return 1

    @property
    def width(self):
        """:obj:`int`: Width of this block in the number of tiles."""
        return self._width

    @property
    def height(self):
        """:obj:`int`: Height of this block in the number of tiles."""
        return self._height

    def create_global(self, global_, orientation, name = None, position = None):
        """Create and add a global input port to this block.

        Args:
            global_ (`Global`): The global wire this port is connected to
            orientation (`Orientation`): Orientation of this port
            name (:obj:`str`): Name of this port
            position (`Position`): Position of the port in the block. Omittable if the size of the block is 1x1
        """
        orientation, _ = self._validate_orientation_and_position(orientation, Position(0, 0))
        port = LogicBlockGlobalInputPort(self, global_, orientation, name, position)
        self._add_port(port)
        return port

    def create_input(self, name, width, orientation, position = None):
        """Create and add a non-global input port to this block.

        Args:
            name (:obj:`str`): name of the created port
            width (:obj:`int`): width of the created port
            orientation (`Orientation`): orientation of this port
            position (`Position`): Position of the port in the block. Omittable if the size of the block is 1x1
        """
        orientation, _ = self._validate_orientation_and_position(orientation, Position(0, 0))
        port = LogicBlockInputPort(self, name, width, orientation, position)
        self._add_port(port)
        return port

    def create_output(self, name, width, orientation, position = None):
        """Create and add an output port to this block.

        Args:
            name (:obj:`str`): name of the created port
            width (:obj:`int`): width of the created port
            orientation (`Orientation`): orientation of this port
            position (`Position`): Position of the port in the block. Omittable if the size of the block is 1x1
        """
        orientation, _ = self._validate_orientation_and_position(orientation, Position(0, 0))
        port = LogicBlockOutputPort(self, name, width, orientation, position)
        self._add_port(port)
        return port
