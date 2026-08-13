; Additional diagnostic screens. All screens use Start+Select as the exit chord.

PULSE1_CTRL  = $4000
PULSE1_SWEEP = $4001
PULSE1_LO    = $4002
PULSE1_HI    = $4003
PULSE2_CTRL  = $4004
PULSE2_SWEEP = $4005
PULSE2_LO    = $4006
PULSE2_HI    = $4007
TRI_CTRL     = $4008
TRI_LO       = $400A
TRI_HI       = $400B
NOISE_CTRL   = $400C
NOISE_PERIOD = $400E
NOISE_LEN    = $400F

.macro point_to label
    lda #<label
    sta screen_ptr
    lda #>label
    sta screen_ptr+1
.endmacro

.segment "CODE"

.proc clear_test_screen
    lda #$00
    sta PPUMASK
    lda #$FF
    ldx #$00
@hide:
    sta $0200,x
    inx
    bne @hide
    jsr load_palette
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
    rts
.endproc

; screen_ptr = source, X/Y = PPU high/low, A = length.
.proc write_text
    sta work0
    lda PPUSTATUS
    stx PPUADDR
    sty PPUADDR
    ldy #$00
@loop:
    lda (screen_ptr),y
    sta PPUDATA
    iny
    dec work0
    bne @loop
    rts
.endproc

.proc finish_background
    lda #$00
    sta PPUADDR
    sta PPUADDR
    lda #%00001010
    sta PPUMASK
    rts
.endproc

.proc finish_sprites
    lda #$00
    sta PPUADDR
    sta PPUADDR
    lda #%00011110
    sta PPUMASK
    rts
.endproc

.proc enter_extra_screen
    lda selected_entry
    cmp #2
    beq @move
    cmp #3
    beq @display
    cmp #4
    beq @palette
    cmp #5
    beq @sprite
    cmp #6
    beq @scroll
    cmp #7
    beq @audio
    cmp #8
    beq @timing
    cmp #9
    beq @ram
    jmp enter_info
@move:    jmp enter_move
@display: jmp enter_display
@palette: jmp enter_palette
@sprite:  jmp enter_sprite
@scroll:  jmp enter_scroll
@audio:   jmp enter_audio
@timing:  jmp enter_timing
@ram:     jmp enter_ram
.endproc

.proc update_extra_screen
    lda buttons
    and #(BTN_START | BTN_SELECT)
    cmp #(BTN_START | BTN_SELECT)
    bne @run
    lda #$00
    sta APU_STATUS
    sta PPUSCROLL
    sta PPUSCROLL
    lda #%10000000
    sta PPUCTRL
    jmp enter_menu
@run:
    lda screen_state
    cmp #SCREEN_MOVE
    beq @move
    cmp #SCREEN_PALETTE
    beq @palette
    cmp #SCREEN_SPRITE
    beq @sprite
    cmp #SCREEN_SCROLL
    beq @scroll
    cmp #SCREEN_AUDIO
    beq @audio
    cmp #SCREEN_TIMING
    beq @timing
    rts
@move:    jmp update_move
@palette: jmp update_palette
@sprite:  jmp update_sprite
@scroll:  jmp update_scroll
@audio:   jmp update_audio
@timing:  jmp update_timing
.endproc

.proc enter_move
    jsr clear_test_screen
    point_to move_title
    ldx #$20
    ldy #$4C
    lda #13
    jsr write_text
    point_to move_help
    ldx #$23
    ldy #$45
    lda #21
    jsr write_text
    lda #111
    sta $0200
    lda #14
    sta $0201
    lda #$00
    sta $0202
    lda #120
    sta $0203
    lda #SCREEN_MOVE
    sta screen_state
    jmp finish_sprites
.endproc

.proc update_move
    lda buttons
    and #BTN_UP
    beq :+
    dec $0200
:
    lda buttons
    and #BTN_DOWN
    beq :+
    inc $0200
:
    lda buttons
    and #BTN_LEFT
    beq :+
    dec $0203
:
    lda buttons
    and #BTN_RIGHT
    beq :+
    inc $0203
:
    rts
.endproc

.proc enter_display
    jsr clear_test_screen
    ; Border plus center crosshair over the 32x30 tile field.
    lda PPUSTATUS
    lda #$20
    sta PPUADDR
    lda #$00
    sta PPUADDR
    lda #$00
    sta work1
@row:
    lda #$00
    sta work0
@column:
    lda work1
    beq @solid
    cmp #29
    beq @solid
    cmp #15
    beq @solid
    lda work0
    beq @solid
    cmp #31
    beq @solid
    cmp #16
    beq @solid
    lda #$00
    beq @write
@solid:
    lda #25
