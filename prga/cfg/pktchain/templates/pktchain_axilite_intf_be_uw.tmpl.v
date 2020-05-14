// Automatically generated by PRGA's RTL generator
`include "pktchain_axilite_intf.vh"
module {{ module.name }} (
    // system ctrl signals (in user clock domain)
    input wire [0:0] clk,
    input wire [0:0] rst,

    // == Main Controller Interface ==========================================
    // write request
    input wire [0:0] wval,
    output wire [0:0] wrdy,
    input wire [`PRGA_USER_ADDR_WIDTH - 1:0] waddr,
    input wire [`PRGA_BYTES_PER_USER_DATA - 1:0] wstrb,
    input wire [`PRGA_USER_DATA_WIDTH - 1:0] wdata,

    // write response
    output reg [0:0] wresp_val,
    output reg [1:0] bresp,
    output reg [0:0] req_timeout,
    output reg [0:0] resp_timeout,

    // other signals
    input wire [`PRGA_TIMER_WIDTH - 1:0] timeout_limit,

    // == AXI4-Lite User Interface ===========================================
    output wire [0:0] u_AWVALID,
    input wire [0:0] u_AWREADY,
    output reg [`PRGA_USER_ADDR_WIDTH - 1:0] u_AWADDR,
    output wire [2:0] u_AWPROT,

    // write data channel
    output wire [0:0] u_WVALID,
    input wire [0:0] u_WREADY,
    output reg [`PRGA_USER_DATA_WIDTH - 1:0] u_WDATA,
    output reg [`PRGA_BYTES_PER_USER_DATA - 1:0] u_WSTRB,

    // write response channel
    input wire [0:0] u_BVALID,
    output wire [0:0] u_BREADY,
    input wire [1:0] u_BRESP
    );

    assign u_AWPROT = 'b0;

    // == Stall Signal Declaration ===========================================
    reg stall_req, stall_resp;

    // == Request Posting Stage ==============================================
    reg [`PRGA_TIMER_WIDTH - 1:0] req_timer;
    reg waddr_val, wdata_val;

    always @(posedge clk) begin
        if (rst) begin
            req_timer <= 'b0;
            req_timeout <= 'b0;
            waddr_val <= 'b0;
            wdata_val <= 'b0;
            u_AWADDR <= 'b0;
            u_WSTRB <= 'b0;
            u_WDATA <= 'b0;
        end else begin
            if (wval && wrdy) begin
                req_timer <= timeout_limit;
                waddr_val <= 'b1;
                wdata_val <= 'b1;
                u_AWADDR <= waddr;
                u_WSTRB <= wstrb;
                u_WDATA <= wdata;
            end else if (~stall_resp) begin
                if (u_AWREADY || req_timer == 0) begin
                    waddr_val <= 'b0;
                end

                if (u_WREADY || req_timer == 0) begin
                    wdata_val <= 'b0;
                end

                if (req_timer > 0) begin
                    req_timer <= req_timer - 1;
                end else if ((waddr_val && ~u_AWREADY) || (wdata_val && ~u_WREADY)) begin
                    req_timeout <= 'b1;
                end
            end
        end
    end

    assign wrdy = (~waddr_val || (~stall_resp && u_AWREADY)) && (~wdata_val || (~stall_resp && u_WREADY));
    assign stall_req = rst || req_timeout || stall_resp || (waddr_val && ~u_AWREADY) || (wdata_val && ~u_WREADY);
    assign u_AWVALID = waddr_val && ~stall_resp;
    assign u_WVALID = wdata_val && ~stall_resp;

    // == Response Collecting Stage ==========================================
    reg [`PRGA_TIMER_WIDTH - 1:0] resp_timer;
    reg resp_val;   // response stage valid

    always @(posedge clk) begin
        if (rst) begin
            resp_timer <= 'b0;
            resp_timeout <= 'b0;
            resp_val <= 'b0;
            wresp_val <= 'b0;
            bresp <= 'b0;
        end else begin
            if ((u_AWVALID || u_WVALID) && (~u_AWVALID || u_AWREADY) && (~u_WVALID || u_WREADY)) begin
                resp_timer <= timeout_limit;
                resp_val <= 'b1;
            end else if (resp_val) begin
                if (u_BVALID) begin
                    resp_val <= 'b0;
                end else if (resp_timer == 0) begin
                    resp_val <= 'b0;
                    resp_timeout <= 'b1;
                end else begin
                    resp_timer <= resp_timer - 1;
                end
            end

            if (u_BREADY && u_BVALID) begin
                wresp_val <= 'b1;
                bresp <= u_BRESP;
            end else begin
                wresp_val <= 'b0;
            end
        end
    end

    assign u_BREADY = resp_val;
    assign stall_resp = rst || resp_timeout || (resp_val && ~u_BVALID);

endmodule
