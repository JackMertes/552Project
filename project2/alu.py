import os
import pathlib
import cocotb
from fixedint import UInt32, Int32
import pytest
import random

from cocotb.triggers import Timer

import util

async def shell_test(dut, test_vectors):
    for opsel, sub, unsigned, arith, op1, op2 in test_vectors:
        op1 = UInt32(op1)
        op2 = UInt32(op2)

        dut.i_opsel.value = opsel
        dut.i_sub.value = sub
        dut.i_unsigned.value = unsigned
        dut.i_arith.value = arith
        dut.i_op1.value = op1
        dut.i_op2.value = op2
        await Timer(10, units = "ns")  # Wait for the ALU to process the inputs

        operations = {
            # opsel, sub, unsigned, arith
            (0, 0, 0, 0): op1 + op2,
            (0, 1, 0, 0): op1 - op2,
            (1, 0, 0, 0): op1 << op2[0:5],
            (2, 0, 0, 0): UInt32(Int32(op1) < Int32(op2)),
            (3, 0, 0, 0): UInt32(Int32(op1) < Int32(op2)),
            (2, 0, 1, 0): UInt32(op1 < op2),
            (3, 0, 1, 0): UInt32(op1 < op2),
            (4, 0, 0, 0): op1 ^ op2,
            (5, 0, 0, 0): op1 >> op2[0:5],
            (5, 0, 0, 1): UInt32(Int32(op1) >> op2[0:5]),
            (6, 0, 0, 0): op1 | op2,
            (7, 0, 0, 0): op1 & op2,
        }

        expected_result = operations[(opsel, sub, unsigned, arith)]
        expected_eq = int(op1 == op2)
        expected_slt = int(op1 < op2) if unsigned else int(Int32(op1) < Int32(op2))

        dut._log.info(f"Testing: opsel={opsel:#010x}, sub={sub}, unsigned={unsigned}, arith={arith}, op1={op1:#010x}, op2={op2:#010x}")
        dut._log.info(f"Expected: result={expected_result:#010x}, eq={expected_eq}, slt={expected_slt}")
        dut._log.info(f"Compare: unsigned={op1 < op2}, signed={Int32(op1) < Int32(op2)}")

        result = dut.o_result.value.integer
        eq = dut.o_eq.value.integer
        slt = dut.o_slt.value.integer
        assert result == expected_result, f"Result mismatch: expected {expected_result:#010x}, got {result:#010x}"
        assert eq == expected_eq, f"Equality flag mismatch: expected {expected_eq:#010x}, got {eq:#010x}"
        assert slt == expected_slt, f"Set less than flag mismatch: expected {expected_slt:#010x}, got {slt:#010x}"

# opsel, sub, unsigned, arith, op1, op2
ADD = [
    (0, 0, 0, 0,            0, 0),                  # ADD: 0 + 0 = 0            # both operands zero
    (0, 0, 0, 0,            5, 5),                  # ADD: 5 + 5 = 10           # two equal vals
    (0, 0, 0, 0,            10, 20),                # ADD: 10 + 20 = 30         # first is less than second
    (0, 0, 0, 0,            5, 3),                  # ADD: 5 + 3 = 8            # second is less than first

    (0, 0, 0, 0,            -5, 5),                 # ADD: -5 + 5 = 0           # negative first operand
    (0, 0, 0, 0,            15, -5),                # ADD: 15 + (-5) = 10       # negative second operand
    (0, 0, 0, 0,            -20, -10),              # ADD: -20 + (-10) = -30    # both negative, first less
    (0, 0, 0, 0,            -10, -20),              # ADD: -10 + (-20) = -30    # both operands negative, second less
    (0, 0, 0, 0,            -5, -5),                # ADD: -5 + (-5) = -10      # both operands negative, equal

    (0, 0, 0, 0,            0xFFFFFFFF, 1),         # ADD: 0xFFFFFFFF + 1 = 0   # wrap around case
    (0, 0, 0, 0,            1, 0xFFFFFFFF),         # ADD: 1 + 0xFFFFFFFF = 0   # wrap around case
]

SUB = [
    (0, 1, 0, 0,            0, 0),                  # SUB: 0 - 0 = 0            # both operands zero
    (0, 1, 0, 0,            5, 5),                  # SUB: 5 - 5 = 0            # two equal vals
    (0, 1, 0, 0,            10, 20),                # SUB: 10 - 20 = -10        # first is less than second
    (0, 1, 0, 0,            5, 3),                  # SUB: 5 - 3 = 2            # second is less than first

    (0, 1, 0, 0,            -5, 5),                 # SUB: -5 - 5 = -10         # negative first operand
    (0, 1, 0, 0,            15, -5),                # SUB: 15 - (-5) = 20       # negative second operand
    (0, 1, 0, 0,            -20, -10),              # SUB: -20 - (-10) = -10    # both negative, first less
    (0, 1, 0, 0,            -10, -20),              # SUB: -10 - (-20) = 10     # both operands negative, second less
    (0, 1, 0, 0,            -5, -5),                # SUB: -5 - (-5) = 0        # both operands negative, equal

    (0, 1, 0, 0,            0xFFFFFFFF, 1),         # SUB: 0 - 1 = 0xFFFFFFFF   # wrap around case
    (0, 1, 0, 0,            1, 0xFFFFFFFF),         # SUB: 1 - 0xFFFFFFFF = 2   # wrap around case
]

