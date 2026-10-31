#!/bin/bash
# The certification of the C64 build in VICE (vice_cert.py) over sessions, N at a time: lote.sh BUILD OUT N SESSION...
B=$1; O=$2; N=$3; shift 3
D=$(dirname "$(realpath "$0")"); R=$(dirname "$(dirname "$D")")
mkdir -p $O; : > $O/resumen.txt
for s in "$@"; do
  while [ $(jobs -r | wc -l) -ge $N ]; do sleep 5; done
  ( cd "$D" && DISPLAY=:99 timeout 14400 python3 -I certifica.py $B $O $s $R/../data/cpc64/inicio_juego/ram.bin $R/../data/cpc64/exploracion/$s.txt 4001 > /dev/null 2>&1
    echo "$s: $(tail -1 $O/$s.host.txt | cut -c1-200)" >> $O/resumen.txt ) &
done
wait
echo FIN >> $O/resumen.txt