@write:
    sta PPUDATA
    inc work0
    lda work0
    cmp #32
    bne @column
    inc work1
    lda work1
    cmp #30
    bne @row
    point_to display_title
    ldx #$20
    ldy #$49
    lda #12
    jsr write_text
    lda #SCREEN_DISPLAY
    sta screen_state
    jmp finish_background
.endproc

.proc enter_palette
    jsr clear_test_screen
    point_to palette_title
    ldx #$20
    ldy #$4A
    lda #12
    jsr write_text
    point_to palette_help
    ldx #$23
    ldy #$44
    lda #23
    jsr write_text
    point_to palette_page
    ldx #$22
    ldy #$2C
    lda #7
    jsr write_text
    ; Four 16x16 swatches made from four sprites each.
    ldx #$00
    ldy #$00
@sprites:
    lda palette_sprite_y,x
    sta $0200,y
    lda #25
    sta $0201,y
    lda palette_sprite_attr,x
    sta $0202,y
    lda palette_sprite_x,x
    sta $0203,y
    iny
    iny
    iny
    iny
    inx
    cpx #16
    bne @sprites
    lda #$00
    sta work2
    jsr draw_palette_page
    lda #SCREEN_PALETTE
    sta screen_state
    jmp finish_sprites
.endproc

.proc update_palette
    lda buttons_pressed
    and #BTN_LEFT
    beq @right
    lda work2
    bne :+
    lda #16
:
    sec
    sbc #1
    sta work2
    jsr draw_palette_page
@right:
    lda buttons_pressed
    and #BTN_RIGHT
    beq @done
    inc work2
    lda work2
    and #$0F
    sta work2
    jsr draw_palette_page
@done:
    rts
.endproc

.proc draw_palette_page
    lda work2
    asl
    asl
    sta work1
    ldx #$00
@color:
    lda PPUSTATUS
    lda #$3F
    sta PPUADDR
    lda palette_sprite_addr,x
    sta PPUADDR
    txa
    clc
    adc work1
    tay
    lda nes_palette,y
    sta PPUDATA
    inx
    cpx #4
    bne @color
    ; Show the high hexadecimal digit in COLORS $x0-$x3.
    lda #$22
    sta PPUADDR
    lda #$32
    sta PPUADDR
    ldx work2
    lda hex_tiles,x
    sta PPUDATA
    lda #$00
    sta PPUADDR
    sta PPUADDR
    rts
.endproc

.proc enter_sprite
    jsr clear_test_screen
    point_to sprite_title
    ldx #$20
    ldy #$4A
    lda #11
    jsr write_text
    point_to sprite_help
    ldx #$23
    ldy #$44
    lda #23
    jsr write_text
    ldx #$00
    ldy #$00
@sprites:
    lda #119
    sta $0200,y
    lda #14
    sta $0201,y
    lda #$00
    sta $0202,y
    lda sprite_test_x,x
    sta $0203,y
    iny
    iny
    iny
    iny
    inx
    cpx #9
    bne @sprites
    lda #$00
    sta work2
    sta work0
    lda #SCREEN_SPRITE
    sta screen_state
    jmp finish_sprites
.endproc

.proc update_sprite
    lda buttons_pressed
    and #BTN_A
    beq @vertical
    lda work2
    eor #%01000000
    sta work2
    ldx #$02
@flip:
    lda work2
    sta $0200,x
    txa
    clc
    adc #4
    tax
    cpx #38
    bcc @flip
@vertical:
    lda buttons
    and #BTN_UP
    beq @down
    ldx #$00
@up_loop:
    dec $0200,x
    txa
    clc
    adc #4
    tax
    cpx #36
    bcc @up_loop
@down:
    lda buttons
    and #BTN_DOWN
    beq @done
    ldx #$00
@down_loop:
    inc $0200,x
    txa
    clc
    adc #4
    tax
    cpx #36
    bcc @down_loop
@done:
    rts
.endproc

.proc enter_scroll
    jsr clear_test_screen
    ; Fill both horizontal nametables with alternating tiles.
    lda #$20
    jsr fill_scroll_table
    lda #$24
    jsr fill_scroll_table
    lda #$00
    sta work2
    sta work0
    lda #SCREEN_SCROLL
    sta screen_state
    jmp finish_background
.endproc

; A = nametable high byte. Writes 1024 bytes including an intentionally patterned
; attribute table, making seams and mirroring behavior easy to see.
.proc fill_scroll_table
    sta work1
    lda PPUSTATUS
    lda work1
    sta PPUADDR
    lda #$00
    sta PPUADDR
    ldx #$04
    ldy #$00
@loop:
    tya
    and #$01
    beq :+
    lda #25
    bne @write
:
    lda #$00
@write:
    sta PPUDATA
    iny
    bne @loop
    dex
    bne @loop
    rts
