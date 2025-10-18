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
	
	//if 1 is postive and 2 neg then 0 else if 1n and 2p then 1 other wise 1<2
	wire signed_slt = (!i_op1[31] && i_op2[31]) ? 1'd0 : (i_op1[31] && !i_op2[31]) ? 1'd1 : (i_op1 < i_op2);
	
	//use case statement again
	reg [31:0] result;
	always_comb begin
		case(i_opsel)
			3'b000: result = (i_sub) ? i_op1 - i_op2 : i_op1 + i_op2;
			3'b001: result = i_op1 << i_op2[4:0];
			3'b010, 3'b011: result = (i_unsigned) ? {31'd0, i_op1 < i_op2} : {31'd0, signed_slt};
			3'b100: result = i_op1 ^ i_op2;
			3'b101: result = (i_arith) ? $unsigned($signed(i_op1) >>> i_op2[4:0]) : i_op1 >> i_op2[4:0];
			3'b110: result = i_op1 | i_op2;
			3'b111: result = i_op1 & i_op2;
			default: result = 32'd0;
		endcase
	end

	//assign Equality
	assign o_eq = i_op1 == i_op2;
	assign o_slt = (i_unsigned) ? (i_op1 < i_op2) : signed_slt;
	assign o_result = result;
	
	
endmodule

`default_nettype wire
