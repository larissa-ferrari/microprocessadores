/**************************************************************************/
/* parse.s - Rotina de interpretação de comando                           */
/**************************************************************************/

.include "var.s"

.global PARSE_COMMAND

PARSE_COMMAND:
    movia   r8, MSG_OK
    call    PRINT_STRING
    ret

PRINT_STRING:
STR_LOOP:
    ldb     r10, (r8)
    beq     r10, r0, STR_END

WAIT_WRITE:
    ldwio   r11, UART_CONTROL(r15)      /* UART_CONTROL = 0x1004 */
    andhi   r11, r11, 0xFFFF
    beq     r11, r0, WAIT_WRITE
    stwio   r10, UART_DATA(r15)      /* UART_DATA = 0x1000 */
    addi    r8, r8, 1
    br      STR_LOOP

STR_END:
    ret

.data
MSG_OK: .asciz "\nComando recebido!\n"
