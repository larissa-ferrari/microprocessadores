# =====================================================================
# arquivo: org.s
#
# Este arquivo contém o tratamento COMPLETO das interrupções do sistema.
# O fluxo é o seguinte:
#
# 1- O timer gera IRQ0 a cada 200 ms → usado para:
#       - CALL_ANIMATION (piscar LEDs)
#       - ROTATE_OI2026 (rotacionar "Oi 2026")
#       - CONTA_TEMPO (cronômetro incrementa a cada 1s → controlado por tick)
#
# 2- Os botões KEY1 e KEY2 geram IRQ1 → usados para:
#       - KEY1: alternar direção da rotação (FLAG_ROTACAO_DIR)
#       - KEY2: pausar/retomar rotação (FLAG_ROTACAO_PAUSA)
#
# A rotina RTI salva registradores, identifica a causa da interrupção,
# executa a ação apropriada e então restaura tudo antes do ERET.
# =====================================================================

.equ TIMER_BASE, 0x10002000
.equ PUSHBUTTON_BASE, 0x10000050
.equ TIMER_IRQ_MASK, 0b01      # IRQ 0 (Timer)
.equ KEY_IRQ_MASK,   0b10      # IRQ 1 (Botões)

.global TICK_COUNTER
TICK_COUNTER:
    .word 0

# =====================================================================
# Vetor de interrupção (endereço 0x20)
# =====================================================================
.org    0x20
.global RTI
RTI:
    # PRÓLOGO — salvar todos os registradores necessários
    subi sp, sp, 44
    stw ra, 0(sp); stw r4, 4(sp); stw r5, 8(sp); stw r6, 12(sp); stw r7, 16(sp)
    stw r8, 20(sp); stw r10, 24(sp); stw r11, 28(sp); stw r12, 32(sp); stw r13, 36(sp)
    stw et, 40(sp)

    # Lê ipending → indica quais interrupções estão ativas
    rdctl et, ipending
    beq et, r0, END_RTI       # Nenhuma interrupção → encerra
    subi ea, ea, 4            # Ajuste padrão do Nios II para retorno correto

    # ================================================================
    # Verifica se interrupção veio do TIMER (IRQ0)
    # ================================================================
    andi r10, et, TIMER_IRQ_MASK
    bne r10, r0, HANDLE_TIMER

    # ================================================================
    # Verifica se interrupção veio dos BOTÕES (IRQ1-
    # ================================================================
    andi r10, et, KEY_IRQ_MASK
    beq r10, r0, END_RTI
    br HANDLE_KEY

# =====================================================================
# TRATAMENTO DA INTERRUPÇÃO DO TIMER (IRQ0)
# =====================================================================
HANDLE_TIMER:
    movia r10, TIMER_BASE
    stwio r0, 0(r10)          # limpa a interrupção do timer

    # -------------------------------------------------------
    # 1- Animação de LEDs (se ligada)
    # -------------------------------------------------------
    movia r10, FLAG_ANIMACAO
    ldw   r11, 0(r10)
    beq   r11, r0, CHECK_ROTATE      # se desligada → pula
    call  CALL_ANIMATION             # animação avança um passo

# -------------------------------------------------------
# 2- Rotação do texto "Oi 2026"
# -------------------------------------------------------
CHECK_ROTATE:
    movia r10, FLAG_ROTACAO
    ldw   r11, 0(r10)
    beq   r11, r0, CHECK_CRONO       # se rotação desligada → pula

    # Verifica se está pausada (FLAG_ROTACAO_PAUSA)
    movia r10, FLAG_ROTACAO_PAUSA
    ldw   r11, 0(r10)
    bne   r11, r0, CHECK_CRONO       # pausada → não rotaciona

    call  ROTATE_OI2026              # atualiza janela de 4 caracteres

# -------------------------------------------------------
# 3) Cronômetro: avança 1 segundo a cada 5 ticks (200ms)
# -------------------------------------------------------
CHECK_CRONO:
    movia r10, FLAG_CRONOMETRO
    ldw r11, 0(r10)
    beq r11, r0, END_RTI             # não está ligado → encerra

    movia r10, CRONOMETRO_PAUSA
    ldw r11, 0(r10)
    bne r11, r0, END_RTI             # pausado → não conta

    # Contagem de ticks (5 ticks = 1s)
    movia r10, TICK_COUNTER
    ldw r11, 0(r10)
    addi r11, r11, 1

    movi r12, 5
    blt r11, r12, SAVE_TICK

    # 1 segundo completo → zera ticks e incrementa cronômetro
    stw r0, 0(r10)
    call CONTA_TEMPO
    br END_RTI

SAVE_TICK:
    stw r11, 0(r10)
    br END_RTI

# =====================================================================
# TRATAMENTO DAS INTERRUPÇÕES DOS BOTÕES - IRQ1
# =====================================================================
HANDLE_KEY:
    movia r10, PUSHBUTTON_BASE
    ldwio r11, 12(r10)        # lê edge capture (quais KEYs dispararam)
    stwio r0, 12(r10)         # limpa edge capture

    # -------------------------------------------------------
    # KEY1 → muda direção da rotação (0 → 1 → 0 → 1…)
    # -------------------------------------------------------
    movi  r12, 0b0010         # bit 1
    and   r13, r11, r12
    beq   r13, r0, CHECK_KEY2

    movia r10, FLAG_ROTACAO_DIR
    ldw   r12, 0(r10)
    xori  r12, r12, 1         # alterna bit
    stw   r12, 0(r10)

# -------------------------------------------------------
# KEY2 → pausa/despausa a rotação
# -------------------------------------------------------
CHECK_KEY2:
    movi  r12, 0b0100         # bit 2
    and   r13, r11, r12
    beq   r13, r0, END_RTI

    movia r10, FLAG_ROTACAO_PAUSA
    ldw   r12, 0(r10)
    xori  r12, r12, 1         # 0→1 (pausa), 1→0 (retoma)
    stw   r12, 0(r10)

    br END_RTI

# =====================================================================
# EPÍLOGO — restaura registradores e retorna da interrupção
# =====================================================================
END_RTI:
    ldw ra, 0(sp); ldw r4, 4(sp); ldw r5, 8(sp); ldw r6, 12(sp); ldw r7, 16(sp)
    ldw r8, 20(sp); ldw r10, 24(sp); ldw r11, 28(sp); ldw r12, 32(sp); ldw r13, 36(sp)
    ldw et, 40(sp)
    addi sp, sp, 44
    eret                           # retorna para o código interrompido
