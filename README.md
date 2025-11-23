# Relatório do Projeto Final de Microprocessadores - 2025

## Introdução

Este relatório apresenta o desenvolvimento completo do projeto final da disciplina de **Microprocessadores**, realizado no segundo semestre de 2025. O objetivo foi implementar um aplicativo em linguagem Assembly para o processador **Nios II**, utilizando a placa **DE2‑Altera**, capaz de interpretar comandos recebidos via UART e executar ações específicas no hardware da placa.

O sistema desenvolvido permite:
- Controle manual de LEDs vermelhos.
- Cálculo e exibição do número triangular.
- Exibição da frase **“Oi 2026”** com rotação automática, reversão de sentido e pausa via botões.
- Controle de animações e sincronização via interrupções de hardware.
- Timer configurado para intervalos fixos de 200 ms.

A seguir, cada módulo do código será explicado individualmente.

---

## Desenvolvimento

### # Arquivo `main.s`
O arquivo `main.s` atua como o **ponto de entrada do sistema**, inicializando o ambiente, configurando interrupções e executando o loop principal responsável por:
- Ler comandos via UART (`GET_JTAG`).
- Interpretá‑los de acordo com a tabela estabelecida no enunciado.
- Redirecionar para a subrotina correspondente:
  - `CALL_LED` → acende ou apaga LEDs vermelhos.
  - `MOSTRA_TRIANGULAR` → realiza o cálculo do número triangular.
  - `DISPLAY_OI2026` → exibe e inicia a rotação da frase.
  - `CANCELA_ROTACAO` → interrompe a rotação.

Trecho ilustrativo:
```
call GET_JTAG
ldb r11, 0(r7)
beq r11, r10, LED
```

A main também configura:
- Timer de 200 ms (`SET_TIMER`)
- Habilitação de interrupções (timer + botões)
- Inicialização dos estados de animação, cronômetro e LEDs.

---

### # Arquivo `led.s`
O arquivo `led.s` contém a subrotina **CALL_LED**, responsável por interpretar os comandos `00 xx` e `01 xx` e alterar diretamente o estado dos LEDs vermelhos.

Principais etapas:
1. Ler os dígitos do número do LED no buffer.
2. Converter dezena e unidade para um índice (`LED = dezena*10 + unidade`).
3. Criar máscara `1 << LED`.
4. Acender (`OR`) ou apagar (`AND`) o LED.
5. Atualizar `LEDS_MANUAIS_STATE`.

Exemplo:
```
sll r4, r4, r14   # máscara: 1 << LED
or r13, r13, r4   # acende LED
```

Se a animação estiver ativa, CALL_LED apenas atualiza memória, deixando o display sob controle da animação.

---

### # Arquivo `animacao.s`
Este módulo contém duas grandes funcionalidades:

#### ## 1. Animação dos LEDs vermelhos – `CALL_ANIMATION`
Executada automaticamente pelo timer:
- Move um LED aceso ao longo da barra.
- Direção definida pelo switch **SW0**:
  - 0 → sentido crescente (0 → 17)
  - 1 → sentido decrescente (17 → 0)
- Usa variável `ANIMATION_COUNTER` para armazenar o LED atual.

#### ## 2. Exibição rotativa da frase “Oi 2026”
A frase é armazenada em `OI2026_BUFFER` e quatro caracteres são exibidos por vez:

Subrotinas:
- **DISPLAY_OI2026**  
  Monta e exibe a janela inicial “Oi20”, ativa a rotação.

- **ROTATE_OI2026**  
  Chamado pelo timer, realiza:
  - Deslocamento circular da janela.
  - Respeita `FLAG_ROTACAO_DIR` (direção) e `FLAG_ROTACAO_PAUSA`.

Exemplo:
```
addi r5, r5, 1   # próxima posição
blt r5, r8, IDX_OK
movi r5, 0       # wrap-around
```

---

### # Arquivo `cronometro.s`
Inclui três funcionalidades principais:

#### ## 1. `CONTA_TEMPO`
Incrementa o cronômetro MM:SS:
- Unidade dos segundos → dezenas → minutos.
- Propagação automática no estouro.
- Usado pelo timer (a cada 5 ticks = 1s).

#### ## 2. `CANCELA_CRONOMETRO`
Reseta todas as variáveis de tempo:
```
stw r0, TEMPO_SEG_UNI
stw r0, TEMPO_SEG_DEZ
...
```

#### ## 3. `MOSTRA_TRIANGULAR`
Implementa o comando **10**:
- Lê valor de `SW7-SW0`.
- Calcula o número triangular.
- Extrai milhares, centenas, dezenas e unidades.
- Converte para os códigos de display de 7 segmentos.

---

### # Arquivo `org.s`
Implementa o **tratamento global de interrupções** (IRQ0 + IRQ1):

#### ## IRQ0 – Timer
Chamado a cada 200 ms:
- Avança animação de LEDs (`CALL_ANIMATION`)
- Avança rotação "Oi 2026" (`ROTATE_OI2026`)
- Atualiza cronômetro a cada 1 segundo

#### ## IRQ1 – Botões
- **KEY1** → alterna sentido da rotação.
- **KEY2** → pausa/despausa rotação.

Exemplo:
```
xori r12, r12, 1   # alterna direção ou pausa
```

---

### # Arquivo `subrotinas.s`

#### ## PUT_JTAG
Envia caracteres para o terminal via UART.

#### ## GET_JTAG
Lê caracteres digitados pelo usuário:
- Limpa o buffer.
- Aceita somente dígitos 0–9.
- Converte ASCII → número.
- Grava em `BUFFER_COMMAND`.

#### ## SET_TIMER
Configura o timer para interrupções a cada 200 ms:
```
movia r4, 10000000
stwio r5, 8(r17)
stwio r5, 12(r17)
```

---

## Conclusão

O sistema desenvolvido atende **integralmente** às especificações do enunciado do projeto final de Microprocessadores.  
Todas as funcionalidades solicitadas foram implementadas:

- Controle individual de LEDs.  
- Cálculo e exibição de número triangular.  
- Exibição animada da frase *"Oi 2026"* com:
  - Rotação automática,
  - Mudança de direção pelo botão KEY1,
  - Pausa e retomada pelo KEY2.  
- Tratamento robusto de interrupções e timer.  
- Estrutura modular, clara e totalmente documentada.

O código foi testado e validado com sucesso, cumprindo todos os requisitos técnicos e funcionais da placa DE2 e do processador Nios II.

---

## Desenvolvido por

- Beatriz de Oliveira Cavalheri
- Eduarda Moreira da Silva
- Larissa Rodrigues Ferrari
