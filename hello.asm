.setcpu "6502"

PPUCTRL    = $2000
PPUMASK    = $2001
PPUSTATUS  = $2002
OAMADDR    = $2003
PPUADDR    = $2006
PPUDATA    = $2007
PPUSCROLL  = $2005
OAMDMA     = $4014
JOY1       = $4016
JOY2       = $4017
DMC_FREQ   = $4010
APU_STATUS = $4015

BTN_A    = %00000001
BTN_B    = %00000010
BTN_UP   = %00010000
BTN_DOWN = %00100000
BTN_SELECT = %00000100
BTN_START  = %00001000
BTN_LEFT   = %01000000
BTN_RIGHT  = %10000000
ENTRY_COUNT = 11
SCREEN_MENU = 0
SCREEN_RGB  = 1
SCREEN_WARNING = 2
SCREEN_CONTROLLER = 3
SCREEN_MOVE = 4
SCREEN_DISPLAY = 5
SCREEN_PALETTE = 6
SCREEN_SPRITE = 7
SCREEN_SCROLL = 8
SCREEN_AUDIO = 9
SCREEN_TIMING = 10
SCREEN_RAM = 11
SCREEN_INFO = 12
COLOR_DELAY = 90
COLOR_COUNT = 10
SNAKE_LENGTH = 16

.segment "ZEROPAGE"
frame_ready:    .res 1
selected_entry: .res 1
buttons:        .res 1
buttons_old:    .res 1
buttons_pressed:.res 1
buttons2:       .res 1
screen_state:   .res 1
color_index:    .res 1
color_timer:    .res 1
snake_phase:    .res 1
work0:          .res 1
work1:          .res 1
work2:          .res 1
screen_ptr:     .res 2
nmi_count_lo:   .res 1
nmi_count_hi:   .res 1

.segment "HEADER"
    .byte "NES", $1A
    .byte 1                  ; 1 x 16 KiB PRG ROM
    .byte 1                  ; 1 x 8 KiB CHR ROM
    .byte $01                ; mapper 0, vertical mirroring
    .byte $00
    .byte $00, $00, $00, $00, $00, $00, $00, $00

.segment "CODE"
.proc reset
    sei
    cld
    ldx #$40
    stx JOY2
    ldx #$FF
    txs
    inx
    stx PPUCTRL
    stx PPUMASK
    stx DMC_FREQ
    stx APU_STATUS

    bit PPUSTATUS
@vblank1:
    bit PPUSTATUS
    bpl @vblank1

    lda #$00
@clear_ram:
    sta $0000,x
    sta $0100,x
    sta $0200,x
    sta $0300,x
    sta $0400,x
    sta $0500,x
    sta $0600,x
    sta $0700,x
    inx
    bne @clear_ram

@vblank2:
    bit PPUSTATUS
    bpl @vblank2

    jsr load_palette
    jsr draw_warning

    lda #$00
    sta PPUADDR
    sta PPUADDR
    lda #%10000000          ; enable NMI, background pattern table 0
    sta PPUCTRL
    lda #%00011110          ; show background and sprites
    sta PPUMASK

@main_loop:
    lda frame_ready
    beq @main_loop
    lda #$00
    sta frame_ready

    jsr read_controller

    lda screen_state
    cmp #SCREEN_RGB
    beq @rgb_screen
    cmp #SCREEN_CONTROLLER
    beq @controller_screen
    cmp #SCREEN_WARNING
    beq @warning_screen
    cmp #SCREEN_MOVE
    bcc @menu
    jsr update_extra_screen
    jmp @main_loop

@menu:
    lda buttons_pressed
    and #BTN_UP
    beq @check_down
    lda selected_entry
    bne @move_up
    lda #ENTRY_COUNT
@move_up:
    sec
    sbc #1
    sta selected_entry

@check_down:
    lda buttons_pressed
    and #BTN_DOWN
    beq @check_a
    inc selected_entry
    lda selected_entry
    cmp #ENTRY_COUNT
    bcc @check_a
    lda #$00
    sta selected_entry

