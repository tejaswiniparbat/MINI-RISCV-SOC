// Memory-mapped peripheral addresses and tiny drivers for MINI-RISKV-SOC
#ifndef MMIO_H
#define MMIO_H

#define GPIO_OUT     (*(volatile unsigned int *)0x10000000)
#define GPIO_IN      (*(volatile unsigned int *)0x10000004)
#define UART_TX      (*(volatile unsigned int *)0x10000100)
#define UART_STATUS  (*(volatile unsigned int *)0x10000104)   // b0 TX ready, b1 RX avail, b2 overrun
#define UART_RX      (*(volatile unsigned int *)0x10000108)   // reading pops the byte
#define SPI_DATA     (*(volatile unsigned int *)0x10000200)   // write = start transfer, read = last RX byte
#define SPI_STATUS   (*(volatile unsigned int *)0x10000204)   // b0 busy
#define SPI_CS       (*(volatile unsigned int *)0x10000208)   // b0 = CS_N level (1 = deselected)
#define SPI_DIV      (*(volatile unsigned int *)0x1000020C)   // SCLK = CLK / (2*(DIV+1))

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

// Full-duplex SPI transfer of one byte (mode 0): sends b, returns the byte received
static inline unsigned char spi_xfer(unsigned char b)
{
    while (SPI_STATUS & 1u) { }
    SPI_DATA = b;
    while (SPI_STATUS & 1u) { }
    return (unsigned char)(SPI_DATA & 0xFFu);
}

#endif
