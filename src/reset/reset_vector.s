.text
.global resetVector

resetVector:
    mrs x0, mpidr_el1
    and x0, x0, #3
    cbz x0, mainCpu

workerCpu:
    wfe
    b workerCpu

mainCpu:
    mrs x0, currentel
    and x0, x0, #0xC
    cmp x0, #0xC
    beq workerCpu
    cmp x0, #8
    beq execEL2

execEL1:
    adr x0, resetVector
    mov sp, x0
    ldr x0, =__kernel_start
    ldr x1, =__kernel_size
    bl initHardware
    b main

execEL2:
    // Initialize EL1 control register to 0
    msr sctlr_el1, xzr
    // Enable AARCH64 and SWIO in EL1
    mov x0, #(1<<31)
    orr x0, x0, #2
    msr hcr_el2, x0
    // Set exception return level to EL1
    mov x0, #0b00101
    msr spsr_el2, x0
    // Disable trapping of FPU operations to EL2
    mov x0, #(3 << 20)
    msr cpacr_el1, x0
    // Set exception link register for current exception level (EL2)
    adr x0, execEL1
    msr elr_el2, x0
    // Setup the exception vector for EL1
    adr x0, exceptionVectorEL1
    msr vbar_el1, x0
    eret

.align 11
exceptionVectorEL1:
.space 0x280
    stp x0, x1, [sp, #-16]!
    stp x2, x3, [sp, #-16]!
    stp x4, x5, [sp, #-16]!
    stp x6, x7, [sp, #-16]!
    stp x8, x9, [sp, #-16]!
    stp x10, x11, [sp, #-16]!
    stp x12, x13, [sp, #-16]!
    stp x14, x15, [sp, #-16]!
    bl handleIRQ
    ldp x14, x15, [sp], #16
    ldp x12, x13, [sp], #16
    ldp x10, x11, [sp], #16
    ldp x8, x9, [sp], #16
    ldp x6, x7, [sp], #16
    ldp x4, x5, [sp], #16
    ldp x2, x3, [sp], #16
    ldp x0, x1, [sp], #16
    eret
