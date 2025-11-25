# Relatório do Projeto Final de Microprocessadores – 2025

## 1. Introdução

Este relatório documenta o desenvolvimento do projeto final da disciplina de **Microprocessadores**, realizado no segundo semestre de 2025, utilizando a placa **DE2-Altera** e o processador **Nios II**.

O objetivo foi implementar, em **Assembly**, um sistema embarcado capaz de:

* Interpretar **comandos enviados via JTAG UART**;
* Controlar **LEDs vermelhos** de forma manual e animada;
* Exibir **números e mensagens** no **display de 7 segmentos**;
* Calcular e exibir **número triangular** a partir de valor de entrada;
* Exibir e rotacionar a frase **“Oi 2026”**, permitindo:

  * Rotação automática em intervalos de 200 ms;
  * Mudança de direção via **KEY1**;
  * Pausa/retomada via **KEY2**;
* Implementar um **cronômetro MM:SS** controlado por **interrupções de timer**.

Todo o código foi estruturado de forma **modular**, distribuído entre os arquivos:

* `main.s` – fluxo principal do programa; 
* `subrotinas.s` – funções de suporte (UART e configuração de timer); 
* `led.s` – controle manual dos LEDs; 
* `animacao.s` – animação dos LEDs e rotação de “Oi 2026”; 
* `cronometro.s` – cronômetro e número triangular; 
* `org.s` – rotina de tratamento de interrupções (RTI). 

---

## 2. Conceitos de Hardware e Arquitetura Utilizados

Antes de descrever a implementação, é importante contextualizar os **principais conceitos da disciplina** que foram aplicados no projeto.

### 2.1. JTAG UART e Comunicação Serial

A **JTAG UART** é um periférico da DE2 que permite comunicação serial entre o processador Nios II e o computador via cabo JTAG. Ela é usada como “terminal” para:

* Exibir textos e mensagens (ex.: menu de comandos);
* Receber comandos digitados pelo usuário.

No projeto:

* O endereço base da UART é definido em `main.s` como:

  ```asm
  .equ UART, 0x10001000
  ```

* A subrotina `PUT_JTAG` envia caracteres pela UART, fazendo **polling** até haver espaço no buffer de escrita; 

* A subrotina `GET_JTAG` lê caracteres do usuário, ecoa na tela e grava **apenas dígitos (0–9)** em `BUFFER_COMMAND`, já convertidos para valores numéricos. 

Esse desenho permite um **protocolo simples de comandos numéricos**, facilitando o parsing em Assembly.

---

### 2.2. Timer e Interrupções Periódicas

O **timer** da placa DE2 é usado para gerar interrupções periódicas.

Configuração no projeto:

* Clock: **50 MHz**;
* Período desejado: **200 ms (0,2 s)**;
* Valor de contagem: `50.000.000 * 0,2 = 10.000.000`.

A subrotina `SET_TIMER` escreve esse valor nos registradores `period_low` e `period_high` do timer e habilita:

* **START** – inicia o contador;
* **CONT** – modo contínuo;
* **ITO** – habilita interrupção. 

Esse timer gera uma interrupção (IRQ0) a cada 200 ms, usada para:

* Atualizar a **animação dos LEDs**;
* Rotacionar a frase **“Oi 2026”**;
* Contar ticks para, a cada 5 ticks (1 segundo), **incrementar o cronômetro**.

---

### 2.3. Interrupções no Nios II

O Nios II possui registradores de controle que gerenciam interrupções:

* `status` – habilita/desabilita interrupções globais;
* `ienable` – habilita interrupções específicas (timer, botões, etc.);
* `ipending` – indica quais interrupções estão pendentes.

No código:

* A `main` habilita interrupções globais e seleciona IRQ0 (timer) e IRQ1 (botões): 

  ```asm
  movi r15, 0x1
  wrctl status, r15           # habilita interrupções globais

  movi et, 0b11               # IRQ0 (timer) e IRQ1 (botões)
  wrctl ienable, et
  ```

* O arquivo `org.s` implementa a rotina de interrupção **RTI**, posicionada em `.org 0x20`, que:

  * Salva todos os registradores relevantes na pilha;
  * Lê `ipending` para descobrir a fonte da interrupção;
  * Chama o handler adequado (timer ou botões);
  * Restaura registradores e executa `eret`. 

---

### 2.4. Display de 7 Segmentos

O display de 7 segmentos da DE2 é mapeado em `SEVEN_SEG_BASE = 0x10000020`.
Cada dígito é representado por 1 byte, com bits controlando cada segmento.

O projeto:

* Utiliza uma **tabela de códigos** (`SEVEN_SEG_CODES`) para os dígitos de 0 a 9; 
* Monta sempre um **word de 32 bits** [b3 b2 b1 b0], onde:

  * `b0` → dígito menos significativo,
  * `b3` → dígito mais significativo.

Isso é usado tanto no **cronômetro**, quanto na exibição do **número triangular** e da frase “Oi 2026”.

---

### 2.5. LEDs, Switches e Botões

* **LEDs vermelhos** – controlados por escrita em `0x10000000`.
* **Switches (SW)** – usados como entrada (ex.: valor para número triangular, direção da animação).
* **Botões (KEY1, KEY2)** – usados para controlar a rotação da palavra (“Oi 2026”).

No projeto:

* `SW0` define a direção da **animação dos LEDs** (caminho crescente ou decrescente). 
* `KEY1` alterna a direção da rotação da palavra (direita ↔ esquerda).
* `KEY2` pausa ou retoma a rotação da palavra. 

---

## 3. Arquitetura de Software e Modularização

O código foi dividido em **módulos**, cada um com responsabilidades bem definidas. A seguir, cada arquivo é explicado, com foco na lógica e no papel dentro do sistema.

### 3.1. `main.s` – Fluxo Principal e Protocolo de Comandos

O arquivo `main.s` contém o **ponto de entrada** (`_start`) e a lógica do **loop principal**, responsável por:

- Ler comandos via UART (`GET_JTAG`).
- Interpretá‑los de acordo com a tabela estabelecida no enunciado.
- Redirecionar para a subrotina correspondente:
    - `CALL_LED` → acende ou apaga LEDs vermelhos.
    - `MOSTRA_TRIANGULAR` → realiza o cálculo do número triangular.
    - `DISPLAY_OI2026` → exibe e inicia a rotação da frase.
    - `CANCELA_ROTACAO` → interrompe a rotação.
    
Funções principais:

1. **Inicialização geral**

   * Ajuste da pilha (`sp`);
   * Definição do endereço da UART em `r6`;
   * Apresentação de um **texto inicial explicando os comandos**, enviado via `PUT_JTAG`. 

2. **Configuração do sistema**

   * Zera flags de animação e estados dos LEDs;
   * Chama `CANCELA_CRONOMETRO` para garantir que o cronômetro inicia zerado;
   * Habilita interrupções globais e específicas (timer + botões);
   * Chama `SET_TIMER` para configurar o intervalo de 200 ms;
   * Configura interrupções dos botões na região de memória dos pushbuttons.

3. **Loop principal (`READ_POLL`)**

   * Chama `GET_JTAG`, que:

     * Lê a linha digitada;
     * Mantém apenas os dígitos numéricos;
     * Converte-os para valores numéricos (0–9);
     * Armazena o comando em `BUFFER_COMMAND`. 
   * Em seguida interpreta o **campo comando[0]** e, em alguns casos, também `comando[1]`.

#### 3.1.1. Protocolo de Comandos

O protocolo segue o formato:

* `comando[0]` – categoria principal (LED, animação, texto, etc.);
* `comando[1]` – subcomando ou parâmetro;
* `comando[2]` e `comando[3]` – parâmetros extras (ex.: número do LED).

Tabela básica:

| Comando | Significado                                    |
| ------: | ---------------------------------------------- |
| `00 XX` | Acender o **XX-ésimo** LED (controle manual)   |
| `01 XX` | Apagar o **XX-ésimo** LED                      |
|    `10` | Operações relacionadas à animação / triangular |
|    `20` | Exibir/rotacionar “Oi 2026”                    |
|    `21` | Cancelar rotação da palavra e apagar display   |

Na prática, o código trata assim:

* `comando[0] == 0` → chama `CALL_LED`; 
* `comando[0] == 1` → rota para **ANIMACAO** (triangular ou parada);
* `comando[0] == 2` → rotas para **MOSTRAR_OI2026** ou **CANCELA_ROTACAO**, dependendo de `comando[1]`. 

Após executar a ação, a `main` imprime um `PROMPT_STRING` pedindo um novo comando, mantendo um fluxo interativo contínuo com o usuário.

---

### 3.2. `subrotinas.s` – Suporte de I/O e Timer

Este módulo concentra **rotinas auxiliares** que são reutilizadas em diversos pontos do código: 

#### 3.2.1. Convenção de Registradores

O arquivo define uma **convenção interna** para o uso de registradores (por exemplo, `r6` = UART, `r7` = BUFFER_COMMAND, `r17` = base do timer, etc.), facilitando a leitura e evitando conflitos entre módulos.

