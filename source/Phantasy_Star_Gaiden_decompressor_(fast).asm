; ***** PSGaiden tile decompressor                                *****
; ***** by sverx - https://github.com/sverx/PSGaiden_tile_decompr *****

.section "PSGaiden tile decompressor" align 256 superfree
PSGaiden_jump_table:                    ; this needs to be 256 bytes aligned!!!!
  .db <typeA_plane0, <typeA_plane1, <typeA_plane2, <typeE    ; [0x00,0x03]
  .repeat 12
    .db <typeE                                               ; [0x04,0x0F]
  .endr
  .db <typeB_plane0, <typeB_plane1, <typeB_plane2, <typeE    ; [0x10,0x13]
  .repeat 12
    .db <typeE                                               ; [0x14,0x1F]
  .endr
  .db <typeC_plane0, <typeC_plane1, <typeC_plane2, <typeE    ; [0x20,0x23]
  .repeat 12+16
    .db <typeE                                               ; [0x24,0x3F]
  .endr
  .db <typeD_plane0, <typeD_plane1, <typeD_plane2, <typeE    ; [0x40,0x43]
  .repeat 12+16*11
    .db <typeE                                               ; [0x44,0xFF]
  .endr

typeE:
       jp typeE_proc

typeA_plane2:
       ld hl,PSGaiden_decomp_buffer+16
       jp +

typeA_plane1:
       ld hl,PSGaiden_decomp_buffer+8
       jp +

typeA_plane0:
       ld hl,PSGaiden_decomp_buffer
+:     push bc                          ; backup BC
         .repeat 8
           ldi                          ; copy new data (DE)=(HL), DE++, HL++, BC--
         .endr
       pop bc                           ; restore BC
     pop hl
     jp _BitplaneDone

typeB_plane2:
       ld hl,PSGaiden_decomp_buffer+16
       jp +

typeB_plane1:
       ld hl,PSGaiden_decomp_buffer+8
       jp +

typeB_plane0:
       ld hl,PSGaiden_decomp_buffer
