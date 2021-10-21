import struct
import sys
import png

def dump_tiles(rom, offset, filename, palette_offset = None, png_filename = None):
    with open(rom, "rb") as f:
        f.seek(offset)
        # We read a 32KB chunk to make things easier
        data = f.read(32*1024)
        if palette_offset is not None:
            f.seek(palette_offset)
            palette = f.read(32)
    # Read the header
    (magic, duplicate_rows_offset, art_data_offset, row_count) = struct.unpack("HHHH", data[0:8])
    # Check the header marker
    if magic != 0x5948:
        raise Exception(f"Invalid header marker: {magic}")
    tile_count = row_count // 8
    # Then we read each byte in turn
    # Each is a bitmask for 8 rows, right to left (LSB is top row)
    # If 0, we consume the next 4 bytes from the "art data"
    # If 1, we consume one or two bytes from the "duplicate rows" data and that is an index into the "art data" (byte offset / 4)
    bitstream_offset = 8 # after header
    art_data_current_offset = art_data_offset
    buffer = bytearray()
    raw_row_count = 0
    duplicated_row_count = 0
    for tile_index in range(tile_count):
        # Read a byte for this tile
        byte = data[bitstream_offset]
        bitstream_offset += 1
        # 903 1 bits and 1145 0 bits, does not match?!?
        for bit_index in range(8):
            if (byte & 0x1) == 0:
                # New art data
                buffer.extend(data[art_data_current_offset:art_data_current_offset+4])
                art_data_current_offset += 4
                raw_row_count += 1
            else:
                # Repeated art data
                duplicate_index = data[duplicate_rows_offset]
                duplicate_rows_offset += 1
                if duplicate_index >= 0xf0:
                    # Two-byte index
                    duplicate_index &= 0x0f;
                    duplicate_index <<= 8;
                    duplicate_index |= data[duplicate_rows_offset]
                    duplicate_rows_offset += 1
                position = art_data_offset + duplicate_index * 4
                buffer.extend(data[position:position+4])
                duplicated_row_count += 1
            # Shift the byte
            byte = byte >> 1
    # Finally save to a file
    if filename is not None:
        with open(filename, "wb") as f:
            f.write(buffer)

    compressed_size = max(art_data_current_offset, duplicate_rows_offset)
    print(f"Range ${offset:0>5x} ${offset+compressed_size-1:0>5x} ; {filename} ; Decompressed {len(buffer)} bytes of graphics data from {compressed_size} bytes of data, {raw_row_count} raw rows and {duplicated_row_count} duplicated")
    
    # Now convert to PNG (!)
    if png_filename is not None:
        with open(png_filename, "wb") as f:
            # Convert palette to RGB triplets
            palette = [colourSMSToRGB(b) for b in palette]
            # Convert data to a 2D image of pixels
            # We need to convert planar to chunky...
            image = planarToChunky(buffer)
            # Then we convert it to 2D
            image = tilesToRect(image, 128)
            w = png.Writer(len(image[0]), len(image), bitdepth=4, palette=palette)
            w.write(f, image);

def tilesToRect(buffer, width):
    # We want to copy the data from an 8xn form to a (width*8)x(n/8) form
    # Each input row is 8 bytes, we want to glue them together to make the width
    num_bytes = len(buffer)
    num_input_rows = num_bytes // 8
    num_tiles = num_input_rows // 8
    num_output_rows = num_input_rows // (width // 8)
    # Make the output list of lists
    result = [[] for _ in range(num_output_rows)]
    # Copy one tile at a time
    for tile_index in range(num_tiles):
        # Compute offset of tile in source
        source_index = tile_index * 64
        # And x, y in dest
        x = (tile_index * 8) % width
        y = (tile_index * 8) // width * 8
        #print(f"Tile {tile_index} is at {x},{y}")
        # And copy
        for row in range(8):
            # Copy 8px
            #print(f"Copy 8 bytes from {source_index} to row {y} column {x}")
            result[y][x:x+8] = buffer[source_index:source_index+8]
            y += 1
            source_index += 8
    return result

