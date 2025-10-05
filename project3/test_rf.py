import pytest
import pathlib
import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge
import util

def to_signed32(n):
    n = n & 0xFFFFFFFF  # mask to 32 bits
    return n if n < 0x80000000 else n - 0x100000000

def to_unsigned32(n):
    n = n & 0xFFFFFFFF
    return n

@cocotb.test()
async def rf_random(dut):
    clock = Clock(dut.i_clk, 10, units='ns')  # 100 MHz clock
    cocotb.start_soon(clock.start())

    # Reset sequence
    if hasattr(dut, "i_rst"):
        dut.i_rst.value = 1
        await RisingEdge(dut.i_clk)
        await RisingEdge(dut.i_clk)
        dut.i_rst.value = 0
        await RisingEdge(dut.i_clk)
        await RisingEdge(dut.i_clk)
        await RisingEdge(dut.i_clk)

    import random
    test_vectors = []
    for _ in range(1000):
        i_rs1_raddr = random.randint(0, 31)
        i_rs2_raddr = random.randint(0, 31)
        i_rd_waddr = random.randint(0, 31)
        i_rd_wdata = random.randint(0, 0xFFFFFFFF)
        i_rd_wen = random.randint(0, 1)
        test_vectors.append((i_rs1_raddr, i_rs2_raddr, i_rd_waddr, i_rd_wdata, i_rd_wen))

    registers = [0] * 32
    BYPASS_EN = dut.BYPASS_EN.value != 0
    print(f"BYPASS_EN = {BYPASS_EN}")

    for i_rs1_raddr, i_rs2_raddr, i_rd_waddr, i_rd_wdata, i_rd_wen in test_vectors:
        dut.i_rs1_raddr.value = i_rs1_raddr
        dut.i_rs2_raddr.value = i_rs2_raddr
        dut.i_rd_waddr.value = i_rd_waddr
        dut.i_rd_wdata.value = i_rd_wdata
        dut.i_rd_wen.value = i_rd_wen

        await RisingEdge(dut.i_clk)

        # update software and hardware models
        if BYPASS_EN:
            expected_rs1 = i_rd_wdata if i_rs1_raddr == i_rd_waddr and i_rd_wen and i_rd_waddr != 0 else registers[i_rs1_raddr]
            expected_rs2 = i_rd_wdata if i_rs2_raddr == i_rd_waddr and i_rd_wen and i_rd_waddr != 0 else registers[i_rs2_raddr]
        else:
            expected_rs1 = registers[i_rs1_raddr]
            expected_rs2 = registers[i_rs2_raddr]

        if i_rd_wen and i_rd_waddr != 0:
            registers[i_rd_waddr] = to_unsigned32(i_rd_wdata)

        # assertions
        val = dut.o_rs1_rdata.value
        assert "x" not in str(val) and "z" not in str(val), f"Invalid value: {val}"
        dut_o_rs1_rdata = int(val)
    
        val = dut.o_rs2_rdata.value
        assert "x" not in str(val) and "z" not in str(val), f"Invalid value: {val}"
        dut_o_rs2_rdata = int(val)

        assert dut_o_rs1_rdata == expected_rs1, f"RS1 Mismatch: got {hex(dut_o_rs1_rdata)}, expected {hex(expected_rs1)}"
        assert dut_o_rs2_rdata == expected_rs2, f"RS2 Mismatch: got {hex(dut_o_rs2_rdata)}, expected {hex(expected_rs2)}"

@pytest.mark.points(10)
def test_rf():
    # proj_path = pathlib.Path(__file__).resolve().parent
    proj_path = pathlib.Path("/autograder/submission/")

    runner = util.get_runner(proj_path, "rf_nobypass")
    runner.test(
        hdl_toplevel="rf_nobypass",
        test_module="test_rf",
        testcase=f"rf_random",
    )

    runner = util.get_runner(proj_path, "rf_bypass")
    runner.test(
        hdl_toplevel="rf_bypass",
        test_module="test_rf",
        testcase=f"rf_random",
    )
