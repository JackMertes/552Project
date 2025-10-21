module alu_decode(
    input wire [1:0]  i_ALUOp,
    input wire [2:0]  i_funct3,
    input wire [6:0]  i_funct7,
    output reg [2:0] o_opsel,
    output reg       o_sub,
    output reg       o_unsigned,
    output reg       o_arith
);

    always @(*) begin
        case(i_ALUOp)
            2'b00: begin 
                o_opsel = 3'b000; // add for load/store
                o_sub = 1'b0;
                o_unsigned = 1'b0;
                o_arith = 1'b0;
            end
            2'b01: begin
                o_opsel = 3'b000; // subtract for branch
                o_sub = 1'b1;
                o_unsigned = 1'b0;
                o_arith = 1'b0;
            end
            2'b10, 2'b11: begin // R-type and I-type
                case(i_funct3)
                    3'b000: begin // add/sub
                        o_opsel = i_funct3;
                        // Only R-type (ALUOp == 2'b10) can have SUB
                        // I-type (ALUOp == 2'b11) is always ADD
                        if(i_ALUOp == 2'b10 && i_funct7[5]) begin
                            o_sub = 1'b1;
                        end else begin
                            o_sub = 1'b0;
                        end
                        o_unsigned = 1'b0;
                        o_arith = 1'b1;
                    end
                    3'b001: begin // sll
                        o_opsel =i_funct3;
                        o_sub = 1'b0;
                        o_unsigned = 1'b0;
                        o_arith = 1'b0;
                    end
                    3'b010: begin // slt
                        o_opsel =i_funct3;
                        o_sub = 1'b0;
                        o_unsigned = 1'b0;
                        o_arith = 1'b1;
                    end
                    3'b011: begin // sltu
                        o_opsel =i_funct3;
                        o_sub = 1'b0;
                        o_unsigned = 1'b1;
                        o_arith = 1'b1;
                    end
                    3'b100: begin // xor
                        o_opsel =i_funct3;
                        o_sub = 1'b0;
                        o_unsigned = 1'b0;
                        o_arith = 1'b0;
                    end
                    3'b101: begin // srl/sra
                        o_opsel =i_funct3;
                        if(i_funct7[5]) begin
                            o_sub = 1'b1; // sra
                        end else begin
                            o_sub = 1'b0; // srl
                        end
                        o_unsigned = 1'b0;
                        o_arith = i_funct7[5]; // SRA/SRAI: set o_arith for arithmetic right shift
                    end
                    3'b110: begin // or
                        o_opsel =i_funct3;
                        o_sub = 1'b0;
                        o_unsigned = 1'b0;
                        o_arith = 1'b0;
                    end
                    3'b111: begin // and
                        o_opsel =i_funct3;
                        o_sub = 1'b0;
                        o_unsigned = 1'b0;
                        o_arith = 1'b0;
                    end
                    default: begin
                        o_opsel = 3'b000;
                        o_sub = 1'b0;
                        o_unsigned = 1'b0; 
                        o_arith = 1'b0;
                    end
                endcase
            end
            default: begin
                o_opsel = 3'b000;
                o_sub = 1'b0;
                o_unsigned = 1'b0;
                o_arith = 1'b0;
            end
        endcase
    end



	
endmodule