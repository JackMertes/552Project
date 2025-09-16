#include <stdio.h>
#include <stdint.h>
#include <string.h>

void booth_compute(int32_t multiplier, int32_t multiplicand, int *cycle, FILE *fp)
{
    int64_t product_upper = 0; // note: need 33 bits
    int32_t product_lower = multiplier;
    int     right = 1;

    fprintf(fp, "Cycle:%12d | load: 1 | multiplier:%12d | multiplicand:%12d\n",
           *cycle, multiplier, multiplicand);

    // 32 iterations
    for (int i = 0; i < 32; ++i, ++(*cycle)) {
        // Determine opcode bits from (left, right)
        int left = (product_lower & 1);
        char opcode_str[4]= "nop"; // "add", "sub", "nop"

        uint64_t prod = ((uint64_t)(uint32_t)product_upper << 32) | (uint64_t)(uint32_t)product_lower;

        // Execute Booth operation
        if (left == 0 && right == 1) {
            // 01 -> add multiplicand
            product_upper = (int64_t)((int64_t)product_upper + (int64_t)multiplicand);
            strcpy(opcode_str, "add");
        } else if (left == 1 && right == 0) {
            // 10 -> sub multiplicand
            product_upper = (int64_t)((int64_t)product_upper - (int64_t)multiplicand);
            strcpy(opcode_str, "sub");
        }
        fprintf(fp, "Cycle:%12d | count: %2d | opcode: %s | product: %016llx (busy: 1, ready: 0)\n",
               *cycle, i, opcode_str, (unsigned long long)prod);
        // Arithmetic right shift
        int new_right = (product_lower & 1);
        uint32_t product_lower_u = (uint32_t)product_lower;
        uint64_t product_upper_u = (uint64_t)product_upper;

        // product_lower gets logical right shift, with product_upper's LSB shifted into product_lower's MSB
        uint32_t product_lower_next = (product_lower_u >> 1) | ((product_upper_u & 1u) << 31);
        // product_upper gets arithmetic right shift
        int64_t  product_upper_next = (product_upper >> 1);

        right = new_right;
        product_lower = (int32_t)product_lower_next;
        product_upper = product_upper_next;
    }

    // Final "ready" line after the 32nd shift
    uint64_t prod = ((uint64_t)(uint32_t)product_upper << 32) | (uint64_t)(uint32_t)product_lower;
    fprintf(fp, "Cycle:%12d | product: %016llx (%21lld) (busy: 1, ready: 1)\n",
            *cycle, (unsigned long long)prod, (long long)prod);
}
