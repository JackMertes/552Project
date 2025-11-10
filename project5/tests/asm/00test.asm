    
    li x1, 0x00000000
    li x2, 0x00007fff
    add x30, x1, x2
    li x29, 0x00007fff
    li gp, 8
    bne x30, x29, fail

pass:
    li a0, 1
    ebreak
    fail:
    li a0, 0xdead
    ebreak
