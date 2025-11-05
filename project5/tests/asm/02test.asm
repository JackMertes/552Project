L0: addi x7, x0, 0xf
    nop                    # Wait for x7
    nop
    nop
L1: addi x1, x0, 10
    nop                    # Wait for x1
    nop
    nop
L2: addi x2, x1, 1        # Now x1 is available
    nop                    # Wait for x2
    nop
    nop
L3: addi x3, x2, 1        # Now x2 is available
    nop                    # Wait for x3
    nop
    nop
L4: addi x4, x3, 1        # Now x3 is available
    nop                    # Wait for x4
    nop
    nop
L5: addi x5, x4, 1        # Now x4 is available
    nop                    # Wait for x5
    nop
    nop
L6: addi x6, x5, 1        # Now x5 is available
    nop                    # Wait for x6
    nop
    nop
L7: beq x6, x7, L10       # Now x6 and x7 are available
L8: lui a0, 0xdead
L9: ebreak
L10: lui a0, 0x1
L11: ebreak