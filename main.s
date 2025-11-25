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

.equ UART, 0x10001000               # Define o endereço base da JTAG UART (comunicação com o terminal do PC).
.equ KEY_ONE, 0x10000050            # Endereço base dos botões KEY0–KEY3.
.equ SEVEN_SEG_BASE, 0x10000020     # Endereço dos displays de 7 segmentos (HEX0–HEX3).
.equ DISPLAY_OFF,    0xFFFFFFFF     # Valor que apaga completamente o display.
.global _start
_start:

    movia sp, 0x100000              # Inicializa o stack pointer
    movia r6, UART                  # r6 passa a guardar o endereço da UART
    movia r8, TEXT_STRING           # r8 aponta para o texto inicial que será enviado ao terminal
    movia r12, 0x10000000           # r12 aponta para a base dos LEDs vermelhos.

    # Zera LEDs no início
    stwio r0, 0(r12)                # Escreve 0 no registrador de LEDs → todos apagados

INIT:
    ldb r5, 0(r8)                   # Lê 1 byte da string TEXT_STRING.
    beq r5, zero, END_INIT          # Se for zero (fim da string), termina.
    call PUT_JTAG                   # Envia o caractere para o terminal via UART.
    addi r8, r8, 1                  # Avança para o próximo caractere.
    br INIT                         # Repete o laço.

END_INIT:

CONFIG:
    movia r4, FLAG_ANIMACAO
    stw r0, 0(r4)                   # Inicialmente animação desligada

    movia r4, LEDS_MANUAIS_STATE
    stw r0, 0(r4)                   # Zera estado dos LEDs manuais

    call CANCELA_CRONOMETRO         # Reseta cronômetro (chama a rotina)

    # Habilita interrupções globais
    movi r15, 0x1                   # Esse valor coloca o bit PIE = 1 no registrador status.
    wrctl status, r15               # Escreve no registrador status da CPU: status.PIE = 1 → Processor Interrupt Enable

    call SET_TIMER                  # Configura timer (200ms)

    # Habilita interrupções KEY1 e KEY2
    movia r4, KEY_ONE               
    movi r5, 0b0110                 # r5 recebe o valor binário: 0110
    stwio r5, 8(r4)                 # Escreve em KEY_ONE + offset 8, que é o Interrupt Mask Register dos botões.

    # # Habilita IRQ0 (timer) e IRQ1 (botões)
    movi et, 0b11                   
    wrctl ienable, et               # A CPU NÃO aceita interrupções. SE o registrador IENABLE não tiver o bit referente àquela interrupção habilitado.

# ===========================
#     LOOP PRINCIPAL
# ===========================

# Começo do laço onde comandos são lidos repetidamente.
READ_POLL:
    call GET_JTAG                   # Lê entrada do usuário via JTAG UART
    movia r7, BUFFER_COMMAND        # r7 aponta para o buffer de comandos

    ldb r11, 0(r7)                  # lê comando[0]
    ldb r5, 1(r7)                   # lê comando[1]

    # 00 → LED
    movi r10, 0
    beq r11, r10, LED

    # 10 → ANIMAÇÃO (triangular, se você quiser manter)
    movi r10, 1
    beq r11, r10, ANIMACAO

    # 20 → Mostrar "Oi 2026"
    movi r10, 2
    beq r11, r10, CHECK_OI2026

    # Outros comandos são inválidos
    movia r4, PROMPT_STRING         # Carrega o endereço da string PROMPT_STRING
    call PRINT_PROMPT               # Chama a função PRINT_PROMPT
    br READ_POLL                    # Retorna ao loop principal

CHECK_OI2026:
    # 20 → MOSTRAR_OI2026
    movi r10, 0
    beq r5, r10, MOSTRAR_OI2026     # Se comando[1] == 0, mostrar Oi 2026

    # 21 → CANCELA_ROTACAO
    movi r10, 1
    beq r5, r10, CANCELA_ROTACAO    # Se comando[1] == 1, cancelar rotação

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
    subi sp, sp, 4          # Reserva 4 bytes na pilha, movendo o stack pointer para baixo
    stw r5, 0(sp)           # Reseta registrador temporário 

# Início do laço que percorre a string a partir de r4.
PP_LOOP:
    ldb r5, 0(r4)           # ê 1 caractere da string
    beq r5, zero, PP_END    # Testa se chegou ao fim da string
    stwio r5, 0(r6)         # Envia o caractere para a UART
    addi r4, r4, 1          # Avança para o próximo caractere
    br PP_LOOP              # Repete o loop

PP_END:
    ldw r5, 0(sp)           # Fim da string — restaura r5
    addi sp, sp, 4          # Libera espaço da pilha
    ret                     # Retorna para o chamador


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
