`default_nettype none

module alu_decode(
    input  wire [1:0] i_ALUOp,
    input  wire [2:0] i_funct3,
    input  wire [6:0] i_funct7,
    output wire [2:0] o_opsel,
    output wire       o_sub,
    output wire       o_unsigned,
    output wire       o_arith
);

    //operation select: funct3 for R/I types, otherwise ADD
    assign o_opsel =
        (i_ALUOp == 2'b00 || i_ALUOp == 2'b01) ? 3'b000 :
        (i_ALUOp == 2'b10 || i_ALUOp == 2'b11) ? i_funct3 :
        3'b000;

    //subtract only for branch (01) or R-type with funct7[5] == 1 and funct3 == 000
    assign o_sub =
        (i_ALUOp == 2'b01) ? 1'b1 :
        ((i_ALUOp == 2'b10) && (i_funct3 == 3'b000) && i_funct7[5]) ? 1'b1 :
        1'b0;

    // unsigned comparison only for SLTU
    assign o_unsigned =
        ((i_ALUOp == 2'b10 || i_ALUOp == 2'b11) && (i_funct3 == 3'b011)) ? 1'b1 :
        1'b0;

    //arithmetic shift or signed comparison (SLT) or add/sub
    assign o_arith =
        ((i_ALUOp == 2'b10 || i_ALUOp == 2'b11) &&
        ((i_funct3 == 3'b000) || (i_funct3 == 3'b010) || (i_funct3 == 3'b101 && i_funct7[5]))) ?
        1'b1 : 1'b0;

endmodule

`default_nettype wire