+:     .repeat 8 index n
         ld a,(hl)                      ; load byte
         cpl                            ; complement
         ld (de),a                      ; write byte
         inc de                         ; DE++
         .if n != 7
           inc hl                       ; HL++ (we don't need it on last rept)
         .endif
       .endr
     pop hl
     jp _BitplaneDone

typeC_plane2:
     pop hl
     push bc
       ld bc,PSGaiden_decomp_buffer+16
       jp typeC_proc

typeC_plane1:
     pop hl
     push bc
       ld bc,PSGaiden_decomp_buffer+8
       jp typeC_proc

typeC_plane0:
     pop hl
     push bc
       ld bc,PSGaiden_decomp_buffer
       jp typeC_proc

typeD_plane2:
     pop hl
     push bc
       ld bc,PSGaiden_decomp_buffer+16
       jp +

typeD_plane1:
     pop hl
     push bc
       ld bc,PSGaiden_decomp_buffer+8
       jp +

typeD_plane0:
     pop hl
     push bc
       ld bc,PSGaiden_decomp_buffer
+:     ld a,(hl)                        ; read bitmask
       inc hl
       .repeat 8 index n
         rlca                           ; get bit out of bitmask
         jr c,+                         ; if 1, copy from previous bitmask
         ldi                            ; copy new data (DE)=(HL), DE++, HL++, BC--
         .if n != 7
           inc bc                       ; we need to BC++ twice because of that LDI...
           inc bc                       ; (we don't need them on last rept)
         .endif
         jp ++
+:       ld ixl,a                       ; faster than push AF
           ld a,(bc)                    ; load byte
           cpl                          ; complement
           ld (de),a                    ; write byte
           .if n != 7
             inc bc                     ; BC++ (we don't need it on last rept)
           .endif
           inc de                       ; DE++
         ld a,ixl                       ; restore A
++:
       .endr
     pop bc
     jp _BitplaneDone

typeE_proc:
     pop hl
     push bc
       ld b,a                           ; move mask (was type) in B
       ld a,(hl)                        ; read next byte ('common')
       inc hl
       ld c,9                           ; so that B doesn't change when BC--
       .repeat 8
         rlc b                          ; get bit out of bitmask
         jr c,+                         ; if 1, copy from common byte
         ldi                            ; copy new data (DE)=(HL), DE++, HL++, BC--
         jp ++
+:       ld (de),a                      ; write 'common' byte
         inc de
++:
       .endr
     pop bc
     jp _BitplaneDone

typeC_proc:
+:     ld a,(hl)                        ; read bitmask
       inc hl
       .repeat 8 index n
         rlca                           ; get bit out of bitmask
         jr c,+                         ; if 1, copy from previous bitmask
         ldi                            ; copy new data (DE)=(HL), DE++, HL++, BC--
         .if n != 7
           inc bc                       ; we need to BC++ twice because of that LDI...
           inc bc                       ; (we don't need them on last rept)
         .endif
         jp ++

+:       ld ixl,a                       ; faster than push AF
           ld a,(bc)                    ; load byte
           ld (de),a                    ; write byte
           inc de                       ; DE++
           .if n != 7
             inc bc                     ; BC++ (we don't need it on last rept)
           .endif
         ld a,ixl                       ; restore A
++:
       .endr
     pop bc
     djnz _BitplaneLoop
     jp _WriteVRAM

PSGaiden_tile_decompr:                  ; ******** procedure entry point *************
   ld c,$bf                             ; set VRAM address
   out (c),e
   out (c),d

   ld c,(hl)                            ; BC = number of tiles
   inc hl
   ld b,(hl)
   inc hl

_MainLoop:
   push bc                              ; save number of tiles left
     ld de,PSGaiden_decomp_buffer       ; DE = decomp_buffer
     ld c,(hl)                          ; C = encoding information for 4 bitplanes
     inc hl
     ld b,4                             ; we've got 4 bitplanes

_BitplaneLoop:
     rlc c                              ; %0x = all bits either 0 or 1
     jr nc,_AllTheSame
     rlc c                              ; %11 = raw data follows
     jr c,_RawData

     ; we're here, so bitplane is somehow compressed!

     ld a,(hl)                          ; get method byte
     inc hl
     push hl                            ; save HL for later
       ld l,a
       ld h,>PSGaiden_jump_table
       ld l,(hl)
       ld h,>typeE
       jp (hl)                          ; jump to desired routine

_AllTheSame:
     rlc c                              ; get next bit into carry
     sbc a,a                            ; will make A=$00 if carry = 0, A=$ff if it's 1
     .repeat 8
       ld (de),a                        ; store the value
       inc de                           ; DE++
     .endr
     djnz _BitplaneLoop
     jp _WriteVRAM

_RawData:
     push bc                            ; backup BC
     .repeat 8
        ldi                             ; copy the raw 8 bytes to (DE)
     .endr
     pop bc                             ; restore BC
     ; fallback to _BitplaneDone

_BitplaneDone:
     djnz _BitplaneLoop
     ; tile is complete - ; fallback to _WriteVRAM

_WriteVRAM:                             ; now loopless!
     push hl
       ld hl,PSGaiden_decomp_buffer     ; HL = source buffer
       ld bc,-8*3+1                     ; after each group of 4 bytes, go back this amount
       ld de,8                          ; each byte is 8 byte apart
       .repeat 8 index k
         .repeat 4 index n
           ld a,(hl)
           out ($be),a                  ; write to vram 4 bytes
           .if n != 3
             add hl,de                  ; we don't need this the last time
           .endif
         .endr
         .if k != 7
           add hl,bc                    ; go back for next run, if it's not the last
         .endif
       .endr
     pop hl

   pop bc
   dec bc                               ; more tiles?
   ld a,b
   or c
   jp nz,_MainLoop                      ; let's go again!
   ret
.ends
