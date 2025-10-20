module branch_decode (
    input i_slt,
    input i_eq,
    input i_branch,
    input [2:0] i_funct3,
    output o_take_branch
);
    assign o_take_branch = (i_branch && ((i_funct3 == 3'b000 && i_eq) || //beq
                                     (i_funct3 == 3'b001 && !i_eq) || //bne
                                     (i_funct3 == 3'b100 && i_slt) || //blt
                                     (i_funct3 == 3'b101 && !i_slt)|| //bge
                                     (i_funct3 == 3'b110 && i_slt) || //bltu
                                     (i_funct3 == 3'b111 && !i_slt)   //bgeu
                                    ));


endmodule


