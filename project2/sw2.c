#include "booth.c"

int main(void)
{
    // open a file to write the output
    FILE *fp = fopen("booth_trace_swsim2.txt", "w");
    if (fp == NULL) {
        perror("Failed to open file");
        return 1;
    }
    fprintf(fp, "Software Simulation Trace 2\n");

    int cycle = 0;

    // Test 1: -8 * -2
    booth_compute(-8, -2, &cycle, fp);

    cycle++;
    // Test 2:  5 *  4
    booth_compute(5, 4, &cycle, fp);

    cycle++;
    // Test 3:  ++
    booth_compute(2147483647, 2147483647, &cycle, fp);

    cycle++;
    // Test 4:  --
    booth_compute(-2147483648, -2147483648, &cycle, fp);

    cycle++;
    // Test 5:  +-
    booth_compute(2147483647, -2147483648, &cycle, fp);

    cycle++;
    // Test 6:  -+
    booth_compute(-2147483648, 2147483647, &cycle, fp);

    cycle++;
    // Test 7:  0,-1
    booth_compute(0, -1, &cycle, fp);

    cycle++;
    // Test 8:  -1,0
    booth_compute(-1, 0, &cycle, fp);

    cycle++;
    // Test 9:  -1,-1
    booth_compute(-1, -1, &cycle, fp);

    return 0;
}
