// I2C demo: write two bytes to register 8 of the device at 0x50, read them back,
// and check that a wrong address is NACKed.
#include "mmio.h"

#define RESULT ((volatile unsigned int *)0x800)

int main(void)
{
    I2C_DIV = 3;                                    // SCL = CLK / (4*(3+1)) = CLK / 16

    // write transaction: START, 0x50+W, register 8, 0x5A, 0x6B, STOP
    RESULT[0] = i2c_write(0xA0, I2C_START);         // 0 = ACK
    RESULT[1] = i2c_write(0x08, 0);
    RESULT[2] = i2c_write(0x5A, 0);
    RESULT[3] = i2c_write(0x6B, I2C_STOP);

    // read transaction: set the pointer, repeated START, 0x50+R, read 2 bytes
    i2c_write(0xA0, I2C_START);
    i2c_write(0x08, 0);
    i2c_write(0xA1, I2C_START);                     // repeated START
    RESULT[4] = i2c_read(0);                        // ACK: more bytes follow
    RESULT[5] = i2c_read(I2C_NACK | I2C_STOP);      // NACK + STOP: last byte

    // nobody has address 0x51: expect a NACK
    RESULT[6] = i2c_write(0xA2, I2C_START | I2C_STOP);

    RESULT[7] = 0xC0DE600D;                         // done marker

    while (1) { }
}
