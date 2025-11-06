module hazard_unit (
    // ID stage - instruction being decoded
    input  wire [ 4:0] i_id_rs1,           // Source register 1 in ID stage
    input  wire [ 4:0] i_id_rs2,           // Source register 2 in ID stage
    input  wire        i_id_valid,         // ID stage has valid instruction
    
    // EX stage - instruction being executed
    input  wire [ 4:0] i_ex_rd,            // Destination register in EX stage
    input  wire        i_ex_regWrite,      // EX instruction will write to register
    input  wire        i_ex_memRead,       // EX instruction is a load
    input  wire        i_ex_valid,         // EX stage has valid instruction
    
    // MEM stage - instruction accessing memory
    input  wire [ 4:0] i_mem_rd,           // Destination register in MEM stage
    input  wire        i_mem_regWrite,     // MEM instruction will write to register
    input  wire        i_mem_memRead,      // MEM instruction is a load
    input  wire        i_mem_valid,        // MEM stage has valid instruction
    
    // WB stage - instruction writing back
    input  wire [ 4:0] i_wb_rd,            // Destination register in WB stage
    input  wire        i_wb_regWrite,      // WB instruction will write to register
    input  wire        i_wb_valid,         // WB stage has valid instruction
    
    // Hazard detection outputs
    output wire        o_stall,            // Stall IF and ID stages (bubble in EX)
    output wire        o_id_rs1_hazard,    // RS1 has a hazard (for forwarding info)
    output wire        o_id_rs2_hazard     // RS2 has a hazard (for forwarding info)
);

    // ============================================================
    // Load-Use Hazard Detection
    // ============================================================
    // A load-use hazard occurs when:
    // 1. The instruction in EX is a load (memRead)
    // 2. The instruction in ID needs the loaded value
    // 3. The destination of the load matches rs1 or rs2 of ID instruction
    //
    // This requires a 1-cycle stall because the load data won't be
    // available until the end of the MEM stage.
    
    wire ex_load_to_rs1 = i_ex_valid && i_ex_memRead && i_ex_regWrite &&
                          (i_ex_rd != 5'd0) && (i_ex_rd == i_id_rs1) && i_id_valid;
    
    wire ex_load_to_rs2 = i_ex_valid && i_ex_memRead && i_ex_regWrite &&
                          (i_ex_rd != 5'd0) && (i_ex_rd == i_id_rs2) && i_id_valid;
    
    wire load_use_hazard = ex_load_to_rs1 || ex_load_to_rs2;
    
    // ============================================================
    // Additional RAW (Read-After-Write) Hazard Detection
    // ============================================================
    // Without forwarding, we need to detect ALL RAW hazards:
    // - EX stage hazard: instruction in EX will write to a register that ID needs
    // - MEM stage hazard: instruction in MEM will write to a register that ID needs
    // - WB stage hazard: instruction in WB will write to a register that ID needs
    //
    // Note: Register x0 is hardwired to 0, so writes to x0 never cause hazards
    
    // EX stage data hazards (non-load)
    wire ex_data_to_rs1 = i_ex_valid && i_ex_regWrite && !i_ex_memRead &&
                          (i_ex_rd != 5'd0) && (i_ex_rd == i_id_rs1) && i_id_valid;
    
    wire ex_data_to_rs2 = i_ex_valid && i_ex_regWrite && !i_ex_memRead &&
                          (i_ex_rd != 5'd0) && (i_ex_rd == i_id_rs2) && i_id_valid;
    
    wire ex_data_hazard = ex_data_to_rs1 || ex_data_to_rs2;
    
    // MEM stage data hazards
    wire mem_data_to_rs1 = i_mem_valid && i_mem_regWrite &&
                           (i_mem_rd != 5'd0) && (i_mem_rd == i_id_rs1) && i_id_valid;
    
    wire mem_data_to_rs2 = i_mem_valid && i_mem_regWrite &&
                           (i_mem_rd != 5'd0) && (i_mem_rd == i_id_rs2) && i_id_valid;
    
    wire mem_data_hazard = mem_data_to_rs1 || mem_data_to_rs2;
    
    // WB stage data hazards
    // Note: In a pipeline with proper register file design, WB hazards
    // can often be resolved by write-before-read in the same cycle.
    // However, if your register file reads occur before writes in the
    // same cycle, you may need to stall for WB hazards too.
    wire wb_data_to_rs1 = i_wb_valid && i_wb_regWrite &&
                          (i_wb_rd != 5'd0) && (i_wb_rd == i_id_rs1) && i_id_valid;
    
    wire wb_data_to_rs2 = i_wb_valid && i_wb_regWrite &&
                          (i_wb_rd != 5'd0) && (i_wb_rd == i_id_rs2) && i_id_valid;
    
    wire wb_data_hazard = wb_data_to_rs1 || wb_data_to_rs2;
    
    // ============================================================
    // Stall Logic
    // ============================================================
    // Stall scenarios (without forwarding):
    // 1. Load-use hazard: MUST stall 1 cycle
    // 2. EX data hazard: MUST stall 2 cycles (wait for WB)
    // 3. MEM data hazard: MUST stall 1 cycle (wait for WB)
    // 4. WB data hazard: Depends on register file timing
    //    - If register file supports write-before-read (internal forwarding),
    //      no stall needed
    //    - Otherwise, stall 1 cycle
    
    // For a simple implementation without forwarding AND without register file
    // internal bypass (BYPASS_EN=0), we must stall on ALL hazards including WB:
    assign o_stall = load_use_hazard || ex_data_hazard || mem_data_hazard || wb_data_hazard;
    
    // If your register file DOES support internal forwarding (BYPASS_EN=1),
    // where writes in WB are visible to reads in ID during the same cycle,
    // you can remove wb_data_hazard from the stall condition above.
    
    // ============================================================
    // Hazard Information Outputs
    // ============================================================
    // These outputs indicate which registers have hazards, which can be
    // useful for debugging or for implementing forwarding later
    
    assign o_id_rs1_hazard = ex_load_to_rs1 || ex_data_to_rs1 || 
                             mem_data_to_rs1 || wb_data_to_rs1;
    
    assign o_id_rs2_hazard = ex_load_to_rs2 || ex_data_to_rs2 || 
                             mem_data_to_rs2 || wb_data_to_rs2;

endmodule