@check_a:
    lda buttons_pressed
    and #BTN_A
    beq @update
    lda selected_entry
    beq @open_rgb
    cmp #1
    beq @open_controller
    jsr enter_extra_screen
    jmp @main_loop
@open_rgb:
    jsr enter_rgb
    jmp @main_loop
@open_controller:
    jsr enter_controller
    jmp @main_loop

@update:
    jsr update_cursor
    jmp @main_loop

@rgb_screen:
    lda buttons_pressed
    and #BTN_B
    bne @leave_rgb
    lda buttons
    and #(BTN_START | BTN_SELECT)
    cmp #(BTN_START | BTN_SELECT)
    bne @run_rgb
@leave_rgb:
    jsr enter_menu
    jmp @main_loop
@run_rgb:
    jsr update_rgb
    jmp @main_loop

@warning_screen:
    lda buttons_pressed
    and #BTN_A
    beq @warning_wait
    jsr enter_menu
@warning_wait:
    jmp @main_loop

@controller_screen:
    jsr update_controller_display
    lda buttons
    and #%00001100         ; Select + Start together returns to the menu
    cmp #%00001100
    bne @controller_wait
    jsr enter_menu
@controller_wait:
    jmp @main_loop
.endproc

.proc enter_controller
    lda #$00
    sta PPUMASK
    lda #$FF
    ldx #$00
@hide:
    sta $0200,x
    inx
    bne @hide

    lda PPUSTATUS
    lda #$20
    sta PPUADDR
    lda #$00
    sta PPUADDR
    lda #$00
    ldx #$04
    ldy #$00
@clear:
    sta PPUDATA
    iny
    bne @clear
    dex
    bne @clear

    ; CONTROLLER TEST at row 4, column 8.
    lda #$20
    sta PPUADDR
    lda #$88
    sta PPUADDR
    ldx #$00
@title:
    lda controller_title,x
    sta PPUDATA
    inx
    cpx #controller_title_end-controller_title
    bne @title

    ; Eight fixed-width button labels.
    ldx #$00
    ldy #$00
@row:
    lda controller_row_hi,y
    sta PPUADDR
    lda controller_row_lo,y
    sta PPUADDR
@label:
    lda controller_labels,x
    sta PPUDATA
    inx
    txa
    and #$07
    bne @label
    iny
    cpy #8
    bne @row

    ; Keep the button labels on normal white-on-black background palette 0.
    ldx #$00
@attributes:
    lda controller_attr_hi,x
    sta PPUADDR
    lda controller_attr_lo,x
    sta PPUADDR
    lda #$00
    sta PPUDATA
    inx
    cpx #8
    bne @attributes

    ; Short footer at row 26.
    lda #$23
    sta PPUADDR
    lda #$45
    sta PPUADDR
    ldx #$00
@footer1:
    lda controller_footer,x
    sta PPUDATA
    inx
    cpx #controller_footer_end-controller_footer
    bne @footer1

    lda #$23
    sta PPUADDR
    lda #$08
    sta PPUADDR
    ldx #$00
@raw_label:
    lda controller_raw_label,x
    sta PPUDATA
    inx
    cpx #controller_raw_label_end-controller_raw_label
    bne @raw_label

    jsr init_controller_highlights

    lda #SCREEN_CONTROLLER
    sta screen_state
    jsr update_controller_display
    lda #$00
    sta PPUADDR
    sta PPUADDR
    lda #%00011110          ; background and highlight sprites
    sta PPUMASK
    rts
.endproc

.proc init_controller_highlights
    ldx #$00
    ldy #$00
@loop:
    lda #$FF
    sta $0200,y
    lda controller_sprite_tiles,x
    sta $0201,y
    lda #$00               ; in front, sprite palette 0
    sta $0202,y
    lda controller_sprite_x,x
    sta $0203,y
    iny
    iny
    iny
    iny
    inx
    cpx #28
    bne @loop
    rts
