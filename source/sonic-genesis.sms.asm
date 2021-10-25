; WLA-DX banking setup
.memorymap
defaultslot 0
slot 0 $0000 $4000 ; ROM
slot 1 $4000 $4000 ; ROM (paged)
slot 2 $8000 $4000 ; ROM (paged)
slot 3 $c000 $2000 ; RAM
.endme

; We expand to 512KB
.rombankmap
bankstotal 32
banksize $4000
banks 32
.endro

; We can replace the tile compression but this will of course break the level editor
;.define USE_PSGCOMPR

.background "sonic.sms"

; Unused areas for our hacks...
.unbackground $000c $0017
.unbackground $001b $001f
.unbackground $0023 $0027
.unbackground $002b $0037
.unbackground $7fdb $7fef

; Definitions for memory and functions from the game...
.define RAM_CURRENT_LEVEL $D23E
.define RAM_TEMP1         $D20E

; Definitions for structures from the game...
.struct LevelHeader
  Solidity            db
  FloorWidth          dw
  FloorHeight         dw
  CropLeft            db
  LevelXOffset        db
  Unknown1            db
  LevelWidth          db
  CropTop             db
  LevelYOffset        db
  ExtendHeight        db
  LevelHeight         db
  StartX              db
  StartY              db
  FloorLayout         dw
  FloorSize           dw
  BlockMappings       dw
  LevelArt            dw
  SpriteBank          db
  SpriteArt           dw
  InitialPalette      db
  CycleSpeed          db
  CycleCount          db
  CyclePalette        db
  ObjectLayout        dw
  ScrollingRingFlags  db
  UnderwaterFlag      db
  TimeLightningFlags  db
  Unknown2            db
  Music               db
.endst
.enum $155CA
  LevelHeaders instanceof LevelHeader 32
.ende

; Helper macros for ROM hacking...

; Sets the .org to a ROM address, optionally in a given slot
.macro ROMPosition args _address, _slot
.if NARGS == 1
  .if _address < $4000
    .bank 0 slot 0                    ; Slot 0 for <$4000
  .else
    .if _address < $8000
      .bank 1 slot 1                  ; Slot 1 for <$8000
    .else
      .bank (_address / $4000) slot 2 ; Slot 2 otherwise
    .endif
  .endif
.else
  .bank (_address / $4000) slot _slot ; Slot is given
.endif
.org _address # $4000 ; modulo
.endm

; Patches a byte at the given ROM address
.macro PatchB args _address, _value
  ROMPosition _address
.section "Auto patch @ \1" overwrite
PatchAt\1:
  .db _value
.ends
.endm

; Patches a word at the given ROM address
.macro PatchW args _address, _value
  ROMPosition _address
.section "Auto patch @ \1" overwrite
PatchAt\1:
  .dw _value
.ends
.endm



; Now we start to remove and replace artwork...
; We want to find all the places where it is loaded and
; 1. Replace the reference with a label
; 2. Mark the old data space as unused
; 3. Insert the new data
; This way the data can be moved around and the assembler sorts it all out.

; art loading is often like this:
/*
	ld	hl, src
	ld	de, dest
	ld	a, :src
	call	decompressArt
*/
; We make a macro to patch one of these. 
; Offset is where the code is
; Source is where the compressed data is.
; Destination is the tile number, i.e. the address divided by 32
.macro patchArtLoad args _offset, _source, _destination
  ROMPosition _offset
.section "Artwork patch for \2 \@" overwrite
  ld hl, _source
  ld de, _destination*32
  ld a, :_source
  call decompressArt
