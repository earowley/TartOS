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
    ldr x1, =resetVector
    mov sp, x1
    bl initHardware
    b main
