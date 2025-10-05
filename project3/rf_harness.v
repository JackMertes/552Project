`default_nettype none

module rf_nobypass (
    input  wire        i_clk,
    input  wire        i_rst,
    input  wire [ 4:0] i_rs1_raddr,
    output wire [31:0] o_rs1_rdata,
    input  wire [ 4:0] i_rs2_raddr,
    output wire [31:0] o_rs2_rdata,
    input  wire        i_rd_wen,
    input  wire [ 4:0] i_rd_waddr,
    input  wire [31:0] i_rd_wdata
);
    localparam BYPASS_EN = 0;

    rf #(.BYPASS_EN(0)) dut (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_rs1_raddr(i_rs1_raddr),
        .o_rs1_rdata(o_rs1_rdata),
        .i_rs2_raddr(i_rs2_raddr),
        .o_rs2_rdata(o_rs2_rdata),
        .i_rd_wen(i_rd_wen),
        .i_rd_waddr(i_rd_waddr),
        .i_rd_wdata(i_rd_wdata)
    );
endmodule

module rf_bypass (
    input  wire        i_clk,
    input  wire        i_rst,
    input  wire [ 4:0] i_rs1_raddr,
    output wire [31:0] o_rs1_rdata,
    input  wire [ 4:0] i_rs2_raddr,
    output wire [31:0] o_rs2_rdata,
    input  wire        i_rd_wen,
    input  wire [ 4:0] i_rd_waddr,
    input  wire [31:0] i_rd_wdata
);
    localparam BYPASS_EN = 1;

    rf #(.BYPASS_EN(1)) dut (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_rs1_raddr(i_rs1_raddr),
        .o_rs1_rdata(o_rs1_rdata),
        .i_rs2_raddr(i_rs2_raddr),
        .o_rs2_rdata(o_rs2_rdata),
        .i_rd_wen(i_rd_wen),
        .i_rd_waddr(i_rd_waddr),
        .i_rd_wdata(i_rd_wdata)
    );
endmodule

`default_nettype wire
