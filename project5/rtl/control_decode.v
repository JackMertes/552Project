`default_nettype none

module control_decode(
    input  wire [6:0] i_opcode,
    output wire       o_branch,
	output wire       o_jalr,
    output wire       o_memRead,
    output wire       o_memToReg,
    output wire       o_memWrite,
    output wire       o_aluSrc,
    output wire       o_regWrite,
    output wire       o_jump,
    output wire [1:0] o_aluOp,
    output wire       o_lui,
    output wire [5:0] o_format
);

    // Identify instruction types
    wire is_rtype  = (i_opcode == 7'b0110011);
    wire is_itype  = (i_opcode == 7'b0010011);
    wire is_load   = (i_opcode == 7'b0000011);
    wire is_store  = (i_opcode == 7'b0100011);
    wire is_branch = (i_opcode == 7'b1100011);
    wire is_lui    = (i_opcode == 7'b0110111);
    wire is_auipc  = (i_opcode == 7'b0010111);
    wire is_jal    = (i_opcode == 7'b1101111);
	wire is_jalr   = (i_opcode == 7'b1100111);

    // Control signals
    assign o_branch   = is_branch;
	assign o_jalr     = is_jalr;
    assign o_memRead  = is_load;
    assign o_memToReg = is_load;
    assign o_memWrite = is_store;
    assign o_aluSrc   = is_itype | is_load | is_store | is_lui | is_auipc | is_jal;
    assign o_regWrite = is_rtype | is_itype | is_load | is_lui | is_auipc | is_jal;
    assign o_jump     = is_jal;
    assign o_lui      = is_lui;

    // ALUOp encoding
    // 00 = load/store/AUIPC/JAL, 01 = branch, 10 = R-type, 11 = I-type
    assign o_aluOp =
        (is_branch) ? 2'b01 :
        (is_rtype)  ? 2'b10 :
        (is_itype)  ? 2'b11 :
        2'b00;

    // Format encoding (one-hot: R, I, S, B, U, J)
    assign o_format =
        (is_rtype)              ? 6'b000001 :
        (is_itype | is_load)    ? 6'b000010 :
        (is_store)              ? 6'b000100 :
        (is_branch)             ? 6'b001000 :
        (is_lui | is_auipc)     ? 6'b010000 :
        (is_jal)                ? 6'b100000 :
        6'b000000;

endmodule

`default_nettype wire
