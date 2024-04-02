extern "C" void ruzik_val_printf(const char* format, ...);

int main() {
    int dec         = 5;
    int hex         = 15;
    int octal       = 8;
    char sym        = '!';
    const char* str = "Hello";

    ruzik_val_printf("dec: %d hex: %x octal: %o sym: %c str: %s", dec, hex, octal, sym, str);

    return 0;
}
