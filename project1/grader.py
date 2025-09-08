import subprocess
import os
import random
from fixedint import UInt32

CC = "riscv32-unknown-elf-gcc"
CFLAGS = ["-march=rv32gc", "-mabi=ilp32d", "-O3", "-static", "-Wall", "-Werror"]
QEMU = "qemu-riscv32"
EXE = "./umul"
NUM_TESTS = 50

def run(input_values: tuple[int, int]) -> int:
    input_str = " ".join(str(val) for val in input_values) + "\n"
    result = subprocess.run(
        [QEMU, EXE],
        input=input_str,
        text=True,
        # capture_output=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    assert result.returncode == 0, f"Test execution failed with error code: {result.returncode}"
    stderr = result.stderr.strip()
    assert stderr == "", f"Test execution produced error output: {stderr}"

    output = result.stdout.strip()
    value = int(output)
    return value

# def run_riscv_code(asm_file: str, input_values: list[int], expected_output):
#     # Build the program
#     subprocess.run([CC] + CFLAGS + [asm_file, "harness.c", "-o", "umul"], check=True)
#
#     input_str = " ".join(str(val) for val in input_values) + "\n"
#
#     if result.returncode != 0:
#         print("Error during execution:", result.stderr)
#         os.remove("umul")
#         return "FAIL"
#
#     try:
#         # Take the last line of stdout
#         lines = result.stdout.strip().splitlines()
#         output_line = lines[-1]
#         result_value = int(output_line, 10)
#
#         print(f"Output: {result_value:08x}")
#     except Exception as e:
#         print("Error parsing output:", e)
#         os.remove("umul")
#         return "FAIL"
#
#     os.remove("umul")
#
#     if result_value == expected_output:
#         return "PASS"
#     else:
#         print(f"Expected: {expected_output:08x}, but got: {result_value:08x}")
#         return "FAIL"

# Run multiple tests
def test_random():
    for _ in range(NUM_TESTS):
        x, y = random.sample(range(0, 0xFFFFFFFF), 2)
        expected = int(UInt32(x) * UInt32(y))
        result = run((x, y))
        # print(f"testing: {x:08x} * {y:08x} = {expected:08x}, got {result:08x}")
        assert result == expected, f"testing {x:08x} * {y:08x}: expected {expected:08x}, got {result:08x}"