.endproc

.proc update_controller_display
    ldx #$00
    ldy #$00
@segment:
    lda buttons
    and controller_sprite_masks,x
    beq @released
    lda controller_sprite_y,x
    bne @write
@released:
    lda #$FF
@write:
    sta $0200,y
    iny
    iny
    iny
    iny
    inx
    cpx #28
    bne @segment
    lda #$23
    sta PPUADDR
    lda #$0C
    sta PPUADDR
    lda buttons
    jsr write_hex_value
    lda #$23
    sta PPUADDR
    lda #$14
    sta PPUADDR
    lda buttons2
    jsr write_hex_value
    lda #$00
    sta PPUADDR
    sta PPUADDR
    rts
.endproc

.proc draw_warning
    ; Launch-time photosensitivity notice on a black background.
    lda #$FF
    ldx #$00
@hide_sprites:
    sta $0200,x
    inx
    bne @hide_sprites

    lda PPUSTATUS
    lda #$20
    sta PPUADDR
    lda #$00
    sta PPUADDR
    lda #$00
    ldx #$04
    ldy #$00
@clear:
    sta PPUDATA
    iny
    bne @clear
    dex
    bne @clear

    lda #$21
    sta PPUADDR
    lda #$4C               ; row 10, column 12
    sta PPUADDR
    ldx #$00
@warning:
    lda warning_text,x
    sta PPUDATA
    inx
    cpx #7
    bne @warning

    lda #$21
    sta PPUADDR
    lda #$A9               ; row 13, column 9
    sta PPUADDR
@flashing:
    lda flashing_text-7,x
    sta PPUDATA
    inx
    cpx #22
    bne @flashing

    lda #$22
    sta PPUADDR
    lda #$0A               ; row 16, column 10
    sta PPUADDR
@carefully:
    lda careful_text-22,x
    sta PPUDATA
    inx
    cpx #35
    bne @carefully

    lda #$22
    sta PPUADDR
    lda #$8C               ; row 20, column 12
    sta PPUADDR
@press_a:
    lda press_a_text-35,x
    sta PPUDATA
    inx
    cpx #42
    bne @press_a

    lda #SCREEN_WARNING
    sta screen_state
    lda #$00
    sta PPUADDR
    sta PPUADDR
    rts
.endproc

.proc enter_menu
    lda #$00
    sta PPUMASK
    jsr load_palette
    jsr draw_menu
    jsr init_cursor
    lda #SCREEN_MENU
    sta screen_state
    lda #%10000000
    sta PPUCTRL
    lda #$00
    sta PPUADDR
    sta PPUADDR
    lda #%00011110
    sta PPUMASK
    rts
.endproc

.proc enter_rgb
    lda #$00
    sta PPUMASK

    ; Hide the menu cursor.
    lda #$FF
    sta $0200

    ; Clear the nametable, then place the label at row 25, column 2.
    lda PPUSTATUS
    lda #$20
    sta PPUADDR
    lda #$00
    sta PPUADDR
    lda #$00
    ldx #$04
    ldy #$00
@clear:
    sta PPUDATA
    iny
    bne @clear
    dex
    bne @clear

    lda #$23
    sta PPUADDR
    lda #$22
    sta PPUADDR
    ldx #$00
@label:
    lda color_label,x
    sta PPUDATA
    inx
    cpx #color_label_end-color_label
    bne @label

    lda #SCREEN_RGB
    sta screen_state
    lda #$00
    sta color_index
    sta color_timer
    sta snake_phase
    jsr init_snake
    jsr draw_rgb_color

    lda #$00
    sta PPUADDR
    sta PPUADDR
    lda #%00011110          ; show label and animated color snake
    sta PPUMASK
    rts
.endproc

