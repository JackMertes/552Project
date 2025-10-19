module imem(
//addr of the instruction we want to fetch
input wire [31:0] addr, 
//output the 32bit instruction
output wire [31:0] instruction);

//our implementation:
reg [7:0] mem [0:1023];
assign instruction = {mem[addr+3], mem[addr+2], mem[addr+1], mem[addr]};

endmodule
