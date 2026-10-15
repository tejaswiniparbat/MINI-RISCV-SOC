// SPI demo: send three bytes to a slave and store the three bytes it returns.
#include "mmio.h"

#define RESULT ((volatile unsigned int *)0x800)

int main(void)
{
    SPI_DIV = 4;                     // SCLK = CLK / (2*(4+1)) = CLK / 10
    RESULT[4] = SPI_DIV;             // read-back check of the register

    SPI_CS = 0;                      // CS low: select the slave
    RESULT[0] = spi_xfer(0x12);
    RESULT[1] = spi_xfer(0x34);
    RESULT[2] = spi_xfer(0x56);
    SPI_CS = 1;                      // CS high: deselect

    RESULT[3] = 0xC0DE600D;          // done marker

    while (1) { }
}
