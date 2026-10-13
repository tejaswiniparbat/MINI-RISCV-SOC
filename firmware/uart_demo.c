// UART demo: print text and a hex number.
#include "mmio.h"

int main(void)
{
    uart_puts("Hello, RISC-V!\n");
    uart_puthex(0xDEADBEEFu);
    uart_putc('\n');

    while (1) { }
}