.proc update_rgb
    inc snake_phase
    jsr update_snake
    inc color_timer
    lda color_timer
    cmp #COLOR_DELAY
    bcc @done
    lda #$00
    sta color_timer
    inc color_index
    lda color_index
    cmp #COLOR_COUNT
    bcc @draw
    lda #$00
    sta color_index
@draw:
    jsr draw_rgb_color
@done:
    rts
.endproc

.proc init_snake
    ; Four vivid sprite colors used repeatedly along the trail.
    lda PPUSTATUS
    lda #$3F
    sta PPUADDR
    lda #$11
    sta PPUADDR
    ldx #$00
@palettes:
    lda snake_palettes,x
    sta PPUDATA
    lda #$0F
    sta PPUDATA
    sta PPUDATA
    sta PPUDATA
    inx
    cpx #4
    bne @palettes

    ldx #$00
    ldy #$00
@sprites:
    lda snake_y,x
    sta $0200,y
    lda #25                ; solid 8x8 segment tile
    sta $0201,y
    txa
    and #$03
    sta $0202,y
    lda snake_x,x
    sta $0203,y
    iny
    iny
    iny
    iny
    inx
    cpx #SNAKE_LENGTH
    bne @sprites
    rts
.endproc

.proc update_snake
    ; Move the curved trail horizontally; byte overflow wraps it naturally.
    ldx #$00
    ldy #$03
@loop:
    lda snake_x,x
    clc
    adc snake_phase
    sta $0200,y
    iny
    iny
    iny
    iny
    inx
    cpx #SNAKE_LENGTH
    bne @loop
    rts
.endproc

.proc draw_rgb_color
    ; Set the universal background color.
    lda PPUSTATUS
    lda #$3F
    sta PPUADDR
    lda #$00
    sta PPUADDR
    ldx color_index
    lda rgb_colors,x
    sta PPUDATA

    ; Replace the two hexadecimal digits after "COLOR $".
    lda #$23
    sta PPUADDR
    lda #$29
    sta PPUADDR
    lda rgb_high_tiles,x
    sta PPUDATA
    lda rgb_low_tiles,x
    sta PPUDATA
    ; PPUADDR writes also affect scrolling; restore nametable 0 at (0,0).
    lda #$00
    sta PPUADDR
    sta PPUADDR
    rts
.endproc

.proc load_palette
    lda PPUSTATUS
    lda #$3F
    sta PPUADDR
    lda #$00
    sta PPUADDR
    ldx #$00
@loop:
    lda palette,x
    sta PPUDATA
    inx
    cpx #$20
    bne @loop
    rts
.endproc

.proc draw_menu
    ; Clear nametable 0 to tile 0 (blank).
    lda PPUSTATUS
    lda #$20
    sta PPUADDR
    lda #$00
    sta PPUADDR
    lda #$00
    ldx #$04
    ldy #$00
@clear:
    sta PPUDATA
    iny
    bne @clear
    dex
    bne @clear

    ; MARKS DEBUG ROM at row 2, column 8 ($2048).
    lda #$20
    sta PPUADDR
    lda #$48
    sta PPUADDR
    ldx #$00
@title:
    lda title,x
    sta PPUDATA
    inx
    cpx #title_end-title
    bne @title

    ; Eleven fixed-width records, two rows apart.
    ldx #$00
    ldy #$00
@entry_row:
    lda menu_row_hi,y
    sta PPUADDR
    lda menu_row_lo,y
    sta PPUADDR
    lda #12
    sta work0
@entry_char:
    lda entries,x
    sta PPUDATA
    inx
    dec work0
    bne @entry_char
    iny
    cpy #ENTRY_COUNT
    bne @entry_row
    rts
.endproc

.proc init_cursor
    ; Hide all sprites, then configure sprite 0 as the menu cursor.
    lda #$FF
    ldx #$00
@hide:
    sta $0200,x
    inx
    bne @hide
    lda #$00
    sta selected_entry
    lda #55                ; screen X
    sta $0203
    lda #14                ; '>' tile
    sta $0201
    lda #$00               ; sprite palette 0, no flip
    sta $0202
    jsr update_cursor
    rts
