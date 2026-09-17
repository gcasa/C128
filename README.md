# C128

A Commodore 128 emulator using the Objective-C CPU core from VIC20 and the
CIA/VIC-II implementation from C64. It boots original BASIC 7.0 firmware in
40 and 80 columns, accepts keyboard input, loads PRGs, and supports GO64 when
C64 firmware is supplied. This is an initial, instruction-level emulator,
with the same general scope as the adjacent C64 application.

## Build

macOS with Xcode command-line tools, without an active GNUstep environment:

```sh
make
make test
make run
```

The application is `build/C128.app`. `C128.xcodeproj` also builds the app.
Use `make -f Makefile` to select the Cocoa build explicitly if GNUstep's
shell setup is active.

GNUstep with base/gui development libraries, gnustep-make, and an Objective-C
compiler (GCC with its Objective-C frontend or a compatible Clang):

```sh
. /path/to/GNUstep.sh
make
make test
openapp ./C128.app
```

The usual GNUstep shell setup is under `/usr/share/GNUstep/Makefiles` on
Linux. This workspace also has it at
`/opt/GNUstep/System/Library/Makefiles/GNUstep.sh`.
GNUstep's standard build produces `C128.app`; `make install` uses the normal
GNUstep installation domain. A standalone alternative is
`make -f Makefile UNAME=GNUstep`, which uses `gnustep-config` and produces
`build/C128`. Override `CC` and `GNUSTEP_CONFIG` when necessary.

All application and core sources use Objective-C 1.0 syntax, explicit instance
variables, manual retain/release, NSAutoreleasePool, and classic collection
messages. No ARC, blocks, properties, object literals, subscripting, fast
enumeration, or synthesized accessors are required. The C language dialect is
GNU99, independent of the Objective-C language version. Cocoa-only activation
is guarded out of GNUstep builds. Deprecated Cocoa API names are intentional
for compatibility with classic AppKit/GNUstep.

## ROMs and controls

Choose **File → Choose ROM Folder…**. Required files:

| File | Bytes | Contents |
| --- | ---: | --- |
| basiclo.rom | 16384 | C128 BASIC low ($4000–$7FFF) |
| basichi.rom | 16384 | C128 BASIC high ($8000–$BFFF) |
| kernal.rom | 16384 | Combined editor, Z80 BIOS, and KERNAL ($C000–$FFFF) |
| characters.rom | 8192 | C128 character generator |
| basic64.rom | 8192 | Optional C64 BASIC; supply with kernal64.rom |
| kernal64.rom | 8192 | Optional C64 KERNAL; supply with basic64.rom |

The entire selection is validated before replacing active firmware. Builds copy
locally supplied `roms/*.rom` files into the app output. The app checks that
copy first, then the remembered folder, `roms` in its working directory, and
`roms` next to the project's build directory. ROM images remain excluded from
source control.
Local test images were copied from the existing VICE installation; see
[roms/README.md](roms/README.md).

Type directly into the window. Return submits a line, Escape is RUN/STOP,
Backspace is DEL, Home is HOME, and arrows operate the cursor. F1–F8,
Control, Option/Alt (Commodore), and shifted punctuation use the C64 keyboard
matrix. Extended C128 keypad and dedicated extra keys are not yet mapped.

- **Machine → Boot in 40 / 80 Columns** toggles the hardware column key and resets.
- **Show Both Displays** opens a second monitor window (Command-B). Both show
  the same running machine without resetting it, and either window accepts
  keyboard input. BASIC writes to its currently selected display; this does
  not duplicate its output. Close the extra window or use Command-B again to
  return to one monitor.
- **Show 40 / 80 Column Display** switches the monitor without resetting (Command-8); with both windows open, it swaps their displays.
- **Reset** clears RAM and reboots C128 mode (Command-R).
- **Pause / Resume** pauses execution (Command-P); **RESTORE** sends NMI.
- **File → Load PRG…** loads a program (Command-O). Wait for `READY.` first.

C128 BASIC PRGs at `$1C01` update the BASIC text/end pointers; type `RUN`.
Other PRGs load into physical RAM bank 0 at their embedded address; use the
program's documented `BANK`/`SYS` entry. BASIC programs reserving graphics
memory or needing a relocated BASIC start need their own loader. C64 BASIC
PRGs at `$0801` work after `GO64` and confirmation with `Y`. Reset returns to
C128 mode. Files extending beyond the address space are rejected.

## Structure

- `C128/CPU`: reusable 6502 bus/core from VIC20, used as the 8502 instruction engine.
- `C128/Core/C64*`: shared C64 bus, video renderer, and CPU NMI helper retained
  from the sibling C64 app, including the C64 compatibility memory map.
- `C128/Core/CIA6526`: timer/port/interrupt implementation, extended with serial
  output completion driven by timer-A underflows for the C128 boot sequence.
- `C128/Core/C128Bus`: two 64 KiB RAM banks; MMU configuration and presets;
  shared RAM; page-zero/stack relocation and bank latches; ROM overlays;
  two color RAM banks; VIC bank selection; PRG/ROM loaders.
