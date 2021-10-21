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

.background "sonic.sms"

; Unused areas for our hacks...
.unbackground $000c $0017
.unbackground $001b $001f
.unbackground $0023 $0027
.unbackground $002b $0037
.unbackground $7fdb $7fef

; Definitions for memory and functions from the game...
.define RAM_CURRENT_LEVEL $D23E
.define decompressArt     $0405


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
; artwork is compressed using "Sonic compression".
; The decompression routine is at offset $0405.
; We are not replacing it (yet).

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
.macro patchArtLoad args offset, source, destination
  ROMPosition offset
.section "Artwork patch for \2 \@" overwrite
  ld hl, source
  ld de, destination*32
  ld a, :source
  call decompressArt
.ends
.endm

  ; We patch these...
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

  patchArtLoad $1575 HUDSprites 256
  patchArtLoad $1580 SonicHasPassedTiles 0

  ; Level loader
  patchArtLoad $2172 HUDSprites 256
  
  ; End sequence (?)
  patchArtLoad $25a9 MapScreen1Tiles 0
  
  ; Credits screen
  patchArtLoad $26ab MapScreen2_CreditsScreenTiles 0
  patchArtLoad $26b6 TitleScreenAnimatedFingerSprites 256
  
  ; End sign sprites
  patchArtLoad $5f2d EndSignSprites 128
  
  ; Bosses
  patchArtLoad $7031 BossSprites 128
  patchArtLoad $8074 BossSprites 128
  patchArtLoad $84bc BossSprites2 128
  patchArtLoad $9291 BossSprites2 128
  patchArtLoad $a816 BossSprites3 128
  patchArtLoad $bb94 BossSprites3 128
  
  ; Trapped enemies sprites
  patchArtLoad $7916 TrappedAnimalsSprites 128
  
  ; Level art needs to be patched differently.
  ; The game data stores it with only addresses, and assumes it will all be packed together in bank 12.
  ; Level headers are from $155CA, 37 bytes each.
  ; Tile pointer is at +21
  ; Sprite bank is at +23
  ; Sprite pointer is at +24
  
  
.define ArtTilesTableLocation $40000
  ROMPosition ArtTilesTableLocation 1 ; slot 1
.section "ArtTilesTable" force
ArtTilesTable:
  .dsb 33, 0 ; will overwrite later
SetArtBank:
  ld a,(RAM_CURRENT_LEVEL)
  push hl
    ld l,a
    ld h,>ArtTilesTable ; as it is 256-aligned anyway
    ld a,(hl) ; Bank number
  pop hl
  ld de,0 ; Destination
  jp decompressArt ; continue to the patched call
.ends

.macro patchLevelHeader args index, tilesLabel, spritesLabel
  PatchW ArtTilesTableLocation+index, :tilesLabel
  PatchW $155CA+index*37+21, tilesLabel
  PatchB $155CA+index*37+23, :spritesLabel
  PatchW $155CA+index*37+24, spritesLabel
.endm

  patchLevelHeader  0, GreenHillArt,      GreenHillSprites
  patchLevelHeader  1, GreenHillArt,      GreenHillSprites
  patchLevelHeader  2, GreenHillArt,      GreenHillSprites
  patchLevelHeader  3, BridgeArt,         BridgeSprites
  patchLevelHeader  4, BridgeArt,         BridgeSprites
  patchLevelHeader  5, BridgeArt,         BridgeSprites
  patchLevelHeader  6, JungleArt,         JungleSprites
  patchLevelHeader  7, JungleArt,         JungleSprites
  patchLevelHeader  8, JungleArt,         JungleSprites
  patchLevelHeader  9, LabyrinthArt,      LabyrinthSprites
  patchLevelHeader 10, LabyrinthArt,      LabyrinthSprites
  patchLevelHeader 11, LabyrinthArt,      LabyrinthSprites
  patchLevelHeader 12, ScrapBrainArt,     ScrapBrainSprites
  patchLevelHeader 13, ScrapBrainArt,     ScrapBrainSprites
  patchLevelHeader 14, ScrapBrainArt,     ScrapBrainSprites
  patchLevelHeader 15, SkyBase1_2Art,     SkyBaseSprites
  patchLevelHeader 16, SkyBase1_2Art,     SkyBaseSprites
  patchLevelHeader 17, SkyBase3Art,       SkyBaseSprites
  patchLevelHeader 18, GreenHillArt,      GreenHillSprites ; Ending sequence
  patchLevelHeader 19, ScrapBrainArt,     ScrapBrainSprites ; Scrap Brain interiors
  patchLevelHeader 20, ScrapBrainArt,     ScrapBrainSprites
  patchLevelHeader 21, ScrapBrainArt,     ScrapBrainSprites
  patchLevelHeader 22, ScrapBrainArt,     ScrapBrainSprites
  patchLevelHeader 23, ScrapBrainArt,     ScrapBrainSprites
  patchLevelHeader 24, ScrapBrainArt,     ScrapBrainSprites
  patchLevelHeader 25, SkyBase3Art,       SkyBaseSprites
  patchLevelHeader 26, SpecialStagesArt, SpecialStageSprites
  patchLevelHeader 27, SpecialStagesArt, SpecialStageSprites
  patchLevelHeader 28, SpecialStagesArt, SpecialStageSprites
  patchLevelHeader 29, SpecialStagesArt, SpecialStageSprites
  patchLevelHeader 30, SpecialStagesArt, SpecialStageSprites
  patchLevelHeader 31, SpecialStagesArt, SpecialStageSprites
  ; TODO:
  ; - More places
  ; - Resolve issue that data doesn't fit in one bank!
  ;   The game cheats. I think I should patch it to just store them sensibly.

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
.ends

; Then we put the art data in...
.macro replaceData args offset, length, label, bank
.unbackground offset, length
.if NARGS == 4
.bank bank slot 0
.section "\3" free
.else
.slot 0 ; Sonic code wants to see labels as relative to the start of the bank
.section "\3" superfree
.endif
\3:
  .incbin "\3.soniccompr"
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