# =====================================================================
# Projeto de Microprocessadores
# Autores: Beatriz de Oliveira Cavalheri,
#          Eduarda Moreira da Silva,
#          Larissa Rodrigues Ferrari
#
# Este arquivo contém o fluxo principal do programa, responsável por:
# - Ler comandos via JTAG UART
# - Direcionar para subrotinas de LED manual (CALL_LED)
# - Controlar animações (MOSTRA_TRIANGULAR / CALL_ANIMATION)
# - Exibir e rotacionar "Oi 2026" (DISPLAY_OI2026, ROTATE_OI2026)
# - Cancelar rotação (CANCELA_ROTACAO)
# - Controlar cronômetro (via interrupções + CONTA_TEMPO)
# =====================================================================

.equ UART, 0x10001000
.equ KEY_ONE, 0x10000050
.equ SEVEN_SEG_BASE, 0x10000020
.equ DISPLAY_OFF,    0xFFFFFFFF
.global _start
_start:

    movia sp, 0x100000
    movia r6, UART
    movia r8, TEXT_STRING
    movia r12, 0x10000000

    # Zera LEDs no início
    stwio r0, 0(r12) 

INIT:
    ldb r5, 0(r8)
    beq r5, zero, END_INIT
    call PUT_JTAG               # Envia texto de boas-vindas via JTAG UART
    addi r8, r8, 1
    br INIT

END_INIT:

CONFIG:
    movia r4, FLAG_ANIMACAO
    stw r0, 0(r4)               # Inicialmente animação desligada

    movia r4, LEDS_MANUAIS_STATE
    stw r0, 0(r4)               # Zera estado dos LEDs manuais

    call CANCELA_CRONOMETRO     # Reseta cronômetro

    movi r15, 0x1
    wrctl status, r15           # Habilita interrupções globais

    call SET_TIMER              # Configura timer (200ms)

    movia r4, KEY_ONE
    movi r5, 0b0110             # Habilita interrupções KEY1 e KEY2
    stwio r5, 8(r4)

    movi et, 0b11               # Habilita IRQ0 (timer) e IRQ1 (botões)
    wrctl ienable, et

# ===========================
#     LOOP PRINCIPAL
# ===========================

READ_POLL:
    call GET_JTAG               # Lê entrada do usuário via JTAG UART
    movia r7, BUFFER_COMMAND

    ldb r11, 0(r7)      # comando[0]
    ldb r5, 1(r7)       # comando[1]

    # 00 → LED
    movi r10, 0
    beq r11, r10, LED

    # 10 → ANIMAÇÃO (triangular, se você quiser manter)
    movi r10, 1
    beq r11, r10, ANIMACAO

    # 20 → Mostrar "Oi 2026"
    movi r10, 2
    beq r11, r10, CHECK_OI2026

    # (por enquanto, outros comandos são inválidos)
    movia r4, PROMPT_STRING
    call PRINT_PROMPT
    br READ_POLL

CHECK_OI2026:
    # 20 → MOSTRAR_OI2026
    movi r10, 0
    beq r5, r10, MOSTRAR_OI2026

    # 21 → CANCELA_ROTACAO
    movi r10, 1
    beq r5, r10, CANCELA_ROTACAO

    # se não for 20 nem 21, trata como comando inválido
    movia r4, PROMPT_STRING
    call PRINT_PROMPT
    br READ_POLL

# ===========================
#       ANIMAÇÃO DOS LEDS
# ===========================

ANIMACAO:
    ldb r5, 1(r7)

    # 10 → triangular
    movi r10, 0
    beq r5, r10, DO_TRIANGULAR

    # 11 → parar animação
    movi r10, 1
    beq r5, r10, STOP_ANIM

    movia r4, PROMPT_STRING
    call PRINT_PROMPT
    br READ_POLL

DO_TRIANGULAR:
    call MOSTRA_TRIANGULAR      # Calcula número triangular e exibe no display
    movia r4, PROMPT_STRING
    call PRINT_PROMPT
    br READ_POLL


STOP_ANIM:
    movia r4, FLAG_ANIMACAO
    stw r0, 0(r4)               # Desativa animação de LEDs

    movia r4, PROMPT_STRING
    call PRINT_PROMPT
    br READ_POLL

# ===========================
#       LEDS MANUAIS
# ===========================

LED:
    call CALL_LED               # CALL_LED → acende/apaga LED manualmente
    movia r4, PROMPT_STRING
    call PRINT_PROMPT
    br READ_POLL

# ===========================
#   NOVO COMANDO → 20
# ===========================

MOSTRAR_OI2026:
    call DISPLAY_OI2026         # Exibe "Oi 2026" e inicia rotação
    movia r4, PROMPT_STRING
    call PRINT_PROMPT
    br READ_POLL

CANCELA_ROTACAO:
    # Desliga rotação da palavra
    movia r4, FLAG_ROTACAO
    stw   r0, 0(r4)

    # Garante que também não fique "congelada" como pausada
    movia r4, FLAG_ROTACAO_PAUSA
    stw   r0, 0(r4)

    # Opcional: resetar índice e direção
    movia r4, OI2026_INDEX
    stw   r0, 0(r4)

    movia r4, FLAG_ROTACAO_DIR
    stw   r0, 0(r4)

    movia r4, SEVEN_SEG_BASE
    movia r5, DISPLAY_OFF
    stwio r5, 0(r4)             # Apaga display

    movia r4, PROMPT_STRING
    call PRINT_PROMPT
    br READ_POLL

END:
br END


# ===========================
# SUBROTINA PARA IMPRIMIR PROMPT
# ===========================

.global PRINT_PROMPT
PRINT_PROMPT:
    subi sp, sp, 4
    stw r5, 0(sp)

PP_LOOP:
    ldb r5, 0(r4)
    beq r5, zero, PP_END
    stwio r5, 0(r6)
    addi r4, r4, 1
    br PP_LOOP

PP_END:
    ldw r5, 0(sp)
    addi sp, sp, 4
    ret


# ===========================
# MEMÓRIA E STRINGS
# ===========================

.global FLAG_ANIMACAO
FLAG_ANIMACAO:
.word 0

.global BUFFER_COMMAND
BUFFER_COMMAND:
.skip 100

.align 2
.global LEDS_MANUAIS_STATE
LEDS_MANUAIS_STATE:
.word 0

.global FLAG_CRONOMETRO
FLAG_CRONOMETRO:
.word 0

.global CRONOMETRO_PAUSA
CRONOMETRO_PAUSA:
.word 0

.global TEMPO_MIN_DEZ
TEMPO_MIN_DEZ:
.word 0

.global TEMPO_MIN_UNI
TEMPO_MIN_UNI:
.word 0

.global TEMPO_SEG_DEZ
TEMPO_SEG_DEZ:
.word 0

.global TEMPO_SEG_UNI
TEMPO_SEG_UNI:
.word 0

TEXT_STRING:
    .asciz "\r\n 00 XX: Acender xx-esimo LED \n 01 XX: Apagar xx-esimo LED \n 10: animacao com leds com SW0 \n 11: Para a animacao do LED \n 20: Mostrar 'Oi 2026' com rotacao \n 21: Cancelar rotacao da palavra \r\n"

PROMPT_STRING:
    .asciz "\r\nEntre com o comando:\r\n"
