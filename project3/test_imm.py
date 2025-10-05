import cocotb
import pathlib
from cocotb.triggers import Timer
from fixedint import FixedInt, Int32, MutableInt32
import random
import pytest

import util

Int12 = FixedInt(12, signed=True, mutable=False)
Int13 = FixedInt(13, signed=True, mutable=False)
Int20 = FixedInt(20, signed=True, mutable=False)
Int21 = FixedInt(21, signed=True, mutable=False)
UInt3 = FixedInt(3, signed=False, mutable=False)
UInt5 = FixedInt(5, signed=False, mutable=False)
UInt7 = FixedInt(7, signed=False, mutable=False)

# Format mapping from opcode to one-hot index
OPCODE_TO_FORMAT = {
    # 0b0110011: 0,  # R-type
    0b0010011: 1,  # I-type (addi, etc.)
    0b0000011: 1,  # I-type (load)
    0b1100111: 1,  # I-type (jalr)
    0b0100011: 2,  # S-type
    0b1100011: 3,  # B-type
    0b0110111: 4,  # U-type (lui)
    0b0010111: 4,  # U-type (auipc)
    0b1101111: 5,  # J-type (jal)
}

NUM_TESTS = 500

def reg():
    return UInt5(random.randint(0, 31))

def assemble(opcode: int, imm: int):
    bit = OPCODE_TO_FORMAT[opcode]
    assert bit != 0

    inst = MutableInt32()
    inst[0:7] = UInt7(opcode)

    match bit:
        # I-type
        case 1:
            inst[20:32] = Int12(imm)
            inst[15:20] = reg()
            inst[12:15] = UInt3(0)
            inst[ 7:12] = reg()
        # S-type
        case 2:
            inst[25:32] = Int12(imm)[5:12]
            inst[20:25] = reg()
            inst[15:20] = reg()
            inst[12:15] = UInt3(0)
            inst[ 7:12] = Int12(imm)[0:5]
        # B-type
        case 3:
            assert (imm & 1) == 0
            inst[   31] = Int13(imm)[12]
            inst[25:31] = Int13(imm)[5:11]
            inst[20:25] = reg()
            inst[15:20] = reg()
            inst[12:15] = UInt3(0)
            inst[ 8:12] = Int13(imm)[1:5]
            inst[    7] = Int13(imm)[11]
        # U-type
        case 4:
            assert (imm & 0xFFF) == 0
            inst[12:32] = Int32(imm)[12:32]
            inst[ 7:12] = reg()
        # J-type
        case 5:
            assert (imm & 1) == 0
            inst[   31] = Int21(imm)[20]
            inst[21:31] = Int21(imm)[1:11]
            inst[   20] = Int21(imm)[11]
            inst[12:20] = Int21(imm)[12:20]
            inst[ 7:12] = reg()

    return inst

@cocotb.test
async def immediate_decoder_random(dut):
    opcodes = list(OPCODE_TO_FORMAT.keys())

    # Randomly sample supported opcodes
    for i, opcode in enumerate(random.choices(opcodes, k=NUM_TESTS)):
        bit = OPCODE_TO_FORMAT[opcode]
        assert bit != 0

        imm: int
        match bit:
            # I-type, S-type
            case 1 | 2:
                imm = random.randint(-(1 << 11), (1 << 11) - 1)
            # B-type
            case 3:
                imm = random.randint(-(1 << 11), (1 << 11) - 1) << 1
            # U-type
            case 4:
                imm = random.randint(-(1 << 19), (1 << 19) - 1) << 12
            # J-type
            case 5:
                imm = random.randint(-(1 << 19), (1 << 19) - 1) << 1
            case _:
                assert False

        inst = assemble(opcode, imm)

        # Drive DUT
        dut.i_inst.value = int(inst)
        dut.i_format.value = 1 << bit
        await Timer(1, units="ns")

        actual = int(Int32(dut.o_immediate.value.integer))
        expected = imm

        print(f"Test {i}: Inst={inst:032b}, Format={bit}, Expected Imm={expected} ({hex(expected)}), Got Imm={actual} ({hex(actual)})")

        assert actual == expected, (
            f"[{i}] Immediate mismatch:\n"
            f"  Inst:      {inst:032b}\n"
            f"  Format:    {bit}\n"
            f"  Expected:  {expected} ({expected:08x})\n"
            f"  Got:       {actual} ({actual:08x})"
        )

@pytest.mark.name("Immediate decoder: randomized")
@pytest.mark.points(15)
def test_immediate_decoder(record_property):
    # proj_path = pathlib.Path(__file__).resolve().parent.parent
    proj_path = pathlib.Path("/autograder/submission/")

    runner = util.get_runner(proj_path, "imm")
    runner.test(
        hdl_toplevel="imm",
        test_module="test_imm",
        testcase=f"immediate_decoder_random",
    )
