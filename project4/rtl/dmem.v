module dmem(
	input wire clk,
	//this enables reading memory
	input wire i_memRead,
	//enable for writing memory
	input wire i_memWrite,
	//input telling memory where to read/write from
	input wire [31:0] i_address,
	//data that is written to memory when memWrite is enabled
	input wire i_wdata,
	//data being read from memory
	output wire o_rdata
	);

//data memory block
reg [7:0] mem [0:1023];


