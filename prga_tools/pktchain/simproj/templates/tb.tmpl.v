// Automatically generated by PRGA SimProj generator

`timescale 1ns/1ps

`include "pktchain.vh"
module {{ behav.name }}_tb_wrapper;

    // system control
    reg sys_clk, sys_rst;
    wire sys_success, sys_fail;

    // logging 
    reg             verbose;
    reg [0:256*8-1] waveform_dump;
    reg [31:0]      cycle_count, max_cycle_count;

    // testbench wires
    reg             tb_rst;

    // behavioral model wires
    {%- for name, port in iteritems(behav.ports) %}
    wire {% if port.low is not none %}[{{ port.high - 1 }}:{{ port.low }}] {% endif %}behav_{{ name }};
    {%- endfor %}

    // FPGA implementation wires
    {%- for name, port in iteritems(behav.ports) %}
        {%- if port.direction.name == 'output' %}
    wire {% if port.low is not none %}[{{ port.high - 1 }}:{{ port.low }}] {% endif %}impl_{{ name }};
        {%- endif %}
    {%- endfor %}

    // testbench
    {{ tb.name }} {% if tb.parameters %}#(
        {%- set comma0 = joiner(",") -%}
        {%- for k, v in iteritems(tb.parameters) %}
        {{ comma0() }}.{{ k }}({{ v }})
        {%- endfor %}
    ) {% endif %}host (
        .sys_clk(sys_clk)
        ,.sys_rst(tb_rst)
        ,.sys_success(sys_success)
        ,.sys_fail(sys_fail)
        ,.cycle_count(cycle_count)
        {%- for name, port in iteritems(behav.ports) %}
            {%- if port.direction.name == 'output' %}
        ,.{{ name }}(impl_{{ name }})
            {%- else %}
        ,.{{ name }}(behav_{{ port.name }})
            {%- endif %}
        {%- endfor %}
        );

`ifndef USE_POST_PAR_BEHAVIORAL_MODEL
    // behavioral model
    {{ behav.name }} {% if behav.parameters %}#(
        {%- set comma1 = joiner(",") -%}
        {%- for k, v in iteritems(behav.parameters) %}
        {{ comma1() }}.{{ k }}({{ v }})
        {%- endfor %}
    ) {% endif %}behav (
        {%- set comma2 = joiner(",") -%}
        {%- for name in behav.ports %}
        {{ comma2() }}.{{ name }}(behav_{{ name }})
        {%- endfor %}
        );
`else
    // post-PAR simulation
    {{ behav.name }} behav (
        {%- set comma3 = joiner(",") -%}
        {%- for name, port in iteritems(behav.ports) %}
            {%- if port.low is not none %}
                {%- for i in range(port.low, port.high) %}
        {{ comma3() }}.{{ "\\" ~ name ~ "[" ~ i ~ "]" }} (behav_{{ name ~ "[" ~ i ~ "]" }})
                {%- endfor %}
            {%- else %}
        {{ comma3() }}.{{ "\\" ~ name }} (behav_{{ name }})
            {%- endif %}
        {%- endfor %}
        );
