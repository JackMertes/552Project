#include <inttypes.h>
#include <stdio.h>

#define MAXN 1024

uint32_t dot(const size_t len,
             const uint32_t *const A,
             const uint32_t *const B);

int main(void) {
    size_t len;
    scanf("%zu", &len);
    if (len > MAXN) return 1;

    uint32_t A[MAXN], B[MAXN];
    for (size_t i = 0; i < len; i++) scanf("%" PRIu32, &A[i]);
    for (size_t i = 0; i < len; i++) scanf("%" PRIu32, &B[i]);

    const uint32_t result = dot(len, A, B);
    printf("%" PRIu32 "\n", result);

    return 0;
}
