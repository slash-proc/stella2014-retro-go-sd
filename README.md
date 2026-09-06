# Stella 2014 — Atari 2600 core for Retro-Go SD

Standalone dynamic core packaging [stella2014-go](https://github.com/sylverb/stella2014-go)
for [Game & Watch Retro-Go SD](https://github.com/sylverb/game-and-watch-retro-go-sd).

| | |
|--|--|
| SD core | `/cores/stella2014.bin` (includes embedded DefProps DB) |
| ROMs | `/roms/a2600/*.a26` / `*.bin` |
| Entry | `app_main_a2600` |

## Memory layout

| Region | Use |
|--------|-----|
| **ITCM** | Hot `.text` only: M6502, TIA, TIASnd, M6532, System (`stella2014_core.ld`) |
| **DTCM** | TIA framebuffers (2×160×320) + PageAccess tables (`dtc_*`, fallback `ram_*`) |
| **AHB** | Small C++ `new` objects via the freeable heap (~56 KiB) |
| **RAM_EMU** | Link image (`.text`/`.rodata`/`.bss` including large TIATables) + leftover heap |

ITCM is **not** used as a C++ heap (`heap_itc_alloc(false)`).

## Build

```bash
make                 # → stella2014.bin (core + DefProps STDP trailer)
make docker          # same in sylverb/retro-go-sd-builder
make host            # → stella2014_host (needs SDL2; also builds stella2014.bin)
./stella2014_host game.a26
```

Copy `stella2014.bin` to the SD `/cores/` folder (single file — DefProps is embedded).

## Assets

Pad/header logos in `src/assets/*.bmp` are inverted 1bpp conversions of the
`header_a2600` / `pad_a2600` tables from the original firmware `rg_logos.c`.

## Stella sources

Vendored under `src/stella2014-go` (from [stella2014-go](https://github.com/sylverb/stella2014-go)
branch `sd`), with DTCM allocation patches in `StellaTIA.cxx` / `StellaSystem.cxx`
and DefProps trailer support in `DefPropsBin.c` (STDP footer via
`scripts/append_stella_defprops.py`).