def planarToChunky(buffer):
    result = bytearray()
    chunk_size = 4 # 4 bitplanes
    data = [buffer[i:i+chunk_size] for i in range(0, len(buffer), chunk_size)]
    # Each chunk is one row of pixels.
    # The first byte is bit 0 for each pixel, and so on.
    for chunk in data:
        for bit in range(8):
            index = 0
            for byte in chunk:
                # Reduce to the bit we want
                byte >>= 7 - bit
                byte &= 1
                # Shift into the result
                index >>= 1
                index |= (byte << 3)
            result.append(index)
    return result

def colourSMSToRGB(b):
    return [extendColour((b>>0)&0b11), extendColour((b>>2)&0b11), extendColour((b>>4)&0b11)]

def extendColour(b):
    b |= b << 2
    b |= b << 4
    return b

def dump_all_tiles(rom):
    locations = [
        { 'offset': 0x26000, 'palette': 0x13e1, 'description': "TitleScreenTiles"},
        { 'offset': 0x2751F, 'palette': 0x1b8d, 'description': "SonicHasPassedTiles"},
        { 'offset': 0x28294, 'palette': 0x626c, 'description': "EndSignSprites"},
        { 'offset': 0x28B0A, 'palette': 0x13f1, 'description': "TitleScreenAnimatedFingerSprites"},
        { 'offset': 0x2926B, 'palette': 0x62ae, 'description': "MapScreen1Sprites"},
        { 'offset': 0x29942, 'palette': 0x62ae, 'description': "MapScreen2Sprites"},
        { 'offset': 0x2A12A, 'palette': 0x62ae, 'description': "GreenHillSprites"},
        { 'offset': 0x2AC3D, 'palette': 0x62fe, 'description': "BridgeSprites"},
        { 'offset': 0x2B7CD, 'palette': 0x634e, 'description': "JungleSprites"},
        { 'offset': 0x2C3B6, 'palette': 0x639e, 'description': "LabyrinthSprites"},
        { 'offset': 0x2CF75, 'palette': 0x63ee, 'description': "ScrapBrainSprites"},
        { 'offset': 0x2D9E0, 'palette': 0x644e, 'description': "SkyBaseSprites"},
        { 'offset': 0x2E511, 'palette': 0x656e, 'description': "SpecialStageSprites"},
        { 'offset': 0x2EEB1, 'palette': 0x731C, 'description': "BossSprites"},
        { 'offset': 0x2F92E, 'palette': 0x62ae, 'description': "HUDSprites"},
        { 'offset': 0x30000, 'palette': 0x0f0e, 'description': "MapScreen1Tiles"},
        { 'offset': 0x31801, 'palette': 0x0f2e, 'description': "MapScreen2_CreditsScreenTiles"},
        { 'offset': 0x32FE6, 'palette': 0x629e, 'description': "GreenHillArt"},
        { 'offset': 0x34578, 'palette': 0x62ee, 'description': "BridgeArt"},
        { 'offset': 0x35B00, 'palette': 0x633e, 'description': "JungleArt"},
        { 'offset': 0x371BF, 'palette': 0x638e, 'description': "LabyrinthArt"},
        { 'offset': 0x3884B, 'palette': 0x63de, 'description': "ScrapBrainArt"},
        { 'offset': 0x39CEE, 'palette': 0x643e, 'description': "SkyBase1_2Art"},
        { 'offset': 0x3B3B5, 'palette': 0x658e, 'description': "SkyBase3Art"},
        { 'offset': 0x3C7FE, 'palette': 0x655e, 'description': "SpecialStagesArt"},
        { 'offset': 0x3da28, 'palette': 0x626c, 'description': "TrappedAnimalsSprites"},
        { 'offset': 0x3e508, 'palette': 0x731C, 'description': "BossSprites2"},
        { 'offset': 0x3ef3f, 'palette': 0x731C, 'description': "BossSprites3"},
    ]
    for location in locations:
        dump_tiles(rom, location['offset'], None, location['palette'], f"art/{location['description']}.png")

def main():
    verb = sys.argv[1]
    if verb == 'dump_tiles':
        dump_tiles(sys.argv[2], int(sys.argv[3], 0), sys.argv[4])
    elif verb == 'dump_all_tiles':
        dump_all_tiles(sys.argv[2])
    else:
        raise Exception(f"Unknown verb \"{verb}\"")


if __name__ == "__main__":
    main()
