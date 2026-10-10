#!/bin/sh
# Build firmware/main.c + start.S into firmware/firmware.hex (one 32-bit word per line)
set -e
cd "$(dirname "$0")"
P=riscv64-unknown-elf
$P-gcc -march=rv32i -mabi=ilp32 -O1 -nostdlib -ffreestanding -Wall \
       -T linker.ld start.S main.c -o firmware.elf
$P-objcopy -O binary firmware.elf firmware.bin
od -An -v -tx4 -w4 firmware.bin | tr -d ' ' > firmware.hex
$P-objdump -d firmware.elf > firmware.lst
echo "built firmware.hex: $(wc -l < firmware.hex) words"
