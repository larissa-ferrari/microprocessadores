# =====================================================================
# arquivo: led.s
#
# Este arquivo implementa o controle MANUAL dos LEDs vermelhos.
# A rotina principal é CALL_LED, que:
# - Lê o comando digitado via UART (já processado e colocado em BUFFER_COMMAND)
# - Interpreta comando[1]:
#       0 → ACENDER LED (00 XX)
#       1 → APAGAR  LED (01 XX)
# - Lê comando[2] e comando[3] como dígitos do número do LED (XX)
# - Converte esses dois dígitos num índice de LED
# - Atualiza o estado manual em LEDS_MANUAIS_STATE
# - Se a animação NÃO estiver ativa, escreve esse estado no hardware dos LEDs físicos
#
# Obs: se FLAG_ANIMACAO = 1, o hardware NÃO é alterado aqui.
# =====================================================================

#
#    IDEIA DE FUNCIONAMENTO DO CÓDIGO:
#
#    switch(comando[1]):
#        
#        case 0: ACENDER
#            verificar comando[2] e comando[3]
#            assim que tiver esses 2 valores, consigo saber qual Led deve ser aceso
#            ir até o endereço, e reescrever o valor
#        
#        case 1: APAGAR
#            ler comando[2] e comando[3]
#        

#
#    r4: flag animacao / uso geral nas contas
#    r5: usado em subrotinas
#    r6: UART port 
#    r7: endereço de BUFFER_COMMAND (inicializado na main)
#    r8: string padrão (não usado aqui)
#    r9: ponteiro para enter (não usado aqui)
#    r10: auxiliar para comparação
#    r11: conteúdo lido de comando[1]
#    r12: endereço dos LEDs vermelhos
#    r13: estado manual atual dos LEDs
#    r14: número do LED (0..17)
#    r15: auxiliar para cálculo da dezena
#

.global CALL_LED
CALL_LED:
    
    # PRÓLOGO — salva registradores usados
    subi sp, sp, 24
    stw r4, 0(sp)
    stw r5, 4(sp)
    stw r10, 8(sp)
    stw r11, 12(sp)
    stw r13, 16(sp)
    stw r14, 20(sp)
    
    # Carrega estado manual dos LEDs
    movia r13, LEDS_MANUAIS_STATE
    ldw r13, 0(r13)

    # comando[1]: 0 = ACENDER, 1 = APAGAR
    ldb r11, 1(r7)

    # Se comando[1] == 0 → ACENDER
    addi r10, r0, 0
    beq r11, r10, ACENDER
    
    # Se comando[1] == 1 → APAGAR
    addi r10, r10, 1
    beq r11, r10, APAGAR

    # Caso contrário → comando inválido
    br END_LED

    # =========================================================
    # ACENDER LED
    # =========================================================
    ACENDER:
        
        # Lê dígitos do número do LED
        ldb r4, 2(r7)   # dezena
        ldb r5, 3(r7)   # unidade

        # Converte dezena: r4 = r4 * 10
        slli r4, r4, 1     # *2
        slli r15, r4, 2    # *8
        add r4, r4, r15    # 8x + 2x = 10x

        add r14, r4, r5    # LED = dezena*10 + unidade

        # Cria máscara: 1 << LED
        movi r4, 1
        sll r4, r4, r14

        # Liga o bit correspondente
        or r13, r13, r4
        
        br SAVE_AND_UPDATE

    # =========================================================
    # APAGAR LED
    # Mesmo cálculo, mas limpa o bit
    # =========================================================
    APAGAR:
        
        ldb r4, 2(r7)   # dezena
        ldb r5, 3(r7)   # unidade

        # Converte dezena: r4 = r4 * 10
        slli r4, r4, 1     # *2
        slli r15, r4, 2    # *8
        add r4, r4, r15    # 10x

        add r14, r4, r5    # número do LED

        # Máscara: 1 << LED
        movi r4, 1
        sll r4, r4, r14

        # Inverte máscara para apagar bit
        nor r4, r4, r4
        and r13, r13, r4   # limpa o LED

        br SAVE_AND_UPDATE

    # =========================================================
    # SALVA ESTADO E (opcionalmente) ATUALIZA HARDWARE
    # =========================================================
    SAVE_AND_UPDATE:
        movia r4, LEDS_MANUAIS_STATE
        stw r13, 0(r4)     # salva estado na memória
        
        # Se a animação está ativa, NÃO escreve no hardware agora
        movia r4, FLAG_ANIMACAO
        ldw r5, 0(r4)
        movi r10, 1
        beq r5, r10, END_LED   # se FLAG_ANIMACAO = 1 → pula escrita nos LEDs

        # Se animação desligada → escrever diretamente nos LEDs vermelhos
        movia r4, 0x10000000   # endereço dos LEDs vermelhos
        stwio r13, 0(r4)

    # =========================================================
    # EPÍLOGO — restaurar registradores
    # =========================================================
    END_LED:
        ldw r4, 0(sp)
        ldw r5, 4(sp)
        ldw r10, 8(sp)
        ldw r14, 12(sp)
        ldw r15, 16(sp)
        addi sp, sp, 20
        
        ret
