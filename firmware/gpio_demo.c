// GPIO demo: walking LED, then switches -> LEDs forever.
#define GPIO_OUT (*(volatile unsigned int *)0x10000000)
#define GPIO_IN  (*(volatile unsigned int *)0x10000004)
#define RESULT   ((volatile unsigned int *)0x800)

int main(void)
{
    unsigned int led = 1;

    for (int i = 0; i < 4; i++) {      // walking LED: 1, 2, 4, 8
        GPIO_OUT = led;
        led <<= 1;
    }
    RESULT[0] = GPIO_OUT;              // read back the output register (8)

    while (1) {
        GPIO_OUT = GPIO_IN;            // switches -> LEDs
    }
}
