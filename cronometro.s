# =====================================================================
# arquivo: cronometro.s
#
# Este arquivo contém:
# - Rotina CONTA_TEMPO: responsável por incrementar o cronômetro
#   no formato MM:SS, manipulando unidades e dezenas com propagação.
#
# - Rotina CANCELA_CRONOMETRO: reseta todas as variáveis do cronômetro
#   porém, NÃO apaga o display (isso é feito em outro módulo).
#
# - Rotina MOSTRA_TRIANGULAR: usada pelo comando 10 da UART
#   para calcular o número triangular de N (onde N vem do hardware),
#   quebrá-lo em unidades/dezenas/centenas/milhares e exibir em 7 segmentos.
#
# O display final é montado sempre em um único word, com dígitos
# posicionados em bytes consecutivos [b3 b2 b1 b0].
# =====================================================================

.equ SEVEN_SEG_BASE, 0x10000020                  /* end display de 7 segmentos */

# Código para apagar o display (quando o cronômetro está desligado)
.equ DISPLAY_OFF, 0xFFFFFFFF

# Tabela de códigos para cada dígito decimal no display
SEVEN_SEG_CODES:
    .byte 0x3F  # 0
    .byte 0x06  # 1
    .byte 0x5B  # 2
    .byte 0x4F  # 3
    .byte 0x66  # 4
    .byte 0x6D  # 5
    .byte 0x7D  # 6
    .byte 0x07  # 7
    .byte 0x7F  # 8
    .byte 0x67  # 9

# =====================================================================
# Rotina CONTA_TEMPO
# - Incrementa o cronômetro em 1 segundo
# - A lógica de esperar 5 ticks (200ms * 5 = 1s) está no RTI (org.s)
# =====================================================================
.global CONTA_TEMPO
CONTA_TEMPO:
    subi sp, sp, 12
    stw r4, 0(sp)
    stw r5, 4(sp)
    stw r8, 8(sp)

    # -------------------------------------
    # Incrementa unidade dos segundos
    # -------------------------------------
    movia r8, TEMPO_SEG_UNI
    ldw r4, 0(r8)
    addi r4, r4, 1

    movi r5, 10                 # Se r4 < 10 → apenas salva
    bne r4, r5, SAVE_SEG_UNI

    # r4 == 10 → zera unidade e incrementa dezenas
    mov r4, r0 
    stw r4, 0(r8)
    
    # -------------------------------------
    # Incrementa dezena dos segundos
    # -------------------------------------
    movia r8, TEMPO_SEG_DEZ
    ldw r4, 0(r8)
    addi r4, r4, 1

    movi r5, 6                  # 0–5 permitido para segundos
    bne r4, r5, SAVE_SEG_DEZ

    # r4 == 6 → overflow, zera e passa para minutos
    mov r4, r0
    stw r4, 0(r8)
    
    # -------------------------------------
    # Incrementa unidade dos minutos
    # -------------------------------------
    movia r8, TEMPO_MIN_UNI
    ldw r4, 0(r8)
    addi r4, r4, 1
    
    movi r5, 10
    bne r4, r5, SAVE_MIN_UNI

    # r4 == 10 → zera e incrementa dezenas
    mov r4, r0
    stw r4, 0(r8)

    # -------------------------------------
    # Incrementa dezena dos minutos
    # -------------------------------------
    movia r8, TEMPO_MIN_DEZ
    ldw r4, 0(r8)
    addi r4, r4, 1

# -----------------------------------------
# Salvas diretas (dependendo da transição)
# -----------------------------------------
SAVE_MIN_DEZ:
    stw r4, 0(r8)
    br END_CONTA_TEMPO

SAVE_MIN_UNI:
    stw r4, 0(r8)
    br END_CONTA_TEMPO

SAVE_SEG_DEZ:
    stw r4, 0(r8)
    br END_CONTA_TEMPO

SAVE_SEG_UNI:
    stw r4, 0(r8)

# -----------------------------------------
# EPÍLOGO
# -----------------------------------------
END_CONTA_TEMPO:
    ldw r4, 0(sp)
    ldw r5, 4(sp)
    ldw r8, 8(sp)
    addi sp, sp, 12
    ret


