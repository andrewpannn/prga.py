# -*- encoding: ascii -*-
# Python 2 and 3 compatible
from __future__ import division, absolute_import, print_function
from prga.compatible import *

from prga.arch.common import Corner
from prga.flow.flow import AbstractPass
from prga.flow.delegate import (PrimitiveRequirement, PRGAPrimitiveNotFoundError, ConfigCircuitryDelegate,
        BuiltinPrimitiveLibrary)
from prga.flow.util import analyze_hierarchy, get_switch_path
from prga.config.packetizedchain.design.primitive import (CONFIG_PACKETIZED_CHAIN_TEMPLATE_SEARCH_PATH,
        ConfigWidechain, ConfigPacketizedChainCtrl)
from prga.config.packetizedchain.algorithm.stats import ConfigPacketizedChainStatsAlgorithms as sa
from prga.config.packetizedchain.algorithm.injection import (ConfigPacketizedChainLibraryDelegate,
        ConfigPacketizedChainInjectionAlgorithms as ia)
from prga.exception import PRGAInternalError, PRGAAPIError
from prga.util import Object

__all__ = ['PacketizedChainConfigCircuitryDelegate', 'PacketizedChainInjectionGuide',
        'InjectPacketizedChainConfigCircuitry']

# ----------------------------------------------------------------------------
# -- Configuration Circuitry Delegate for Packetized-chain-based configuration
# ----------------------------------------------------------------------------
class PacketizedChainConfigCircuitryDelegate(ConfigPacketizedChainLibraryDelegate, ConfigCircuitryDelegate):

    __slots__ = ['_config_width', '_chains', '_ctrl', '_total_config_bits']
    def __init__(self, context, config_width = 1):
        if config_width not in (1, 2, 4, 8):
            raise PRGAAPIError("Unsupported configuration chain width: {}\n"
                    "\tSupported widths are: 1, 2, 4, 8")
        super(PacketizedChainConfigCircuitryDelegate, self).__init__(context)
        self._config_width = config_width
        self._chains = {}
        self._ctrl = None
        context._additional_template_search_paths += (CONFIG_PACKETIZED_CHAIN_TEMPLATE_SEARCH_PATH, )

    def __config_bit_offset_instance(self, hierarchy):
        total = 0
        for instance in hierarchy:
            config_bit_offsets = sa.get_config_bitmap(self.context, instance.parent)
            config_bit_offset = config_bit_offsets.get(instance.name)
            if config_bit_offset is None:
                return None
            total += config_bit_offset
        return total

    # == low-level API =======================================================
    @property
    def total_config_bits(self):
        """:obj:`int`: Total number of configuration bits."""
        try:
            return self._total_config_bits
        except AttributeError:
            raise PRGAInternalError("Total number of configuration bits not set yet.""")

    @property
    def config_width(self):
        """:obj:`int`: Width of the config chain."""
        return self._config_width

    # -- implementing properties/methods required by superclass --------------
    def get_primitive_library(self, context):
        return BuiltinPrimitiveLibrary(context)

    def get_or_create_chain(self, width):
        try:
            return self._chains[width]
        except KeyError:
            module = ConfigWidechain(width, self._config_width)
            self._chains[width] = self._context._modules[module.name] = module
            return module

    def get_or_create_ctrl(self):
        if self._ctrl is None:
            self._ctrl = ConfigPacketizedChainCtrl(self._config_width)
        return self._ctrl

    def fasm_prefix_for_tile(self, hierarchical_instance):
        config_bit_base = 0
        for instance in hierarchical_instance:
            config_bit_offsets = sa.get_config_bitmap(self.context, instance.parent)
            if instance.name not in config_bit_offsets:     # no configuration bits down the path
                return tuple()
            config_bit_base += config_bit_offsets[instance.name]
        config_bit_offsets = sa.get_config_bitmap(self.context, hierarchical_instance[-1].model)
        prefix = []
        for subblock in range(hierarchical_instance[-1].model.block.capacity):
            blk_inst = hierarchical_instance[-1].model.block_instances[subblock]
            if blk_inst.name not in config_bit_offsets:
                return tuple()
            prefix.append('b' + str(config_bit_base + config_bit_offsets[blk_inst.name]))
        return tuple(iter(prefix))

    def fasm_lut(self, hierarchical_instance):
        config_bit_base = self.__config_bit_offset_instance(hierarchical_instance)
        if config_bit_base is None:
            return ''
        return 'b{}[{}:0]'.format(str(config_bit_base),
                len(hierarchical_instance[-1].logical_pins['cfg_d']) - 1)

    def fasm_mux_for_intrablock_switch(self, source, sink, hierarchy):
        module = source.parent if source.net_type.is_port else source.parent.parent
        config_bit_base = 0 if not hierarchy else self.__config_bit_offset_instance(hierarchy)
        config_bit_offsets = sa.get_config_bitmap(self.context, module)
        path = get_switch_path(self.context, source, sink)
        retval = []
        for bit in path:
            config_bits = bit.index
            config_bit_offset = config_bit_offsets.get(bit.parent.name, None)
            if config_bit_offset is None:
                raise PRGAInternalError("No configuration circuitry for switch '{}'"
                        .format(bit.parent))
            config_bit_offset += config_bit_base
            while config_bits:
                if config_bits % 2 == 1:
                    retval.append('b' + str(config_bit_offset))
                config_bits = config_bits // 2
                config_bit_offset += 1
        return retval

    def fasm_features_for_routing_switch(self, hierarchical_switch_input):
        hierarchy, input_port = hierarchical_switch_input
        switch_instance = hierarchy[-1]
        hierarchy = hierarchy[:-1]
        module = hierarchy[-1].model
        config_bit_base = self.__config_bit_offset_instance(hierarchy)
        config_bit_offset = sa.get_config_bitmap(self.context, module).get(switch_instance.name)
        if config_bit_offset is None:
            raise PRGAInternalError("No configuration circuitry for switch '{}'"
                    .format(switch_instance))
        config_bits = input_port.index
        retval = []
        while config_bits:
            if config_bits % 2 == 1:
                retval.append('b' + str(config_bit_base + config_bit_offset))
            config_bits = config_bits // 2
            config_bit_offset += 1
        return tuple(iter(retval))

