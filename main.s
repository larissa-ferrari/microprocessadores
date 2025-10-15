/**************************************************************************/
/* main.s - Interpretação de comandos via UART                            */
/* Etapa: 14/10 - Comunicação e leitura básica                            */
/**************************************************************************/

.include "var.s"

.global _start

_start:
    /* Configura stack e endereço base */
    movia   sp, 0x0FFFFFFF
    movia   r15, 0x10000000         /* Endereço base dos periféricos */

    /* Habilita interrupções globais (modo supervisor) */
    movi    r8, 0b1
    wrctl   status, r8

    /* (Opcional) Configura timer de 200ms, mas ainda não usado */
    movia   r8, 0x9680
    stwio   r8, TIMER_ADDRESS_COUNTER_LOW(r15)
    movi    r8, 0x98
    stwio   r8, TIMER_ADDRESS_COUNTER_HIGH(r15)
    movi    r8, 0b111
    stwio   r8, TIMER_ADDRESS_CONTROL(r15)

    /* Exibe mensagem inicial */
    call    PRINT_START_MSG

    /* Define contador de caracteres e registrador do comando */
    movi    r13, 4
    mov     r14, r0

UART_LOOP:
    /* Lê UART (polling) */
    ldwio   r8, 0x1000(r15)
    andi    r9, r8, 0x8000           /* Bit RVALID */
    beq     r9, r0, UART_LOOP        /* Espera até receber dado */

    andi    r8, r8, 0xFF             /* Mantém apenas o byte do caractere */

    /* Ecoa o caractere de volta */
WAIT_UART_WRITE:
    ldwio   r9, 0x1004(r15)
    andhi   r9, r9, 0xFFFF
    beq     r9, r0, WAIT_UART_WRITE
    stwio   r8, 0x1000(r15)

    /* Verifica tecla ENTER (NEWLINE) */
    movi    r11, NEWLINE
    beq     r8, r11, HANDLE_ENTER

    /* Armazena caractere no registrador r14 */
    addi    r13, r13, -1
    slli    r14, r14, 8
    or      r14, r14, r8
    br      UART_LOOP

HANDLE_ENTER:
    /* Chama rotina para tratar o comando */
    call    PARSE_COMMAND
    /* Reinicia leitura */
    movi    r13, 4
    mov     r14, r0
    call    PRINT_START_MSG
    br      UART_LOOP


/**************************************************************************/
/* Função: PRINT_START_MSG                                                */
/**************************************************************************/
PRINT_START_MSG:
    movia   r8, MSG_START
PRINT_LOOP:
    ldb     r9, (r8)
    beq     r9, r0, PRINT_END
WAIT_WRITE:
    ldwio   r10, 0x1004(r15)
    andhi   r10, r10, 0xFFFF
    beq     r10, r0, WAIT_WRITE
    stwio   r9, 0x1000(r15)
    addi    r8, r8, 1
    br      PRINT_LOOP
PRINT_END:
    ret

/**************************************************************************/
/* Mensagens                                                              */
/**************************************************************************/
.data
MSG_START: .asciz "\nEntre com o comando:\n"
