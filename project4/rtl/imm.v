`default_nettype none

// The immediate generator is responsible for decoding the 32-bit
// sign-extended immediate from the incoming instruction word. It is a purely
// combinational block that is expected to be embedded in the instruction
// decoder.
module imm (
    // Input instruction word. This is used to extract the relevant immediate
    // bits and assemble them into the final immediate.
    input  wire [31:0] i_inst,
    // Instruction format, determined by the instruction decoder based on the
    // opcode. This is one-hot encoded according to the following format:
    // [0] R-type (don't-care, see below)
    // [1] I-type
    // [2] S-type
    // [3] B-type
    // [4] U-type
    // [5] J-type
    input  wire [ 5:0] i_format,
    // Output 32-bit immediate, sign-extended from the immediate bitstring.
    // Because the R-type format does not have an immediate, the output
    // immediate can be treated as a don't-care under this case. It is
    // included for completeness.
    output wire [31:0] o_immediate
);
    // Fill in your implementation here.
	
	//using cases here
	reg [31:0] imm;
	always @(*) begin
		case(1'b1) //one hot
			i_format[1]: imm = {{21{i_inst[31]}},i_inst[30:20]};
			i_format[2]: imm = {{21{i_inst[31]}},i_inst[30:25],i_inst[11:7]};
			i_format[3]: imm = {{20{i_inst[31]}},i_inst[7],i_inst[30:25],i_inst[11:8],1'b0};
			i_format[4]: imm = {i_inst[31],i_inst[30:12],12'b0};
			i_format[5]: imm = {{12{i_inst[31]}},i_inst[19:12],i_inst[20],i_inst[30:21],1'b0};
			default: imm = 32'd0; //this is also for r case
		endcase
	end
	
	//need to assign 
	assign o_immediate = imm;
	
	
endmodule

`default_nettype wire