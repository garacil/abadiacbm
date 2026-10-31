# m6502: a 6502 core for the hybrid host

`6502.c` and `6502.h` are cc65's sim65 CPU core (<https://github.com/cc65/cc65>, `src/sim65/`, the copy
built in `tools/terceros/cc65`, version `cc65 V2.19 - Git a6530f469`), zlib licence (see the notice at the
top of each file), unchanged.  The headers it includes from sim65 are replaced here by minimal ones
(`memory.h`, `peripherals.h`, `paravirt.h`, `trace.h`, `error.h`, written for abadia64ks): the memory
is the array `Mem[]` (`m6502.c`), no paravirtualisation, no trace.  Use: `m6502.h`.
