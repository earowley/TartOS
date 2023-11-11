.text
.global resetVector

resetVector:
    mrs x1, mpidr_el1
    and x1, x1, #3
    cbz x1, mainCpu

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
    ldr x1, =resetVector
    mov sp, x1
    bl initHardware
    b main

execEL2:
    
