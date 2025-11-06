.text
main:
  # Buffer
  li s0, 0x100
  nop
  nop
  nop

  #-------------------------------------------------------------
  # Memory tests
  #-------------------------------------------------------------

# word load/store
test_2:
  jal reset
  nop
  nop
  nop
  li t0, 0x12341234
  nop
  nop
  nop
  sw t0, 0(s0)
  nop
  nop
  nop
  lw t1, 0(s0)
  nop
  nop
  nop
  li gp, 2
  nop
  nop
  nop
  bne t0, t1, fail
  nop
  nop
  nop

# Half-word load/store
test_3:
  jal reset
  nop
  nop
  nop
  li t0, -1234
  nop
  nop
  nop
  sh t0, 0(s0)
  nop
  nop
  nop
  lh t1, 0(s0)
  nop
  nop
  nop
  lhu t2, 0(s0)
  nop
  nop
  nop
  li gp, 3
  nop
  nop
  nop
  bne t0, t1, fail
  nop
  nop
  nop
  li t3, 64302
  nop
  nop
  nop
  bne t2, t3, fail
  nop
  nop
  nop

# Byte load/store
test_4:
  jal reset
  nop
  nop
  nop
  li t0, -123
  nop
  nop
  nop
  sh t0, 0(s0)
  nop
  nop
  nop
  lb t1, 0(s0)
  nop
  nop
  nop
  lbu t2, 0(s0)
  nop
  nop
  nop
  li gp, 4
  nop
  nop
  nop
  bne t0, t1, fail
  nop
  nop
  nop
  li t3, 133
  nop
  nop
  nop
  bne t2, t3, fail
  nop
  nop
  nop

pass:
	li a0, 1
	nop
	nop
	nop
	ebreak
fail:
	li a0, 0xdead
	nop
	nop
	nop
	ebreak

reset:
  li t0, 0
  nop
  nop
  nop
  li t1, 0
  nop
  nop
  nop
  li t2, 0
  nop
  nop
  nop
  li t3, 0
  nop
  nop
  nop
  sw zero, 0(s0)
  nop
  nop
  nop
  ret
  nop
  nop
  nop