#### 3.2.2. `PUT_JTAG`

Lógica:

1. Salva `r4` na pilha (prólogo);
2. Lê o registrador de controle da UART (offset 4);
3. Verifica se há espaço de escrita (bit de WSPACE);
4. Se não houver, repete o polling;
5. Quando houver espaço, escreve o byte de `r5` no registrador de dados (offset 0); 
6. Restaura `r4` e retorna (epílogo).

#### 3.2.3. `GET_JTAG`

A lógica desta rotina é fundamental para o sistema:

1. Salva `ra`, `r4` e `r5` na pilha;
2. Zera os 100 bytes de `BUFFER_COMMAND` para garantir que não exista lixo;
3. Entra em loop de **polling** da UART até chegar um caractere válido (bit RVALID);
4. Para cada caractere:

   * Se for ENTER (`0x0A`), encerra a leitura;
   * Ecoa o caractere no terminal (feedback visual para o usuário);
   * Se não for dígito `'0'`..`'9'`, ignora (não grava no buffer);
   * Se for dígito, converte ASCII → número subtraindo `'0'` e armazena em `BUFFER_COMMAND`. 
5. Ao final, escreve um `0` como terminador lógico e restaura registradores.

Esse filtro garante que a lógica de parsing de comandos em `main.s` seja feita diretamente sobre valores numéricos, simplificando muito o código Assembly.

#### 3.2.4. `SET_TIMER`

Responsável por:

1. Calcular o valor de período (hardcoded como 10.000.000);
2. Separar este valor em parte baixa (16 bits) e alta;
3. Escrever em `period_low` e `period_high`;
4. Escrever `0x7` no registrador de controle (START, CONT e ITO habilitados). 

---

### 3.3. `led.s` – Controle Manual dos LEDs

A rotina principal deste arquivo é `CALL_LED`, responsável por interpretar `comando[1]` e os dois dígitos que representam o índice do LED. 

#### 3.3.1. Lógica Geral

Passos principais:

1. Salvar registradores usados (prólogo);

2. Carregar o estado atual dos LEDs de `LEDS_MANUAIS_STATE`;

3. Ler `comando[1]` (`r11`):

   * `0` → **ACENDER** LED;
   * `1` → **APAGAR** LED;
   * outros valores → comando inválido (retorna sem mudanças). 

4. Em ambos os casos (acender/apagar):

   * Lê a dezena (`comando[2]`) e unidade (`comando[3]`);
   * Converte `dezena` para `dezena*10` usando shift e soma (multiplicação por 10 em Assembly);
   * Calcula `LED = dezena*10 + unidade`, resultando em valor de 0 a 17;
   * Cria uma máscara `1 << LED`.

5. Para acender:

   * `or r13, r13, mascara` → liga o bit do LED.

6. Para apagar:

   * `nor` para inverter a máscara e depois `and` para limpar o bit daquele LED. 

7. Atualiza `LEDS_MANUAIS_STATE` na memória;

8. Se **FLAG_ANIMACAO == 0**, escreve imediatamente o estado no hardware (`0x10000000`);

9. Restaura registradores (epílogo) e retorna.

Essa estrutura separa claramente:

* **Estado lógico** dos LEDs (em memória);
* **Estado físico** dos LEDs (hardware), que pode ser temporariamente tomado pela animação.

---

### 3.4. `animacao.s` – Animação de LEDs e Rotação “Oi 2026”

Este módulo agrega duas funcionalidades avançadas do projeto: 

#### 3.4.1. Animação dos LEDs – `CALL_ANIMATION`

Chamado periodicamente pelo timer (`org.s`):

1. Salva registradores;
2. Lê a máscara de LEDs manuais (`LEDS_MANUAIS_STATE`);
3. Lê o índice atual da animação (`ANIMATION_COUNTER`);
4. Gera uma máscara com `1 << índice` para o LED animado;
5. Faz `OR` dessa máscara com o estado manual (assim, **animação e controle manual coexistem**);
6. Analisa `SW0`:

   * Se `0` → contador cresce (0 → 17 → volta a 0);
   * Se `1` → contador decresce (17 → 0 → volta a 17). 
7. Atualiza `ANIMATION_COUNTER` para o próximo passo;
8. Restaura registradores.

#### 3.4.2. Estruturas para “Oi 2026”

O arquivo define:

