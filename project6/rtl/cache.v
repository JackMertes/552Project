`default_nettype none

module cache (
    // Global clock.
    input  wire        i_clk,
    // Synchronous active-high reset.
    input  wire        i_rst,
    // External memory interface. See hart interface for details. This
    // interface is nearly identical to the phase 5 memory interface, with the
    // exception that the byte mask (`o_mem_mask`) has been removed. This is
    // no longer needed as the cache will only access the memory at word
    // granularity, and implement masking internally.
    input  wire        i_mem_ready,
    output wire [31:0] o_mem_addr,
    output wire        o_mem_ren,
    output wire        o_mem_wen,
    output wire [31:0] o_mem_wdata,
    input  wire [31:0] i_mem_rdata,
    input  wire        i_mem_valid,
    // Interface to CPU hart. This is nearly identical to the phase 5 hart memory
    // interface, but includes a stall signal (`o_busy`), and the input/output
    // polarities are swapped for obvious reasons.
    //
    // The CPU should use this as a stall signal for both instruction fetch
    // (IF) and memory (MEM) stages, from the instruction or data cache
    // respectively. If a memory request is made (`i_req_ren` for instruction
    // cache, or either `i_req_ren` or `i_req_wen` for data cache), this
    // should be asserted *combinationally* if the request results in a cache
    // miss.
    //
    // In case of a cache miss, the CPU must stall the respective pipeline
    // stage and deassert ren/wen on subsequent cycles, until the cache
    // deasserts `o_busy` to indicate it has serviced the cache miss. However,
    // the CPU must keep the other request lines constant. For example, the
    // CPU should not change the request address while stalling.
    output wire        o_busy,
    // 32-bit read/write address to access from the cache. This should be
    // 32-bit aligned (i.e. the two LSBs should be zero). See `i_req_mask` for
    // how to perform half-word and byte accesses to unaligned addresses.
    input  wire [31:0] i_req_addr,
    // When asserted, the cache should perform a read at the aligned address
    // specified by `i_req_addr` and return the 32-bit word at that address,
    // either immediately (i.e. combinationally) on a cache hit, or
    // synchronously on a cache miss. It is illegal to assert this and
    // `i_dmem_wen` on the same cycle.
    input  wire        i_req_ren,
    // When asserted, the cache should perform a write at the aligned address
    // specified by `i_req_addr` with the 32-bit word provided in
    // `o_req_wdata` (specified by the mask). This is necessarily synchronous,
    // but may either happen on the next clock edge (on a cache hit) or after
    // multiple cycles of latency (cache miss). As the cache is write-through
    // and write-allocate, writes must be applied to both the cache and
    // underlying memory.
    // It is illegal to assert this and `i_dmem_ren` on the same cycle.
    input  wire        i_req_wen,
    // The memory interface expects word (32 bit) aligned addresses. However,
    // WISC-25 supports byte and half-word loads and stores at unaligned and
    // 16-bit aligned addresses, respectively. To support this, the access
    // mask specifies which bytes within the 32-bit word are actually read
    // from or written to memory.
    input  wire [ 3:0] i_req_mask,
    // The 32-bit word to write to memory, if the request is a write
    // (i_req_wen is asserted). Only the bytes corresponding to set bits in
    // the mask should be written into the cache (and to backing memory).
    input  wire [31:0] i_req_wdata,
    // THe 32-bit data word read from memory on a read request.
    output wire [31:0] o_res_rdata
);
    // These parameters are equivalent to those provided in the project
    // 6 specification. Feel free to use them, but hardcoding these numbers
    // rather than using the localparams is also permitted, as long as the
    // same values are used (and consistent with the project specification).
    //
    // 32 sets * 2 ways per set * 16 bytes per way = 1K cache
    localparam O = 4;            // 4 bit offset => 16 byte cache line
    localparam S = 5;            // 5 bit set index => 32 sets
    localparam DEPTH = 2 ** S;   // 32 sets
    localparam W = 2;            // 2 way set associative, NMRU
    localparam T = 32 - O - S;   // 23 bit tag
    localparam D = 2 ** O / 4;   // 16 bytes per line / 4 bytes per word = 4 words per line

    // The following memory arrays model the cache structure. As this is
    // an internal implementation detail, you are *free* to modify these
    // arrays as you please.

    // Backing memory, modeled as two separate ways.
    reg [   31:0] datas0 [DEPTH - 1:0][D - 1:0];
    reg [   31:0] datas1 [DEPTH - 1:0][D - 1:0];
    reg [T - 1:0] tags0  [DEPTH - 1:0];
    reg [T - 1:0] tags1  [DEPTH - 1:0];
    reg [1:0] valid [DEPTH - 1:0];
    reg       lru   [DEPTH - 1:0];

    localparam IDLE = 2'b00;
    localparam ALLOCATE = 2'b01;
    localparam WRITE_THROUGH = 2'b10;
    reg [1:0] state, next_state;

    // Address breakdown
    // For a 16-byte cache line with 32-bit words:
    // Bits [1:0]: byte offset within word (always 00 for aligned accesses)
    // Bits [3:2]: word index within cache line (0-3 for 4 words)
    // Bits [8:4]: set index (5 bits for 32 sets)
    // Bits [31:9]: tag (23 bits)
    wire [S-1:0] addr_index  = i_req_addr[O+S-1:O];        // bits [8:4]
    wire [T-1:0] addr_tag    = i_req_addr[31:O+S];         // bits [31:9]
    wire [1:0]   addr_word   = i_req_addr[3:2];            // bits [3:2] - word within line

    // Hit detection
    wire way0_valid = valid[addr_index][0];
    wire way1_valid = valid[addr_index][1];
    wire hit0 = way0_valid && (tags0[addr_index] == addr_tag);
    wire hit1 = way1_valid && (tags1[addr_index] == addr_tag);
    wire hit = hit0 || hit1;

    // Data reading
    wire [31:0] read_data_way0 = datas0[addr_index][addr_word];
    wire [31:0] read_data_way1 = datas1[addr_index][addr_word];
    wire [31:0] hit_data = hit0 ? read_data_way0 : read_data_way1;

    // Request tracking
    wire req = i_req_ren || i_req_wen;
    wire miss = req && !hit;
    wire write_hit = i_req_wen && hit;

    // Mask expansion for byte-level writes
    wire [31:0] req_mask_expanded = { {8{i_req_mask[3]}}, {8{i_req_mask[2]}}, {8{i_req_mask[1]}}, {8{i_req_mask[0]}} };

    // Write data merging
    wire [31:0] merged_write_data = (hit_data & ~req_mask_expanded) | (i_req_wdata & req_mask_expanded);

    // Allocate state registers
    reg [T-1:0] alloc_tag;
    reg [S-1:0] alloc_index;
    reg [2:0] alloc_req_cnt;
    reg [2:0] alloc_fill_cnt;
    reg alloc_way;
    reg [31:0] alloc_addr;
    reg alloc_write;
    reg [3:0] alloc_mask;
    reg [31:0] alloc_wdata;

    // Wires for write-back logic
    wire [1:0] write_word = alloc_addr[O-1:2];
    wire [31:0] mask_exp = { {8{alloc_mask[3]}}, {8{alloc_mask[2]}}, {8{alloc_mask[1]}}, {8{alloc_mask[0]}} };
    wire [31:0] write_current_data = (alloc_way == 1'b0) ? datas0[alloc_index][write_word] : datas1[alloc_index][write_word];
    wire [31:0] write_new_data = (write_current_data & ~mask_exp) | (alloc_wdata & mask_exp);

    // Output assignments
    assign o_busy = (state != IDLE) || miss;
    assign o_res_rdata = hit_data;

    // Memory interface
    assign o_mem_addr = (state == ALLOCATE) ? {alloc_tag, alloc_index, alloc_req_cnt[1:0], 2'b00} :
                        (state == WRITE_THROUGH) ? alloc_addr :
                        (state == IDLE && write_hit) ? i_req_addr :
                        32'h00000000;
    assign o_mem_ren = (state == ALLOCATE) && i_mem_ready && (alloc_req_cnt < D);
    assign o_mem_wen = ((state == WRITE_THROUGH) && i_mem_ready) || (state == IDLE && write_hit && i_mem_ready);
    assign o_mem_wdata = (state == WRITE_THROUGH) ? alloc_wdata : merged_write_data;

    // State machine
    always @(posedge i_clk) begin
        if (i_rst) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (miss) begin
                    next_state = ALLOCATE;
                end else if (write_hit) begin
                    // Write-through: write to memory on write hit
                    if (i_mem_ready) begin
                        next_state = IDLE;
                    end else begin
                        next_state = IDLE; // Stay in IDLE but keep busy high
                    end
                end
            end
            ALLOCATE: begin
                if (i_mem_valid && alloc_fill_cnt == 3'd3) begin
                    if (alloc_write) begin
                        next_state = WRITE_THROUGH;
                    end else begin
                        next_state = IDLE;
                    end
                end
            end
            WRITE_THROUGH: begin
                if (i_mem_ready) begin
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end

    // Allocation logic
    always @(posedge i_clk) begin
        if (i_rst) begin
            alloc_tag <= {T{1'b0}};
            alloc_index <= {S{1'b0}};
            alloc_req_cnt <= 3'd0;
            alloc_fill_cnt <= 3'd0;
            alloc_way <= 1'b0;
            alloc_addr <= 32'd0;
            alloc_write <= 1'b0;
            alloc_mask <= 4'b0000;
            alloc_wdata <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (miss) begin
                        alloc_tag <= addr_tag;
                        alloc_index <= addr_index;
                        alloc_req_cnt <= 3'd0;
                        alloc_fill_cnt <= 3'd0;
                        // Choose way: if one invalid, use it; else use NMRU
                        alloc_way <= (!way0_valid) ? 1'b0 : 
                                     (!way1_valid) ? 1'b1 : 
                                     ~lru[addr_index];
                        alloc_write <= i_req_wen;
                        alloc_mask <= i_req_mask;
                        alloc_wdata <= i_req_wdata;
                        alloc_addr <= i_req_addr;
                    end
                end
                ALLOCATE: begin
                    if (i_mem_ready && alloc_req_cnt < D) begin
                        alloc_req_cnt <= alloc_req_cnt + 3'd1;
                    end
                    if (i_mem_valid && alloc_fill_cnt < D) begin
                        alloc_fill_cnt <= alloc_fill_cnt + 3'd1;
                    end
                end
            endcase
        end
    end

    // Cache update logic
    integer i, j;
    always @(posedge i_clk) begin
        if (i_rst) begin
            for (i = 0; i < DEPTH; i = i + 1) begin
                for (j = 0; j < D; j = j + 1) begin
                    datas0[i][j] <= 32'd0;
                    datas1[i][j] <= 32'd0;
                end
                tags0[i] <= {T{1'b0}};
                tags1[i] <= {T{1'b0}};
                valid[i] <= 2'b00;
                lru[i] <= 1'b0;
            end
        end else begin
            // Handle cache writes (both hits and after allocation)
            if (state == IDLE && hit) begin
                // Update LRU on any hit
                lru[addr_index] <= hit0 ? 1'b0 : 1'b1;
                
                // Handle writes on hit (write to cache immediately, memory write handled by write-through)
                if (i_req_wen) begin
                    if (hit0) begin
                        datas0[addr_index][addr_word] <= merged_write_data;
                    end else begin
                        datas1[addr_index][addr_word] <= merged_write_data;
                    end
                end
            end
            
            // Handle cache allocation (fill cache line from memory)
            if (state == ALLOCATE && i_mem_valid) begin
                if (alloc_way == 1'b0) begin
                    datas0[alloc_index][alloc_fill_cnt] <= i_mem_rdata;
                    if (alloc_fill_cnt == 3'd3) begin
                        tags0[alloc_index] <= alloc_tag;
                        valid[alloc_index][0] <= 1'b1;
                        lru[alloc_index] <= 1'b0;
                    end
                end else begin
                    datas1[alloc_index][alloc_fill_cnt] <= i_mem_rdata;
                    if (alloc_fill_cnt == 3'd3) begin
                        tags1[alloc_index] <= alloc_tag;
                        valid[alloc_index][1] <= 1'b1;
                        lru[alloc_index] <= 1'b1;
                    end
                end
            end
            
            // Handle write after allocation (write-allocate: write to cache after allocating line)
            if (state == WRITE_THROUGH && i_mem_ready) begin
                // Apply the write with masking to the newly allocated cache line
                if (alloc_way == 1'b0) begin
                    datas0[alloc_index][write_word] <= write_new_data;
                end else begin
                    datas1[alloc_index][write_word] <= write_new_data;
                end
            end
        end
    end

endmodule