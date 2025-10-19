module pc #(
    parameter RESET_ADDR = 32'h00000000
)(
    input wire clk,
	//active high, synchronous reset
    input wire i_rst,
	//the value of the pc at the next clock cycle
	input wire [31:0] i_pc,
	//the current value of the pc
    output reg [31:0] o_pc
);

    always @(posedge clk) begin
        if (i_rst)
            o_pc <= RESET_ADDR;
        else
            o_pc <= i_pc;
    end

endmodule




