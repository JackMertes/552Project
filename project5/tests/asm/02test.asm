L0: addi x7, x0, 0xf
                        # Wait for x7
    
    
L1: addi x1, x0, 10
                        # Wait for x1
    
    
L2: addi x2, x1, 1        # Now x1 is available
                        # Wait for x2
    
    
L3: addi x3, x2, 1        # Now x2 is available
                        # Wait for x3
    
    
L4: addi x4, x3, 1        # Now x3 is available
                        # Wait for x4
    
    
L5: addi x5, x4, 1        # Now x4 is available
                        # Wait for x5
    
    
L6: addi x6, x5, 1        # Now x5 is available
                        # Wait for x6
    
    
L7: beq x6, x7, L10       # Now x6 and x7 are available
    
    
    
    
    
L8: lui a0, 0xdead
L9: ebreak
L10: lui a0, 0x1
L11: ebreak