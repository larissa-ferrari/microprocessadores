# Projeto de Microprocessadores

## Sobre o Projeto
Este projeto consiste em um sistema desenvolvido para a placa DE2 Altera que implementa um aplicativo console via comunicação UART. O sistema aceita comandos do usuário para controlar LEDs, executar animações e gerenciar um cronômetro, utilizando a linguagem de montagem do Nios II.

---

## Estrutura do Projeto

### Arquivos Principais

#### 1. `main.s`
Arquivo principal do sistema que gerencia o loop de comandos e inicialização.

_start:

* Configuração inicial do sistema
* Inicialização de hardware
* Loop principal de polling de comandos
* Despacho para subrotinas específicas

#### 2. `led.s`
Controla os LEDs individuais da placa.

CALL_LED:

* Processamento de comandos 00 (acender) e 01 (apagar)
* Conversão ASCII para número do LED
* Aplicação de máscaras de bits
* Atualização do estado dos LEDs

#### 3. `animacao.s`
Implementa o sistema de animação dos LEDs.

CALL_ANIMATION:

* Controle de direção baseado no switch SW0
* Animação direita-esquerda ou esquerda-direita
* Atualização contínua do contador de animação
* Integração com estado manual dos LEDs


#### 4. `cronometro.s`
Gerencia o sistema de cronômetro com display de 7 segmentos.

CONTA_TEMPO:

* Incremento de segundos e minutos
* Tratamento de overflow (59s → 00s, 59m → 00m)
* Conversão para display de 7 segmentos
* Atualização do hardware de display

#### 5. `subrotinas.s`
Contém rotinas auxiliares do sistema.

GET_JTAG:

* Leitura de caracteres da UART
* Conversão ASCII para numérico
* Armazenamento em buffer circular

PUT_JTAG:

* Transmissão serial de caracteres
* Verificação de hardware disponível

SET_TIMER:

* Configuração do timer para 200ms
* Habilitação de interrupções


#### 6. `org.s`
Gerencia o tratamento de interrupções do sistema.

RTI:

* Salvamento de contexto
* Identificação da fonte de interrupção
* Tratamento de timer e botões
* Restauração de contexto


---

## Especificações de Hardware

### Endereços de Mapeamento
* UART: 0x10001000
* LED_BASE: 0x10000000
* SWITCH: 0x40
* SEVEN_SEG_BASE: 0x10000020
* TIMER_BASE: 0x10002000
* PUSHBUTTON_BASE: 0x10000050


### Variáveis Globais
* FLAG_ANIMACAO: Controla estado da animação (0=desligada, 1=ligada)
* BUFFER_COMMAND: Buffer para armazenamento de comandos
* LEDS_MANUAIS_STATE: Estado atual dos LEDs controlados manualmente
* ANIMATION_COUNTER: Índice do LED atual na animação
* FLAG_CRONOMETRO: Controla estado do cronômetro
* CRONOMETRO_PAUSA: Controla pausa do cronômetro
* TICK_COUNTER: Contador de ticks para temporização


---

## Comandos Suportados

### Tabela de Comandos

| Comando | Ação |
|---------|------|
| 00 XX | Acender LED XX (00-17) |
| 01 XX | Apagar LED XX (00-17) |
| 10 | Iniciar animação dos LEDs |
| 11 | Parar animação dos LEDs |
| 20 | Iniciar cronômetro |
| 21 | Cancelar cronômetro |

---

## Sistema de Interrupções

### Fluxo de Temporização
* Timer (200ms) → RTI → Verifica flags → Executa animação/cronômetro


### Tratamento de Interrupções
* Timer (IRQ 0): Atualização de animação e cronômetro
* Botões (IRQ 1): Pausa/continuação do cronômetro


---

## Funcionalidades Principais

### Controle de LEDs
- Acionamento individual de LEDs via comandos
- Suporte a LEDs de 0 a 17
- Preservação de estado durante animações

### Sistema de Animação
- Direção controlada por switch SW0
- Velocidade de 200ms por passo
- Integração com controle manual

### Cronômetro Digital
- Contagem de minutos e segundos
- Display em 7 segmentos
- Controle de pausa via botão

### Interface UART
- Recebimento de comandos via serial
- Echo de caracteres digitados
- Buffer para armazenamento de comandos

---

## Desenvolvido por
* Beatriz de Oliveira Cavalheri
* Eduarda Moreira da Silva
* Larissa Rodrigues Ferrari
