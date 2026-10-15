// Memory-mapped peripheral addresses and tiny drivers for MINI-RISKV-SOC
#ifndef MMIO_H
#define MMIO_H

#define GPIO_OUT     (*(volatile unsigned int *)0x10000000)
#define GPIO_IN      (*(volatile unsigned int *)0x10000004)
#define UART_TX      (*(volatile unsigned int *)0x10000100)
#define UART_STATUS  (*(volatile unsigned int *)0x10000104)   // b0 TX ready, b1 RX avail, b2 overrun
#define UART_RX      (*(volatile unsigned int *)0x10000108)   // reading pops the byte

static inline void uart_putc(char c)
{
    while ((UART_STATUS & 1u) == 0) { }      // wait until the transmitter is ready
    UART_TX = (unsigned int)c;
}

static inline void uart_puts(const char *s)
{
    while (*s) uart_putc(*s++);
}

static inline void uart_puthex(unsigned int v)
{
    for (int i = 28; i >= 0; i -= 4) {
        unsigned int d = (v >> i) & 0xFu;
        uart_putc(d < 10 ? (char)('0' + d) : (char)('A' + d - 10));
    }
}

static inline int uart_rx_ready(void)
{
    return (UART_STATUS & 2u) != 0;
}

static inline char uart_getc(void)           // blocks until a byte arrives
{
    while (!uart_rx_ready()) { }
    return (char)(UART_RX & 0xFFu);
}

#endif
