/**************************************************************************/
/* parse.s - Rotina de interpretação de comando                           */
/**************************************************************************/

.global PARSE_COMMAND

PARSE_COMMAND:
    /* Nesta etapa, apenas exibe mensagem genérica */
    movia r8, MSG_OK
    call PRINT_STRING
    ret

PRINT_STRING:
    movia r9, UART_DATA
STR_LOOP:
    ldb r10, (r8)
    beq r10, r0, STR_END
WAIT_WRITE:
    ldwio r11, UART_CONTROL(r15)
    andhi r11, r11, 0xFFFF
    beq r11, r0, WAIT_WRITE
    stwio r10, UART_DATA(r15)
    addi r8, r8, 1
    br STR_LOOP
STR_END:
    ret

.data
MSG_OK: .asciz "\nComando recebido!\n"