* `FLAG_ROTACAO` – indica se a rotação está ativa;
* `FLAG_ROTACAO_DIR` – direção (0 = direita, 1 = esquerda);
* `FLAG_ROTACAO_PAUSA` – 1 se pausada;
* `OI2026_BUFFER` – buffer com 6 bytes correspondentes aos caracteres da frase (já em códigos de 7 segmentos); 
* `OI2026_INDEX` – índice atual da janela de 4 caracteres.

#### 3.4.3. Exibir inicial – `DISPLAY_OI2026`

Lógica:

1. Reinicia `OI2026_INDEX` em 0;
2. Lê os 4 primeiros bytes de `OI2026_BUFFER` (“Oi20”);
3. Monta o word [b3 b2 b1 b0] com shifts e ORs;
4. Escreve no display de 7 segmentos;
5. Salva o padrão em `OI2026_WORD`;
6. Ativa `FLAG_ROTACAO = 1` e garante `FLAG_ROTACAO_PAUSA = 0`. 

#### 3.4.4. Rotação periódica – `ROTATE_OI2026`

Chamado somente pelo timer, dentro de `org.s` **se**:

* `FLAG_ROTACAO == 1` **e**
* `FLAG_ROTACAO_PAUSA == 0`. 

Passos principais:

1. Carrega `OI2026_INDEX`;
2. Lê `FLAG_ROTACAO_DIR`:

   * Se 0 → incrementa índice (direita);
   * Se 1 → decrementa índice (esquerda);
   * Aplica **“wrap-around”** (se passar de 5, volta a 0, etc.);
3. Com base no índice, calcula as posições cíclicas de 4 caracteres a serem exibidos;
4. Lê esses 4 bytes de `OI2026_BUFFER`;
5. Monta o word final e escreve no display;
6. Atualiza `OI2026_WORD` para depuração/estado interno. 

---

### 3.5. `cronometro.s` – Cronômetro e Número Triangular

Este arquivo contém três funcionalidades centrais: 

#### 3.5.1. `CONTA_TEMPO` – Incremento de MM:SS

Cada chamada desta rotina incrementa o cronômetro em **1 segundo**. A lógica de chamar `CONTA_TEMPO` a cada 5 ticks de 200 ms é feita em `org.s`.

Passos:

1. Incrementa a **unidade dos segundos**;
2. Se atingir 10, zera e incrementa a **dezena dos segundos**;
3. Se a dezena dos segundos chegar a 6 (60 segundos), zera e incrementa **unidade dos minutos**;
4. Se unidade dos minutos chegar a 10, zera e incrementa **dezena dos minutos**;
5. Salva os valores em `TEMPO_SEG_UNI`, `TEMPO_SEG_DEZ`, `TEMPO_MIN_UNI`, `TEMPO_MIN_DEZ`. 

Essa lógica reproduz fielmente a contagem de tempo no formato MM:SS.


#### 3.5.2. `CANCELA_CRONOMETRO`

Reseta o estado interno do cronômetro:

* `FLAG_CRONOMETRO`;
* `CRONOMETRO_PAUSA`;
* todos os campos de tempo (minutos e segundos, unidades e dezenas).

Importante: **não apaga o display** aqui; isso é feito quando o comando 21 é chamado na `main` para “limpar” a palavra / display. 

#### 3.5.3. `MOSTRA_TRIANGULAR`

Implementação do comando **10**, que:

1. Lê um valor `N` do hardware, a partir do endereço `0x10000040` (pinos de entrada, usualmente switches `SW7-SW0`.); 
2. Calcula o **número triangular** `T(N) = 1 + 2 + ... + N` usando um laço;
3. Decompõe `T(N)` em unidades, dezenas, centenas e milhares através de laços que subtraem blocos de 10 (método simples, porém fácil de entender em Assembly);
4. Para cada dígito, soma o índice à tabela `SEVEN_SEG_CODES` e obtém o código de 7 segmentos;
5. Monta o word final [b3 b2 b1 b0];
6. Escreve o resultado no display.

Essa rotina demonstra bem o uso conjunto de **aritmética**, **tabelas de lookup** e **acesso ao display**.

---

### 3.6. `org.s` – Tratamento de Interrupções (RTI)

Este arquivo é o “cérebro” do sistema de interrupções. 

#### 3.6.1. Estrutura Geral da RTI

1. Posiciona o vetor em `.org 0x20`;
2. Salva na pilha:

   * `ra`, registradores de uso geral (`r4`..`r13`), e o próprio `et`;
3. Lê `ipending` para verificar quais interrupções estão ativas;
4. Ajusta `ea` para o retorno correto (padrão do Nios II);
5. Verifica:

   * Se bit do timer (IRQ0) está setado → `HANDLE_TIMER`;
   * Senão, se bit dos botões (IRQ1) está setado → `HANDLE_KEY`;
