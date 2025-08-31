# Compiler and tools
CC      := riscv32-unknown-elf-gcc
QEMU    := qemu-riscv32

# Compiler and linker flags
CFLAGS  := -march=rv32gc -mabi=ilp32d -O3 -Wall -Werror
LDFLAGS := -static

# Sources and target
SRCS    := umul.s harness.c
TARGET  := umul
TEST    := grader.py

# Default target
all: $(TARGET)

# Build everything in one step
$(TARGET): $(SRCS)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^

# Clean build artifacts
clean:
	rm -f $(TARGET)

# Run executable with QEMU (non-default target)
run: $(TARGET)
	$(QEMU) ./$(TARGET)

# Test with pytest.
test: $(TARGET)
	pytest grader.py

.PHONY: all clean run test
