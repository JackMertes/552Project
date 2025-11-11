module forwarding(
    input wire i_ex_mem_regWrite,
    input wire i_mem_wb_regWrite,
    input wire i_ex_mem_valid,
    input wire i_mem_wb_valid,
    input wire [4:0] i_ex_mem_rd,
    input wire [4:0] i_mem_wb_rd,
    input wire [4:0] i_id_ex_rs1,
    input wire [4:0] i_id_ex_rs2,
    input wire [31:0] i_id_ex_rs1_data,
    input wire [31:0] i_id_ex_rs2_data,
    input wire [31:0] i_ex_mem_alu_result,
    input wire [31:0] i_rd_data_int,
    output wire [31:0] o_op1,
    output wire [31:0] o_op2
);

assign o_op1 = ((i_ex_mem_valid && i_ex_mem_regWrite) && (i_ex_mem_rd != 0) && (i_ex_mem_rd == i_id_ex_rs1)) ? i_ex_mem_alu_result :
               ((i_mem_wb_valid && i_mem_wb_regWrite) && (i_mem_wb_rd != 0) && !(i_ex_mem_valid && i_ex_mem_regWrite && (i_ex_mem_rd != 0) && (i_ex_mem_rd == i_id_ex_rs1)) && (i_mem_wb_rd == i_id_ex_rs1)) ? i_rd_data_int :
                i_id_ex_rs1_data;

assign o_op2 = ((i_ex_mem_valid && i_ex_mem_regWrite) && (i_ex_mem_rd != 0) && (i_ex_mem_rd == i_id_ex_rs2)) ? i_ex_mem_alu_result :
               ((i_mem_wb_valid && i_mem_wb_regWrite) && (i_mem_wb_rd != 0) && !(i_ex_mem_valid && i_ex_mem_regWrite && (i_ex_mem_rd != 0) && (i_ex_mem_rd == i_id_ex_rs2)) && (i_mem_wb_rd == i_id_ex_rs2)) ? i_rd_data_int :
                i_id_ex_rs2_data;

endmodule