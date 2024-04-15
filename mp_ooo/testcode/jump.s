.align 4
.section .text
.globl _start

_start:




halt:                 # Infinite loop to keep the processor
    beq x0, x0, halt  # from trying to execute code further

