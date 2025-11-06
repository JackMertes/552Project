.text
main:
  # Simple RAW hazard test
  addi x1, x0, 5      # x1 = 5
  addi x2, x1, 3      # x2 = x1 + 3 = 8 (HAZARD: needs x1)
  addi x3, x2, 2      # x3 = x2 + 2 = 10 (HAZARD: needs x2)
  
  # Check result
  addi x4, x0, 10     # x4 = 10
  beq x3, x4, pass    # Should be equal
  
fail:
  li a0, 0xdead
  ebreak
  
pass:
  li a0, 1
  ebreak
