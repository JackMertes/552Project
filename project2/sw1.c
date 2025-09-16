
#include "booth.c"

int main(void)
{
    // open a file to write the output
    FILE *fp = fopen("booth_trace_swsim1.txt", "w");
    if (fp == NULL) {
        perror("Failed to open file");
        return 1;
    }
    fprintf(fp, "Software Simulation Trace 1\n");

    int cycle = 0;

    // Test 1: -8 * -2
    booth_compute(-8, -2, &cycle, fp);

    cycle++;
    // Test 2:  5 *  4
    booth_compute(5, 4, &cycle, fp);

    return 0;
}
