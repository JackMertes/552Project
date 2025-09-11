FROM ubuntu:jammy as build
ARG VERSION="2025.08.29"

RUN apt-get update && apt-get upgrade -y

# Build the RISC-V GCC toolchain.
RUN apt-get install -y autoconf automake autotools-dev curl python3 python3-pip python3-tomli libmpc-dev libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo gperf libtool patchutils bc zlib1g-dev libexpat-dev ninja-build git cmake libglib2.0-dev libslirp-dev
RUN git clone --depth 1 --branch $VERSION https://github.com/riscv/riscv-gnu-toolchain
RUN cd riscv-gnu-toolchain && ./configure --prefix=/opt/riscv --enable-multilib && make -j$(nproc) && make -j$(nproc) musl

FROM ubuntu:jammy

# Copy RISC-V GCC toolchain from build stage.
COPY --from=build /opt/riscv /opt/riscv

RUN apt-get update && apt-get upgrade -y
RUN apt-get install -y libmpc-dev && apt-get clean

# Add toolchain to PATH
ENV PATH="/opt/riscv/bin:${PATH}"
