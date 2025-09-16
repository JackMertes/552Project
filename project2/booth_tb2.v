
module booth_tb2 ();
    reg clk; // All the input signals to the uut (unit under test) are regs as they are driven by the testbench
    reg rst_n;
    reg load;
    reg [31:0] multiplier;
    reg [31:0] multiplicand;
    wire ready; // All the output signals from the uut are wires as they are driven by the uut
    wire [1:0] opcode;
    wire busy;
    wire [63:0] product;

    // Instantiate the uut (unit under test)
    booth #(32) uut (
        .clk(clk),
        .rst_n(rst_n),
        .load(load),
        .multiplier(multiplier),
        .multiplicand(multiplicand),
        .ready(ready),
        .busy(busy),
        .opcode(opcode),
        .product(product)
    );

     // Initial blocks are executed once at the start of the simulation.
     // You can have multiple initial blocks; they will run concurrently
    initial begin
        clk = 0;
        rst_n = 0;
        load = 0;
        multiplier = -8;
        multiplicand = -2;
        #10 rst_n = 1; // release reset
        #10 load = 1;  // assert load to start counting
        #10 load = 0;  // deassert load
        // wait for ready signal
        wait (ready);

        # 15 load = 1; // load new value
        multiplier = 5;
        multiplicand = 4;
        #10 load = 0;  // deassert load
        wait (ready);

        # 15 load = 1; // load new value
        multiplier = 2147483647;
        multiplicand = 2147483647;
        #10 load = 0;  // deassert load
        wait (ready);

        # 15 load = 1; // load new value
        multiplier = -2147483648;
        multiplicand = -2147483648;
        #10 load = 0;  // deassert load
        wait (ready);

        # 15 load = 1; // load new value
        multiplier = 2147483647;
        multiplicand = -2147483648;
        #10 load = 0;  // deassert load
        wait (ready);

        # 15 load = 1; // load new value
        multiplier = -2147483648;
        multiplicand = 2147483647;
        #10 load = 0;  // deassert load
        wait (ready);

        # 15 load = 1; // load new value
        multiplier = 0;
        multiplicand = -1;
        #10 load = 0;  // deassert load
        wait (ready);

        # 15 load = 1; // load new value
        multiplier = -1;
        multiplicand = 0;
        #10 load = 0;  // deassert load
        wait (ready);

        # 15 load = 1; // load new value
        multiplier = -1;
        multiplicand = -1;
        #10 load = 0;  // deassert load
        wait (ready);

        #30 
        $fclose(fd); // Close the file
        $display("Trace written to booth_trace_rtlsim2.txt");
        $finish;
    end

    // clock generation logic
    always #5 clk = ~clk; // 10ns clock period

    // handy cycle counter for traces
    integer cycle_count;
    initial begin
        cycle_count = 0;
    end
    always @(posedge clk) begin
        if (~rst_n) begin
            cycle_count <= 0;
        end else if (busy) begin
            cycle_count <= cycle_count + 1;
        end
    end

    // Trace generation
    always @(posedge clk) begin
        if (rst_n) begin
          // write the following trace to file
          if (load) begin
            $fdisplay(fd, "Cycle: %d | load: %b | multiplier: %d | multiplicand: %d",
                    cycle_count, load, $signed(multiplier), $signed(multiplicand));
          end else if (ready) begin
            $fdisplay(fd, "Cycle: %d | product: %h (%d) (busy: %b, ready: %b)",
                    cycle_count, product, $signed(product), busy, ready);
          end else if (busy) begin
            if (opcode == 2'b01) begin
              $fdisplay(fd, "Cycle: %d | count: %d | opcode: add | product: %h (busy: %b, ready: %b)",
                      cycle_count, uut.count, product, busy, ready);
            end else if (opcode == 2'b10) begin
              $fdisplay(fd, "Cycle: %d | count: %d | opcode: sub | product: %h (busy: %b, ready: %b)",
                      cycle_count, uut.count, product, busy, ready);
            end else begin
              $fdisplay(fd, "Cycle: %d | count: %d | opcode: nop | product: %h (busy: %b, ready: %b)",
                      cycle_count, uut.count, product, busy, ready);
            end
          end
        end
    end

    initial begin
        // In Verilog, $monitor is a continuous assignment, so it should be placed inside an initial block.
        // It will print whenever any of the variables change, useful for debugging in testbenches.
        $monitor("Time: %0t | rst_n: %b | load: %b | count: %d | ready: %b | busy: %b | opcode: %b | product: %h",
                 $time, rst_n, load, uut.count, ready, busy, opcode, product);
    end

    // As we mentioned before, initial blocks are concurrent; initial blocks that appear later in the file
    // do not imply they run later in time. 
    integer fd;
    initial begin
      fd = $fopen("booth_trace_rtlsim2.txt", "w"); // Open "trace_output.txt" in write mode
      if (fd == 0) begin
        $display("Error: Could not open file for writing.");
        $finish;
      end
      $fdisplay(fd, "RTL Simulation Trace 2");
    end
endmodule
