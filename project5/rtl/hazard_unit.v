module hazard_unit (
    input  [4:0] id_rs1,
    input  [4:0] id_rs2,
    input  [4:0] ex_rd,
    input        ex_regWrite,
    input  [4:0] mem_rd,
    input        mem_regWrite,
    output       hazard
);

    wire ex_hazard;
    wire mem_hazard;

// EX hazard: if the instruction in the EX stage is writing to a register that
// is being read by the instruction in the ID stage, then we have a hazard.
    assign ex_hazard  = ex_regWrite  && (ex_rd  != 5'd0) &&
                       ((ex_rd  == id_rs1) || (ex_rd  == id_rs2));

// MEM hazard: if the instruction in the MEM stage is writing to a register that
// is being read by the instruction in the ID stage, then we have a hazard.
    assign mem_hazard = mem_regWrite && (mem_rd != 5'd0) &&
                       ((mem_rd == id_rs1) || (mem_rd == id_rs2));

    assign hazard = ex_hazard | mem_hazard;

endmodule

`default_nettype wire