.endproc

.proc update_scroll
    lda buttons
    and #BTN_LEFT
    beq @right
    lda work2
    bne :+
    lda work0
    eor #$01
    sta work0
:
    dec work2
@right:
    lda buttons
    and #BTN_RIGHT
    beq @apply
    inc work2
    bne @apply
    lda work0
    eor #$01
    sta work0
@apply:
    lda work0
    ora #%10000000
    sta PPUCTRL
    lda work2
    sta PPUSCROLL
    lda #$00
    sta PPUSCROLL
    rts
.endproc

.proc enter_audio
    jsr clear_test_screen
    point_to audio_title
    ldx #$20
    ldy #$4B
    lda #10
    jsr write_text
    point_to audio_help
    ldx #$22
    ldy #$C5
    lda #24
    jsr write_text
    point_to audio_channel
    ldx #$22
    ldy #$0B
    lda #9
    jsr write_text
    lda #$80
    sta work2
    lda #$01
    sta work1
    lda #$00
    sta work0
    jsr audio_apply
    lda #SCREEN_AUDIO
    sta screen_state
    jmp finish_background
.endproc

.proc update_audio
    lda buttons_pressed
    and #BTN_UP
    beq @down
    lda work0
    bne :+
    lda #4
:
    sec
    sbc #1
    sta work0
    jsr audio_show_channel
    jsr audio_apply
@down:
    lda buttons_pressed
    and #BTN_DOWN
    beq @toggle
    inc work0
    lda work0
    and #$03
    sta work0
    jsr audio_show_channel
    jsr audio_apply
@toggle:
    lda buttons_pressed
    and #BTN_A
    beq @pitch
    lda work1
    eor #$01
    sta work1
    jsr audio_apply
@pitch:
    lda buttons
    and #BTN_LEFT
    beq @right
    inc work2
    jsr audio_apply
@right:
    lda buttons
    and #BTN_RIGHT
    beq @done
    dec work2
    jsr audio_apply
@done:
    rts
.endproc

.proc audio_show_channel
    lda #$22
    sta PPUADDR
    lda #$13
    sta PPUADDR
    ldx work0
    lda audio_channel_tiles,x
    sta PPUDATA
    lda #$00
    sta PPUADDR
    sta PPUADDR
    rts
.endproc

.proc audio_apply
    lda work1
    bne @enabled
    lda #$00
    sta APU_STATUS
    rts
@enabled:
    ldx work0
    lda audio_status_masks,x
    sta APU_STATUS
    cpx #0
    beq @pulse1
    cpx #1
    beq @pulse2
    cpx #2
    beq @triangle
    lda #%00111111
    sta NOISE_CTRL
    lda work2
    and #$0F
    sta NOISE_PERIOD
    lda #$02
    sta NOISE_LEN
    rts
@pulse1:
    lda #%10111111
    sta PULSE1_CTRL
    lda #$08
    sta PULSE1_SWEEP
    lda work2
    sta PULSE1_LO
    lda #$02
    sta PULSE1_HI
    rts
@pulse2:
    lda #%10111111
    sta PULSE2_CTRL
    lda #$08
    sta PULSE2_SWEEP
    lda work2
    sta PULSE2_LO
    lda #$02
    sta PULSE2_HI
    rts
@triangle:
    lda #$FF
    sta TRI_CTRL
    lda work2
    sta TRI_LO
    lda #$02
    sta TRI_HI
    rts
.endproc

.proc enter_timing
    jsr clear_test_screen
    point_to timing_title
    ldx #$20
    ldy #$4A
    lda #11
    jsr write_text
    point_to timing_label
    ldx #$21
    ldy #$CC
    lda #10
    jsr write_text
    lda #SCREEN_TIMING
    sta screen_state
    jsr update_timing
    jmp finish_background
.endproc

.proc update_timing
    lda #$21
    sta PPUADDR
    lda #$D6
    sta PPUADDR
    lda nmi_count_hi
    jsr write_hex_value
    lda nmi_count_lo
    jsr write_hex_value
    lda #$00
    sta PPUADDR
    sta PPUADDR
    rts
.endproc

; Writes A as two hexadecimal tiles at the current PPU address.
.proc write_hex_value
    pha
    lsr
    lsr
    lsr
    lsr
    tax
    lda hex_tiles,x
    sta PPUDATA
    pla
    and #$0F
    tax
    lda hex_tiles,x
    sta PPUDATA
    rts
.endproc

.proc enter_ram
    jsr clear_test_screen
    point_to ram_title
    ldx #$20
    ldy #$4C
    lda #8
    jsr write_text
    lda #$01
    sta work2
    lda #$03
    sta screen_ptr+1
    lda #$00
    sta screen_ptr
@page:
    ldy #$00
    lda #$AA
