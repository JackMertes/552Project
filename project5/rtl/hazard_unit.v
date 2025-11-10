module hazard_unit (
    input  [4:0] i_id_rs1,
    input  [4:0] i_id_rs2,
    input  [4:0] i_ex_rd,
    input        i_ex_regWrite,
    input  [4:0] i_mem_rd,
    input        i_mem_regWrite,
    output       o_stall
);

    wire ex_hazard;
    wire mem_hazard;

// EX hazard: if the instruction in the EX stage is writing to a register that
// is being read by the instruction in the ID stage, then we have a hazard.
    assign ex_hazard  = i_ex_regWrite  && (i_ex_rd  != 5'd0) &&
                       ((i_ex_rd  == i_id_rs1) || (i_ex_rd  == i_id_rs2));

// MEM hazard: if the instruction in the MEM stage is writing to a register that
// is being read by the instruction in the ID stage, then we have a hazard.
    assign mem_hazard = i_mem_regWrite && (i_mem_rd != 5'd0) &&
                       ((i_mem_rd == i_id_rs1) || (i_mem_rd == i_id_rs2));

    assign o_stall = ex_hazard | mem_hazard;

endmodule

`default_nettype wire
