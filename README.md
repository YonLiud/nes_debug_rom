# Mark's NES Debug ROM

A self-contained mapper-0/NROM-128 diagnostic ROM written in ca65 assembly.
Use Up/Down and A in the menu. Hold Start+Select to leave any diagnostic screen.

## Diagnostics

- `COLOR SNAKE` — slow full-screen palette changes and an animated color trail
- `CONTROLLER` — inverted held buttons and raw bytes for controller ports 1/2
- `MOVEMENT` — held-input, diagonal movement, and sprite-position testing
- `DISPLAY TEST` — visible border and center alignment crosshair
- `PALETTE VIEW` — all 64 palette indices in 16 four-color pages
- `SPRITE TEST` — nine sprites on one scanline, vertical movement, and flipping
- `SCROLL TEST` — manual horizontal scrolling across both nametables
- `AUDIO TEST` — Pulse 1/2, triangle, and noise selection, toggle, and pitch
- `TIMING TEST` — live 16-bit NMI/frame counter
- `RAM TEST` — `$AA`/`$55` verification over RAM pages `$0300-$07FF`
- `SYSTEM INFO` — mapper, PRG/CHR sizes, and target region

## Build

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1
```

The finished ROM is `build\debug.nes`.
