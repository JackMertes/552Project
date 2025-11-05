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

reg [31:0] pc;
wire [31:0] pc_next;
wire [31:0] curr_instruction;

// Instruction fields
wire [6:0] if_id_opcode;
wire [4:0] if_id_rd;
wire [4:0] if_id_rs1;
wire [4:0] if_id_rs2;
wire [2:0] if_id_funct3;
wire [6:0] if_id_funct7;

// Control signals
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
wire [5:0]  format;
wire        auipc;

// Register file signals
wire [31:0] rs1_data;
wire [31:0] rs2_data;
wire [31:0] rd_data;

// Immediate
wire [31:0] immediate;

// ALU control
wire [2:0] opsel;
wire sub;
wire u_unsigned;
wire arith;

// ALU signals
wire [31:0] alu_op2;  //alu_op1 is the same as rs1_data
wire [31:0] alu_result;
wire        alu_eq;
wire        alu_slt;

// Branch signal
wire take_branch;

// Writeback signal
wire [31:0] wb_int;

// IF/ID Pipeline Stage
reg [31:0] if_id_pc;
reg [31:0] if_id_instruction;
reg [31:0] if_id_pc_inc;
reg if_id_valid;

// ID/EX Pipeline Stage
reg [31:0] id_ex_pc;
reg [31:0] id_ex_instruction;
reg [31:0] id_ex_pc_inc;
reg id_ex_branch, id_ex_jalr, id_ex_memRead, id_ex_memToReg,
    id_ex_memWrite, id_ex_aluSrc, id_ex_regWrite, id_ex_jump, id_ex_lui, id_ex_auipc;
reg [1:0] id_ex_aluOp;
reg [32:0] id_ex_rs1_data, id_ex_rs2_data;
reg [31:0] id_ex_immediate;
reg [31:0] id_ex_rd_waddr;
reg [5:0] id_ex_format;
reg id_ex_valid;

// EX/MEM Pipeline Stage
reg [31:0] ex_mem_pc;
reg [31:0] ex_mem_instruction;
reg [31:0] ex_mem_pc_inc;
reg ex_mem_branch, ex_mem_jalr, ex_mem_memRead, ex_mem_memToReg,
    ex_mem_memWrite, ex_mem_regWrite, ex_mem_jump, ex_mem_lui, ex_mem_auipc;
reg [31:0] ex_mem_pc_imm;
reg [31:0] ex_mem_alu_result;
reg [31:0] ex_mem_rs1_data;
reg [31:0] ex_mem_rs2_data;
reg [31:0] ex_mem_rd_waddr;
reg [31:0] ex_mem_immediate;
reg ex_mem_slt, ex_mem_eq;
reg [5:0] ex_mem_format;
reg ex_mem_valid;

// MEM/WB Pipeline Stage
reg [31:0] mem_wb_pc_imm;
reg [31:0] mem_wb_pc_inc;
reg [31:0] mem_wb_alu_result;
reg [31:0] mem_wb_dmem_rdata;
reg [31:0] mem_wb_rd_waddr;
reg [31:0] mem_wb_instruction;
reg mem_wb_memToReg, mem_wb_regWrite, mem_wb_lui, mem_wb_jump, mem_wb_auipc;
reg [5:0] mem_wb_format;
reg [31:0] mem_wb_pc;
reg [31:0] mem_wb_pc_next;
reg [31:0] mem_wb_rs1_data;
reg [31:0] mem_wb_rs2_data;
reg mem_wb_valid;

// PC
always @(posedge i_clk) begin
    if(i_rst)
        pc <= RESET_ADDR;
    else
        pc <= pc_next;
end

// instruction memory read
assign o_imem_raddr = pc;
assign curr_instruction = i_imem_rdata;

