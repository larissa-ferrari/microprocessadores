# =====================================================================
# arquivo: animacao.s
# 
# Este arquivo contém:
# - Rotina de animação dos LEDs vermelhos (CALL_ANIMATION)
# - Controle de direção via switch (SW0)
# - Implementação completa da rotação da palavra "Oi 2026" (DISPLAY_OI2026 e ROTATE_OI2026)
# - Flags de estado para direção e pausa da rotação
#
# Observação:
# A função CALL_ANIMATION é chamada automaticamente no handler de interrupção do timer (a cada 200 ms).
# =====================================================================

.equ SWITCH, 0x40

.global CALL_ANIMATION
CALL_ANIMATION:
    
    # PRÓLOGO - salva os registradores usados
    subi sp, sp, 20                         # Mais espaço para salvar registradores
    stw ra, 0(sp)
    stw r4, 4(sp)
    stw r5, 8(sp)
    stw r8, 12(sp)
    stw r10, 16(sp)
    movia r12, 0x10000000                   # Endereço do led vermelho

    # Carrega estado manual dos leds    
    movia r10, LEDS_MANUAIS_STATE           # Pegar o estado dos LEDs manuais da memória
    ldw r10, 0(r10)                         # r10 contém a máscara dos LEDs manuais

    # Pega o índice atual da animação (qual LED piscar)
    movia r8, ANIMATION_COUNTER             # Pega o contador da animação e calcula o LED da vez
    ldw r8, 0(r8)                           # r8 = número do LED da animação

    # Cria a máscara para o LED da animação
    movi r4, 1
    sll r4, r4, r8                          # r4 contém a máscara do LED da animação

    # Combina máscara da animação com LEDs manuais
    or r4, r4, r10                          # r4 = máscara final (manuais + animação)
    stwio r4, 0(r12)

    # Leitura da alavanca SW0 para decidir direção de deslocamento
    ldwio r5, SWITCH(r12)
    andi r5, r5, 1                          # Isola o bit 0 da alavanca

    beq r5, r0, DIR_ESQ_STEP                # Se alavanca = 0, (17 <- 0)
    br ESQ_DIR_STEP                         # Se alavanca = 1, (17 -> 0)

    DIR_ESQ_STEP:

        # Movimento do LED quando SW0 = 0 (caminho crescente)
        addi r8, r8, 1                      # Incrementa o contador do LED
        movi r10, 18
        bne r8, r10, SAVE_STATE             # Se não chegou em 18, apenas salva
        mov r8, r0                          # Se chegou em 18, volta para 0
        
        br SAVE_STATE

    ESQ_DIR_STEP:
        
        # Movimento do LED quando SW0 = 1 (caminho decrescente)
        subi r8, r8, 1                      # Decrementa o contador do LED
        movi r10, -1
        bne r8, r10, SAVE_STATE             # Se não chegou em -1, apenas salva
        movi r8, 17                         # Se chegou em -1, volta para 17
        
        br SAVE_STATE

SAVE_STATE:

    # Salva o novo estado (próximo LED a ser aceso) na memória
    movia r4, ANIMATION_COUNTER
    stw r8, 0(r4)

END_ANIMATION:
    
    # EPÍLOGO - restaura registradores
    ldw ra, 0(sp)
    ldw r4, 4(sp)
    ldw r5, 8(sp)
    ldw r8, 12(sp)
    ldw r10, 16(sp)
    addi sp, sp, 20
    
    ret

.global ANIMATION_COUNTER
ANIMATION_COUNTER:
.word 0


# =====================================================================
# FLAGS e BUFFER para exibição do texto "Oi 2026" no display de
# 7 segmentos. A rotação é tratada pelo timer usando ROTATE_OI2026.
# =====================================================================

.equ SEVEN_SEG_BASE, 0x10000020

.global FLAG_ROTACAO         # 1 = rotação ativa
FLAG_ROTACAO:
    .word 0

.global FLAG_ROTACAO_DIR     # 0 = direita, 1 = esquerda
FLAG_ROTACAO_DIR:
    .word 0

.global OI2026_WORD          # último padrão exibido (não essencial)
OI2026_WORD:
    .word 0

# Buffer contendo os 6 caracteres usados na rotação
.global OI2026_BUFFER
OI2026_BUFFER:
    .byte 0x3F   # 'O'
    .byte 0x06   # 'i'
    .byte 0x5B   # '2'
    .byte 0x3F   # '0'
    .byte 0x5B   # '2'
    .byte 0x7D   # '6'
    .byte 0x00   # padding
    .byte 0x00   # padding

.global OI2026_INDEX         # índice atual da rotação
OI2026_INDEX:
    .word 0

