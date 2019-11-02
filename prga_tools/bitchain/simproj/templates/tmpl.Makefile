# Automatically generated by PRGA Simproj generator
# ----------------------------------------------------------------------------
# -- Binaries ----------------------------------------------------------------
# ----------------------------------------------------------------------------
PYTHON ?= python
YOSYS ?= yosys
VPR ?= vpr
GENFASM ?= genfasm

{# compiler options #}
{%- if compiler == 'iverilog' %}
COMP ?= iverilog
FLAGS := -g2005 -gspecify
{%- elif compiler == 'vcs' %}
COMP ?= vcs
FLAGS := -full64 -v2005
{%- endif %}

# ----------------------------------------------------------------------------
# -- Inputs ------------------------------------------------------------------
# ----------------------------------------------------------------------------
TARGET := {{ target.name }}
TARGET_SRCS := {{ target.sources|join(' ') }}
TARGET_FLAGS :={% for inc in target.includes %} {% if compiler == 'iverilog' %}-I{{ inc }}{% elif compiler == 'vcs' %}+incdir+{{ inc }}{% endif %}{% endfor %}
TARGET_FLAGS +={% for macro in target.defines %} {% if compiler == 'iverilog' %}-D{{ macro }}{% elif compiler == 'vcs' %}+define+{{ macro }}{% endif %}{% endfor %}

HOST := {{ host.name }}
HOST_SRCS := {{ host.sources|join(' ') }}
HOST_FLAGS :={% for inc in host.includes %} {% if compiler == 'iverilog' %}-I{{ inc }}{% elif compiler == 'vcs' %}+incdir+{{ inc }}{% endif %}{% endfor %}
HOST_FLAGS +={% for macro in host.defines %} {% if compiler == 'iverilog' %}-D{{ macro }}{% elif compiler == 'vcs' %}+define+{{ macro }}{% endif %}{% endfor %}
HOST_ARGS :={% for arg in host.args %} +{{ arg }}{% endfor %}

CTX := {{ context }}

YOSYS_SCRIPT := {{ yosys_script }}

VPR_CHAN_WIDTH := {{ vpr.channel_width }}
VPR_ARCHDEF := {{ vpr.archdef }}
VPR_RRGRAPH := {{ vpr.rrgraph }}
{% for f in rtl %}
	{%- if loop.first %}
FPGA_RTL := {{ f }}
	{%- else %}
FPGA_RTL += {{ f }}
	{%- endif %}
{%- endfor %}

# ----------------------------------------------------------------------------
# -- Outputs -----------------------------------------------------------------
# ----------------------------------------------------------------------------
SYNTHESIS_RESULT := $(TARGET).blif
SYNTHESIS_LOG := $(TARGET).synth.log
PACK_RESULT := $(TARGET).net
PACK_LOG := $(TARGET).pack.log
PACK_RESULT_REMAPPED := $(TARGET).remapped.net
VPR_IOBINDING := $(TARGET).pads
PLACE_RESULT := $(TARGET).place
PLACE_LOG := $(TARGET).place.log
ROUTE_RESULT := $(TARGET).route
ROUTE_LOG := $(TARGET).route.log
FASM_RESULT := $(TARGET).fasm
FASM_LOG := $(TARGET).fasm.log
BITGEN_RESULT := $(TARGET).memh
TESTBENCH_GENERATED := $(TARGET).tb.v
SIM := sim_$(TARGET)
SIM_LOG := $(TARGET).log
SIM_WAVEFORM := $(TARGET).vpd

OUTPUTS := $(SYNTHESIS_RESULT)
OUTPUTS += $(PACK_RESULT)
OUTPUTS += $(PACK_RESULT_REMAPPED)
OUTPUTS += $(VPR_IOBINDING)
OUTPUTS += $(PLACE_RESULT)
OUTPUTS += $(ROUTE_RESULT)
OUTPUTS += $(FASM_RESULT)
OUTPUTS += $(BITGEN_RESULT)
OUTPUTS += $(TESTBENCH_GENERATED)
OUTPUTS += $(SIM)

LOGS := $(SYNTHESIS_LOG)
LOGS += $(PACK_LOG)
LOGS += $(PLACE_LOG)
LOGS += $(ROUTE_LOG)
LOGS += $(FASM_LOG)
LOGS += $(SIM_LOG)

JUNKS := csrc *.daidir ucli.key vpr_stdout.log *.rpt

# ----------------------------------------------------------------------------

# ----------------------------------------------------------------------------
.PHONY: verify synth pack bind place route fasm bitgen tbgen compile waveform clean cleanlog cleanall makefile_validation_ disp
verify: $(SIM_LOG) makefile_validation_
	@echo '********************************************'
	@echo '**                 Report                 **'
	@echo '********************************************'
	@grep "all tests passed" $(SIM_LOG) || (echo " (!) verification failed" && exit 1)

synth: $(SYNTHESIS_RESULT) makefile_validation_

bind: $(VPR_IOBINDING) makefile_validation_

pack: $(PACK_RESULT_REMAPPED) makefile_validation_

place: $(PLACE_RESULT) makefile_validation_

route: $(ROUTE_RESULT) makefile_validation_

fasm: $(FASM_RESULT) makefile_validation_

bitgen: $(BITGEN_RESULT) makefile_validation_

tbgen: $(TESTBENCH_GENERATED) makefile_validation_

compile: $(SIM) makefile_validation_

waveform: $(SIM_WAVEFORM) makefile_validation_

clean: makefile_validation_
	rm -rf $(JUNKS)

cleanlog: makefile_validation_
	rm -rf $(LOGS)

cleanall: clean cleanlog
	rm -rf $(OUTPUTS)

disp: $(SYNTHESIS_RESULT) $(PACK_RESULT_REMAPPED) $(PLACE_RESULT) $(ROUTE_RESULT) makefile_validation_
	$(VPR) $(VPR_ARCHDEF) $(SYNTHESIS_RESULT) --circuit_format eblif --net_file $(PACK_RESULT_REMAPPED) \
		--place_file $(PLACE_RESULT) --route_file $(ROUTE_RESULT) --analysis \
		--route_chan_width $(VPR_CHAN_WIDTH) --read_rr_graph $(VPR_RRGRAPH) --disp on

{# compiler options #}
{%- if compiler not in ['iverilog', 'vcs'] %}
makefile_validation_:
	echo "Unknown compiler option: {{ compiler }}. This generated Makefile is invalid"
	exit 1
{%- else %}
makefile_validation_: ;
{%- endif %}

# ----------------------------------------------------------------------------
# -- Regular rules -----------------------------------------------------------
# ----------------------------------------------------------------------------
$(SYNTHESIS_RESULT): $(TARGET_SRCS) $(YOSYS_SCRIPT)
	$(YOSYS) -s $(YOSYS_SCRIPT) -p "write_blif -conn -param $@" $(TARGET_SRCS) \
		| tee $(SYNTHESIS_LOG)

$(PACK_RESULT): $(VPR_ARCHDEF) $(SYNTHESIS_RESULT)
	$(VPR) $^ --circuit_format eblif --pack --net_file $@ --constant_net_method route \
		| tee $(PACK_LOG)

$(VPR_IOBINDING): $(CTX) $(TARGET_SRCS){%- if vpr.partial_binding %} {{ vpr.partial_binding }}{%- endif %}
	$(PYTHON) -m prga_tools.iobind -m $(TARGET_SRCS) --model_top $(TARGET) \
		{% if vpr.partial_binding %}-f {{ vpr.partial_binding }} {% endif -%} $(CTX) $@

$(PACK_RESULT_REMAPPED): $(CTX) $(VPR_IOBINDING) $(PACK_RESULT)
	$(PYTHON) -m prga_tools.ioremap $^ $@

$(PLACE_RESULT): $(VPR_ARCHDEF) $(SYNTHESIS_RESULT) $(PACK_RESULT_REMAPPED) $(VPR_IOBINDING)
	$(VPR) $(VPR_ARCHDEF) $(SYNTHESIS_RESULT) --circuit_format eblif --constant_net_method route \
		--net_file $(PACK_RESULT_REMAPPED) \
		--place --place_file $@ --fix_pins $(VPR_IOBINDING) \
		--place_delay_model delta_override --place_chan_width $(VPR_CHAN_WIDTH) \
		| tee $(PLACE_LOG)

$(ROUTE_RESULT): $(VPR_ARCHDEF) $(SYNTHESIS_RESULT) $(VPR_RRGRAPH) $(PACK_RESULT_REMAPPED) $(PLACE_RESULT)
	$(VPR) $(VPR_ARCHDEF) $(SYNTHESIS_RESULT) --circuit_format eblif --constant_net_method route \
		--net_file $(PACK_RESULT_REMAPPED) --place_file $(PLACE_RESULT) \
		--route --route_file $@ --route_chan_width $(VPR_CHAN_WIDTH) --read_rr_graph $(VPR_RRGRAPH) \
		| tee $(ROUTE_LOG)

$(FASM_RESULT): $(VPR_ARCHDEF) $(SYNTHESIS_RESULT) $(VPR_RRGRAPH) $(PACK_RESULT_REMAPPED) $(PLACE_RESULT) $(ROUTE_RESULT)
	$(GENFASM) $(VPR_ARCHDEF) $(SYNTHESIS_RESULT) --circuit_format eblif --analysis \
		--net_file $(PACK_RESULT_REMAPPED) --place_file $(PLACE_RESULT) --route_file $(ROUTE_RESULT) \
		--route_chan_width $(VPR_CHAN_WIDTH) --read_rr_graph $(VPR_RRGRAPH) \
		| tee $(FASM_LOG)

$(BITGEN_RESULT): $(CTX) $(FASM_RESULT)
	$(PYTHON) -m prga_tools.bitchain.bitgen $^ $@

$(TESTBENCH_GENERATED): $(CTX) $(VPR_IOBINDING) $(TARGET_SRCS) $(HOST_SRCS)
	$(PYTHON) -m prga_tools.bitchain.simproj.tbgen \
		-t $(HOST_SRCS) --testbench_top $(HOST) \
		{%- if host.parameters %}--testbench_parameters
			{%- for param, value in iteritems(host.parameters) %} {{ param }}={{ value }}{% endfor %} \
		{%- endif %}
		-m $(TARGET_SRCS) --model_top $(TARGET) \
		{%- if target.parameters %}--model_parameters
			{%- for param, value in iteritems(target.parameters) %} {{ param }}={{ value }}{% endfor %} \
		{%- endif %}
		$(CTX) $(VPR_IOBINDING) $@

$(SIM): $(TESTBENCH_GENERATED) $(TARGET_SRCS) $(HOST_SRCS) $(FPGA_RTL)
	$(COMP) $(FLAGS) $(HOST_FLAGS) $(TARGET_FLAGS) $< -o $@ $(addprefix -v ,$^)

$(SIM_LOG): $(SIM) $(BITGEN_RESULT)
	./$< $(HOST_ARGS) +bitstream_memh=$(BITGEN_RESULT) | tee $@

$(SIM_WAVEFORM): $(SIM) $(BITGEN_RESULT)
	./$< $(HOST_ARGS) +bitstream_memh=$(BITGEN_RESULT) +waveform_dump=$@
