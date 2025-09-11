# # NOTE: This is a bit old (based on Ubuntu 22.04 Jammy) so packages will
# # be out of date. If any issues arise, switch away to manually installing
# # dependencies or using a new PPA.
FROM gradescope/autograder-base:ubuntu-jammy

RUN apt-get update && apt-get upgrade -y

# Basic dependencies.
RUN apt-get install -y git make python3 python3-pip jq && apt-get clean
RUN pip install --upgrade pip

# Python dependencies for toplevel test runner and cocotb.
ARG COCOTB=""
RUN if [ -n "${COCOTB}" ]; then pip3 install --no-cache-dir pytest cocotb fixedint; fi

# Icarus verilog simulator.
ARG ICARUS=""
RUN if [ -n "${ICARUS}" ]; then apt-get install -y iverilog && apt-get clean; fi

# QEMU userspace emulation (for running RISC-V binaries with syscalls, but supports all platforms).
ARG QEMU_USER=""
RUN if [ -n "${QEMU_USER}" ]; then apt-get install -y qemu-user && apt-get clean; fi

# QEMU system emulation (for running RISC-V baremetal binaries).
ARG QEMU_SYSTEM=""
RUN if [ -n "${QEMU_SYSTEM}" ]; then apt-get install -y qemu-system-riscv32 && apt-get clean; fi

# Copy RISC-V GCC toolchain and add it to PATH.
# These are the minimal binaries needed for this grader, not the entire
# toolchain provided to the local user image.
# COPY --from=registry.doit.wisc.edu/engr/ece/ece552/wisc25-dist/riscv-gnu-toolchain:2025-08-29 /opt/riscv/bin/riscv64-unknown-elf-gcc /opt/riscv/bin/riscv64-unknown-elf-as /opt/riscv/bin/riscv64-unknown-elf-ld /opt/riscv/bin/
# COPY --from=registry.doit.wisc.edu/engr/ece/ece552/wisc25-dist/riscv-gnu-toolchain:2025-08-29 /opt/riscv/lib/ /opt/riscv/lib/
# COPY --from=registry.doit.wisc.edu/engr/ece/ece552/wisc25-dist/riscv-gnu-toolchain:2025-08-29 /opt/riscv /opt/riscv
# RUN apt-get install -y libmpc-dev && apt-get clean
# ENV PATH="/opt/riscv/bin:${PATH}"

COPY conftest.py /autograder/

COPY build/* /autograder/