.endproc

.proc update_cursor
    ; Menu entries occupy rows 6, 8, ... 26.
    lda selected_entry
    asl
    asl
    asl
    asl
    clc
    adc #47
    sta $0200
    rts
.endproc

.proc read_controller
    lda buttons
    sta buttons_old
    lda #$01
    sta JOY1
    lda #$00
    sta JOY1
    sta buttons
    sta buttons2
    ldx #$08
@read:
    lda JOY1
    lsr
    ror buttons
    lda JOY2
    lsr
    ror buttons2
    dex
    bne @read

    ; Eight ROR operations leave A in bit 0 and Right in bit 7.
    lda buttons_old
    eor #$FF
    and buttons
    sta buttons_pressed
    rts
.endproc

.include "extras.asm"

.proc nmi
    pha
    txa
    pha
    tya
    pha
    lda #$00
    sta OAMADDR
    lda #$02
    sta OAMDMA
    lda #$01
    sta frame_ready
    inc nmi_count_lo
    bne @counted
    inc nmi_count_hi
@counted:
    pla
    tay
    pla
    tax
    pla
    rti
.endproc

.proc irq
    rti
.endproc

.segment "RODATA"
palette:
    ; Background palette 0: white text on the universal black backdrop.
    .byte $0F, $30, $10, $00
    .byte $0F, $0F, $10, $00
    .repeat 2
        .byte $0F, $30, $10, $00
    .endrepeat
    ; Sprite palette 0 supports inverse glyphs: white field, black letters.
    .byte $0F, $30, $0F, $00
    .repeat 3
        .byte $0F, $30, $10, $00
    .endrepeat

title:
    .byte 4,1,6,20,21,0,22,2,23,12,24,0,6,15,4 ; MARKS DEBUG ROM
title_end:

warning_text:
    .byte 28,1,6,5,3,5,24                 ; WARNING
flashing_text:
    .byte 29,16,1,21,31,3,5,24,0,17,15,16,15,6,21 ; FLASHING COLORS
careful_text:
    .byte 12,21,2,0,17,1,6,2,29,12,16,16,8       ; USE CAREFULLY
press_a_text:
    .byte 30,6,2,21,21,0,1                ; PRESS A

; Each menu record is exactly 12 tiles.
entries:
    .byte 17,15,16,15,6,0,21,5,1,20,2,0       ; COLOR SNAKE
    .byte 17,15,5,7,6,15,16,16,2,6,0,0       ; CONTROLLER
    .byte 4,15,32,2,4,2,5,7,0,0,0,0          ; MOVEMENT
    .byte 22,3,21,30,16,1,8,0,7,2,21,7       ; DISPLAY TEST
    .byte 30,1,16,2,7,7,2,0,32,3,2,28        ; PALETTE VIEW
    .byte 21,30,6,3,7,2,0,7,2,21,7,0         ; SPRITE TEST
    .byte 21,17,6,15,16,16,0,7,2,21,7,0      ; SCROLL TEST
    .byte 1,12,22,3,15,0,7,2,21,7,0,0        ; AUDIO TEST
    .byte 7,3,4,3,5,24,0,7,2,21,7,0          ; TIMING TEST
    .byte 6,1,4,0,7,2,21,7,0,0,0,0           ; RAM TEST
    .byte 21,8,21,7,2,4,0,3,5,29,15,0        ; SYSTEM INFO
menu_row_hi:
    .byte $20,$21,$21,$21,$21,$22,$22,$22,$22,$23,$23
menu_row_lo:
    .byte $C9,$09,$49,$89,$C9,$09,$49,$89,$C9,$09,$49

; RGB test cycles through NES palette $16 (red), $1A (green), and $12 (blue).
color_label:
    .byte 17,15,16,15,6,0,18,9,19 ; COLOR $16 (digits are updated dynamically)