.ends
.endm

  ; We patch these...
  ; Background tiles are always loaded at tile 0
  ; Sprites are always loaded at tile 256
  ; Except the HUD tiles which are at tile 384 
  ; Title screen
  patchArtLoad $1296 TitleScreenTiles 0
  patchArtLoad $12a1 TitleScreenAnimatedFingerSprites 256
  
  ; Map 1
  patchArtLoad $0c89 MapScreen1Tiles 0
  patchArtLoad $0c94 MapScreen1Sprites 256
  patchArtLoad $0c9f HUDSprites 384

  ; Map 2
  patchArtLoad $0ceb MapScreen2_CreditsScreenTiles 0
  patchArtLoad $0cf6 MapScreen2Sprites 256
  patchArtLoad $0d01 HUDSprites 384

  ; Level done
  patchArtLoad $1411 SonicHasPassedTiles 0

  patchArtLoad $1575 HUDSprites 384
  patchArtLoad $1580 SonicHasPassedTiles 0

  ; Level loader
  patchArtLoad $2172 HUDSprites 384
  
  ; End sequence (?)
  patchArtLoad $25a9 MapScreen1Tiles 0
  
  ; Credits screen
  patchArtLoad $26ab MapScreen2_CreditsScreenTiles 0
  patchArtLoad $26b6 TitleScreenAnimatedFingerSprites 256
  
  ; End sign sprites
  patchArtLoad $5f2d EndSignSprites 256
  
  ; Bosses
  patchArtLoad $7031 BossSprites 256
  patchArtLoad $8074 BossSprites 256
  patchArtLoad $84bc BossSprites2 256
  patchArtLoad $9291 BossSprites2 256
  patchArtLoad $a816 BossSprites3 256
  patchArtLoad $bb94 BossSprites3 256
  
  ; Trapped animals sprites
  patchArtLoad $7916 TrappedAnimalsSprites 256
  
  ; Level art needs to be patched differently.
  ; The game data stores it with only offsets to bank 12.
  ; Level headers are from $155CA, 37 bytes each, not in game order.
  ; Game order comes from a table at $15580 that points into this area.
  ; Tile pointer is at +21
  ; Sprite bank is at +23
  ; Sprite pointer is at +24

; We have to set this at an absolute address because WLA DX can't figure it out on its own.
.define ArtTilesTableLocation $26000 ; Start of art data
  ROMPosition ArtTilesTableLocation 1
.section "ArtTilesTable" force  
ArtTilesTable:
  ; Data will be overwritten here by the macro below
  .dsb 36 0
SetArtBank:
  ld a,(RAM_CURRENT_LEVEL)
  push hl
    ld l,a
    ld h,0
    ld de,ArtTilesTable
    add hl,de
    ld a,(hl) ; Bank number
  pop hl
  ld de,0 ; Destination
  jp decompressArt ; continue to the patched call
.ends

.macro patchLevelHeader args levelNumber, headerOffset, tilesLabel, spritesLabel
  PatchB ArtTilesTableLocation + levelNumber,    :tilesLabel
  PatchW headerOffset + LevelHeader.LevelArt,   tilesLabel
  PatchB headerOffset + LevelHeader.SpriteBank, :spritesLabel
  PatchW headerOffset + LevelHeader.SpriteArt,  spritesLabel
.endm

  patchLevelHeader  0, $155CA, GreenHillArt,      GreenHillSprites
  patchLevelHeader  1, $155EF, GreenHillArt,      GreenHillSprites
  patchLevelHeader  2, $15614, GreenHillArt,      GreenHillSprites
  patchLevelHeader  3, $1565E, BridgeArt,         BridgeSprites
  patchLevelHeader  4, $15683, BridgeArt,         BridgeSprites
  patchLevelHeader  5, $156A8, BridgeArt,         BridgeSprites
  patchLevelHeader  6, $156CD, JungleArt,         JungleSprites
  patchLevelHeader  7, $156F2, JungleArt,         JungleSprites
  patchLevelHeader  8, $15717, JungleArt,         JungleSprites
  patchLevelHeader  9, $1573C, LabyrinthArt,      LabyrinthSprites
  patchLevelHeader 10, $15761, LabyrinthArt,      LabyrinthSprites
  patchLevelHeader 11, $15786, LabyrinthArt,      LabyrinthSprites
  patchLevelHeader 12, $157AB, ScrapBrainArt,     ScrapBrainSprites
  patchLevelHeader 13, $157D0, ScrapBrainArt,     ScrapBrainSprites
  patchLevelHeader 14, $1583F, ScrapBrainArt,     ScrapBrainSprites
  patchLevelHeader 15, $158F8, SkyBase1_2Art,     SkyBaseSprites
  patchLevelHeader 16, $1591D, SkyBase1_2Art,     SkyBaseSprites
  patchLevelHeader 17, $15942, SkyBase3Art,       SkyBaseSprites
  patchLevelHeader 18, $15639, GreenHillArt,      GreenHillSprites ; Ending sequence
  ; Index 19 unused
  patchLevelHeader 20, $157F5, ScrapBrainArt,     ScrapBrainSprites ; Scrap Brain interiors
  patchLevelHeader 21, $1581A, ScrapBrainArt,     ScrapBrainSprites
  patchLevelHeader 22, $158AE, ScrapBrainArt,     ScrapBrainSprites
  patchLevelHeader 23, $158D3, ScrapBrainArt,     ScrapBrainSprites
  patchLevelHeader 24, $15864, ScrapBrainArt,     ScrapBrainSprites
  patchLevelHeader 25, $15889, ScrapBrainArt,     ScrapBrainSprites
  patchLevelHeader 26, $15967, SkyBase3Art,       SkyBaseSprites
  ; Index 27 unused
  patchLevelHeader 28, $1598C, SpecialStagesArt, SpecialStageSprites
  patchLevelHeader 29, $159B1, SpecialStagesArt, SpecialStageSprites
  patchLevelHeader 30, $159D6, SpecialStagesArt, SpecialStageSprites
  patchLevelHeader 31, $159FB, SpecialStagesArt, SpecialStageSprites
  patchLevelHeader 32, $15A20, SpecialStagesArt, SpecialStageSprites
  patchLevelHeader 33, $15A45, SpecialStagesArt, SpecialStageSprites
  patchLevelHeader 34, $15A6A, SpecialStagesArt, SpecialStageSprites
  patchLevelHeader 35, $15A8F, SpecialStagesArt, SpecialStageSprites

