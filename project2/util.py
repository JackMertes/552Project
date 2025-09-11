import os
import pathlib

import cocotb.runner
from cocotb.runner import Simulator

def get_runner(proj_path: pathlib.Path, toplevel: str) -> Simulator:
    sim = os.getenv("SIM", "icarus")
    sources = [str(f) for f in proj_path.glob("*.v") if f.is_file()]

    runner = cocotb.runner.get_runner(sim)
    runner.build(
        verilog_sources=sources,
        vhdl_sources=[],
        hdl_toplevel=toplevel,
        always=True,
        timescale=("1ns","1ps"),
    )

    return runner
