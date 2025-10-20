`default_nettype none

// The arithmetic logic unit (ALU) is responsible for performing the core
// calculations of the processor. It takes two 32-bit operands and outputs
// a 32 bit result based on the selection operation - addition, comparison,
// shift, or logical operation. This ALU is a purely combinational block, so
// you should not attempt to add any registers or pipeline it in phase 3.
module alu (
    // Major operation selection.
    // NOTE: In order to simplify instruction decoding in phase 4, both 3'b010
    // and 3'b011 are used for set less than (they are equivalent).
    // Unsigned comparison is controlled through the `i_unsigned` signal.
    //
    // 3'b000: addition/subtraction if `i_sub` asserted
    // 3'b001: shift left logical
    // 3'b010,
    // 3'b011: set less than/unsigned if `i_unsigned` asserted
    // 3'b100: exclusive or
    // 3'b101: shift right logical/arithmetic if `i_arith` asserted
    // 3'b110: or
    // 3'b111: and
    input  wire [ 2:0] i_opsel,
    // When asserted, addition operations should subtract instead.
    // This is only used for `i_opsel == 3'b000` (addition/subtraction).
    input  wire        i_sub,
    // When asserted, comparison operations should be treated as unsigned.
    // This is only used for branch comparisons and set less than.
    // For branch operations, the ALU result is not used, only the comparison
    // results.
    input  wire        i_unsigned,
    // When asserted, right shifts should be treated as arithmetic instead of
    // logical. This is only used for `i_opsel == 3'b011` (shift right).
    input  wire        i_arith,
    // First 32-bit input operand.
    input  wire [31:0] i_op1,
    // Second 32-bit input operand.
    input  wire [31:0] i_op2,
    // 32-bit output result. Any carry out (from addition) should be ignored.
    output wire [31:0] o_result,
    // Equality result. This is used downstream to determine if a
    // branch should be taken.
    output wire        o_eq,
    // Set less than result. This is used downstream to determine if a
    // branch should be taken.
    output wire        o_slt
);
    // Fill in your implementation here.
    wire [31:0] add_res; 
    wire [31:0] slt_res;
    wire signed_lt;
    wire unsigned_lt;
    wire [31:0] shift_res;

    assign add_res = (i_sub) ? i_op1 - i_op2 : i_op1 + i_op2;

    assign unsigned_lt = (i_op1 < i_op2);
    assign signed_lt = (i_op1[31] & ~i_op2[31]) | (~(i_op1[31] ^ i_op2[31]) & unsigned_lt);
    assign slt_res = (i_unsigned) ? unsigned_lt : signed_lt;

    barrel_shifter32 barrel(.a(i_op1), .shamt(i_op2[4:0]), .dir(i_opsel != 3'b001), .is_arith(i_arith), .res(shift_res));

    assign o_result = 
        (i_opsel == 3'b000) ? add_res :
        (i_opsel == 3'b001) ? shift_res :
        (i_opsel == 3'b010) ? slt_res :
        (i_opsel == 3'b011) ? slt_res :
        (i_opsel == 3'b100) ? i_op1 ^ i_op2 :
        (i_opsel == 3'b101) ? shift_res :
        (i_opsel == 3'b110) ? i_op1 | i_op2 : 
        (i_opsel == 3'b111) ? i_op1 & i_op2 : 32'b0;

    assign o_eq = i_op1 == i_op2;
    assign o_slt = slt_res[0];

endmodule

module barrel_shifter32 (
    input  wire [31:0] a,
    input  wire [4:0]  shamt,
    input  wire        dir,        // 0=left, 1=right
    input  wire        is_arith, 
    output wire [31:0] res
);
    // fill bit for arithmetic right shift
    wire fill = (dir & is_arith & a[31]);

    // right shift
    wire [31:0] s0  = a;
    wire [31:0] s1  = shamt[0] ? {fill,       s0[31:1]}    : s0;
    wire [31:0] s2  = shamt[1] ? {{2{fill}},  s1[31:2]}    : s1;
    wire [31:0] s4  = shamt[2] ? {{4{fill}},  s2[31:4]}    : s2;
    wire [31:0] s8  = shamt[3] ? {{8{fill}},  s4[31:8]}    : s4;
    wire [31:0] s16 = shamt[4] ? {{16{fill}}, s8[31:16]}   : s8;

    // left shift
    wire [31:0] l0  = a;
    wire [31:0] l1  = shamt[0] ? {l0[30:0], 1'b0}  : l0;
    wire [31:0] l2  = shamt[1] ? {l1[29:0], 2'b0}  : l1;
    wire [31:0] l4  = shamt[2] ? {l2[27:0], 4'b0}  : l2;
    wire [31:0] l8  = shamt[3] ? {l4[23:0], 8'b0}  : l4;
    wire [31:0] l16 = shamt[4] ? {l8[15:0], 16'b0} : l8;

    assign res = (dir) ? s16 : l16;
endmodule

`default_nettype wire