# =====================================================================
# arquivo: subrotinas.s
#
# Este arquivo contém subrotinas de suporte:
# - PUT_JTAG: envia um caractere pela JTAG UART (polling de espaço livre)
# - GET_JTAG: lê uma linha digitada, ecoa no terminal e grava apenas dígitos
#             numéricos (0..9) em BUFFER_COMMAND já convertidos para número.
# - SET_TIMER: configura o timer para gerar interrupções a cada 200 ms.
#
# Registradores (convenção usada no projeto):
# r4: flag animacao / uso geral
# r5: usado em subrotinas
# r6: UART port
# r7: endereço de BUFFER_COMMAND (inicializado na main)
# r8: string padrão (não usado aqui)
# r9: endereço de enter (não usado aqui)
# r10: comparação para condicionais / conversões
# r11: valor lido de BUFFER_COMMAND
# r12: endereço base dos LEDs (referência geral)
# r13: estado atual dos LEDs
# r14: número do LED
# r15: temp para cálculo da dezena
# r16: estado aceso
# r17: base do timer
# r18: flags de animação/cronômetro
# =====================================================================

.equ TIMER_BASE, 0x10002000     # Endereço base do Timer na placa DE2.
.equ COUNTER, 0x2000

# =====================================================================
# PUT_JTAG
#   Envia o caractere em r5 pela JTAG UART (port em r6).
#   Faz polling até haver espaço no buffer de escrita.
# =====================================================================
.global PUT_JTAG
PUT_JTAG:

    # PRÓLOGO — salva r4 (usado como auxiliar)
    subi sp, sp, 4
    stw r4, 0(sp)

PUT_JTAG_POLL:
    ldwio r4, 4(r6)             # lê registrador de controle da JTAG UART
    andhi r4, r4, 0xffff        # verifica espaço para escrita (WSPACE)
    beq r4, r0, PUT_JTAG_POLL   # se não houver espaço, continua esperando (polling)
    stwio r5, 0(r6)             # envia o caractere em r5

END_PUT:
    # EPÍLOGO — restaura r4 e retorna
    ldw r4, 0(sp)
    addi sp, sp, 4
    ret                      # retorna ao chamador


# =====================================================================
# GET_JTAG
#   - Limpa BUFFER_COMMAND (100 bytes)
#   - Lê caracteres da JTAG UART até ENTER (0x0A)
#   - Ecoa cada caractere digitado
#   - Converte apenas dígitos '0'..'9' para número (0..9) e armazena no buffer
#   - Adiciona terminador 0 no final do buffer
# =====================================================================
.global GET_JTAG
GET_JTAG:
    # PRÓLOGO - Guarda ra, r4 e r5 — todos serão usados
    subi sp, sp, 12
    stw ra, 0(sp)
    stw r4, 4(sp)
    stw r5, 8(sp)

    movia r7, BUFFER_COMMAND

    # Zera o buffer (100 bytes)
    movi r10, 100
CLR_BUF:
    stb zero, 0(r7)
    addi r7, r7, 1
    subi r10, r10, 1
    bne r10, zero, CLR_BUF

    movia r7, BUFFER_COMMAND  # volta ponteiro para o início

# -------------------- LOOP PRINCIPAL ------------------------
GET_POLL:
    ldwio r4, 0(r6)           # lê registrador DATA da JTAG UART
    andi r8, r4, 0x8000       # testa bit RVALID (dado válido?)
    beq r8, zero, GET_POLL    # se vazio, continua polling

    andi r5, r4, 0x00FF       # Extrai o byte do caractere (bits 7 a 0)

    movi r9, 0x0A             # Verifica se o caractere é ENTER
    beq r5, r9, END_GET       # Se foi ENTER termina o processo de leitura.

    # ecoa caractere no terminal
    stwio r5, 0(r6)

    # converte ASCII para número APENAS se for dígito '0'..'9'
    # Filtro: só aceita dígitos '0'..'9'

    # Se caractere < '0' → ignora
    movi r10, '0'
    blt r5, r10, GET_POLL

    # Se caractere > '9' → ignora
    movi r10, '9'
    bgt r5, r10, GET_POLL


    # Conversão ASCII → número
    subi r5, r5, '0'          # ASCII → número 0..9
    stb r5, 0(r7)             # Guarda o número no BUFFER_COMMAND
    addi r7, r7, 1            # Avança ponteiro
    br GET_POLL               # Continua lendo caracteres
# ------------------------------------------------------------

END_GET:
    movi r5, 0
    stb r5, 0(r7)             # terminador 0 no fim da string numérica

    # EPÍLOGO
    ldw ra, 0(sp)
    ldw r4, 4(sp)
    ldw r5, 8(sp)
    addi sp, sp, 12
    ret


# =====================================================================
# SET_TIMER
#
# Configura o timer para gerar interrupções a cada 200 ms:
#   - Frequência do clock: 50 MHz
#   - Período desejado: 0,2 s
#   - Valor de contagem: 50.000.000 * 0,2 = 10.000.000
#
# O código:
#   - Programa os registradores period_low e period_high
#   - Liga o timer com interrupção habilitada (ITO=1)
#
# O tratamento das interrupções (RTI) é feito em org.s.
# =====================================================================

.global SET_TIMER
SET_TIMER:

    # PRÓLOGO — salva r17, r4, r5, ra
    subi sp, sp, 16
    stw r17, 0(sp)
    stw r4, 4(sp)
    stw r5, 8(sp)
    stw ra, 12(sp)

    movia r17, TIMER_BASE        # base do timer em r17

    movia r4, 10000000           # valor para 200 ms (50MHz * 0,2s)

    # Escreve 16 bits baixos em period_low (offset 8)
    andi r5, r4, 0xFFFF
    stwio r5, 8(r17)

    # Escreve 16 bits altos em period_high (offset 12)
    srli r5, r4, 16
    stwio r5, 12(r17)
    
    # Controle: START=1, CONT=1, ITO=1 (0x7)
    # Liga o timer e habilita interrupções
    movi r4, 0x7
    stwio r4, 4(r17)             # registrador de controle (offset 4)

    # EPÍLOGO - restaura registradores
    ldw r17, 0(sp)
    ldw r4, 4(sp)
    ldw r5, 8(sp)
    ldw ra, 12(sp)
    addi sp, sp, 16

ret
