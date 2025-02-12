// abstract view
// synch write, asynch read
`timescale 1ns/1ps
module {{ module.vpr_model }} #(
    parameter   WIDTH   = 6
    ,parameter LUT     = 64'b0
    ) 
    
    (input wire [WIDTH - 1:0] in
    ,input wire [WIDTH - 1:0] wr_addr // write addr
    ,input wire clk
    ,input wire wr_en // write enable
    ,input wire d_in // data
    ,output reg [0:0] out
    );

    logic [(2**WIDTH) - 1:0] data = LUT; // initial TODO: check if works
    // should work in sim but not sure if it is synthesizable
    // PRGA allows for nets to be multiply driven

    always @(posedge clk) begin
        if (wr_en) begin
            data[wr_addr] <= d_in;
        end
    end

    always @* begin
        out = data >> in;
    end

endmodule