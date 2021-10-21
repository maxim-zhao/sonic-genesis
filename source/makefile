WLA-Z80 = wla-z80
WLALINK = wlalink
BMP2TILE = bmp2tile
GENERATED_FILES = sonic-genesis.sms *.o *.makefile *.1bpp *.sym *.zip *.soniccompr
7Z = 7z

all: sonic-genesis.sms

# We get WLA DX to generate the dependencies list for our source
sonic-genesis.sms.makefile: sonic-genesis.sms.asm
	$(WLA-Z80) -M -o sonic-genesis.sms.o $^ > $@

include sonic-genesis.sms.makefile

# Graphics conversion
%.soniccompr: art/%.png
	 bmp2tile "$<" -noremoveduplicates -savetiles "$@"

sonic-genesis.sms.o: sonic-genesis.sms.asm
	$(WLA-Z80) -o $@ $<

sonic-genesis.sms: sonic-genesis.sms.o linkfile
	$(WLALINK) -d -r -v -S -A linkfile $@

play: sonic-genesis.sms
	cmd /c start sonic-genesis.sms

clean:
	del $(GENERATED_FILES)