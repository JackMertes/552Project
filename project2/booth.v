module booth #(
    parameter N = 32 
)(
    input clk,
    input rst_n,      // synchronous active-low reset
    input load,
    input [N-1:0] multiplicand,
    input [N-1:0] multiplier,
    output [1:0] opcode, // 00 for no op, 01 for +, 10 for -
    output busy,
    output ready,
    output [2*N-1:0] product
);

    wire busy_next;
    DFF #(.N(1)) dff_busy_fsm (
        .clk(clk),
        .rst_n(rst_n),
        .d(busy_next),
        .q(busy)
    );
    assign busy_next = ready ? 1'b0 : (load ? 1'b1 : busy);

    localparam LOG2N = $clog2(N);
    wire [LOG2N:0] count; 
    counter #(.WIDTH(LOG2N+1)) count_inst (
        .clk(clk),
        .rst_n(rst_n),
        .clear(load), // clear count to 0 on load
        .en(busy), // enable counting until we reach 31
        .q(count)
    );
    assign ready = (count == N); // done after N cycles

    // parallel to serial conversion of multiplier
    wire left;
    wire left_reg;
    wire right;
    assign right = busy ? left_reg : 1'b0;
    DFF #(.N(1)) dff_right (
        .clk(clk),
        .rst_n(rst_n),
        .d(left),
        .q(left_reg)
    );
    parallel_to_serial #(N) p2s_inst (
        .clk(clk),
        .rst_n(rst_n),
        .load(load),
        .parallel_in(multiplier),
        .serial_out(left)
    );
    assign opcode = busy && {left, right} == 2'b01 ? 2'b01 :
                (busy && {left, right} == 2'b10 ? 2'b10 : 2'b00);


    // Note bit width here
    wire [N:0] product_upper;
    ALU #(.N(N+1)) alu_inst (
        .A({product[2*N-1], product[2*N-1:N]}), // sign-extend upper half
        .B({multiplicand[N-1], multiplicand}),  // sign-extend multiplicand
        .opcode(opcode),
        .C(product_upper)
    );
    reg [2*N-1:0] product_next;
    always @(*) begin
        product_next = product; // default hold value
        if (load) begin
            product_next = {{N{1'b0}}, multiplier}; // load multiplier into lower half, clear upper half
        end else if (busy) begin
            product_next = {product_upper, product[N-1:0]} >> 1; // shift right
        end
    end

    DFF #(.N(2*N)) dff_product (
        .clk(clk),
        .rst_n(rst_n),
        .d(product_next),
        .q(product)
    );

endmodule

module ALU # (
    parameter N = 32
)(
    input [N-1:0] A,
    input [N-1:0] B,
    input [1:0]  opcode, // 00 for no op, 01 for +, 10 for -
    output reg [N-1:0] C
);
    always @(*) begin
        case (opcode)
            2'b01: C = A + B; // add
            2'b10: C = A - B; // sub
            default: C = A;   // nop, just pass A through
        endcase
    end
endmodule

module DFF #(
    parameter N = 4
)(
    input clk,
    input rst_n, // synchronous active-low reset
    input [N-1:0] d,
    output reg [N-1:0] q
);
    always @(posedge clk) begin
        if (!rst_n) begin
            q <= {N{1'b0}};
        end else begin
            q <= d;
        end
    end
endmodule

module counter #(
    parameter WIDTH = 5
)(
    input  wire clk,
    input  wire rst_n,  // synchronous active-low reset
    input  wire en,     // increment when 1, hold when 0
    input wire clear,
    output reg  [WIDTH-1:0] q
);
    always @(posedge clk) begin
        if (!rst_n) begin
            q <= {WIDTH{1'b0}};
        end else if (clear) begin
            q <= {WIDTH{1'b0}};
        end else if (en) begin
            q <= q + 1;
        end else begin
            q <= q;
        end
    end
endmodule

module parallel_to_serial #(
    parameter N = 32 
)(
    input clk,
    input rst_n,      // synchronous active-low reset
    input load,
    input [N-1:0] parallel_in,
    output serial_out
);
    reg [N-1:0] shift_reg;
    assign serial_out = shift_reg[0]; // LSB is the serial output

    always @(posedge clk) begin
        if (!rst_n) begin
            shift_reg <= {N{1'b0}};
        end else if (load) begin
            shift_reg <= parallel_in;
        end else begin
            shift_reg <= {1'b0, shift_reg[N-1:1]}; // shift right, fill with 0
        end
    end
endmodule