.global FLAG_ROTACAO_PAUSA   # 1 = pausado, 0 = rodando
FLAG_ROTACAO_PAUSA:
    .word 0


# =====================================================================
# Rotina: DISPLAY_OI2026
# Objetivo:
# - exibir os primeiros 4 chars da palavra ("Oi20")
# - habilitar flag de rotação
# =====================================================================

.global DISPLAY_OI2026
DISPLAY_OI2026:
    subi sp, sp, 16
    stw r4, 0(sp)
    stw r5, 4(sp)
    stw r6, 8(sp)
    stw r7, 12(sp)

    # Reinicia índice
    movia r4, OI2026_INDEX
    stw   r0, 0(r4)

    # Carrega primeiros 4 caracteres "Oi20"
    movia r4, OI2026_BUFFER
    ldb   r5, 0(r4)   # 'O'
    ldb   r6, 1(r4)   # 'i'
    ldb   r7, 2(r4)   # '2'
    ldb   r10,3(r4)   # '0'

    # Constrói word [b3 b2 b1 b0]
    slli r5, r5, 24
    slli r6, r6, 16
    slli r7, r7, 8

    or   r5, r5, r6
    or   r5, r5, r7
    or   r5, r5, r10

    # Exibe no display
    movia r4, SEVEN_SEG_BASE
    stwio r5, 0(r4)

    # Guarda padrão na memória
    movia r6, OI2026_WORD
    stw   r5, 0(r6)

    # Ativa rotação
    movia r6, FLAG_ROTACAO
    movi  r7, 1
    stw   r7, 0(r6)

    # Garante que não está pausado
    movia r6, FLAG_ROTACAO_PAUSA
    stw   r0, 0(r6)

    # Restaura registradores
    ldw r4, 0(sp)
    ldw r5, 4(sp)
    ldw r6, 8(sp)
    ldw r7, 12(sp)
    addi sp, sp, 16
    ret


# =====================================================================
# Rotina: ROTATE_OI2026
# Objetivo:
# - chamada pelo timer
# - rotaciona a string (direita/esquerda)
# - monta palavra final e envia ao display
# =====================================================================

.global ROTATE_OI2026
ROTATE_OI2026:
    subi sp, sp, 16
    stw r4, 0(sp)
    stw r5, 4(sp)
    stw r6, 8(sp)
    stw r7, 12(sp)

    # Carrega índice atual
    movia r4, OI2026_INDEX
    ldw   r5, 0(r4)

    # Lê direção (0 = dir, 1 = esq)
    movia r6, FLAG_ROTACAO_DIR
    ldw   r6, 0(r6)

    movi  r8, 6              # tamanho do buffer

    # -----------------------------------
    # Direção das rotações
    # -----------------------------------
    beq   r6, r0, ROT_DIR    # se 0: direita

    # Rotação esquerda: idx--
    subi  r5, r5, 1
    bge   r5, r0, IDX_OK
    movi  r5, 5              # wrap
    br    IDX_OK

ROT_DIR:
    # Rotação direita: idx++
    addi  r5, r5, 1
    blt   r5, r8, IDX_OK
    movi  r5, 0              # wrap

# Salva índice normalizado
IDX_OK:
    stw   r5, 0(r4)

    # Base do buffer
    movia r4, OI2026_BUFFER

    # Calcula posições cíclicas pos0..pos3
    mov   r9,  r5
    addi  r10, r5, 1
    addi  r11, r5, 2
    addi  r12, r5, 3

    # Aplica módulo 6
    movi  r8, 6
    blt   r10, r8, P1_OK
    addi  r10, r10, -6
P1_OK:
    blt   r11, r8, P2_OK
    addi  r11, r11, -6
P2_OK:
    blt   r12, r8, P3_OK
    addi  r12, r12, -6
P3_OK:

    # -----------------------------------
    # Carrega os 4 bytes que serão exibidos
    # -----------------------------------
    add   r13, r4, r9
    ldb   r5, 0(r13)

    add   r13, r4, r10
    ldb   r6, 0(r13)

    add   r13, r4, r11
    ldb   r7, 0(r13)

    add   r13, r4, r12
    ldb   r10,0(r13)

    # Constrói Word final
    slli  r5, r5, 24
    slli  r6, r6, 16
    slli  r7, r7, 8

    or    r5, r5, r6
    or    r5, r5, r7
    or    r5, r5, r10

    # Escreve no display
    movia r4, SEVEN_SEG_BASE
    stwio r5, 0(r4)

    # Atualiza padrão em memória (opcional)
    movia r4, OI2026_WORD
    stw   r5, 0(r4)

    # EPÍLOGO
    ldw r4, 0(sp)
    ldw r5, 4(sp)
    ldw r6, 8(sp)
    ldw r7, 12(sp)
    addi sp, sp, 16
    ret