// IF/ID Pipeline
always @(posedge i_clk, posedge i_rst) begin
    if(i_rst) begin
        if_id_pc <= 32'd0;
        if_id_instruction <= 32'd0;
        if_id_pc_inc <= 32'd0;
        if_id_valid <= 1'b0;
    end
    else begin
        if_id_pc <= pc;
        if_id_instruction <= curr_instruction;
        if_id_pc_inc <= pc + 4;
        if (curr_instruction != 32'0x00000013) begin
            if_id_valid <= 1'b1;
        end
    end
end

// Decode instruction fields
assign if_id_opcode = if_id_instruction[6:0];
assign if_id_rd     = if_id_instruction[11:7];
assign if_id_funct3 = if_id_instruction[14:12];
assign if_id_rs1    = if_id_instruction[19:15];
assign if_id_rs2    = if_id_instruction[24:20];
assign if_id_funct7 = if_id_instruction[31:25];

// Control modules
control_decode control(.i_opcode(opcode), 
                       .o_branch(branch),
					   .o_jalr(jalr),
                       .o_memRead(memRead), 
                       .o_memToReg(memToReg), 
                       .o_memWrite(memWrite), 
                       .o_aluSrc(aluSrc), 
                       .o_regWrite(regWrite), 
                       .o_jump(jump), 
                       .o_aluOp(aluOp), 
                       .o_lui(lui), 
                       .o_auipc(auipc),
                       .o_format(format)
                       );

assign o_dmem_ren = ex_mem_memRead;
assign o_dmem_wen = ex_mem_memWrite;

// Register file
rf rf(.i_clk(i_clk),
        .i_rst(i_rst),
        .i_rs1_raddr(if_id_rs1),
        .o_rs1_rdata(rs1_data),
        .i_rs2_raddr(if_id_rs2),
        .o_rs2_rdata(rs2_data),
        .i_rd_wen(mem_wb_regWrite),
        .i_rd_waddr(mem_wb_rd_waddr),
        .i_rd_wdata(rd_data)
        );


// Immediate generation
imm imm(.i_inst(if_id_instruction),
            .i_format(format),
            .o_immediate(immediate)
            );

// ID/EX Pipeline Stage
always @(posedge i_clk, posedge i_rst) begin
    if(i_rst) begin
        id_ex_pc <= 32'd0;
        id_ex_instruction <= 32'd0;
        id_ex_pc_inc <= 32'd0;
        id_ex_branch <= 1'b0;
        id_ex_jalr <= 1'b0;
        id_ex_memRead <= 1'b0;
        id_ex_memToReg <= 1'b0;
        id_ex_memWrite <= 1'b0;
        id_ex_aluSrc <= 1'b0;
        id_ex_regWrite <= 1'b0;
        id_ex_jump <= 1'b0;
        id_ex_aluOp <= 2'b00;
        id_ex_lui <= 1'b0;
        id_ex_auipc <= 1'b0;
        id_ex_rs1_data <= 32'd0;
        id_ex_rs2_data <= 32'd0;
        id_ex_immediate <= 32'd0;
        id_ex_rd_waddr <= 5'd0;
        id_ex_format <= 6'd0;
        id_ex_valid <= 1'b0;
    end
    else begin
        id_ex_pc <= if_id_pc;
        id_ex_instruction <= if_id_instruction;
        id_ex_pc_inc <= if_id_pc_inc;
        id_ex_branch <= branch;
        id_ex_jalr <= jalr;
        id_ex_memRead <= memRead;
        id_ex_memToReg <= memToReg;
        id_ex_memWrite <= memWrite;
        id_ex_aluSrc <= aluSrc;
        id_ex_regWrite <= regWrite;
        id_ex_jump <= jump;
        id_ex_aluOp <= aluOp;
        id_ex_lui <= lui;
        id_ex_auipc <= auipc;
        id_ex_rs1_data <= rs1_data;
        id_ex_rs2_data <= rs2_data;
        id_ex_immediate <= immediate;
        id_ex_rd_waddr <= if_id_rd;
        id_ex_format <= format;
        id_ex_valid <= if_id_valid;
    end
end

// ALU instruction decoder
alu_decode alu_decode(.i_ALUOp(id_ex_aluOp),
                      .i_funct3(id_ex_instruction[14:12]),
                      .i_funct7(id_ex_instruction[31:25]),
                      .o_opsel(opsel),
                      .o_sub(sub),
                      .o_unsigned(u_unsigned),
                      .o_arith(arith)
                      );

// ALU
alu alu(.i_opsel(opsel),
        .i_sub(sub),
        .i_unsigned(u_unsigned),
        .i_arith(arith),
        .i_op1(id_ex_rs1_data),
        .i_op2(alu_op2),
        .o_result(alu_result),
        .o_eq(alu_eq),
        .o_slt(alu_slt)
        );

// ALU operand 2 selection
assign alu_op2 = (id_ex_aluSrc) ? id_ex_immediate : id_ex_rs2_data;

// EX/MEM Pipeline Stage
always @(posedge i_clk, posedge i_rst) begin
    if (i_rst) begin
        ex_mem_pc <= 32'd0;
        ex_mem_instruction <= 32'd0;
        ex_mem_pc_inc <= 32'd0;
        ex_mem_branch <= 1'b0;
        ex_mem_jalr <= 1'b0;
        ex_mem_memRead <= 1'b0;
        ex_mem_memToReg <= 1'b0;
        ex_mem_memWrite <= 1'b0;
        ex_mem_regWrite <= 1'b0;
        ex_mem_jump <= 1'b0;
        ex_mem_lui <= 1'b0;
        ex_mem_auipc <= 1'b0;
        ex_mem_alu_result <= 32'd0;
        ex_mem_rs1_data <= 32'd0;
        ex_mem_rs2_data <= 32'd0;
        ex_mem_rd_waddr <= 5'd0;
        ex_mem_pc_imm <= 32'd0;
        ex_mem_slt <= 1'b0;
        ex_mem_eq <= 1'b0;
        ex_mem_format <= 6'd0;
        ex_mem_valid <= 1'b0;
    end
    else begin
        ex_mem_pc <= id_ex_pc;
        ex_mem_instruction <= id_ex_instruction;
        ex_mem_pc_inc <= id_ex_pc_inc;
        ex_mem_branch <= id_ex_branch;
        ex_mem_jalr <= id_ex_jalr;
        ex_mem_memRead <= id_ex_memRead;
        ex_mem_memToReg <= id_ex_memToReg;
        ex_mem_memWrite <= id_ex_memWrite;
        ex_mem_regWrite <= id_ex_regWrite;
        ex_mem_jump <= id_ex_jump;
        ex_mem_lui <= id_ex_lui;
        ex_mem_auipc <= id_ex_auipc;
        ex_mem_alu_result <= alu_result;
        ex_mem_rs1_data <= id_ex_rs1_data;
        ex_mem_rs2_data <= id_ex_rs2_data;
        ex_mem_rd_waddr <= id_ex_rd_waddr;
        ex_mem_pc_imm <= id_ex_immediate + id_ex_pc;
        ex_mem_slt <= alu_slt;
        ex_mem_eq <= alu_eq;
        ex_mem_branch <= id_ex_branch;
        ex_mem_format <= id_ex_format;
        ex_mem_valid <= id_ex_valid;
    end
end
// Branch decode
branch_decode branch_dec(.i_slt(ex_mem_slt),
                         .i_funct3(ex_mem_instruction[14:12]),
                         .i_eq(ex_mem_eq),
                         .i_branch(ex_mem_branch),
                         .o_take_branch(take_branch)
                         );

// Next PC logic
// JALR: next PC = (rs1_data + immediate) & ~1
assign pc_next = (ex_mem_jalr) ? ex_mem_alu_result & 32'hfffffffe : 
                 (ex_mem_jump || take_branch) ? ex_mem_pc_imm :
                 ex_mem_pc_inc;

// Data memory interface
assign o_dmem_addr = {ex_mem_alu_result[31:2], 2'b00};
// Store data placement for SB/SH/SW
assign o_dmem_wdata = (ex_mem_instruction[14:12] == 3'b000 || ex_mem_instruction[14:12] == 3'b100) ? // SB/SBU
    (ex_mem_rs2_data[7:0] << (8 * ex_mem_alu_result[1:0])) :
    (ex_mem_instruction[14:12] == 3'b001 || ex_mem_instruction[14:12] == 3'b101) ? // SH/SHU
    (ex_mem_alu_result[1] ? ({{16{ex_mem_rs2_data[15]}}, ex_mem_rs2_data[15:0]} << 16) : {{16{ex_mem_rs2_data[15]}}, ex_mem_rs2_data[15:0]}) :
    ex_mem_rs2_data; // SW
// Mask logic for loads and stores
assign o_dmem_mask = (ex_mem_instruction[14:12] == 3'b000 || ex_mem_instruction[14:12] == 3'b100) ? (4'b0001 << ex_mem_alu_result[1:0]) : // LB/LBU/SB
                      (ex_mem_instruction[14:12] == 3'b001 || ex_mem_instruction[14:12] == 3'b101) ? (4'b0011 << {ex_mem_alu_result[1], 1'b0}) : // LH/LHU/SH
                      4'b1111; // LW/SW

// Writeback data selection
// Sign/zero extension for loads
wire [31:0] load_data;
assign load_data = (ex_mem_instruction[14:12] == 3'b000) ? // LB
    {{24{i_dmem_rdata[7 + 8*ex_mem_alu_result[1:0]]}}, i_dmem_rdata[8*ex_mem_alu_result[1:0]+:8]} :
    (ex_mem_instruction[14:12] == 3'b001) ? // LH
    (ex_mem_alu_result[1] ? {{16{i_dmem_rdata[31]}}, i_dmem_rdata[31:16]} : {{16{i_dmem_rdata[15]}}, i_dmem_rdata[15:0]}) :
    (ex_mem_instruction[14:12] == 3'b100) ? // LBU
    {24'b0, i_dmem_rdata[8*ex_mem_alu_result[1:0]+:8]} :
    (ex_mem_instruction[14:12] == 3'b101) ? // LHU
    (ex_mem_alu_result[1] ? {16'b0, i_dmem_rdata[31:16]} : {16'b0, i_dmem_rdata[15:0]}) :
    i_dmem_rdata;

// MEM/WB Pipeline Stage
always @(posedge i_clk, posedge i_rst) begin
    if(i_rst) begin
        mem_wb_pc <= 32'd0;
        mem_wb_pc_next <= 32'd0;
        mem_wb_pc_imm <= 32'd0;
        mem_wb_alu_result <= 32'd0;
        mem_wb_dmem_rdata <= 32'd0;
        mem_wb_rd_waddr <= 5'd0;
        mem_wb_instruction <= 32'd0;
        mem_wb_memToReg <= 1'b0;
        mem_wb_regWrite <= 1'b0;
        mem_wb_lui <= 1'b0;
        mem_wb_jump <= 1'b0;
        mem_wb_auipc <= 1'b0;
        mem_wb_format <= 6'd0;
        mem_wb_rs1_data <= 32'd0;
        mem_wb_rs2_data <= 32'd0;
        mem_wb_valid <= 1'b0;
    end
    else begin
        mem_wb_pc <= ex_mem_pc;
        mem_wb_pc_next <= pc_next;
        mem_wb_pc_imm <= ex_mem_pc_imm;
        mem_wb_pc_inc <= ex_mem_pc_inc;
        mem_wb_alu_result <= ex_mem_alu_result;
        mem_wb_dmem_rdata <= load_data;
        mem_wb_rd_waddr <= ex_mem_rd_waddr;
        mem_wb_instruction <= ex_mem_instruction;
        mem_wb_memToReg <= ex_mem_memToReg;
        mem_wb_regWrite <= ex_mem_regWrite;
        mem_wb_lui <= ex_mem_lui;
        mem_wb_jump <= ex_mem_jump;
        mem_wb_auipc <= ex_mem_auipc;
        mem_wb_format <= ex_mem_format;
        mem_wb_rs1_data <= ex_mem_rs1_data;
        mem_wb_rs2_data <= ex_mem_rs2_data;
        mem_wb_valid <= ex_mem_valid;
    end
end

assign wb_int = (mem_wb_memToReg) ? load_data : 
                  (mem_wb_lui) ? immediate :
                  alu_result;

assign rd_data = (mem_wb_jump) ? mem_wb_pc_inc :
                   (mem_wb_auipc) ? (pc + immediate) :
                   wb_int;

// Retire interface
assign o_retire_valid = mem_wb_valid; //always retiring because single cycle
assign o_retire_inst = mem_wb_instruction;
assign o_retire_trap = 1'b0; //assert if illegal instruction. All tests pass with 1'b0 right now
assign o_retire_halt = (mem_wb_instruction == 32'h00100073) ? 1'b1 : 1'b0; //ebreak

assign o_retire_rs1_raddr = (mem_wb_instruction[6:0] == 7'b1101111) ? mem_wb_instruction[11:7] : ((mem_wb_format[5] || mem_wb_format[4]) ? 5'd0 : mem_wb_instruction[11:7]); // JAL: x31, else original logic
assign o_retire_rs2_raddr = (mem_wb_format[0] || mem_wb_format[2] || mem_wb_format[3]) ? mem_wb_instruction[11:7] : 5'd0;  // Only R-type, S-type, B-type read rs2
assign o_retire_rs1_rdata = (mem_wb_format[5] || mem_wb_format[4]) ? 32'd0 : mem_wb_rs1_data;  // Zero if U-type or J-type
assign o_retire_rs2_rdata = (mem_wb_format[0] || mem_wb_format[2] || mem_wb_format[3]) ? mem_wb_rs2_data : 32'd0;  // Only R-type, S-type, B-type read rs2
assign o_retire_rd_waddr  = (mem_wb_format[2] || mem_wb_format[3]) ? 5'd0 : mem_wb_rd_waddr;  // Zero if S or B-type
assign o_retire_rd_wdata  = rd_data;

assign o_retire_pc = mem_wb_pc;
assign o_retire_next_pc = mem_wb_pc_next;


endmodule

`default_nettype wire