SLL = [
    (1, 0, 0, 0,            0, 0),                  # SLL: 0 << 0 = 0            # both operands zero
    (1, 0, 0, 0,            5, 1),                  # SLL: 5 << 1 = 10           # shift left by 1
    (1, 0, 0, 0,            10, 2),                 # SLL: 10 << 2 = 40          # shift left by 2
    (1, 0, 0, 0,            3, 3),                  # SLL: 3 << 3 = 24           # shift left by itself

    (1, 0, 0, 0,            -5, 1),                 # SLL: -5 << 1 = -10         # negative first operand
    (1, 0, 0, 0,            -10, 2),                # SLL: -10 << 2 = -40        # negative first operand

    (1, 0, 0, 0,            0xFFFFFFFF, 1),         # SLL: max value << 1 = wrap around
    (1, 0, 0, 0,            1, 31),                 # SLL: shift by full width should be zero
]

SLT = [
    (2, 0, 0, 0,            0, 0),                  # SLT: 0 < 0 = 0            # both operands zero

    (2, 0, 0, 0,            1, 2),                  # SLT: 1 < 2 = 1            # first less than second, both positive
    (2, 0, 0, 0,            2, 1),                  # SLT: 2 < 1 = 0            # second less than first, both positive

    (2, 0, 0, 0,            -2, -1),                # SLT: -2 < -1 = 1          # first less than second, both negative
    (2, 0, 0, 0,            -1, -2),                # SLT: -1 < -2 = 0          # second less than first, both negative

    (2, 0, 0, 0,            -1, 1),                 # SLT: -1 < 1 = 1           # first less than second, mixed signs
    (2, 0, 0, 0,            1, -1),                 # SLT: 1 < -1 = 0           # second less than first, mixed signs

    (3, 0, 0, 0,            0, 0),                  # SLT: 0 < 0 = 0            # both operands zero

    (3, 0, 0, 0,            1, 2),                  # SLT: 1 < 2 = 1            # first less than second, both positive
    # (3, 0, 0, 0,            2, 1),                  # SLT: 2 < 1 = 0            # second less than first, both positive
    #
    # (3, 0, 0, 0,            -2, -1),                # SLT: -2 < -1 = 1          # first less than second, both negative
    # (3, 0, 0, 0,            -1, -2),                # SLT: -1 < -2 = 0          # second less than first, both negative
    #
    # (3, 0, 0, 0,            -1, 1),                 # SLT: -1 < 1 = 1           # first less than second, mixed signs
    # (3, 0, 0, 0,            1, -1),                 # SLT: 1 < -1 = 0           # second less than first, mixed signs
]

SLTU = [
    # (2, 0, 1, 0,            0, 0),                  # SLTU: 0 < 0 = 0            # both operands zero
    #
    # (2, 0, 1, 0,            1, 2),                  # SLTU: 1 < 2 = 1            # first less than second, both positive
    # (2, 0, 1, 0,            2, 1),                  # SLTU: 2 < 1 = 0            # second less than first, both positive
    #
    # (2, 0, 1, 0,            -2, -1),                # SLTU: -2 < -1 = 1          # first less than second, both negative
    # (2, 0, 1, 0,            -1, -2),                # SLTU: -1 < -2 = 0          # second less than first, both negative
    #
    # (2, 0, 1, 0,            -1, 1),                 # SLTU: -1 < 1 = 0           # first less than second, mixed signs
    # (2, 0, 1, 0,            1, -1),                 # SLTU: 1 < -1 = 1           # second less than first, mixed signs

    (3, 0, 1, 0,            0, 0),                  # SLTU: 0 < 0 = 0            # both operands zero

    (3, 0, 1, 0,            1, 2),                  # SLTU: 1 < 2 = 1            # first less than second, both positive
    (3, 0, 1, 0,            2, 1),                  # SLTU: 2 < 1 = 0            # second less than first, both positive

    (3, 0, 1, 0,            -2, -1),                # SLTU: -2 < -1 = 1          # first less than second, both negative
    (3, 0, 1, 0,            -1, -2),                # SLTU: -1 < -2 = 0          # second less than first, both negative

    (3, 0, 1, 0,            -1, 1),                 # SLTU: -1 < 1 = 0           # first less than second, mixed signs
    (3, 0, 1, 0,            1, -1),                 # SLTU: 1 < -1 = 1           # second less than first, mixed signs
]

XOR = [
    (4, 0, 0, 0,            0x00000000, 0x00000000),                  # XOR: 0 ^ 0 = 0            # both operands zero
    (4, 0, 0, 0,            0x11111111, 0x11111111),                  # XOR: '1 ^ '1 = 0          # complete overlap
    (4, 0, 0, 0,            0x01010101, 0x01010101),                  # XOR: '01 ^ '01 = 0        # complete overlap
    (4, 0, 0, 0,            0x01010101, 0x10101010),                  # XOR: '01 ^ '10 = '1       # no overlap
]