@write_aa:
    sta (screen_ptr),y
    iny
    bne @write_aa
    ldy #$00
@check_aa:
    lda (screen_ptr),y
    cmp #$AA
    bne @fail
    iny
    bne @check_aa
    ldy #$00
    lda #$55
@write_55:
    sta (screen_ptr),y
    iny
    bne @write_55
    ldy #$00
@check_55:
    lda (screen_ptr),y
    cmp #$55
    bne @fail
    iny
    bne @check_55
    inc screen_ptr+1
    lda screen_ptr+1
    cmp #$08
    bne @page
    jmp @result
@fail:
    lda #$00
    sta work2
@result:
    lda work2
    beq @failed
    point_to ram_pass
    jmp @show
@failed:
    point_to ram_fail
@show:
    ldx #$21
    ldy #$CE
    lda #4
    jsr write_text
    lda #SCREEN_RAM
    sta screen_state
    jmp finish_background
.endproc

.proc enter_info
    jsr clear_test_screen
    point_to info_title
    ldx #$20
    ldy #$4A
    lda #11
    jsr write_text
    point_to info_lines
    ldx #$21
    ldy #$49
    lda #12
    jsr write_text
    point_to info_prg
    ldx #$21
    ldy #$89
    lda #12
    jsr write_text
    point_to info_chr
    ldx #$21
    ldy #$C9
    lda #12
    jsr write_text
    point_to info_region
    ldx #$22
    ldy #$09
    lda #12
    jsr write_text
    lda #SCREEN_INFO
    sta screen_state
    jmp finish_background
.endproc

.segment "RODATA"
move_title:    .byte 4,15,32,2,4,2,5,7,0,7,2,21,7
move_help:     .byte 22,30,1,22,0,4,15,32,2,21,0,21,30,6,3,7,2,0,0,0,0
display_title: .byte 22,3,21,30,16,1,8,0,7,2,21,7
palette_title: .byte 30,1,16,2,7,7,2,0,32,3,2,28
palette_help:  .byte 16,2,29,7,0,6,3,24,31,7,0,17,31,1,5,24,2,0,30,1,24,2,0
palette_page:  .byte 30,1,24,2,0,18,26
sprite_title:  .byte 21,30,6,3,7,2,0,7,2,21,7
sprite_help:   .byte 1,0,29,16,3,30,21,0,0,12,30,0,22,15,28,5,0,4,15,32,2,0,0
audio_title:   .byte 1,12,22,3,15,0,7,2,21,7
audio_help:    .byte 12,30,0,22,15,28,5,0,17,31,1,5,5,2,16,0,1,0,7,15,24,24,16,2
audio_channel: .byte 17,31,1,5,5,2,16,0,9
audio_channel_tiles: .byte 9,10,11,13
audio_status_masks: .byte $01,$02,$04,$08
timing_title:  .byte 7,3,4,3,5,24,0,7,2,21,7
timing_label:  .byte 5,4,3,0,17,15,12,5,7,0
ram_title:     .byte 6,1,4,0,7,2,21,7
ram_pass:      .byte 30,1,21,21
ram_fail:      .byte 29,1,3,16
info_title:    .byte 21,8,21,7,2,4,0,3,5,29,15
info_lines:    .byte 4,1,30,30,2,6,0,0,0,0,0,26
info_prg:      .byte 30,6,24,0,0,9,19,20,0,0,0,0
info_chr:      .byte 17,31,6,0,0,0,54,20,0,0,0,0
info_region:   .byte 5,7,21,17,0,7,1,6,24,2,7,0

hex_tiles:
    .byte 26,9,10,11,13,52,19,53,54,27,1,23,17,22,2,29

; Common NTSC palette ordering, including the normally avoided $xD-$xF values.
nes_palette:
    .byte $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0A,$0B,$0C,$0F,$0F,$0F
    .byte $10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$1A,$1B,$1C,$0F,$0F,$0F
    .byte $20,$21,$22,$23,$24,$25,$26,$27,$28,$29,$2A,$2B,$2C,$0F,$0F,$0F
    .byte $30,$31,$32,$33,$34,$35,$36,$37,$38,$39,$3A,$3B,$3C,$0F,$0F,$0F
palette_sprite_addr: .byte $11,$15,$19,$1D
palette_sprite_x:
    .byte 48,56,48,56, 96,104,96,104, 144,152,144,152, 192,200,192,200
palette_sprite_y:
    .byte 111,111,119,119, 111,111,119,119, 111,111,119,119, 111,111,119,119
palette_sprite_attr:
    .byte 0,0,0,0, 1,1,1,1, 2,2,2,2, 3,3,3,3
sprite_test_x:
    .byte 72,88,104,120,136,152,168,184,200

.segment "CODE"