color_label_end:
rgb_colors:
    .byte $06, $16, $26, $19, $29, $1A, $2A, $12, $22, $23
rgb_high_tiles:
    .byte 26, 9, 10, 9, 10, 9, 10, 9, 10, 10
rgb_low_tiles:
    .byte 19, 19, 19, 27, 27, 1, 1, 10, 10, 11
snake_palettes:
    .byte $16, $28, $1A, $12
snake_x:
    .byte 0,12,24,36,48,60,72,84,96,108,120,132,144,156,168,180
snake_y:
    .byte 72,76,84,96,108,116,120,116,108,96,84,76,72,76,84,96

controller_title:
    .byte 17,15,5,7,6,15,16,16,2,6,0,7,2,21,7 ; CONTROLLER TEST
controller_title_end:
; Eight bytes per row, padded with blanks.
controller_labels:
    .byte 1,0,0,0,0,0,0,0                  ; A
    .byte 23,0,0,0,0,0,0,0                 ; B
    .byte 21,2,16,2,17,7,0,0               ; SELECT
    .byte 21,7,1,6,7,0,0,0                 ; START
    .byte 12,30,0,0,0,0,0,0                ; UP
    .byte 22,15,28,5,0,0,0,0               ; DOWN
    .byte 16,2,29,7,0,0,0,0                ; LEFT
    .byte 6,3,24,31,7,0,0,0                ; RIGHT
controller_row_hi:
    .byte $21,$21,$21,$21,$22,$22,$22,$22
controller_row_lo:
    .byte $0C,$4C,$8C,$CC,$0C,$4C,$8C,$CC ; rows 8..22, column 12
controller_attr_hi:
    .byte $23,$23,$23,$23,$23,$23,$23,$23
controller_attr_lo:
    .byte $D3,$D4,$DB,$DC,$E3,$E4,$EB,$EC
controller_footer:
    .byte 21,7,1,6,7,0,21,2,16,2,17,7,0,7,15,0,16,2,1,32,2
controller_footer_end:
controller_raw_label:
    .byte 30,9,0,18,26,26,0,0,30,10,0,18,26,26
controller_raw_label_end:

; One white sprite per letter, grouped by its owning controller button.
controller_sprite_x:
    .byte 96, 96
    .byte 96,104,112,120,128,136
    .byte 96,104,112,120,128
    .byte 96,104
    .byte 96,104,112,120
    .byte 96,104,112,120
    .byte 96,104,112,120,128
controller_sprite_tiles:
    .byte 34,35
    .byte 36,37,38,37,39,40
    .byte 36,40,34,41,40
    .byte 42,43
    .byte 44,45,46,47
    .byte 38,37,48,40
    .byte 41,49,50,51,40
controller_sprite_y:
    .byte 63,79
    .byte 95,95,95,95,95,95
    .byte 111,111,111,111,111
    .byte 127,127
    .byte 143,143,143,143
    .byte 159,159,159,159
    .byte 175,175,175,175,175
controller_sprite_masks:
    .byte $01,$02
    .repeat 6
        .byte $04
    .endrepeat
    .repeat 5
        .byte $08
    .endrepeat
    .repeat 2
        .byte $10
    .endrepeat
    .repeat 4
        .byte $20
    .endrepeat
    .repeat 4
        .byte $40
    .endrepeat
    .repeat 5
        .byte $80
    .endrepeat

.segment "VECTORS"
    .addr nmi, reset, irq

