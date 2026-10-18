#!/bin/sh
# Run every testbench and print one result line per test.   Usage: sh run_all_tests.sh
# Takes several minutes (each test rebuilds the simulator).
TESTS="alu_tb regfile_tb imm_gen_tb decoder_tb imem_tb dmem_tb branch_unit_tb core_tb core_fw_tb \
gpio_tb soc_tb uart_tb soc_uart_tb soc_echo_tb spi_tb soc_spi_tb i2c_tb soc_i2c_tb fpga_top_tb"

pass=0; fail=0; skip=0
for t in $TESTS; do
  if [ ! -f "tb/$t.sv" ]; then
    printf 'SKIP  %-16s (tb/%s.sv not found)\n' "$t" "$t"; skip=$((skip+1)); continue
  fi
  out=$(make sim TOP=$t 2>&1 | grep -E "^ALL [0-9]+ TESTS PASSED|^[0-9]+ of [0-9]+ TESTS FAILED|^%Error" | head -1)
  case "$out" in
    ALL*) printf 'PASS  %-16s %s\n' "$t" "$out"; pass=$((pass+1)) ;;
    *)    printf 'FAIL  %-16s %s\n' "$t" "${out:-no result (build error?)}"; fail=$((fail+1)) ;;
  esac
done
echo "----------------------------------------"
echo "$pass passed, $fail failed, $skip skipped"
[ "$fail" -eq 0 ]
