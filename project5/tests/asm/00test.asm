.text
# L0: Initialize x7 (Branch target value)
L0: addi x7, x0, 0xf                  # x7 = 15 (0xf)

    # 3 NOPs to resolve RAW hazard for x7 (L0 -> L7)
    addi x0, x0, 0
    addi x0, x0, 0
    addi x0, x0, 0

# L1: Initialize x1
L1: addi x1, x0, 10                   # x1 = 10
    
    # 3 NOPs to resolve RAW hazard for x1 (L1 -> L2)
    addi x0, x0, 0
    addi x0, x0, 0
    addi x0, x0, 0

# L2: x2 = x1 + 1
L2: addi x2, x1, 1                    # x2 = 11
    
    # 3 NOPs to resolve RAW hazard for x2 (L2 -> L3)
    addi x0, x0, 0
    addi x0, x0, 0
    addi x0, x0, 0

# L3: x3 = x2 + 1
L3: addi x3, x2, 1                    # x3 = 12
    
    # 3 NOPs to resolve RAW hazard for x3 (L3 -> L4)
    addi x0, x0, 0
    addi x0, x0, 0
    addi x0, x0, 0

# L4: x4 = x3 + 1
L4: addi x4, x3, 1                    # x4 = 13
    
    # 3 NOPs to resolve RAW hazard for x4 (L4 -> L5)
    addi x0, x0, 0
    addi x0, x0, 0
    addi x0, x0, 0

# L5: x5 = x4 + 1
L5: addi x5, x4, 1                    # x5 = 14
    
    # 3 NOPs to resolve RAW hazard for x5 (L5 -> L6)
    addi x0, x0, 0
    addi x0, x0, 0
    addi x0, x0, 0

# L6: x6 = x5 + 1
L6: addi x6, x5, 1                    # x6 = 15 (Final calculated value)
    
    # 3 NOPs to resolve RAW hazard for x6 (L6 -> L7)
    addi x0, x0, 0
    addi x0, x0, 0
    addi x0, x0, 0

# L7: Branch instruction (Control Hazard)
L7: beq x6, x7, L10                   # Branch TAKEN (15 == 15)
    
    # 2 NOPs to fill the branch delay slots (Branch resolved in EX)
    addi x0, x0, 0                    # NOP 1 (Will be flushed)
    addi x0, x0, 0                    # NOP 2 (Will be flushed)

# L8: Fall-through instructions (Should be FLUSHED/IGNORED)
L8: lui a0, 0xdead
L9: ebreak

# L10: Branch Target
L10: lui a0, 0x1                      # Sets a0 = 0x1000 (0x1 in the upper 20 bits)
L11: ebreak