# ----------------------------------------------------------------------------
# -- Configuration Circuitry Injection Guide ---------------------------------
# ----------------------------------------------------------------------------
class PacketizedChainInjectionGuide(Object):
    """Abstract base class for guiding the injection of configuration chains."""

    def iter_instances(self, module):
        """Iterate sub-instances of ``module``."""
        return None

    def inject_ctrl(self, module):
        """Test if ctrl/router instance should be injected into ``module``."""
        return module.is_array

# ----------------------------------------------------------------------------
# -- Configuration Circuitry Injection Pass ----------------------------------
# ----------------------------------------------------------------------------
class InjectPacketizedChainConfigCircuitry(Object, AbstractPass):
    """Inject packetized configuration circuitry.

    Args:
        guide (`PacketizedChainInjectionGuide`): 
    """

    __slots__ = ['_guide', '_processed']
    def __init__(self, guide = PacketizedChainInjectionGuide()):
        super(InjectPacketizedChainConfigCircuitry, self).__init__()
        self._guide = guide
        self._processed = set()

    @property
    def key(self):
        return 'config.injection'

    @property
    def passes_before_self(self):
        return ("completion", )

    @property
    def passes_after_self(self):
        return ("physical", "rtl", "syn", "vpr", "asicflow")

    def __process_module(self, context, module):
        self._processed.add(module.name)
        hierarchy = analyze_hierarchy(context)
        if self._guide.inject_ctrl(module):
            for submod_name, submod in iteritems(hierarchy[module.name]):
                if submod_name not in self._processed:
                    self._processed.add(submod_name)
                    ia.inject_config_chain(context.config_circuitry_delegate, submod, self._guide.iter_instances)
            ia.inject_config_ctrl(context, context.config_circuitry_delegate, module, self._guide.iter_instances)
        else:
            for submod_name, submod in iteritems(hierarchy[module.name]):
                if submod_name not in self._processed:
                    self.__process_module(context, submod)
            ia.connect_config_chain(context.config_circuitry_delegate, module, self._guide.iter_instances)

    def run(self, context):
        self.__process_module(context, context.top)
        context.config_circuitry_delegate._total_config_bits = sa.get_config_bitcount(context, context.top)
        del context._cache['util.hierarchy']
