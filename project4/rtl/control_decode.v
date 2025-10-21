module control_decode(
    input wire [6:0] i_opcode,
    output reg       o_branch,
    output reg       o_memRead,
    output reg       o_memToReg,
    output reg       o_memWrite,
    output reg       o_aluSrc,
    output reg       o_regWrite,
    output reg       o_jump,
    // aluOP is 00 for load/store, 01 for branch, 10 for R-type, 11 for I-type
    output reg [1:0] o_aluOp,
    output reg       o_lui,
    output wire [5:0] o_format
);

    always @(*) begin
        case(i_opcode)
            7'b0110011: begin // R-type
                o_branch = 1'b0;
                o_memRead = 1'b0;
                o_memToReg = 1'b0;
                o_memWrite = 1'b0;
                o_aluSrc = 1'b0;
                o_regWrite = 1'b1;
                o_jump = 1'b0;
                o_aluOp = 2'b10;
                o_lui = 1'b0;
            end
            7'b0010011: begin // I-type (ALU immediate)
                o_branch = 1'b0;
                o_memRead = 1'b0;
                o_memToReg = 1'b0;
                o_memWrite = 1'b0;
                o_aluSrc = 1'b1;
                o_regWrite = 1'b1;
                o_jump = 1'b0;
                o_aluOp = 2'b11;
                o_lui = 1'b0;
            end
            7'b0000011: begin // Load instructions
                o_branch = 1'b0;
                o_memRead = 1'b1;
                o_memToReg = 1'b1;
                o_memWrite = 1'b0;
                o_aluSrc = 1'b1;
                o_regWrite = 1'b1;
                o_jump = 1'b0;
                o_aluOp = 2'b00;
                o_lui = 1'b0;
            end
            7'b0100011: begin // S-type (Store)
                o_branch = 1'b0;
                o_memRead = 1'b0;
                o_memToReg = 1'b0;
                o_memWrite = 1'b1;
                o_aluSrc = 1'b1;
                o_regWrite = 1'b0;
                o_jump = 1'b0;
                o_aluOp = 2'b00;
                o_lui = 1'b0;
            end
            7'b1100011: begin // B-type (Branch)
                o_branch = 1'b1;
                o_memRead = 1'b0;
                o_memToReg = 1'b0;
                o_memWrite = 1'b0;
                o_aluSrc = 1'b0;
                o_regWrite = 1'b0;
                o_jump = 1'b0;
                o_aluOp = 2'b01;
                o_lui = 1'b0;
            end
            7'b0110111: begin // LUI (Load Upper Immediate)
                o_branch = 1'b0;
                o_memRead = 1'b0;
                o_memToReg = 1'b0;
                o_memWrite = 1'b0;
                o_aluSrc = 1'b1;
                o_regWrite = 1'b1;
                o_jump = 1'b0;
                o_aluOp = 2'b11;
                o_lui = 1'b1;
            end
            7'b0010111: begin // AUIPC (Add Upper Immediate to PC)
                o_branch = 1'b0;
                o_memRead = 1'b0;
                o_memToReg = 1'b0;
                o_memWrite = 1'b0;
                o_aluSrc = 1'b1;
                o_regWrite = 1'b1;
                o_jump = 1'b0;
                o_aluOp = 2'b00;
                o_lui = 1'b0;
            end
            7'b1101111: begin // JAL (Jump and Link)
                o_branch = 1'b0;
                o_memRead = 1'b0;
                o_memToReg = 1'b0;
                o_memWrite = 1'b0;
                o_aluSrc = 1'b1;
                o_regWrite = 1'b1;
                o_jump = 1'b1;
                o_aluOp = 2'b00;
                o_lui = 1'b0;
            end
            default: begin
                o_branch = 1'b0;
                o_memRead = 1'b0;
                o_memToReg = 1'b0;
                o_memWrite = 1'b0;
                o_aluSrc = 1'b0;
                o_regWrite = 1'b0;
                o_jump = 1'b0;
                o_aluOp = 2'b00;
                o_lui = 1'b0;
            end


        endcase
    end

    // format output encoding one-hot: R-type, I-type, S-type, B-type, U-type, J-type
    assign o_format = (i_opcode == 7'b0110011) ? 6'b000001 : // R-type
                      (i_opcode == 7'b0010011 || i_opcode == 7'b0000011) ? 6'b000010 : // I-type
                      (i_opcode == 7'b0100011) ? 6'b000100 : // S-type
                      (i_opcode == 7'b1100011) ? 6'b001000 : // B-type
                      (i_opcode == 7'b0110111 || i_opcode == 7'b0010111) ? 6'b010000 : // U-type
                      (i_opcode == 7'b1101111) ? 6'b100000 : // J-type
                        6'b000000; // default

endmodule