# =====================================================================
# CANCELA_CRONOMETRO
# - Reseta todas as variáveis internas do cronômetro
# - NÃO apaga o display (isso é feito no comando 21)
# =====================================================================
.global CANCELA_CRONOMETRO
CANCELA_CRONOMETRO:
    movia r4, FLAG_CRONOMETRO
    stw r0, 0(r4)

    movia r4, CRONOMETRO_PAUSA
    stw r0, 0(r4)

    movia r4, TEMPO_MIN_DEZ
    stw r0, 0(r4)

    movia r4, TEMPO_MIN_UNI
    stw r0, 0(r4)

    movia r4, TEMPO_SEG_DEZ
    stw r0, 0(r4)

    movia r4, TEMPO_SEG_UNI
    stw r0, 0(r4)

    # DISPLAY NÃO É MAIS APAGADO AQUI!
    ret


# =====================================================================
# MOSTRA_TRIANGULAR
# - Comando 10: lê valor de N do hardware em 0x10000040
# - Calcula T(N) = 1 + 2 + ... + N
# - Decompõe T(N) em unidades / dezenas / centenas / milhares
# - Converte cada dígito para seu código de 7 segmentos
# - Exibe no display
# =====================================================================

.global MOSTRA_TRIANGULAR
MOSTRA_TRIANGULAR:

    # PRÓLOGO — salva registradores usados
    subi sp, sp, 32
    stw r4, 0(sp)
    stw r5, 4(sp)
    stw r6, 8(sp)
    stw r7, 12(sp)
    stw r8, 16(sp)
    stw r9, 20(sp)
    stw r10, 24(sp)
    stw r11, 28(sp)

    # Lê N do hardware (0x10000040), isolando somente 8 bits
    movia r4, 0x10000040
    ldwio r4, 0(r4)
    andi r4, r4, 0xFF

    mov r5, r0        # acumulador da soma T(N)
    mov r6, r0        # contador para 1..N

# -----------------------------------------
# Calcula número triangular: T(N)
# -----------------------------------------
TRI_LOOP:
    beq r6, r4, TRI_END
    addi r6, r6, 1
    add r5, r5, r6
    br TRI_LOOP

TRI_END:
    mov r7, r5        # valor final T(N)

    # -----------------------------------------
    # Extração dígitos (milhar / centena / dezena / unidade)
    # Cada laço subtrai blocos de 10 até restar um dígito
    # -----------------------------------------

    mov r8, r0
U_LOOP:
    subi r7, r7, 10
    blt r7, r0, U_DONE
    addi r8, r8, 1
    br U_LOOP
U_DONE:
    addi r4, r7, 10   # unidade final estará em r4

    mov r7, r8
    mov r8, r0

D_LOOP:
    subi r7, r7, 10
    blt r7, r0, D_DONE
    addi r8, r8, 1
    br D_LOOP
D_DONE:
    addi r5, r7, 10   # dezena final estará em r5
    mov r7, r8

    mov r8, r0

C_LOOP:
    subi r7, r7, 10
    blt r7, r0, C_DONE
    addi r8, r8, 1
    br C_LOOP
C_DONE:
    addi r6, r7, 10   # centena final em r6
    mov r7, r8

    # -----------------------------------------
    # Converte cada dígito via tabela SEVEN_SEG_CODES
    # -----------------------------------------
    movia r10, SEVEN_SEG_CODES

    add r4, r10, r4
    ldb r4, 0(r4)

    add r5, r10, r5
    ldb r5, 0(r5)

    add r6, r10, r6
    ldb r6, 0(r6)

    add r7, r10, r7
    ldb r7, 0(r7)

    # Montagem final do word [b3 b2 b1 b0]
    slli r5, r5, 8
    slli r6, r6, 16
    slli r7, r7, 24

    or r4, r4, r5
    or r4, r4, r6
    or r4, r4, r7

    # Exibe resultado no display
    movia r10, SEVEN_SEG_BASE
    stwio r4, 0(r10)

    # Restaurar registradores
    ldw r4, 0(sp)
    ldw r5, 4(sp)
    ldw r6, 8(sp)
    ldw r7, 12(sp)
    ldw r8, 16(sp)
    ldw r9, 20(sp)
    ldw r10, 24(sp)
    ldw r11, 28(sp)
    addi sp, sp, 32
    ret