.segment "CHARS"
; Existing font, then inverse sprite glyphs for the controller highlights.
    .repeat 16
        .byte $00
    .endrepeat
    .byte $18,$24,$42,$7E,$42,$42,$42,$00, $00,$00,$00,$00,$00,$00,$00,$00 ; A
    .byte $7E,$40,$40,$7C,$40,$40,$7E,$00, $00,$00,$00,$00,$00,$00,$00,$00 ; E
    .byte $3C,$18,$18,$18,$18,$18,$3C,$00, $00,$00,$00,$00,$00,$00,$00,$00 ; I
    .byte $42,$66,$5A,$5A,$42,$42,$42,$00, $00,$00,$00,$00,$00,$00,$00,$00 ; M
    .byte $42,$62,$52,$4A,$46,$42,$42,$00, $00,$00,$00,$00,$00,$00,$00,$00 ; N
    .byte $7C,$42,$42,$7C,$48,$44,$42,$00, $00,$00,$00,$00,$00,$00,$00,$00 ; R
    .byte $7E,$18,$18,$18,$18,$18,$18,$00, $00,$00,$00,$00,$00,$00,$00,$00 ; T
    .byte $42,$42,$24,$18,$18,$18,$18,$00, $00,$00,$00,$00,$00,$00,$00,$00 ; Y
    .byte $18,$38,$18,$18,$18,$18,$7E,$00, $00,$00,$00,$00,$00,$00,$00,$00 ; 1
    .byte $3C,$42,$02,$0C,$30,$40,$7E,$00, $00,$00,$00,$00,$00,$00,$00,$00 ; 2
    .byte $3C,$42,$02,$1C,$02,$42,$3C,$00, $00,$00,$00,$00,$00,$00,$00,$00 ; 3
    .byte $42,$42,$42,$42,$42,$42,$3C,$00, $00,$00,$00,$00,$00,$00,$00,$00 ; U
    .byte $0C,$14,$24,$44,$7E,$04,$04,$00, $00,$00,$00,$00,$00,$00,$00,$00 ; 4
    .byte $20,$10,$08,$04,$08,$10,$20,$00, $00,$00,$00,$00,$00,$00,$00,$00 ; >
    .byte $3C,$42,$42,$42,$42,$42,$3C,$00, $00,$00,$00,$00,$00,$00,$00,$00 ; O
    .byte $40,$40,$40,$40,$40,$40,$7E,$00, $00,$00,$00,$00,$00,$00,$00,$00 ; L
    .byte $3C,$42,$40,$40,$40,$42,$3C,$00, $00,$00,$00,$00,$00,$00,$00,$00 ; C
    .byte $18,$3E,$58,$3C,$1A,$7C,$18,$00, $00,$00,$00,$00,$00,$00,$00,$00 ; $
    .byte $1C,$20,$40,$7C,$42,$42,$3C,$00, $00,$00,$00,$00,$00,$00,$00,$00 ; 6
    .byte $42,$44,$48,$70,$48,$44,$42,$00, $00,$00,$00,$00,$00,$00,$00,$00 ; K
    .byte $3C,$42,$40,$3C,$02,$42,$3C,$00, $00,$00,$00,$00,$00,$00,$00,$00 ; S
    .byte $78,$44,$42,$42,$42,$44,$78,$00, $00,$00,$00,$00,$00,$00,$00,$00 ; D
    .byte $7C,$42,$42,$7C,$42,$42,$7C,$00, $00,$00,$00,$00,$00,$00,$00,$00 ; B
    .byte $3C,$42,$40,$4E,$42,$42,$3C,$00, $00,$00,$00,$00,$00,$00,$00,$00 ; G
    .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF, $00,$00,$00,$00,$00,$00,$00,$00 ; solid
    .byte $3C,$42,$46,$4A,$52,$62,$3C,$00, $00,$00,$00,$00,$00,$00,$00,$00 ; 0
    .byte $3C,$42,$42,$3E,$02,$04,$38,$00, $00,$00,$00,$00,$00,$00,$00,$00 ; 9
    .byte $42,$42,$42,$5A,$5A,$66,$42,$00, $00,$00,$00,$00,$00,$00,$00,$00 ; W
    .byte $7E,$40,$40,$7C,$40,$40,$40,$00, $00,$00,$00,$00,$00,$00,$00,$00 ; F
    .byte $7C,$42,$42,$7C,$40,$40,$40,$00, $00,$00,$00,$00,$00,$00,$00,$00 ; P
    .byte $42,$42,$42,$7E,$42,$42,$42,$00, $00,$00,$00,$00,$00,$00,$00,$00 ; H
    .byte $42,$42,$42,$42,$42,$24,$18,$00, $00,$00,$00,$00,$00,$00,$00,$00 ; V
    .byte $00,$00,$00,$00,$00,$18,$18,$10, $00,$00,$00,$00,$00,$00,$00,$00 ; comma
    .byte $E7,$DB,$BD,$81,$BD,$BD,$BD,$FF, $18,$24,$42,$7E,$42,$42,$42,$00 ; inverse A
    .byte $83,$BD,$BD,$83,$BD,$BD,$83,$FF, $7C,$42,$42,$7C,$42,$42,$7C,$00 ; inverse B
    .byte $C3,$BD,$BF,$C3,$FD,$BD,$C3,$FF, $3C,$42,$40,$3C,$02,$42,$3C,$00 ; inverse S
    .byte $81,$BF,$BF,$83,$BF,$BF,$81,$FF, $7E,$40,$40,$7C,$40,$40,$7E,$00 ; inverse E
    .byte $BF,$BF,$BF,$BF,$BF,$BF,$81,$FF, $40,$40,$40,$40,$40,$40,$7E,$00 ; inverse L
    .byte $C3,$BD,$BF,$BF,$BF,$BD,$C3,$FF, $3C,$42,$40,$40,$40,$42,$3C,$00 ; inverse C
    .byte $81,$E7,$E7,$E7,$E7,$E7,$E7,$FF, $7E,$18,$18,$18,$18,$18,$18,$00 ; inverse T
    .byte $83,$BD,$BD,$83,$B7,$BB,$BD,$FF, $7C,$42,$42,$7C,$48,$44,$42,$00 ; inverse R
    .byte $BD,$BD,$BD,$BD,$BD,$BD,$C3,$FF, $42,$42,$42,$42,$42,$42,$3C,$00 ; inverse U
    .byte $83,$BD,$BD,$83,$BF,$BF,$BF,$FF, $7C,$42,$42,$7C,$40,$40,$40,$00 ; inverse P
    .byte $87,$BB,$BD,$BD,$BD,$BB,$87,$FF, $78,$44,$42,$42,$42,$44,$78,$00 ; inverse D
    .byte $C3,$BD,$BD,$BD,$BD,$BD,$C3,$FF, $3C,$42,$42,$42,$42,$42,$3C,$00 ; inverse O
    .byte $BD,$BD,$BD,$A5,$A5,$99,$BD,$FF, $42,$42,$42,$5A,$5A,$66,$42,$00 ; inverse W
    .byte $BD,$9D,$AD,$B5,$B9,$BD,$BD,$FF, $42,$62,$52,$4A,$46,$42,$42,$00 ; inverse N
    .byte $81,$BF,$BF,$83,$BF,$BF,$BF,$FF, $7E,$40,$40,$7C,$40,$40,$40,$00 ; inverse F
    .byte $C3,$E7,$E7,$E7,$E7,$E7,$C3,$FF, $3C,$18,$18,$18,$18,$18,$3C,$00 ; inverse I
    .byte $C3,$BD,$BF,$B1,$BD,$BD,$C3,$FF, $3C,$42,$40,$4E,$42,$42,$3C,$00 ; inverse G
    .byte $BD,$BD,$BD,$81,$BD,$BD,$BD,$FF, $42,$42,$42,$7E,$42,$42,$42,$00 ; inverse H
    .byte $3C,$40,$40,$3C,$02,$42,$3C,$00, $00,$00,$00,$00,$00,$00,$00,$00 ; 5
    .byte $7E,$02,$04,$08,$10,$20,$20,$00, $00,$00,$00,$00,$00,$00,$00,$00 ; 7
    .byte $3C,$42,$42,$3C,$42,$42,$3C,$00, $00,$00,$00,$00,$00,$00,$00,$00 ; 8
