module pc (
	//global clock signal
	input wire clk,
	//the value of the pc at the next clock cycle
	input wire [31:0] i_pc,
	//the current value of the pc
	output reg [31:0] o_pc,
	);
	
	always @(posedge clk) begin
		o_pc <= i_pc;
	end
	

endmodule
