`default_nettype none

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
    input  wire        i_imem_ready,
    output wire [31:0] o_imem_raddr,
    output wire        o_imem_ren,
    // Instruction word fetched from memory, available on the same cycle.
    input  wire        i_imem_valid,
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
    input  wire        i_dmem_ready,
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
    // `0x00002003`, assert `o_dmem_wen`, and set the mask to 0b1000 to
    // indicate that only the upper byte should be written. On the next clock
    // cycle, the upper byte of `o_dmem_wdata` will be written to memory, with
    // the other three bytes of the aligned word unaffected. Remember to shift
    // the value of the `sb` instruction left by 24 bits to place it in the
    // appropriate byte lane.
    output wire [ 3:0] o_dmem_mask,
    // The 32-bit word read from data memory. When `o_dmem_ren` is asserted,
    // this will immediately reflect the contents of memory at the specified
    // address, for the bytes enabled by the mask. When read enable is not
    // asserted, or for bytes not set in the mask, the value is undefined.
    input  wire        i_dmem_valid,
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
    output wire [31:0] o_retire_dmem_addr,
    output wire [ 3:0] o_retire_dmem_mask,
    output wire        o_retire_dmem_ren,
    output wire        o_retire_dmem_wen,
    output wire [31:0] o_retire_dmem_rdata,
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

// PC and IF stage

reg [31:0] pc;
wire [31:0] pc_next;

// Cache instances

// Instruction cache interface signals
wire        ic_busy;
wire [31:0] ic_rdata;
wire        ic_req_ren;
reg         ic_miss_pending;

// Data cache interface signals
wire        dc_busy;
wire [31:0] dc_rdata;
wire        dc_req_ren;
wire        dc_req_wen;
reg         dc_miss_pending;

cache icache (
    .i_clk        (i_clk),
    .i_rst        (i_rst),
    .i_mem_ready  (i_imem_ready),
    .o_mem_addr   (o_imem_raddr),
    .o_mem_ren    (o_imem_ren),
    .o_mem_wen    (),
    .o_mem_wdata  (),
    .i_mem_rdata  (i_imem_rdata),
    .i_mem_valid  (i_imem_valid),
    .o_busy       (ic_busy),
    .i_req_addr   (pc),
    .i_req_ren    (ic_req_ren),
    .i_req_wen    (1'b0),
    .i_req_mask   (4'b1111),
    .i_req_wdata  (32'b0),
    .o_res_rdata  (ic_rdata)
);

cache dcache (
    .i_clk        (i_clk),
    .i_rst        (i_rst),
    .i_mem_ready  (i_dmem_ready),
    .o_mem_addr   (o_dmem_addr),
    .o_mem_ren    (o_dmem_ren),
    .o_mem_wen    (o_dmem_wen),
    .o_mem_wdata  (o_dmem_wdata),
    .i_mem_rdata  (i_dmem_rdata),
    .i_mem_valid  (i_dmem_valid),
    .o_busy       (dc_busy),
    .i_req_addr   (dmem_addr),
    .i_req_ren    (dc_req_ren),
    .i_req_wen    (dc_req_wen),
    .i_req_mask   (dmem_mask),
    .i_req_wdata  (dmem_wdata),
    .o_res_rdata  (dc_rdata)
);

// Cache does word-level memory access, so mask is always full word
assign o_dmem_mask = 4'b1111;

// Stall signals - use registered miss_pending to avoid combinational loops
wire imem_stall = ic_busy || ic_miss_pending;
wire dmem_stall = dc_busy || dc_miss_pending;

// Request signals to caches
assign ic_req_ren = !ic_miss_pending && !ex_ctrl_flush && !dmem_stall;
assign dc_req_ren = !dc_miss_pending && ex_mem_valid && ex_mem_memRead;
assign dc_req_wen = !dc_miss_pending && ex_mem_valid && ex_mem_memWrite;

// Pipeline registers

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
reg        mem_wb_retired;
reg [31:0] mem_wb_inst;

// dmem retire info in MEM/WB
reg        mem_wb_memRead;
reg        mem_wb_memWrite;
reg [31:0] mem_wb_dmem_addr;
reg [ 3:0] mem_wb_dmem_mask;
reg [31:0] mem_wb_dmem_wdata;
reg [31:0] mem_wb_load_data;

wire hazard_stall;
wire stall = hazard_stall || imem_stall || dmem_stall;

// ID stage: instruction fields and control
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

// EX stage wires
wire [31:0] ex_alu_op2;
wire [31:0] ex_alu_result;
wire        ex_alu_eq;
wire        ex_alu_slt;

wire [2:0]  ex_opsel;
wire        ex_sub;
wire        ex_unsigned;
wire        ex_arith;

wire        ex_take_branch;

wire [31:0] forwarding_rs1_data;
wire [31:0] forwarding_rs2_data;

wire [31:0] ex_pc_plus4  = id_ex_pc + 32'd4;
wire [31:0] ex_pc_branch = id_ex_pc + id_ex_imm;
wire [31:0] ex_pc_jalr   = (forwarding_rs1_data + id_ex_imm) & ~32'b1;

// Gate control with id_ex_valid
wire ex_branch_taken = id_ex_valid && ex_take_branch;
wire ex_jump_taken   = id_ex_valid && id_ex_jump;
wire ex_jalr_taken   = id_ex_valid && id_ex_jalr;

// Combined control transfer signal for flushing
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

// MEM stage wires
wire [31:0] dmem_addr;
wire [31:0] dmem_wdata;
wire [ 3:0] dmem_mask;
wire [31:0] load_data_mem;

// WB stage

// Calculate load data in WB stage from pipeline register (captured from cache in MEM)
wire [31:0] wb_load_data =
    (mem_wb_funct3 == 3'b000) ? // LB
        {{24{mem_wb_load_data[7 + 8*mem_wb_alu_result[1:0]]}},
         mem_wb_load_data[8*mem_wb_alu_result[1:0]+:8]} :
    (mem_wb_funct3 == 3'b001) ? // LH
        (mem_wb_alu_result[1]
            ? {{16{mem_wb_load_data[31]}}, mem_wb_load_data[31:16]}
            : {{16{mem_wb_load_data[15]}}, mem_wb_load_data[15:0]}) :
    (mem_wb_funct3 == 3'b100) ? // LBU
        {24'b0, mem_wb_load_data[8*mem_wb_alu_result[1:0]+:8]} :
    (mem_wb_funct3 == 3'b101) ? // LHU
        (mem_wb_alu_result[1]
            ? {16'b0, mem_wb_load_data[31:16]}
            : {16'b0, mem_wb_load_data[15:0]}) :
        mem_wb_load_data;

wire [31:0] wb_int =
    mem_wb_memToReg ? wb_load_data :
    mem_wb_lui      ? mem_wb_imm   :
                      mem_wb_alu_result;

wire [31:0] rd_data_int =
    mem_wb_jump                   ? (mem_wb_pc + 32'd4)      :  // JAL
    (mem_wb_opcode == 7'b0010111) ? (mem_wb_pc + mem_wb_imm) :  // AUIPC
                                    wb_int;

wire [31:0] ex_mem_wb_int =
    ex_mem_memToReg ? 32'd0 :
    ex_mem_lui      ? ex_mem_imm :
                      ex_mem_alu_result;

wire [31:0] ex_mem_wb_data =
    ex_mem_jump                   ? (ex_mem_pc + 32'd4)      :  // JAL/JALR
    (ex_mem_opcode == 7'b0010111) ? (ex_mem_pc + ex_mem_imm) :  // AUIPC
                                    ex_mem_wb_int;

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
    .i_rd_wen   (mem_wb_valid && mem_wb_regWrite),
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

assign ex_alu_op2 = id_ex_aluSrc ? id_ex_imm : forwarding_rs2_data;

forwarding forwarding_inst(
    .i_ex_mem_regWrite(ex_mem_regWrite),
    .i_mem_wb_regWrite(mem_wb_regWrite),
    .i_ex_mem_valid(ex_mem_valid),
    .i_mem_wb_valid(mem_wb_valid),
    .i_ex_mem_rd(ex_mem_rd),
    .i_mem_wb_rd(mem_wb_rd),
    .i_id_ex_rs1(id_ex_rs1),
    .i_id_ex_rs2(id_ex_rs2),
    .i_id_ex_rs1_data(id_ex_rs1_data),
    .i_id_ex_rs2_data(id_ex_rs2_data),
    .i_ex_mem_alu_result(ex_mem_wb_data),
    .i_rd_data_int(rd_data_int),
    .o_op1(forwarding_rs1_data),
    .o_op2(forwarding_rs2_data)
);

alu alu_inst (
    .i_opsel   (ex_opsel),
    .i_sub     (ex_sub),
    .i_unsigned(ex_unsigned),
    .i_arith   (ex_arith),
    .i_op1     (forwarding_rs1_data),
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

// Data memory (MEM) combinational logic
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

// Sequential logic: PC + pipeline regs
always @(posedge i_clk) begin
    if (i_rst) begin
        pc           <= RESET_ADDR;
        ic_miss_pending <= 1'b0;
        dc_miss_pending <= 1'b0;

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
        mem_wb_retired  <= 1'b0;

        mem_wb_memRead  <= 1'b0;
        mem_wb_memWrite <= 1'b0;
        mem_wb_dmem_addr<= 32'd0;
        mem_wb_dmem_mask<= 4'd0;
        mem_wb_dmem_wdata<=32'd0;
        mem_wb_load_data<= 32'd0;

    end else begin
        // Track cache miss states
        // Set pending when we request and cache signals busy
        // Clear pending when cache is no longer busy (miss serviced)
        if (ic_req_ren && ic_busy) begin
            ic_miss_pending <= 1'b1;
        end else if (!ic_busy) begin
            ic_miss_pending <= 1'b0;
        end

        if ((dc_req_ren || dc_req_wen) && dc_busy) begin
            dc_miss_pending <= 1'b1;
        end else if (!dc_busy) begin
            dc_miss_pending <= 1'b0;
        end

        // Clear icache pending on flush (we'll fetch from new address)
        if (ex_ctrl_flush) begin
            ic_miss_pending <= 1'b0;
        end

        // PC update - with caches, advance PC when not stalling
        if (ex_ctrl_flush) begin
            pc <= ex_next_pc;
        end else if (!stall) begin
            pc <= pc_next;
        end

        // IF/ID - with cache, instruction is available combinationally on hit
        if (ex_ctrl_flush) begin
            // Flush IF/ID on control transfer
            if_id_valid <= 1'b0;
        end else if (stall) begin
            // Hold IF/ID steady during stall
            if_id_pc    <= if_id_pc;
            if_id_inst  <= if_id_inst;
            if_id_valid <= if_id_valid;
        end else begin
            // Cache provides instruction combinationally (on hit)
            // ic_busy will be high on miss, causing stall
            if_id_pc    <= pc;
            if_id_inst  <= ic_rdata;
            if_id_valid <= 1'b1;
        end

        // ID/EX
        if (dmem_stall) begin
            // Hold ID/EX during dmem stall (preserve instruction in pipeline)
            id_ex_valid    <= id_ex_valid;
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
            id_ex_inst     <= id_ex_inst;
        end else if (stall) begin
            // Insert bubble (NOP) for other stalls (imem, hazard)
            id_ex_valid    <= 1'b0;
            id_ex_pc       <= 32'b0;
            id_ex_rs1_data <= 32'b0;
            id_ex_rs2_data <= 32'b0;
            id_ex_rs1      <= 5'b0;
            id_ex_rs2      <= 5'b0;
            id_ex_rd       <= 5'b0;
            id_ex_imm      <= 32'b0;
            id_ex_funct3   <= 3'b0;
            id_ex_funct7   <= 7'b0;
            id_ex_opcode   <= 7'b0;
            id_ex_format   <= 6'b0;
            id_ex_branch   <= 1'b0;
            id_ex_jalr     <= 1'b0;
            id_ex_memRead  <= 1'b0;
            id_ex_memToReg <= 1'b0;
            id_ex_memWrite <= 1'b0;
            id_ex_aluSrc   <= 1'b0;
            id_ex_regWrite <= 1'b0;
            id_ex_jump     <= 1'b0;
            id_ex_lui      <= 1'b0;
            id_ex_aluOp    <= 2'b0;
            id_ex_inst     <= 32'b0;
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

        // EX/MEM
        if (dmem_stall) begin
            // Hold EX/MEM steady during dmem stall (waiting for load data)
            ex_mem_pc         <= ex_mem_pc;
            ex_mem_next_pc    <= ex_mem_next_pc;
            ex_mem_alu_result <= ex_mem_alu_result;
            ex_mem_rs1_data   <= ex_mem_rs1_data;
            ex_mem_rs2_data   <= ex_mem_rs2_data;
            ex_mem_rs1        <= ex_mem_rs1;
            ex_mem_rs2        <= ex_mem_rs2;
            ex_mem_rd         <= ex_mem_rd;
            ex_mem_imm        <= ex_mem_imm;
            ex_mem_funct3     <= ex_mem_funct3;
            ex_mem_opcode     <= ex_mem_opcode;
            ex_mem_format     <= ex_mem_format;
            ex_mem_memRead    <= ex_mem_memRead;
            ex_mem_memToReg   <= ex_mem_memToReg;
            ex_mem_memWrite   <= ex_mem_memWrite;
            ex_mem_regWrite   <= ex_mem_regWrite;
            ex_mem_jump       <= ex_mem_jump;
            ex_mem_lui        <= ex_mem_lui;
            ex_mem_valid      <= ex_mem_valid;
            ex_mem_inst       <= ex_mem_inst;
        end else begin
            ex_mem_pc         <= id_ex_pc;
            ex_mem_next_pc    <= ex_next_pc;
            ex_mem_alu_result <= ex_alu_result;
            ex_mem_rs1_data   <= forwarding_rs1_data;
            ex_mem_rs2_data   <= forwarding_rs2_data;
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
        end

        // MEM/WB
        if (dmem_stall) begin
            // During dmem_stall, EX/MEM holds the memory instruction.
            // MEM/WB holds for forwarding, but mark as retired to prevent re-retirement.
            mem_wb_pc         <= mem_wb_pc;
            mem_wb_next_pc    <= mem_wb_next_pc;
            mem_wb_alu_result <= mem_wb_alu_result;
            mem_wb_rs1_data   <= mem_wb_rs1_data;
            mem_wb_rs2_data   <= mem_wb_rs2_data;
            mem_wb_rs1        <= mem_wb_rs1;
            mem_wb_rs2        <= mem_wb_rs2;
            mem_wb_rd         <= mem_wb_rd;
            mem_wb_imm        <= mem_wb_imm;
            mem_wb_funct3     <= mem_wb_funct3;
            mem_wb_opcode     <= mem_wb_opcode;
            mem_wb_format     <= mem_wb_format;
            mem_wb_memToReg   <= mem_wb_memToReg;
            mem_wb_regWrite   <= mem_wb_regWrite;
            mem_wb_jump       <= mem_wb_jump;
            mem_wb_lui        <= mem_wb_lui;
            mem_wb_valid      <= mem_wb_valid;
            mem_wb_retired    <= 1'b1;
            mem_wb_inst       <= mem_wb_inst;
            mem_wb_memRead    <= mem_wb_memRead;
            mem_wb_memWrite   <= mem_wb_memWrite;
            mem_wb_dmem_addr  <= mem_wb_dmem_addr;
            mem_wb_dmem_mask  <= mem_wb_dmem_mask;
            mem_wb_dmem_wdata <= mem_wb_dmem_wdata;
            mem_wb_load_data  <= mem_wb_load_data;
        end else begin
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
            mem_wb_retired    <= 1'b0;
            mem_wb_inst       <= ex_mem_inst;

            // dmem retire info and load data
            mem_wb_memRead    <= ex_mem_memRead;
            mem_wb_memWrite   <= ex_mem_memWrite;
            mem_wb_dmem_addr  <= dmem_addr;
            mem_wb_dmem_mask  <= dmem_mask;
            mem_wb_dmem_wdata <= dmem_wdata;
            mem_wb_load_data  <= dc_rdata;
        end

        if (ex_ctrl_flush) begin
            // Kill younger instructions in IF/ID
            if_id_valid <= 1'b0;
            // Only invalidate ID/EX if not stalled for dmem

            if (!dmem_stall) begin
                id_ex_valid <= 1'b0;
            end
        end
    end
end

// Retire interface (WB stage)
assign o_retire_valid = mem_wb_valid && !mem_wb_retired;
assign o_retire_inst  = mem_wb_inst;
assign o_retire_trap  = 1'b0;
assign o_retire_halt  = mem_wb_valid && !mem_wb_retired && (mem_wb_inst == 32'h0010_0073);

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
assign o_retire_dmem_rdata = mem_wb_load_data;
assign o_retire_dmem_wdata = mem_wb_dmem_wdata;

assign o_retire_pc      = mem_wb_pc;
assign o_retire_next_pc = mem_wb_next_pc;

wire [4:0] id_rs1_actual = (format[4] || format[5]) ? 5'd0 : rs1;
wire [4:0] id_rs2_actual = (format[0] || format[2] || format[3]) ? rs2 : 5'd0;

hazard_unit hazard (
    .i_if_id_rs1(if_id_valid ? id_rs1_actual : 5'd0),
    .i_if_id_rs2(if_id_valid ? id_rs2_actual : 5'd0),
    .i_id_ex_rd(id_ex_valid ? id_ex_rd : 5'd0),
    .i_id_ex_memRead(id_ex_valid && id_ex_memRead),
    .o_stall(hazard_stall)
);

endmodule

`default_nettype wire