6. Ao final, restaura registradores e executa `eret`. 

#### 3.6.2. `HANDLE_TIMER` – Lado do Timer

Quando o timer dispara:

1. Limpa o bit de interrupção escrevendo em seu registrador de status;
2. Verifica `FLAG_ANIMACAO`:

   * Se ativo → chama `CALL_ANIMATION`;
3. Verifica `FLAG_ROTACAO` e `FLAG_ROTACAO_PAUSA`:

   * Se rotação ativa e não pausada → chama `ROTATE_OI2026`;
4. Verifica `FLAG_CRONOMETRO` e `CRONOMETRO_PAUSA`:

   * Se cronômetro ativo e não pausado:

     * Incrementa `TICK_COUNTER`;
     * Se `TICK_COUNTER == 5`:

       * Zera `TICK_COUNTER`;
       * Chama `CONTA_TEMPO`. 

Esse encadeamento mostra **uso integrado do timer** para três funcionalidades distintas, todas coordenadas via flags.

#### 3.6.3. `HANDLE_KEY` – Lado dos Botões

Ao detectar IRQ1:

1. Lê o registrador de `edge capture` dos botões e limpa o registrador (ack);
2. Analisa se **KEY1** foi pressionado (bit 1):

   * Se sim, alterna (`xori`) o valor de `FLAG_ROTACAO_DIR`, invertendo o sentido da rotação da palavra;
3. Analisa se **KEY2** foi pressionado (bit 2):

   * Se sim, alterna `FLAG_ROTACAO_PAUSA` (0 → 1 → 0), pausando ou retomando a rotação. 

---

## 4. Visão Geral do Desenvolvimento e Decisões de Projeto

Durante o desenvolvimento, algumas decisões foram importantes para manter o código organizado e funcional:

1. **Modularização por responsabilidade**
   Separar o projeto em arquivos (`main.s`, `led.s`, `animacao.s`, `cronometro.s`, `subrotinas.s`, `org.s`) torna mais fácil testar e entender cada parte de forma isolada, além de refletir boas práticas de engenharia de software, mesmo em Assembly.

2. **Uso consistente de flags em memória**
   Várias funcionalidades (animação, rotação, cronômetro, pausa, direção) são controladas via **variáveis globais** (flags). Isso permite que **a lógica de interrupção** e **o loop principal** conversem sem conflitos, já que as flags representam o estado atual do sistema.

3. **Convenção de registradores e uso da pilha**
   Cada subrotina salva apenas os registradores que usa, garantindo que o chamador não tenha seus valores corrompidos. Isso é essencial quando se trabalha com muitas interrupções e chamadas encadeadas.

4. **Separação entre “estado lógico” e hardware**
   No caso dos LEDs, o estado manual é sempre mantido em `LEDS_MANUAIS_STATE`. A animação gera uma máscara adicional e apenas na escrita final essa combinação é enviada ao hardware. Isso facilita a coexistência de animação e controle manual sem sobrescrever um ao outro.

5. **Polling apenas onde faz sentido (UART)**
   A UART, por ser dependente da digitação do usuário, é tratada por **polling** (`GET_JTAG` e `PUT_JTAG`). Já as funcionalidades de tempo e interação rápida (animações, cronômetro) são tratadas por **interrupções**, o que é mais eficiente e adequado.

---

## 5. Conclusão

O projeto desenvolvido implementa, de forma completa e coerente, os requisitos propostos na disciplina de Microprocessadores:

* **Controle manual dos LEDs** via comandos pela UART;
* **Animação de LEDs** com direção controlada por switch;
* **Cálculo e exibição de número triangular** a partir de entrada de hardware;
* **Exibição e rotação da mensagem “Oi 2026”**, com:

  * Rotação automática;
  * Mudança de direção por **KEY1**;
  * Pausa e retomada por **KEY2**;
* **Cronômetro MM:SS** alimentado por interrupções de timer;
* Uso correto de **interrupções**, **timer**, **JTAG UART**, **display de 7 segmentos** e **mapeamento de memória** da DE2.

Além de cumprir as especificações funcionais, o código foi estruturado de forma **modular e documentada**, facilitando manutenção, depuração e eventual expansão do sistema (por exemplo, novos comandos, novos modos de exibição ou mais animações).

---

## 6. Integrantes

* **Beatriz de Oliveira Cavalheri**
* **Eduarda Moreira da Silva**
* **Larissa Rodrigues Ferrari**

---