- `C128/Core/VDC8563`: separate 64 KiB video RAM, indexed registers, sequential
  access, block fill/copy, text attributes/cursor, and a basic bitmap renderer.
- `C128/Core/C128Machine`: CPU scheduling and interrupt delivery.
- `C128/AppDelegate`: application lifecycle, windows, display selection, panels,
  menus, and frame pacing.
- `C128/UI/C128Display`: bitmap display and keyboard input.
- `C128/main.m`: application entry point and autorelease pool setup.
  The UI is programmatic, with no nib or Cocoa binding dependencies.

## Validation

`make test` exercises reusable CPU execution, inherited C64 hardware behavior,
C128 banking/common RAM/page latches, ROM writes, MMU presets, color RAM,
CIA serial completion, VDC transfers/fill/copy/wraparound/rendering, PRG bounds,
and unsupported-CPU stopping. Tests do not require ROMs.

With firmware installed, run the appropriate executable:

```sh
./build/C128Tests roms                 # Cocoa/Foundation build
./build/gnustep/C128Tests roms         # GNUstep build
```

Firmware tests verify the 122365-byte BASIC 7.0 banner, READY in both display
modes, arithmetic, actual keyboard scanning, execution of a loaded BASIC PRG,
and GO64's 38911-byte banner. Both full suites passed locally using Apple Clang
with Foundation and GCC 16 with GNUstep's GNU Objective-C runtime. Cocoa,
GNUstep application, and Xcode Debug builds succeeded. Cocoa 40/80 displays
were also inspected visually. Linux GUI execution has not been tested here.

## Current limits

Reset enters the 8502 KERNAL reset vector directly, bypassing the initial Z80
cartridge-detection bootstrap. **There is no Z80 execution or CP/M support.**
Switching to Z80, or to C64 without its ROM pair, stops execution and labels the
window; reset recovers. Function ROM slots read as empty. MMU relocation covers
forward page mapping; hardware reverse page exchange is not modeled.

There is no SID audio synthesis, disk/IEC device, tape, cartridge, joystick,
REU, or save state. CIA TOD, external serial input, and CNT/FLAG pins are absent;
serial completion does not imply an attached drive. Timing is PAL, at a fixed
approximately 1 MHz; D030's fast-mode bit is stored but 2 MHz scheduling is not
implemented. CPU/device timing is instruction-granular.

VIC-II rendering inherits the C64 frame-based text/bitmap/sprite implementation,
without bad-line stalls, DMA timing, raster effects, collision IRQs, or fine
scrolling. VDC readiness/retrace is approximated as ready, transfers are
immediate, and rendering targets the standard 80×25, 8-pixel character width;
programmable geometry, interlace, smooth scrolling, and precise blink timing
are incomplete. A BASIC boot is not a claim of general game/demo compatibility.

## Origin and license

GPL-3.0-or-later; see [LICENSE](LICENSE). Original Gregory John Casamento
copyright notices are retained. The CPU comes through the adjacent C64 app
from VIC20. Local CPU changes normalize legacy bitfield mask assignments and
clarify the standalone release receiver; C64 bus/test syntax was converted to
Objective-C 1.0. CIA serial output completion and the C128 files are new here.
Neither sibling workspace was modified.

Hardware references: [Commodore 128 Programmer's Reference Guide](https://www.pagetable.com/docs/Commodore%20128%20Programmer%27s%20Reference%20Guide.pdf),
[VICE MMU implementation](https://github.com/VICE-Team/svn-mirror/blob/main/vice/src/c128/c128mmu.c),
and [VICE memory implementation](https://github.com/VICE-Team/svn-mirror/blob/main/vice/src/c128/c128mem.c).

## Source formatting and API comments

The checked-in `.clang-format` uses GNU style: two-space indentation, GNU
brace placement, spaces before C function-call parentheses, and expanded
control flow. Objective-C sources, headers, and tests use C-style comments;
public header declarations have autogsdoc `/** ... */` descriptions with
GSDoc markup. GNU99 and Objective-C 1.0 compatibility are retained.

Use clang-format 22 (the version used for this formatting pass):

```sh
make format
make format-check
```

Set `CLANG_FORMAT` if it is not on PATH, for example:

```sh
CLANG_FORMAT=/opt/homebrew/opt/llvm/bin/clang-format make format-check
```

The formatter operates on project source and tests, excluding generated app
bundles, build output, firmware, and image assets. Makefiles, shell scripts,
and project metadata retain their respective file formats.

With the GNUstep environment loaded, generate API documentation with:

```sh
autogsdoc -Project C128 -DocumentationDirectory build/docs \
  -DocumentInstanceVariables YES \
  C128/CPU/*.h C128/Core/*.h C128/AppDelegate.h C128/UI/*.h
```

The installed GNUstep autogsdoc currently raises a `GSTimSort` assertion when
generating the larger CPU6502 API page. Device, UI, and bus-protocol pages
were generated successfully separately; this tool failure does not affect
compilation or execution of the emulator.
