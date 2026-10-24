// UART monitor: a tiny command line running on the SoC.
//   r <addr> [n]   read n words (default 1, max 16) starting at addr
//   w <addr> <val> write a word
//   led <val>      set the LEDs
//   sw             read the switches
//   h              help
// Numbers are hexadecimal (an optional 0x prefix is accepted).
#include "mmio.h"

#define LINE_MAX 40

static char line[LINE_MAX];

static void nl(void) { uart_puts("\r\n"); }

static const char *skip_spaces(const char *p)
{
    while (*p == ' ') p++;
    return p;
}

static int hexval(char c)
{
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

// Parse a hex number at *pp; returns 1 if a number was found
static int parse_hex(const char **pp, unsigned int *out)
{
    const char *p = skip_spaces(*pp);
    unsigned int v = 0;
    int n = 0;

    if (p[0] == '0' && (p[1] == 'x' || p[1] == 'X')) p += 2;
    while (hexval(*p) >= 0) {
        v = (v << 4) | (unsigned int)hexval(*p);
        p++;
        n++;
    }
    *pp  = p;
    *out = v;
    return n > 0;
}

// Does p start with the word w (followed by a space or the end)?
static int word_is(const char *p, const char *w)
{
    while (*w) {
        if (*p != *w) return 0;
        p++;
        w++;
    }
    return (*p == '\0') || (*p == ' ');
}

static void run(const char *s)
{
    const char *p = skip_spaces(s);
    unsigned int a, v, c;

    if (word_is(p, "r")) {
        p += 1;
        unsigned int n = 1;
        if (!parse_hex(&p, &a)) { uart_puts("?"); nl(); return; }
        if (parse_hex(&p, &c)) {
            if (c < 1 || c > 16) { uart_puts("?"); nl(); return; }
            n = c;
        }
        a &= ~3u;                                   // word aligned
        for (unsigned int i = 0; i < n; i++, a += 4) {
            uart_puthex(a);
            uart_puts(": ");
            uart_puthex(*(volatile unsigned int *)a);
            nl();
        }
    } else if (word_is(p, "w")) {
        p += 1;
        if (!parse_hex(&p, &a) || !parse_hex(&p, &v)) { uart_puts("?"); nl(); return; }
        *(volatile unsigned int *)(a & ~3u) = v;
        uart_puts("ok"); nl();
    } else if (word_is(p, "led")) {
        p += 3;
        if (!parse_hex(&p, &v)) { uart_puts("?"); nl(); return; }
        GPIO_OUT = v;
        uart_puts("ok"); nl();
    } else if (word_is(p, "sw")) {
        uart_puthex(GPIO_IN);
        nl();
    } else if (word_is(p, "h") || word_is(p, "help")) {
        uart_puts("r <addr> [n]   read n words"); nl();
        uart_puts("w <addr> <val> write word");   nl();
        uart_puts("led <val>      set LEDs");     nl();
        uart_puts("sw             read switches"); nl();
    } else {
        uart_puts("?"); nl();
    }
}

int main(void)
{
    unsigned int len = 0;
    char last = 0;

    nl();
    uart_puts("MINI-RISKV-SOC monitor. Type h for help.");
    nl();
    uart_puts("> ");

    while (1) {
        char c = uart_getc();

        if (c == '\r' || c == '\n') {
            if (!(c == '\n' && last == '\r')) {     // ignore the LF of a CR+LF pair
                line[len] = '\0';
                nl();
                if (len) run(line);
                len = 0;
                uart_puts("> ");
            }
        } else if (c == 8 || c == 127) {            // backspace
            if (len) {
                len--;
                uart_puts("\010 \010");
            }
        } else if (c >= ' ' && len < LINE_MAX - 1) {
            line[len++] = c;
            uart_putc(c);                           // echo
        }
        last = c;
    }
}
