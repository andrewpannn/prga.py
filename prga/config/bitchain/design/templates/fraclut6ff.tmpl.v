// Automatically generated by PRGA's RTL generator
module fraclut6ff (
    // user-accessible ports
    input wire [0:0] clk,
    input wire [5:0] in,
    output reg [0:0] o6,
    output reg [0:0] o5,

    // config ports
    input wire [0:0] cfg_clk,
    input wire [0:0] cfg_e,
    input wire [0:0] cfg_we,
    input wire [0:0] cfg_i,
    output wire [0:0] cfg_o
    );

    // mode enum
    localparam MODE_LUT6 = 1'd0;
    localparam MODE_LUT5X2 = 1'd1;

    // prog bits
    localparam NUM_CFG_BITS = 67;
    reg [NUM_CFG_BITS - 1:0] cfg_d;

    // decode prog bits
    wire mode;
    wire [1:0] ff_en;
    wire [63:0] lut_data;

    assign {mode, ff_en, lut_data} = cfg_d;

    // convert 'x' inputs to '0' in simulation
    reg [5:0] internal_in;

    always @* begin
        internal_in = in;

        // synopsys translate off
        {%- for i in range(6) %}
        if (in[{{ i }}] === 1'bx || in[{{ i }}] === 1'bz) begin
            internal_in[{{ i }}] = 1'b0;
        end
        {%- endfor %}
        // synopsys translate on
    end

    // lut5 output
    reg [1:0] internal_lut5;
    {%- for i in range(2) %}
    always @* begin
        case (internal_in[4:0])  // synopsys infer_mux
            {%- for j in range(32) %}
            5'd{{ j }}: begin
                internal_lut5[{{ i }}] = lut_data[{{ 32 * i + j }}];
            end
            {%- endfor %}
        endcase
    end
    {%- endfor %}

    // flipflop
    reg [1:0] internal_ff;
    always @(posedge clk) begin
        internal_ff <= internal_lut5;
    end

    // lut6 and lut5
    always @* begin
        if (ff_en[1]) begin
            o5 = internal_ff[1];
        end else begin
            o5 = internal_lut5[1];
        end

        case (mode)             // synopsys infer_mux
            MODE_LUT5X2: begin
                if (ff_en[0]) begin
                    o6 = internal_ff[0];
                end else begin
                    o6 = internal_lut5[0];
                end
            end
            MODE_LUT6: begin
                if (ff_en[0]) begin
                    o6 = internal_ff[internal_in[5]];
                end else begin
                    o6 = internal_lut5[internal_in[5]];
                end
            end
        endcase
    end

    always @(posedge cfg_clk) begin
        if (cfg_e && cfg_we) begin    // configuring
            cfg_d <= {cfg_d, cfg_i};
        end
    end

    assign cfg_o = cfg_d[NUM_CFG_BITS - 1];

endmodule

