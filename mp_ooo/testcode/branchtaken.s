ooo_test.s: 
.align 4
.section .text
.globl _start
    # This program will provide a simple test for
    # demonstrating OOO-ness

    # This test is NOT exhaustive
_start:

# initialize
li x1, 10
li x2, 20
li x3, 30
li x4, 40

bne x1, x2, halt; 

li x5, 50
li x6, 60

bne x4, x6, halt


halt:                 
    slti x0, x0, -256
                       