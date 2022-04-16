# Mr. V. S. F. Unfreeze
https://github.com/c1570/MrVSFUnfreeze

These scripts allow to convert a [VICE](https://vice-emu.sourceforge.io/) VSF snapshot file to a C64 cartridge (CRT) file.
While the cartridge content gets copied to the C64's RAM, the user can look at nice graphics supplied as a Koala file at build time.

MVU uses the [Magic Desk](https://codebase64.org/doku.php?id=base:crt_file_format#magic_desk_domark_hes_australia) (19) cartridge type.
Hardware for it is readily available (e.g., [c64-magic-desk-512k](https://github.com/msolajic/c64-magic-desk-512k)).

For crunching, MVU uses [LZSA1](https://github.com/emmanuel-marty/lzsa) and 6502 decompressor code by John Brandwood.

The VSF unfreeze code is a modified version of [VSFReanimator](https://sourceforge.net/p/viceplus/code/HEAD/tree/trunk/tools/vsfReanimator/).

For building your own cartridge, you will need to adjust sources (file segments, compression, helper starting offset).
The comments available in the files might help a bit with that.