`endif

    // test setup
    initial begin
        verbose = 1'b1;
        if ($test$plusargs("quiet")) begin
            verbose = 1'b0;
        end

        if ($value$plusargs("waveform_dump=%s", waveform_dump)) begin
            if (verbose)
                $display("[INFO] Dumping waveform: %s", waveform_dump);
            $dumpfile(waveform_dump);
            $dumpvars;
        end

        if (!$value$plusargs("max_cycle=%d", max_cycle_count)) begin
            max_cycle_count = 100_000;
        end

        if (verbose)
            $display("[INFO] Max cycle count: %d", max_cycle_count);

        sys_clk = 1'b0;
        sys_rst = 1'b0;
        #{{ (clk_period|default(10)) * 0.25 }} sys_rst = 1'b1;
        #{{ (clk_period|default(10)) * 100 }} sys_rst = 1'b0;
    end

    // system clock generator
    always #{{ (clk_period|default(10)) / 2.0 }} sys_clk = ~sys_clk;

    // cycle count tracking
    always @(posedge sys_clk) begin
        if (sys_rst) begin
            cycle_count <= 0;
        end else begin
            cycle_count <= cycle_count + 1;
        end

        if (~sys_rst && (cycle_count % 1_000 == 0)) begin
            if (verbose)
                $display("[INFO] %3dK cycles passed", cycle_count / 1_000);
        end

        if (~sys_rst && (cycle_count >= max_cycle_count)) begin
            $display("[ERROR] max cycle count reached, killing simulation");
            $finish;
        end
    end

    // test result reporting
    always @* begin
        if (~tb_rst) begin
            if (sys_success) begin
                $display("[INFO] ********* all tests passed **********");
                $finish;
            end else if (sys_fail) begin
                $display("[INFO] ********* test failed **********");
                $finish;
            end
        end
    end

    // configuration (programming) control 
    localparam  INIT                    = 4'd0,
                RESET                   = 4'd1,
                PROGRAMMING_HDR         = 4'd2,
                PROGRAMMING_PLD         = 4'd3,
                STABLIZING_RESP         = 4'd4,
                PROG_DONE               = 4'd5,
                TB_RESET                = 4'd6,
                IMPL_RUNNING            = 4'd7;

    localparam  MAX_BS_FILESIZE_DWORDS = 65536;     // maximum 256MB bitstream size

    reg [3:0]       state;
    reg [0:256*8-1] bs_file;
    reg             cfg_e;
    reg [31:0]      cfg_m [0:MAX_BS_FILESIZE_DWORDS - 1];
    wire            disasm_full, asm_empty;
    reg             disasm_wr, asm_rd;
    wire [31:0]     pkt, bsresp;

    wire [`PRGA_PKTCHAIN_PHIT_WIDTH-1:0]      phit_i;
    wire [`PRGA_PKTCHAIN_PHIT_WIDTH-1:0]      phit_o;
    wire            phit_i_wr, phit_o_full, phit_i_full, phit_o_wr;

    reg [(1 << (`PRGA_PKTCHAIN_POS_WIDTH * 2)) - 1:0] pending_tiles;
    reg [`PRGA_PKTCHAIN_POS_WIDTH * 2 - 1:0] pending_counter;
    reg set_pending, unset_pending;

    integer         total_cfg_frames;
    integer         cfg_progress;
    reg [15:0]      payload;
    reg reset_payload, decrease_payload;

    wire [`PRGA_PKTCHAIN_POS_WIDTH - 1:0]     pkt_x, pkt_y, bsresp_x, bsresp_y;
    assign pkt = cfg_m[cfg_progress];
    assign pkt_x = pkt[`PRGA_PKTCHAIN_XPOS_INDEX];
    assign pkt_y = pkt[`PRGA_PKTCHAIN_YPOS_INDEX];
    assign bsresp_x = bsresp[`PRGA_PKTCHAIN_XPOS_INDEX];
    assign bsresp_y = `PRGA_PKTCHAIN_Y_TILES - 1 - bsresp[`PRGA_PKTCHAIN_YPOS_INDEX];

    pktchain_frame_disassemble disasm (
        .cfg_clk                (sys_clk)
        ,.cfg_rst               (sys_rst)
        ,.frame_full            (disasm_full)
        ,.frame_wr              (disasm_wr)
        ,.frame_i               (pkt)
        ,.phit_wr               (phit_i_wr)
        ,.phit_full             (phit_i_full)
        ,.phit_o                (phit_i)
        );

    pktchain_frame_assemble asm (
        .cfg_clk                (sys_clk)
        ,.cfg_rst               (sys_rst)
        ,.phit_full             (phit_o_full)
        ,.phit_wr               (phit_o_wr)
        ,.phit_i                (phit_o)
        ,.frame_empty           (asm_empty)
        ,.frame_rd              (asm_rd)
        ,.frame_o               (bsresp)
        );

    always @(posedge sys_clk) begin
        if (sys_rst) begin
            pending_counter <= 'b0;
            cfg_progress <= 'b0;
            payload <= 'b0;
        end else begin
            if (~disasm_full && disasm_wr) begin
                cfg_progress <= cfg_progress + 1;
            end

            if (set_pending) begin
                pending_tiles[{pkt_x, pkt_y}] <= 'b1;
                pending_counter <= pending_counter + 1;
            end else if (unset_pending) begin
                pending_tiles[{bsresp_x, bsresp_y}] <= 'b0;
                pending_counter <= pending_counter - 1;
            end

            if (reset_payload) begin
                payload <= cfg_m[cfg_progress][`PRGA_PKTCHAIN_PAYLOAD_INDEX];
            end else if (decrease_payload) begin
                payload <= payload - 1;
            end
        end
    end

    // FPGA implementation
    {{ impl.name }} impl (
        .cfg_clk(sys_clk)
        ,.cfg_rst(sys_rst || state == RESET)
        ,.cfg_e(cfg_e)
        ,.phit_i_wr(phit_i_wr)
        ,.phit_i(phit_i)
        ,.phit_i_full(phit_i_full)
        ,.phit_o_wr(phit_o_wr)
        ,.phit_o(phit_o)
        ,.phit_o_full(phit_o_full)
        {%- for name, port in iteritems(impl.ports) %}
            {%- if port.direction.name == 'output' %}
        ,.{{ name }}(impl_{{ port.name }})
            {%- else %}
        ,.{{ name }}(behav_{{ port.name }})
            {%- endif %}
        {%- endfor %}
        );

    // test setup
    integer i;
    initial begin
        state = INIT;
        cfg_e = 'b0;

        if (!$value$plusargs("bitstream_memh=%s", bs_file)) begin
            if (verbose)
                $display("[ERROR] Missing required argument: bitstream_memh");
            $finish;
        end

        $readmemh(bs_file, cfg_m);

        for (i = 0; i < (1 << (`PRGA_PKTCHAIN_POS_WIDTH * 2)); i = i + 1) begin
            pending_tiles[i] = 'b0;
        end

        for (total_cfg_frames = 0; total_cfg_frames < MAX_BS_FILESIZE_DWORDS && cfg_m[total_cfg_frames] !== 32'bx;
            total_cfg_frames = total_cfg_frames + 1) begin
        end
    end

    // configuration
    always @(posedge sys_clk) begin
        if (sys_rst) begin
            state <= INIT;
        end else begin
            case (state)
                INIT: state <= RESET;
                RESET: state <= PROGRAMMING_HDR;
                PROGRAMMING_HDR: begin
                    if (~asm_empty) begin
                        if (bsresp[`PRGA_PKTCHAIN_PAYLOAD_INDEX] != 0) begin
                            $display("[ERROR] [Cycle %04d] Response payload (%d) > 0", cycle_count, bsresp[`PRGA_PKTCHAIN_PAYLOAD_INDEX]);
                            $finish;
                        end else if (bsresp[`PRGA_PKTCHAIN_XPOS_INDEX] >= `PRGA_PKTCHAIN_X_TILES) begin
                            $display("[ERROR] [Cycle %04d] Response XPOS (%d) > X_TILES (%d)", cycle_count, bsresp[`PRGA_PKTCHAIN_XPOS_INDEX], `PRGA_PKTCHAIN_X_TILES);
                            $finish;
                        end else if (bsresp[`PRGA_PKTCHAIN_YPOS_INDEX] >= `PRGA_PKTCHAIN_Y_TILES) begin
                            $display("[ERROR] [Cycle %04d] Response YPOS (%d) > Y_TILES (%d)", cycle_count, bsresp[`PRGA_PKTCHAIN_YPOS_INDEX], `PRGA_PKTCHAIN_Y_TILES);
                            $finish;
                        end else if (!pending_tiles[{bsresp_x, bsresp_y}]) begin
                            $display("[ERROR] [Cycle %04d] Not expecting response from (%d, %d)", cycle_count, bsresp_x, bsresp_y);
                            $finish;
                        end else begin
                            case (bsresp[`PRGA_PKTCHAIN_MSG_TYPE_INDEX])
                                `PRGA_PKTCHAIN_MSG_TYPE_ERROR_UNKNOWN_MSG_TYPE: begin
                                    $display("[ERROR] [Cycle %04d] Unknown msg type error from (%d, %d)", cycle_count, bsresp_x, bsresp_y);
                                    $finish;
                                end
                                `PRGA_PKTCHAIN_MSG_TYPE_ERROR_ECHO_MISMATCH: begin
                                    $display("[ERROR] [Cycle %04d] Echo mismatch error from (%d, %d)", cycle_count, bsresp_x, bsresp_y);
                                    $finish;
                                end
                                `PRGA_PKTCHAIN_MSG_TYPE_ERROR_CHECKSUM_MISMATCH: begin
                                    $display("[ERROR] [Cycle %04d] Checksum mismatch error from (%d, %d)", cycle_count, bsresp_x, bsresp_y);
                                    $finish;
                                end
                                `PRGA_PKTCHAIN_MSG_TYPE_DATA_ACK: begin
                                    $display("[INFO] [Cycle %04d] DATA_ACK received from (%d, %d)", cycle_count, bsresp_x, bsresp_y);
                                end
                                default: begin
                                    $display("[ERROR] [Cycle %04d] Unknown response: %08x", cycle_count, bsresp);
                                    $finish;
                                end
                            endcase
                        end
                    end else if (cfg_m[cfg_progress] === 32'bx) begin
                        $display("[INFO] [Cycle %04d] Bitstream loading complete", cycle_count);
                        state <= STABLIZING_RESP;
                    end else begin
                        if (pkt_x >= `PRGA_PKTCHAIN_X_TILES) begin
                            $display("[ERROR] [Cycle %04d] Packet XPOS (%d) > X_TILES (%d)", cycle_count, pkt_x, `PRGA_PKTCHAIN_X_TILES);
                            $finish;
                        end else if (pkt_y >= `PRGA_PKTCHAIN_Y_TILES) begin
                            $display("[ERROR] [Cycle %04d] Packet YPOS (%d) > Y_TILES (%d)", cycle_count, pkt_y, `PRGA_PKTCHAIN_Y_TILES);
                            $finish;
                        end else if (pending_tiles[{pkt_x, pkt_y}]) begin
                            $display("[ERROR] [Cycle %04d] CHECKSUM already sent to (%d, %d)", cycle_count, pkt_x, pkt_y);
                            $finish;
                        end else begin
                            if (~disasm_full) begin
                                case (pkt[`PRGA_PKTCHAIN_MSG_TYPE_INDEX])
                                    `PRGA_PKTCHAIN_MSG_TYPE_DATA_INIT: begin
                                        $display("[INFO] [Cycle %04d] INIT sent to (%d, %d)", cycle_count, pkt_x, pkt_y);
                                    end
                                    `PRGA_PKTCHAIN_MSG_TYPE_DATA: begin
                                        $display("[INFO] [Cycle %04d] DATA sent to (%d, %d)", cycle_count, pkt_x, pkt_y);
                                    end
                                    `PRGA_PKTCHAIN_MSG_TYPE_DATA_CHECKSUM: begin
                                        $display("[INFO] [Cycle %04d] CHECKSUM sent to (%d, %d)", cycle_count, pkt_x, pkt_y);
                                    end
                                    `PRGA_PKTCHAIN_MSG_TYPE_DATA_INIT_CHECKSUM: begin
                                        $display("[INFO] [Cycle %04d] INIT_CHECKSUM sent to (%d, %d)", cycle_count, pkt_x, pkt_y);
                                    end
                                    default: begin
                                        $display("[ERROR] [Cycle %04d] Unknown packet: %08x", cycle_count, pkt);
                                        $finish;
                                    end
                                endcase

                                if (pkt[`PRGA_PKTCHAIN_PAYLOAD_INDEX] > 0) begin
                                    state <= PROGRAMMING_PLD;
                                end
                            end
                        end
                    end
                end
                PROGRAMMING_PLD: begin
                    if (cfg_m[cfg_progress] === 32'bx) begin
                        $display("[ERROR] [Cycle %04d] Incomplete packet, %d frames left", cycle_count, payload);
                        $finish;
                    end else if (~disasm_full && payload == 1) begin
                        state <= PROGRAMMING_HDR;
                    end
                end
                STABLIZING_RESP: begin
                    if (pending_counter == 0) begin
                        state <= PROG_DONE;
                    end else if (~asm_empty) begin
                        if (bsresp[`PRGA_PKTCHAIN_PAYLOAD_INDEX] != 0) begin
                            $display("[ERROR] [Cycle %04d] Response payload (%d) > 0", cycle_count, bsresp[`PRGA_PKTCHAIN_PAYLOAD_INDEX]);
                            $finish;
                        end else if (bsresp[`PRGA_PKTCHAIN_XPOS_INDEX] >= `PRGA_PKTCHAIN_X_TILES) begin
                            $display("[ERROR] [Cycle %04d] Response XPOS (%d) > X_TILES (%d)", cycle_count, bsresp[`PRGA_PKTCHAIN_XPOS_INDEX], `PRGA_PKTCHAIN_X_TILES);
                            $finish;
                        end else if (bsresp[`PRGA_PKTCHAIN_YPOS_INDEX] >= `PRGA_PKTCHAIN_Y_TILES) begin
                            $display("[ERROR] [Cycle %04d] Response YPOS (%d) > Y_TILES (%d)", cycle_count, bsresp[`PRGA_PKTCHAIN_YPOS_INDEX], `PRGA_PKTCHAIN_Y_TILES);
                            $finish;
                        end else if (!pending_tiles[{bsresp_x, bsresp_y}]) begin
                            $display("[ERROR] [Cycle %04d] Not expecting response from (%d, %d)", cycle_count, bsresp_x, bsresp_y);
                            $finish;
                        end else begin
                            case (bsresp[`PRGA_PKTCHAIN_MSG_TYPE_INDEX])
                                `PRGA_PKTCHAIN_MSG_TYPE_ERROR_UNKNOWN_MSG_TYPE: begin
                                    $display("[ERROR] [Cycle %04d] Unknown msg type error from (%d, %d)", cycle_count, bsresp_x, bsresp_y);
                                    $finish;
                                end
                                `PRGA_PKTCHAIN_MSG_TYPE_ERROR_ECHO_MISMATCH: begin
                                    $display("[ERROR] [Cycle %04d] Echo mismatch error from (%d, %d)", cycle_count, bsresp_x, bsresp_y);
                                    $finish;
                                end
                                `PRGA_PKTCHAIN_MSG_TYPE_ERROR_CHECKSUM_MISMATCH: begin
                                    $display("[ERROR] [Cycle %04d] Checksum mismatch error from (%d, %d)", cycle_count, bsresp_x, bsresp_y);
                                    $finish;
                                end
                                `PRGA_PKTCHAIN_MSG_TYPE_DATA_ACK: begin
                                    $display("[INFO] [Cycle %04d] DATA_ACK received from (%d, %d)", cycle_count, bsresp_x, bsresp_y);
                                end
                                default: begin
                                    $display("[ERROR] [Cycle %04d] Unknown response: %08x", cycle_count, bsresp);
                                    $finish;
                                end
                            endcase
                        end
                    end
                end
                PROG_DONE: begin
                    $display("[INFO] [Cycle %04d] Programming complete", cycle_count);
                    state <= TB_RESET;
                end
                TB_RESET: begin
                    state <= IMPL_RUNNING;
                end
            endcase
        end
    end

    always @* begin
        cfg_e = 'b0;
        disasm_wr = 'b0;
        asm_rd = 'b0;
        set_pending = 'b0;
        unset_pending = 'b0;
        reset_payload = 'b0;
        decrease_payload = 'b0;

        case (state)
            INIT,
            RESET: begin
                cfg_e = 'b1;
            end
            PROGRAMMING_HDR: begin
                cfg_e = 'b1;
                if (~asm_empty) begin
                    if (bsresp[`PRGA_PKTCHAIN_MSG_TYPE_INDEX] == `PRGA_PKTCHAIN_MSG_TYPE_DATA_ACK) begin
                        asm_rd = 'b1;
                        unset_pending = 'b1;
                    end
                end else begin
                    disasm_wr = 'b1;

                    if (~disasm_full) begin
                        reset_payload = 'b1;
                        set_pending = (pkt[`PRGA_PKTCHAIN_MSG_TYPE_INDEX] == `PRGA_PKTCHAIN_MSG_TYPE_DATA_CHECKSUM ||
                                      pkt[`PRGA_PKTCHAIN_MSG_TYPE_INDEX] == `PRGA_PKTCHAIN_MSG_TYPE_DATA_INIT_CHECKSUM);
                    end
                end
            end
            PROGRAMMING_PLD: begin
                cfg_e = 'b1;

                disasm_wr = 'b1;
                decrease_payload = ~disasm_full;
            end
            STABLIZING_RESP: begin
                cfg_e = 'b1;

                if (~asm_empty && bsresp[`PRGA_PKTCHAIN_MSG_TYPE_INDEX] == `PRGA_PKTCHAIN_MSG_TYPE_DATA_ACK) begin
                    asm_rd = 'b1;
                    unset_pending = 'b1;
                end
            end
        endcase
    end

    always @* begin
        tb_rst = sys_rst || state != IMPL_RUNNING;
    end

    // progress tracking
    reg [7:0]       cfg_percentage;

    always @(posedge sys_clk) begin
        if (sys_rst) begin
            cfg_percentage <= 'b0;
        end else begin
            if (cfg_progress * 100 / total_cfg_frames > cfg_percentage) begin
                cfg_percentage <= cfg_percentage + 1;

                $display("[INFO] Bitstream loading progress: %02d%%", cfg_percentage + 1);
            end
        end
    end

    // output tracking
    always @(posedge sys_clk) begin
        if (~sys_rst && state == IMPL_RUNNING) begin
            {%- for name, port in iteritems(behav.ports) %}
                {%- if port.direction.name == 'output' %}
            if (verbose && impl_{{ name }} !== behav_{{ name }}) begin
                $display("[WARNING] [Cycle %04d] Output mismatch: {{ name }}, impl (%h) != behav (%h)",
                    cycle_count, impl_{{ name }}, behav_{{ name }});
            end
                {%- endif %}
            {%- endfor %}
        end
    end

endmodule
