L0: addi x7, x0, 0xf
L1: addi x1, x0, 10
L2: addi x2, x1, 1
L3: addi x3, x2, 1
L4: addi x4, x3, 1
L5: addi x5, x4, 1
L6: addi x6, x5, 1
L7: beq x6, x7, L10
L8: lui a0, 0xdead
L9: ebreak
L10: lui a0, 0x1
L11: ebreak