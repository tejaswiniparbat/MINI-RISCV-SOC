// First C program on the MINI-RISKV-SOC core: Fibonacci numbers into RAM.
#define RESULT ((volatile unsigned int *)0x800)

int main(void)
{
    unsigned int a = 0, b = 1;

    for (int i = 0; i < 10; i++) {
        RESULT[i] = b;              // 1 1 2 3 5 8 13 21 34 55
        unsigned int t = a + b;
        a = b;
        b = t;
    }

    RESULT[10] = 0xC0DE600D;        // "done" marker

    while (1) { }
}
