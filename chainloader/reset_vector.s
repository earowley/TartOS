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
    ldr x0, =__chainloader_start
    ldr x1, =__chainloader_size
    mov x2, #0x80000
1:  ldr x3, [x2], #0x8
    str x3, [x0], #0x8
    sub x1, x1, #0x8
    cbnz x1, 1b
    adr x0, resetVector
    mov sp, x0
    b main