SRL = [
    (5, 0, 0, 0,            0x00000001, 0),                           # SRL: 1 >> 0 = 1
    (5, 0, 0, 0,            0x00000001, 1),                           # SRL: 1 >> 1 = 0
    (5, 0, 0, 0,            0x00000010, 1),                           # SRL: 16 >> 1 = 8
    (5, 0, 0, 0,            0x00000100, 1),                           # SRL: 256 >> 1 = 128
    (5, 0, 0, 0,            0x00000100, 1),                           # SRL: 256 >> 2 = 64
    (5, 0, 0, 0,            0x80000000, 1),                           # SRL: 8'0 >> 1 = 4'0
    (5, 0, 0, 0,            0x80000000, 31),                          # SRL: 8'0 >> 31 = 0
]

SRA = [
    (5, 0, 0, 1,            0x00000001, 0),                           # SRL: 1 >> 0 = 1
    (5, 0, 0, 1,            0x00000001, 1),                           # SRL: 1 >> 1 = 0
    (5, 0, 0, 1,            0x00000010, 1),                           # SRL: 16 >> 1 = 8
    (5, 0, 0, 1,            0x00000100, 1),                           # SRL: 256 >> 1 = 128
    (5, 0, 0, 1,            0x00000100, 1),                           # SRL: 256 >> 2 = 64
    (5, 0, 0, 1,            0x80000000, 1),                           # SRL: 8'0 >> 1 = C'0
    (5, 0, 0, 1,            0x80000000, 31),                          # SRL: 8'0 >> 31 = '1
]

OR = [
    (6, 0, 0, 0,            0x00000000, 0x00000000),                  # OR: 0 | 0 = 0             # both operands zero
    (6, 0, 0, 0,            0x00000001, 0x00000000),                  # OR: 1 | 0 = 1             # first operand 1
    (6, 0, 0, 0,            0x00000000, 0x00000001),                  # OR: 0 | 1 = 1             # second operand 1
    (6, 0, 0, 0,            0x01010101, 0x01010101),                  # OR: full overlap 01s
    (6, 0, 0, 0,            0x10101010, 0x10101010),                  # OR: full overlap 10s
    (6, 0, 0, 0,            0x10101010, 0x01010101),                  # OR: no overlap all 1s
]

AND = [
    (7, 0, 0, 0,            0x00000000, 0x00000000),                  # AND: 0 & 0 = 0            # both operands zero
    (7, 0, 0, 0,            0x00000001, 0x00000000),                  # AND: 1 & 0 = 0            # first operand 1
    (7, 0, 0, 0,            0x00000000, 0x00000001),                  # AND: 0 & 1 = 0            # second operand 1
    (7, 0, 0, 0,            0x01010101, 0x01010101),                  # AND: full overlap 01s get 01s
    (7, 0, 0, 0,            0x10101010, 0x10101010),                  # AND: full overlap 10s get 10s
    (7, 0, 0, 0,            0x10101010, 0x01010101),                  # AND: no overlap get 0s
]

VECTORS = [ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND]

@cocotb.test()
async def alu_fixed_op(dut) -> None:
    # cocotb doesn't have a parametrize decorator in the stable version
    # (it's being introduced in 2.0) so we need to use env vars
    vectors = eval(os.getenv("VECTORS"))
    await shell_test(dut, vectors)

@cocotb.test()
async def alu_random(dut):
    vectors = []
    for _ in range(5000):
        opsel = random.randint(0, 7)
        sub = random.randint(0, 1) if opsel == 0 else 0
        arith = random.randint(0, 1) if opsel == 5 else 0
        unsigned = random.randint(0, 1) if opsel in (2, 3) else 0

        op1 = random.choice([
            0, -1, 1, 0xFFFFFFFF, 0x80000000, 0x7FFFFFFF,
            random.randint(-2**31, 2**31 - 1),
        ])
        op2 = random.choice([
            0, 1, 31, 32, -1, 0xFFFFFFFF, 0x7FFFFFFF, 
            random.randint(-2**31, 2**31 - 1),
        ])

        vectors.append((opsel, sub, unsigned, arith, op1, op2))

    await shell_test(dut, vectors)

@pytest.mark.parametrize("vectors", VECTORS)
def test_alu_fixed_op(vectors: list[tuple[int]]):
    # proj_path = pathlib.Path(__file__).resolve().parent.parent
    proj_path = pathlib.Path("/autograder/submission/")

    runner = util.get_runner(proj_path, "alu")
    runner.test(
        hdl_toplevel="alu",
        test_module="alu",
        testcase=f"alu_fixed_op",
        extra_env={"VECTORS": str(vectors)}
    )

def test_alu_random():
    # proj_path = pathlib.Path(__file__).resolve().parent.parent
    proj_path = pathlib.Path("/autograder/submission/")

    runner = util.get_runner(proj_path, "alu")
    runner.test(
        hdl_toplevel="alu",
        test_module="alu",
        testcase=f"alu_random",
    )
