# c256-vgm-player
Video Game Music Player for C256 Foenix

Starting to support the VGM format as described here: (https://www.smspower.org/uploads/Music/vgmspec170.txt)

The C256 Foenix has multiple sound chips:
- YM262 (OPL3) (which can also play OPL2 files)
- SN76489 (PSG)
- YM2612 (OPN2)
- YM2151 (OPM)

This application maps the addresses of the chips such that songs can be played.  Right now, the songs are "backed into" the executable.  
Eventually, we'll be able to load files from SD Card or floppy disk or IDE disk drive.

I'm hoping that this may get included in the C256 Foenix kernel, such that we can type "play song.vgm".

Also to be added (maybe) is gzip decompression for vgz files.
