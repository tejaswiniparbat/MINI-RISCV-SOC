// UART echo: prints a banner, then echoes every received character in UPPER CASE.
#include "mmio.h"

int main(void)
{
    uart_puts("Echo ready\n");

    while (1) {
        char c = uart_getc();
        if (c >= 'a' && c <= 'z') c = (char)(c - 32);
        uart_putc(c);
    }
}
