module hart #(
    // After reset, the program counter (PC) should be initialized to this
    // address and start executing instructions from there.
    parameter RESET_ADDR = 32'h00000000
) (
    // Global clock.
    input  wire        i_clk,
    // Synchronous active-high reset.
    input  wire        i_rst,
    // Instruction fetch goes through a read only instruction memory (imem)
    // port. The port accepts a 32-bit address (e.g. from the program counter)
    // per cycle and combinationally returns a 32-bit instruction word. This
    // is not representative of a realistic memory interface; it has been
    // modeled as more similar to a DFF or SRAM to simplify phase 3. In
    // later phases, you will replace this with a more realistic memory.
    //
    // 32-bit read address for the instruction memory. This is expected to be
    // 4 byte aligned - that is, the two LSBs should be zero.
    output wire [31:0] o_imem_raddr,
    // Instruction word fetched from memory, available synchronously after
    // the next clock edge.
    // NOTE: This is different from the previous phase. To accomodate a
    // multi-cycle pipelined design, the instruction memory read is
    // now synchronous.
    input  wire [31:0] i_imem_rdata,
    // Data memory accesses go through a separate read/write data memory (dmem)
    // that is shared between read (load) and write (stored). The port accepts
    // a 32-bit address, read or write enable, and mask (explained below) each
    // cycle. Reads are combinational - values are available immediately after
    // updating the address and asserting read enable. Writes occur on (and
    // are visible at) the next clock edge.
    //
    // Read/write address for the data memory. This should be 32-bit aligned
    // (i.e. the two LSB should be zero). See `o_dmem_mask` for how to perform
    // half-word and byte accesses at unaligned addresses.
    output wire [31:0] o_dmem_addr,
    // When asserted, the memory will perform a read at the aligned address
    // specified by `i_addr` and return the 32-bit word at that address
    // immediately (i.e. combinationally). It is illegal to assert this and
    // `o_dmem_wen` on the same cycle.
    output wire        o_dmem_ren,
    // When asserted, the memory will perform a write to the aligned address
    // `o_dmem_addr`. When asserted, the memory will write the bytes in
    // `o_dmem_wdata` (specified by the mask) to memory at the specified
    // address on the next rising clock edge. It is illegal to assert this and
    // `o_dmem_ren` on the same cycle.
    output wire        o_dmem_wen,
    // The 32-bit word to write to memory when `o_dmem_wen` is asserted. When
    // write enable is asserted, the byte lanes specified by the mask will be
    // written to the memory word at the aligned address at the next rising
    // clock edge. The other byte lanes of the word will be unaffected.
    output wire [31:0] o_dmem_wdata,
    // The dmem interface expects word (32 bit) aligned addresses. However,
    // WISC-25 supports byte and half-word loads and stores at unaligned and
    // 16-bit aligned addresses, respectively. To support this, the access
    // mask specifies which bytes within the 32-bit word are actually read
    // from or written to memory.
    //
    // To perform a half-word read at address 0x00001002, align `o_dmem_addr`
    // to 0x00001000, assert `o_dmem_ren`, and set the mask to 0b1100 to
    // indicate that only the upper two bytes should be read. Only the upper
    // two bytes of `i_dmem_rdata` can be assumed to have valid data; to
    // calculate the final value of the `lh[u]` instruction, shift the rdata
    // word right by 16 bits and sign/zero extend as appropriate.
    //
    // To perform a byte write at address 0x00002003, align `o_dmem_addr` to
    // `0x00002000`, assert `o_dmem_wen`, and set the mask to 0b1000 to
    // indicate that only the upper byte should be written. On the next clock
    // cycle, the upper byte of `o_dmem_wdata` will be written to memory, with
    // the other three bytes of the aligned word unaffected. Remember to shift
    // the value of the `sb` instruction left by 24 bits to place it in the
    // appropriate byte lane.
    output wire [ 3:0] o_dmem_mask,
    // The 32-bit word read from data memory. When `o_dmem_ren` is asserted,
    // after the next clock edge, this will reflect the contents of memory
    // at the specified address, for the bytes enabled by the mask. When
    // read enable is not asserted, or for bytes not set in the mask, the
    // value is undefined.
    // NOTE: This is different from the previous phase. To accomodate a
    // multi-cycle pipelined design, the data memory read is
    // now synchronous.
    input  wire [31:0] i_dmem_rdata,
	// The output `retire` interface is used to signal to the testbench that
    // the CPU has completed and retired an instruction. A single cycle
    // implementation will assert this every cycle; however, a pipelined
    // implementation that needs to stall (due to internal hazards or waiting
    // on memory accesses) will not assert the signal on cycles where the
    // instruction in the writeback stage is not retiring.
    //
    // Asserted when an instruction is being retired this cycle. If this is
    // not asserted, the other retire signals are ignored and may be left invalid.
    output wire        o_retire_valid,
    // The 32 bit instruction word of the instrution being retired. This
    // should be the unmodified instruction word fetched from instruction
    // memory.
    output wire [31:0] o_retire_inst,
    // Asserted if the instruction produced a trap, due to an illegal
    // instruction, unaligned data memory access, or unaligned instruction
    // address on a taken branch or jump.
    output wire        o_retire_trap,
    // Asserted if the instruction is an `ebreak` instruction used to halt the
    // processor. This is used for debugging and testing purposes to end
    // a program.
    output wire        o_retire_halt,
    // The first register address read by the instruction being retired. If
    // the instruction does not read from a register (like `lui`), this
    // should be 5'd0.
    output wire [ 4:0] o_retire_rs1_raddr,
    // The second register address read by the instruction being retired. If
    // the instruction does not read from a second register (like `addi`), this
    // should be 5'd0.
    output wire [ 4:0] o_retire_rs2_raddr,
    // The first source register data read from the register file (in the
    // decode stage) for the instruction being retired. If rs1 is 5'd0, this
    // should also be 32'd0.
    output wire [31:0] o_retire_rs1_rdata,
    // The second source register data read from the register file (in the
    // decode stage) for the instruction being retired. If rs2 is 5'd0, this
    // should also be 32'd0.
    output wire [31:0] o_retire_rs2_rdata,
    // The destination register address written by the instruction being
    // retired. If the instruction does not write to a register (like `sw`),
    // this should be 5'd0.
    output wire [ 4:0] o_retire_rd_waddr,
    // The destination register data written to the register file in the
    // writeback stage by this instruction. If rd is 5'd0, this field is
    // ignored and can be treated as a don't care.
    output wire [31:0] o_retire_rd_wdata,
    // The following data memory retire interface is used to record the
    // memory transactions completed by the instruction being retired.
    // As such, it mirrors the transactions happening on the main data
    // memory interface (o_dmem_* and i_dmem_*) but is delayed to match
    // the retirement of the instruction. You can hook this up by just
    // registering the main dmem interface signals into the writeback
    // stage of your pipeline.
    //
    // All these fields are don't-care for instructions that do not
    // access data memory (o_retire_dmem_ren and o_retire_dmem_wen
    // not asserted).
    // NOTE: This interface is new for phase 5 in order to account for
    // the delay between data memory accesses and instruction retire.
    //
    // The 32-bit data memory address accessed by the instruction.
    output wire [31:0] o_retire_dmem_addr,
    // The byte masked used for the data memory access.
    output wire [ 3:0] o_retire_dmem_mask,
    // Asserted if the instruction performed a read (load) from data memory.
    output wire        o_retire_dmem_ren,
    // Asserted if the instruction performed a write (store) to data memory.
    output wire        o_retire_dmem_wen,
    // The 32-bit data read from memory by a load instruction.
    output wire [31:0] o_retire_dmem_rdata,
    // The 32-bit data written to memory by a store instruction.
    output wire [31:0] o_retire_dmem_wdata,
    // The current program counter of the instruction being retired - i.e.
    // the instruction memory address that the instruction was fetched from.
    output wire [31:0] o_retire_pc,
    // the next program counter after the instruction is retired. For most
    // instructions, this is `o_retire_pc + 4`, but must be the branch or jump
    // target for *taken* branches and jumps.
    output wire [31:0] o_retire_next_pc

`ifdef RISCV_FORMAL
    ,`RVFI_OUTPUTS,
`endif
);

// ============================================================
// PC and IF stage
// ============================================================

reg [31:0] pc;
wire [31:0] pc_next;
reg [31:0] pc_fetch;  // The PC of the instruction currently being fetched

// Track when first synchronous imem data is "real"
reg fetch_ready;

assign o_imem_raddr = pc;

// ============================================================
// Pipeline registers
// ============================================================

// IF/ID
reg [31:0] if_id_pc;
reg [31:0] if_id_inst;
reg        if_id_valid;

// ID/EX
reg [31:0] id_ex_pc;
reg [31:0] id_ex_rs1_data;
reg [31:0] id_ex_rs2_data;
reg [ 4:0] id_ex_rs1;
reg [ 4:0] id_ex_rs2;
reg [ 4:0] id_ex_rd;
reg [31:0] id_ex_imm;
reg [ 2:0] id_ex_funct3;
reg [ 6:0] id_ex_funct7;
reg [ 6:0] id_ex_opcode;
reg [ 5:0] id_ex_format;

reg        id_ex_branch;
reg        id_ex_jalr;
reg        id_ex_memRead;
reg        id_ex_memToReg;
reg        id_ex_memWrite;
reg        id_ex_aluSrc;
reg        id_ex_regWrite;
reg        id_ex_jump;
reg        id_ex_lui;
reg [ 1:0] id_ex_aluOp;

reg        id_ex_valid;
reg [31:0] id_ex_inst;

// EX/MEM
reg [31:0] ex_mem_pc;
reg [31:0] ex_mem_next_pc;
reg [31:0] ex_mem_alu_result;
reg [31:0] ex_mem_rs1_data;
reg [31:0] ex_mem_rs2_data;
reg [ 4:0] ex_mem_rs1;
reg [ 4:0] ex_mem_rs2;
reg [ 4:0] ex_mem_rd;
reg [31:0] ex_mem_imm;
reg [ 2:0] ex_mem_funct3;
reg [ 6:0] ex_mem_opcode;
reg [ 5:0] ex_mem_format;

reg        ex_mem_memRead;
reg        ex_mem_memToReg;
reg        ex_mem_memWrite;
reg        ex_mem_regWrite;
reg        ex_mem_jump;
reg        ex_mem_lui;

reg        ex_mem_valid;
reg [31:0] ex_mem_inst;

// MEM/WB
reg [31:0] mem_wb_pc;
reg [31:0] mem_wb_next_pc;
reg [31:0] mem_wb_alu_result;
reg [31:0] mem_wb_rs1_data;
reg [31:0] mem_wb_rs2_data;
reg [ 4:0] mem_wb_rs1;
reg [ 4:0] mem_wb_rs2;
reg [ 4:0] mem_wb_rd;
reg [31:0] mem_wb_imm;
reg [ 2:0] mem_wb_funct3;
reg [ 6:0] mem_wb_opcode;
reg [ 5:0] mem_wb_format;

reg        mem_wb_memToReg;
reg        mem_wb_regWrite;
reg        mem_wb_jump;
reg        mem_wb_lui;

reg        mem_wb_valid;
reg [31:0] mem_wb_inst;

// dmem retire info in MEM/WB
reg        mem_wb_memRead;
reg        mem_wb_memWrite;
reg [31:0] mem_wb_dmem_addr;
reg [ 3:0] mem_wb_dmem_mask;
reg [31:0] mem_wb_dmem_wdata;
reg [31:0] mem_wb_load_data;

wire stall;

// ============================================================
// ID stage: instruction fields and control
// ============================================================

wire [31:0] curr_instruction = if_id_inst;

wire [6:0] opcode  = curr_instruction[6:0];
wire [4:0] rd      = curr_instruction[11:7];
wire [2:0] funct3  = curr_instruction[14:12];
wire [4:0] rs1     = curr_instruction[19:15];
wire [4:0] rs2     = curr_instruction[24:20];
wire [6:0] funct7  = curr_instruction[31:25];

wire        branch;
wire        jalr;
wire        memRead;
wire        memToReg;
wire        memWrite;
wire        aluSrc;
wire        regWrite;
wire        jump;
wire [1:0]  aluOp;
wire        lui;
wire        auipc;    // Add auipc control signal
wire [5:0]  format;

wire [31:0] rs1_data;
wire [31:0] rs2_data;
wire [31:0] rd_data;
wire [31:0] immediate;

// ============================================================
// EX stage wires
// ============================================================

wire [31:0] ex_alu_op2;
wire [31:0] ex_alu_result;
wire        ex_alu_eq;
wire        ex_alu_slt;

wire [2:0]  ex_opsel;
wire        ex_sub;
wire        ex_unsigned;
wire        ex_arith;

wire        ex_take_branch;

// id_ex_pc contains the actual PC of the instruction (not PC+4)
// For PC-relative control transfers (branches/JAL), the target is PC + imm
wire [31:0] ex_pc_plus4  = id_ex_pc + 32'd4;
wire [31:0] ex_pc_branch = id_ex_pc + id_ex_imm;
wire [31:0] ex_pc_jalr   = (id_ex_rs1_data + id_ex_imm) & ~32'b1;

// Gate control with id_ex_valid
wire ex_branch_taken = id_ex_valid && ex_take_branch;
wire ex_jump_taken   = id_ex_valid && id_ex_jump;
wire ex_jalr_taken   = id_ex_valid && id_ex_jalr;

// Combined "control transfer" signal for flushing
wire ex_ctrl_flush   = ex_branch_taken || ex_jump_taken || ex_jalr_taken;

// For this instruction's architectural next PC (for retire)
wire [31:0] ex_next_pc =
    ex_jalr_taken                      ? ex_pc_jalr   :
    (ex_jump_taken || ex_branch_taken) ? ex_pc_branch :
                                         ex_pc_plus4;

// Global PC next (for fetch)
// When a branch/jump/jalr is taken, use the calculated target address
// Otherwise increment PC normally
assign pc_next = ex_ctrl_flush ? ex_next_pc : (pc + 32'd4);

// ============================================================
// MEM stage wires
// ============================================================

wire [31:0] dmem_addr;
wire [31:0] dmem_wdata;
wire [ 3:0] dmem_mask;
wire [31:0] load_data_mem;

// ============================================================
// Writeback mux (WB stage)
// ============================================================

// WB stage wires
// ============================================================

// Calculate load data in WB stage from registered dmem data
wire [31:0] wb_load_data =
    (mem_wb_funct3 == 3'b000) ? // LB
        {{24{i_dmem_rdata[7 + 8*mem_wb_alu_result[1:0]]}},
         i_dmem_rdata[8*mem_wb_alu_result[1:0]+:8]} :
    (mem_wb_funct3 == 3'b001) ? // LH
        (mem_wb_alu_result[1]
            ? {{16{i_dmem_rdata[31]}}, i_dmem_rdata[31:16]}
            : {{16{i_dmem_rdata[15]}}, i_dmem_rdata[15:0]}) :
    (mem_wb_funct3 == 3'b100) ? // LBU
        {24'b0, i_dmem_rdata[8*mem_wb_alu_result[1:0]+:8]} :
    (mem_wb_funct3 == 3'b101) ? // LHU
        (mem_wb_alu_result[1]
            ? {16'b0, i_dmem_rdata[31:16]}
            : {16'b0, i_dmem_rdata[15:0]}) :
        i_dmem_rdata;

wire [31:0] wb_int =
    mem_wb_memToReg ? wb_load_data :
    mem_wb_lui      ? mem_wb_imm   :
                      mem_wb_alu_result;

wire [31:0] rd_data_int =
    mem_wb_jump                   ? (mem_wb_pc + 32'd4)      :  // JAL
    (mem_wb_opcode == 7'b0010111) ? (mem_wb_pc + mem_wb_imm) :  // AUIPC
                                    wb_int;

// ============================================================
// Modules
// ============================================================

control_decode control (
    .i_opcode (opcode),
    .o_branch (branch),
    .o_jalr   (jalr),
    .o_memRead(memRead),
    .o_memToReg(memToReg),
    .o_memWrite(memWrite),
    .o_aluSrc (aluSrc),
    .o_regWrite(regWrite),
    .o_jump   (jump),
    .o_aluOp  (aluOp),
    .o_lui    (lui),
    .o_auipc  (auipc),
    .o_format (format)
);

rf rf_inst (
    .i_clk      (i_clk),
    .i_rst      (i_rst),
    .i_rs1_raddr(rs1),
    .o_rs1_rdata(rs1_data),
    .i_rs2_raddr(rs2),
    .o_rs2_rdata(rs2_data),
    .i_rd_wen   (mem_wb_regWrite),
    .i_rd_waddr (mem_wb_rd),
    .i_rd_wdata (rd_data_int)
);

imm imm_inst (
    .i_inst   (curr_instruction),
    .i_format (format),
    .o_immediate(immediate)
);

alu_decode alu_dec (
    .i_ALUOp  (id_ex_aluOp),
    .i_funct3 (id_ex_funct3),
    .i_funct7 (id_ex_funct7),
    .o_opsel  (ex_opsel),
    .o_sub    (ex_sub),
    .o_unsigned(ex_unsigned),
    .o_arith  (ex_arith)
);

assign ex_alu_op2 = id_ex_aluSrc ? id_ex_imm : id_ex_rs2_data;

alu alu_inst (
    .i_opsel   (ex_opsel),
    .i_sub     (ex_sub),
    .i_unsigned(ex_unsigned),
    .i_arith   (ex_arith),
    .i_op1     (id_ex_rs1_data),
    .i_op2     (ex_alu_op2),
    .o_result  (ex_alu_result),
    .o_eq      (ex_alu_eq),
    .o_slt     (ex_alu_slt)
);

branch_decode branch_dec_inst (
    .i_slt   (ex_alu_slt),
    .i_funct3(id_ex_funct3),
    .i_eq    (ex_alu_eq),
    .i_branch(id_ex_branch),
    .o_take_branch(ex_take_branch)
);

// ============================================================
// Data memory (MEM) combinational logic
// ============================================================

assign dmem_addr = {ex_mem_alu_result[31:2], 2'b00};

assign dmem_wdata =
    (ex_mem_funct3 == 3'b000 || ex_mem_funct3 == 3'b100) ? // SB/SBU
        (ex_mem_rs2_data[7:0] << (8 * ex_mem_alu_result[1:0])) :
    (ex_mem_funct3 == 3'b001 || ex_mem_funct3 == 3'b101) ? // SH/SHU
        (ex_mem_alu_result[1]
            ? ({{16{ex_mem_rs2_data[15]}}, ex_mem_rs2_data[15:0]} << 16)
            :  {{16{ex_mem_rs2_data[15]}}, ex_mem_rs2_data[15:0]}) :
        ex_mem_rs2_data; // SW

assign dmem_mask =
    (ex_mem_funct3 == 3'b000 || ex_mem_funct3 == 3'b100) ? // LB/LBU/SB
        (4'b0001 << ex_mem_alu_result[1:0]) :
    (ex_mem_funct3 == 3'b001 || ex_mem_funct3 == 3'b101) ? // LH/LHU/SH
        (4'b0011 << {ex_mem_alu_result[1], 1'b0}) :
        4'b1111; // LW/SW

assign o_dmem_addr  = dmem_addr;
assign o_dmem_wdata = dmem_wdata;
assign o_dmem_mask  = dmem_mask;
assign o_dmem_ren   = ex_mem_memRead;
assign o_dmem_wen   = ex_mem_memWrite;

// ============================================================
// Sequential logic: PC + pipeline regs
// ============================================================

always @(posedge i_clk) begin
    if (i_rst) begin
        pc           <= RESET_ADDR;
        pc_fetch     <= RESET_ADDR;
        fetch_ready  <= 1'b0;

        if_id_valid  <= 1'b0;
        id_ex_valid  <= 1'b0;
        ex_mem_valid <= 1'b0;
        mem_wb_valid <= 1'b0;

        if_id_pc     <= 32'd0;
        if_id_inst   <= 32'd0;

        id_ex_pc     <= 32'd0;
        id_ex_rs1_data <= 32'd0;
        id_ex_rs2_data <= 32'd0;
        id_ex_rs1    <= 5'd0;
        id_ex_rs2    <= 5'd0;
        id_ex_rd     <= 5'd0;
        id_ex_imm    <= 32'd0;
        id_ex_funct3 <= 3'd0;
        id_ex_funct7 <= 7'd0;
        id_ex_opcode <= 7'd0;
        id_ex_format <= 6'd0;
        id_ex_branch <= 1'b0;
        id_ex_jalr   <= 1'b0;
        id_ex_memRead<= 1'b0;
        id_ex_memToReg<=1'b0;
        id_ex_memWrite<=1'b0;
        id_ex_aluSrc <= 1'b0;
        id_ex_regWrite<=1'b0;
        id_ex_jump   <= 1'b0;
        id_ex_lui    <= 1'b0;
        id_ex_aluOp  <= 2'd0;
        id_ex_inst   <= 32'd0;

        ex_mem_pc       <= 32'd0;
        ex_mem_next_pc  <= 32'd0;
        ex_mem_alu_result <= 32'd0;
        ex_mem_rs1_data <= 32'd0;
        ex_mem_rs2_data <= 32'd0;
        ex_mem_rs1      <= 5'd0;
        ex_mem_rs2      <= 5'd0;
        ex_mem_rd       <= 5'd0;
        ex_mem_imm      <= 32'd0;
        ex_mem_funct3   <= 3'd0;
        ex_mem_opcode   <= 7'd0;
        ex_mem_format   <= 6'd0;
        ex_mem_memRead  <= 1'b0;
        ex_mem_memToReg <= 1'b0;
        ex_mem_memWrite <= 1'b0;
        ex_mem_regWrite <= 1'b0;
        ex_mem_jump     <= 1'b0;
        ex_mem_lui      <= 1'b0;
        ex_mem_inst     <= 32'd0;

        mem_wb_pc       <= 32'd0;
        mem_wb_next_pc  <= 32'd0;
        mem_wb_alu_result <= 32'd0;
        mem_wb_rs1_data <= 32'd0;
        mem_wb_rs2_data <= 32'd0;
        mem_wb_rs1      <= 5'd0;
        mem_wb_rs2      <= 5'd0;
        mem_wb_rd       <= 5'd0;
        mem_wb_imm      <= 32'd0;
        mem_wb_funct3   <= 3'd0;
        mem_wb_opcode   <= 7'd0;
        mem_wb_format   <= 6'd0;
        mem_wb_memToReg <= 1'b0;
        mem_wb_regWrite <= 1'b0;
        mem_wb_jump     <= 1'b0;
        mem_wb_lui      <= 1'b0;
        mem_wb_inst     <= 32'd0;

        mem_wb_memRead  <= 1'b0;
        mem_wb_memWrite <= 1'b0;
        mem_wb_dmem_addr<= 32'd0;
        mem_wb_dmem_mask<= 4'd0;
        mem_wb_dmem_wdata<=32'd0;

    end else begin
        // PC update - pc_fetch tracks the address we're fetching from this cycle
        if (ex_ctrl_flush) begin
            // On control transfer, update both PC and pc_fetch to target
            pc <= ex_next_pc;
            pc_fetch <= ex_next_pc;
            fetch_ready <= 1'b0;  // Mark next fetch as invalid since we're changing course
        end else if (stall) begin
            pc <= pc;           // Hold PC steady during stall
        end else begin
            pc_fetch <= pc;       // Track current PC for fetch
            pc <= pc_next;        // Normal PC increment
            fetch_ready <= 1'b1;  // Normal fetch is valid
        end

        // ----------------------------------------------------
        // IF/ID
        // ----------------------------------------------------
        if_id_pc    <= pc_fetch;  // Use the registered fetch PC
        if_id_inst  <= i_imem_rdata;
        if_id_valid <= fetch_ready;

        // ----------------------------------------------------
        // ID/EX
        // ----------------------------------------------------
        if (stall) begin
            // Hold ID/EX steady during stall
            id_ex_pc       <= id_ex_pc;
            id_ex_rs1_data <= id_ex_rs1_data;
            id_ex_rs2_data <= id_ex_rs2_data;
            id_ex_rs1      <= id_ex_rs1;
            id_ex_rs2      <= id_ex_rs2;
            id_ex_rd       <= id_ex_rd;
            id_ex_imm      <= id_ex_imm;
            id_ex_funct3   <= id_ex_funct3;
            id_ex_funct7   <= id_ex_funct7;
            id_ex_opcode   <= id_ex_opcode;
            id_ex_format   <= id_ex_format;
            id_ex_branch   <= id_ex_branch;
            id_ex_jalr     <= id_ex_jalr;
            id_ex_memRead  <= id_ex_memRead;
            id_ex_memToReg <= id_ex_memToReg;
            id_ex_memWrite <= id_ex_memWrite;
            id_ex_aluSrc   <= id_ex_aluSrc;
            id_ex_regWrite <= id_ex_regWrite;
            id_ex_jump     <= id_ex_jump;
            id_ex_lui      <= id_ex_lui;
            id_ex_aluOp    <= id_ex_aluOp;
            // Keep valid and inst steady during stall
        end else begin
            id_ex_pc       <= if_id_pc;
            id_ex_rs1_data <= rs1_data;
            id_ex_rs2_data <= rs2_data;
            id_ex_rs1      <= rs1;
            id_ex_rs2      <= rs2;
            id_ex_rd       <= rd;
            id_ex_imm      <= immediate;
            id_ex_funct3   <= funct3;
            id_ex_funct7   <= funct7;
            id_ex_opcode   <= opcode;
            id_ex_format   <= format;
            id_ex_branch   <= branch;
            id_ex_jalr     <= jalr;
            id_ex_memRead  <= memRead;
            id_ex_memToReg <= memToReg;
            id_ex_memWrite <= memWrite;
            id_ex_aluSrc   <= aluSrc;
            id_ex_regWrite <= regWrite;
            id_ex_jump     <= jump;
            id_ex_lui      <= lui;
            id_ex_aluOp    <= aluOp;
            id_ex_valid    <= if_id_valid;
            id_ex_inst     <= if_id_inst;
        end
        // ----------------------------------------------------
        // EX/MEM
        // ----------------------------------------------------
        ex_mem_pc         <= id_ex_pc;
        ex_mem_next_pc    <= ex_next_pc;
        ex_mem_alu_result <= ex_alu_result;
        ex_mem_rs1_data   <= id_ex_rs1_data;
        ex_mem_rs2_data   <= id_ex_rs2_data;
        ex_mem_rs1        <= id_ex_rs1;
        ex_mem_rs2        <= id_ex_rs2;
        ex_mem_rd         <= id_ex_rd;
        ex_mem_imm        <= id_ex_imm;
        ex_mem_funct3     <= id_ex_funct3;
        ex_mem_opcode     <= id_ex_opcode;
        ex_mem_format     <= id_ex_format;
        ex_mem_memRead    <= id_ex_memRead;
        ex_mem_memToReg   <= id_ex_memToReg;
        ex_mem_memWrite   <= id_ex_memWrite;
        ex_mem_regWrite   <= id_ex_regWrite;
        ex_mem_jump       <= id_ex_jump;
        ex_mem_lui        <= id_ex_lui;
        ex_mem_valid      <= id_ex_valid;
        ex_mem_inst       <= id_ex_inst;

        // ----------------------------------------------------
        // MEM/WB
        // ----------------------------------------------------
        mem_wb_pc         <= ex_mem_pc;
        mem_wb_next_pc    <= ex_mem_next_pc;
        mem_wb_alu_result <= ex_mem_alu_result;
        mem_wb_rs1_data   <= ex_mem_rs1_data;
        mem_wb_rs2_data   <= ex_mem_rs2_data;
        mem_wb_rs1        <= ex_mem_rs1;
        mem_wb_rs2        <= ex_mem_rs2;
        mem_wb_rd         <= ex_mem_rd;
        mem_wb_imm        <= ex_mem_imm;
        mem_wb_funct3     <= ex_mem_funct3;
        mem_wb_opcode     <= ex_mem_opcode;
        mem_wb_format     <= ex_mem_format;
        mem_wb_memToReg   <= ex_mem_memToReg;
        mem_wb_regWrite   <= ex_mem_regWrite;
        mem_wb_jump       <= ex_mem_jump;
        mem_wb_lui        <= ex_mem_lui;
        mem_wb_valid      <= ex_mem_valid;
        mem_wb_inst       <= ex_mem_inst;

        // dmem retire info and load data
        mem_wb_memRead    <= ex_mem_memRead;
        mem_wb_memWrite   <= ex_mem_memWrite;
        mem_wb_dmem_addr  <= dmem_addr;
        mem_wb_dmem_mask  <= dmem_mask;
        mem_wb_dmem_wdata <= dmem_wdata;

        // ----------------------------------------------------
        // CONTROL-FLOW FLUSH (branches/jumps/jalr)
        // ----------------------------------------------------
        if (ex_ctrl_flush) begin
            // Kill younger instructions in IF and ID so there are no delay slots
            if_id_valid <= 1'b0;
            id_ex_valid <= 1'b0;
        end
    end
end

// ============================================================
// Retire interface (WB stage)
// ============================================================

assign o_retire_valid = mem_wb_valid;
assign o_retire_inst  = mem_wb_inst;
assign o_retire_trap  = 1'b0;
assign o_retire_halt  = mem_wb_valid && (mem_wb_inst == 32'h0010_0073);

assign o_retire_rs1_raddr =
    (mem_wb_opcode == 7'b1101111) ? mem_wb_rs1 :
    ((mem_wb_format[5] || mem_wb_format[4]) ? 5'd0 : mem_wb_rs1);

assign o_retire_rs2_raddr =
    (mem_wb_format[0] || mem_wb_format[2] || mem_wb_format[3]) ? mem_wb_rs2 : 5'd0;

assign o_retire_rs1_rdata =
    (mem_wb_format[5] || mem_wb_format[4]) ? 32'd0 : mem_wb_rs1_data;

assign o_retire_rs2_rdata =
    (mem_wb_format[0] || mem_wb_format[2] || mem_wb_format[3]) ? mem_wb_rs2_data : 32'd0;

assign o_retire_rd_waddr =
    (mem_wb_format[2] || mem_wb_format[3]) ? 5'd0 : mem_wb_rd;

assign o_retire_rd_wdata = rd_data_int;

assign o_retire_dmem_addr  = mem_wb_dmem_addr;
assign o_retire_dmem_mask  = mem_wb_dmem_mask;
assign o_retire_dmem_ren   = mem_wb_memRead;
assign o_retire_dmem_wen   = mem_wb_memWrite;
assign o_retire_dmem_rdata = i_dmem_rdata;
assign o_retire_dmem_wdata = mem_wb_dmem_wdata;

assign o_retire_pc      = mem_wb_pc;
assign o_retire_next_pc = mem_wb_next_pc;

// Hazard detection unit
hazard_unit hazard (
    .i_id_rs1(if_id_rs1),
    .i_id_rs2(if_id_rs2),
    .i_ex_rd(id_ex_rd),
    .i_ex_regWrite(id_ex_regWrite),
    .i_mem_rd(ex_mem_rd),
    .i_mem_regWrite(ex_mem_regWrite),
    .o_stall(stall)
);

endmodule

`default_nettype wire