/* var.s — variáveis e endereços de I/O */

.equ LEDS_RED, 0x0
.equ SWITCH, 0x40
.equ PUSH_BUTTON, 0x50
.equ UART_DATA, 0x1000
.equ UART_CONTROL, 0x1004
.equ TIMER_ADDRESS_STATUS, 0x2000
.equ TIMER_ADDRESS_CONTROL, 0x2004
.equ TIMER_ADDRESS_COUNTER_LOW, 0x2008
.equ TIMER_ADDRESS_COUNTER_HIGH, 0x200C

/* Interrupções */
.equ IRQ_TIMER, 0b1
.equ IRQ_PUSHBUTTON, 0b10

/* ASCII */
.equ BACKSPACE, 0x8
.equ NEWLINE, 0xA
.equ ZERO, 0x30
.equ ONE, 0x31
.equ TWO, 0x32
