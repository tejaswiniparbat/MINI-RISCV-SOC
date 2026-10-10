#!/bin/sh
# Usage: sh firmware/build.sh <name>     e.g.  sh firmware/build.sh fib
# Builds firmware/<name>.c + start.S into firmware/<name>.hex (one 32-bit word per line)
set -e
cd "$(dirname "$0")"
NAME=${1:-fib}
P=riscv64-unknown-elf
$P-gcc -march=rv32i -mabi=ilp32 -O1 -nostdlib -ffreestanding -Wall \
       -T linker.ld start.S $NAME.c -o $NAME.elf
$P-objcopy -O binary $NAME.elf $NAME.bin
od -An -v -tx4 -w4 $NAME.bin | tr -d ' ' > $NAME.hex
$P-objdump -d $NAME.elf > $NAME.lst
echo "built firmware/$NAME.hex: $(wc -l < $NAME.hex) words"
