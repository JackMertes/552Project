module hazard_unit (
    input  [4:0] i_if_id_rs1,
    input  [4:0] i_if_id_rs2,
    input  [4:0] i_id_ex_rd,
    input        i_id_ex_memRead,
    output       o_stall
);

    wire load_use_hazard;
    
    assign load_use_hazard = i_id_ex_memRead && (i_id_ex_rd != 5'd0) &&
                            ((i_id_ex_rd == i_if_id_rs1) || (i_id_ex_rd == i_if_id_rs2));
    
    assign o_stall = load_use_hazard;

endmodule

`default_nettype wire
