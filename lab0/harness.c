#include <stdint.h>
#include <stdio.h>

extern uint32_t umul(const uint32_t x, const uint32_t y);

int main(void) {
    uint32_t x, y;
    scanf("%lu %lu", &x, &y);

    const uint32_t result = umul(x, y);
    printf("%lu\n", result);

    return 0;
}
