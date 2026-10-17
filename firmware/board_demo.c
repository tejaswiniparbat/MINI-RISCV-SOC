// Board demo for the FPGA:
//  - prints a banner on the UART
//  - switch 0 UP  : LEDs mirror the 16 switches
//  - switch 0 DOWN: a single LED walks across the 16 LEDs
//  - anything typed on the serial terminal is echoed back in UPPER CASE
#include "mmio.h"

#ifndef DELAY_COUNT
#define DELAY_COUNT 800000u          // about 0.25 s at 50 MHz (set by the simulation build to a small value)
#endif

static void service_uart(void)
{
    if (uart_rx_ready()) {
        char c = uart_getc();
        if (c >= 'a' && c <= 'z') c = (char)(c - 32);
        uart_putc(c);
    }
}

static void delay(void)
{
    for (volatile unsigned int i = 0; i < DELAY_COUNT; i++) {
        service_uart();              // keep answering the terminal while we wait
    }
}

int main(void)
{
    unsigned int led = 1;

    uart_puts("MINI-RISKV-SOC ready\n");

    while (1) {
        if (GPIO_IN & 1u) {
            GPIO_OUT = GPIO_IN;                                   // switches -> LEDs
        } else {
            GPIO_OUT = led;                                       // walking LED
            led = ((led << 1) | (led >> 15)) & 0xFFFFu;           // rotate within 16 bits
        }
        delay();
    }
}