; The game expects to fit all art near bank 12, and thus doesn't bother storing bank numbers for it.
; I want to change that...
  ROMPosition $225a
; Original code:
;	;load the level art from bank 12+ ($30000)
;	ld	de,$0000
;	ld	a,12
;	call	decompressArt
.section "Level art loader patch" overwrite
  ld a,:SetArtBank
  ld ($fffe),a
  call SetArtBank
  ; Exact fit
.ends

; Then we put the art data in...
.macro replaceData args offset, length, label
.unbackground offset, length
.slot 0 ; Sonic code wants to see labels as relative to the start of the bank
.section "\3" superfree
\3:
.ifdef USE_PSGCOMPR
  .incbin "\3.psgcompr"
.else
  .incbin "\3.soniccompr"
.endif  
.ends
.endm
  replaceData $26000 $2751e TitleScreenTiles
  replaceData $2751f $28293 SonicHasPassedTiles
  replaceData $28294 $28b09 EndSignSprites
  replaceData $28b0a $2926a TitleScreenAnimatedFingerSprites
  replaceData $2926b $29941 MapScreen1Sprites
  replaceData $29942 $2a129 MapScreen2Sprites
  replaceData $2a12a $2ac3c GreenHillSprites
  replaceData $2ac3d $2b7cc BridgeSprites
  replaceData $2b7cd $2c3b5 JungleSprites
  replaceData $2c3b6 $2cf74 LabyrinthSprites
  replaceData $2cf75 $2d9df ScrapBrainSprites
  replaceData $2d9e0 $2e510 SkyBaseSprites
  replaceData $2e511 $2eeb0 SpecialStageSprites
  replaceData $2eeb1 $2f92d BossSprites
  replaceData $2f92e $2fcef HUDSprites
  replaceData $30000 $31800 MapScreen1Tiles
  replaceData $31801 $32fe5 MapScreen2_CreditsScreenTiles
  replaceData $32fe6 $34577 GreenHillArt
  replaceData $34578 $35aff BridgeArt
  replaceData $35b00 $371be JungleArt
  replaceData $371bf $3884a LabyrinthArt
  replaceData $3884b $39ced ScrapBrainArt
  replaceData $39cee $3b3b4 SkyBase1_2Art
  replaceData $3b3b5 $3c7fd SkyBase3Art
  replaceData $3c7fe $3da27 SpecialStagesArt
  replaceData $3da28 $3e507 TrappedAnimalsSprites
  replaceData $3e508 $3ef3e BossSprites2
  replaceData $3ef3f $3f9ec BossSprites3
  
.ifdef USE_PSGCOMPR
; Now we replace the compression function!
.unbackground $0405 $0500
.bank 0 slot 0
.section "Art decompressor" free
decompressArt:
  ; hl = source (relative to start of bank)
  ; de = dest (write bit not set)
  ; a = bank
  ; First remember the current pages
  ld (RAM_TEMP1),a
  ld bc,($fffe)
  push bc
  push ix
    ; Select the right page
    ld a,(RAM_TEMP1)
    ld ($ffff),a
    ; We trampoline to it because it is too large to fit...
    ld a,:PSGaiden_tile_decompr
    ld ($fffe),a
    ; Make hl an absolute address for slot 2
    set 7,h
    ; And make de a write address
    set 6,d
    ; Do the decompression
    bit 1, (iy+9)
    jr nz,+
    di
      call PSGaiden_tile_decompr
    ei
    jr +
    ; No di/ei version
    call PSGaiden_tile_decompr
+:pop ix
  pop bc
  ; restore pages
  ld ($fffc),a
	res	1, (iy+9) ; game does this
  ret
  
.ends

.slot 1
.define PSGaiden_decomp_buffer $d500 ; TODO find a better place? 32B needed
.include "Phantasy_Star_Gaiden_decompressor_(fast).asm"
.else
.define decompressArt $0405 ; Original code
.export decompressArt
.endif
