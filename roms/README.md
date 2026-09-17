# Firmware

ROMs are user-supplied and excluded from source control. Local builds copy
available `.rom` files into their app output.
See the root README for required sizes. This local workspace uses these files
from `/opt/homebrew/share/vice/C128`:

| Local name | Existing VICE image |
| --- | --- |
| basiclo.rom | basiclo-318018-04.bin |
| basichi.rom | basichi-318019-04.bin |
| kernal.rom | kernal-318020-05.bin |
| characters.rom | chargen-315079-01.bin |
| basic64.rom | basic64-901226-01.bin |
| kernal64.rom | kernal64-901227-03.bin |

The 16 KiB C128 KERNAL image includes the editor and Z80 BIOS portions;
a C64 8 KiB KERNAL is not a substitute. Firmware is not covered by the
application's GPL license.
