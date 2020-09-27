; File Descriptor -- Used as parameter for higher level DOS functions
FILEDESC            .struct
STATUS              .byte ?             ; The status flags of the file descriptor (open, closed, error, EOF, etc.)
DEV                 .byte ?             ; The ID of the device holding the file
PATH                .dword ?            ; Pointer to a NULL terminated path string
CLUSTER             .dword ?            ; The current cluster of the file.
FIRST_CLUSTER       .dword ?            ; The ID of the first cluster in the file
BUFFER              .dword ?            ; Pointer to a cluster-sized buffer
SIZE                .dword ?            ; The size of the file
CREATE_DATE         .word ?             ; The creation date of the file
CREATE_TIME         .word ?             ; The creation time of the file
MODIFIED_DATE       .word ?             ; The modification date of the file
MODIFIED_TIME       .word ?             ; The modification time of the file
RESERVED            .word ?             ; Two reserved bytes to bring the descriptor up to 32 bytes
                    .ends

; File descriptor status flags

FD_STAT_READ = $01                      ; The file is readable
FD_STAT_WRITE = $02                     ; The file is writable
FD_STAT_ALLOC = $10                     ; The file descriptor has been allocated
FD_STAT_OPEN = $38                      ; The file is open
FD_STAT_ERROR = $40                     ; The file is in an error condition
FD_STAT_EOF = $80                       ; The file cursor is at the end of the file


BIOS_DEV_FDC = 0                ; Floppy 0
BIOS_DEV_FD1 = 1                ; Future support: Floppy 1 (not likely to be attached)
BIOS_DEV_SD  = 2                ; SD card, partition 0
BIOS_DEV_SD1 = 3                ; Future support: SD card, partition 1
BIOS_DEV_SD2 = 4                ; Future support: SD card, partition 2
BIOS_DEV_SD3 = 5                ; Future support: SD card, partition 3
BIOS_DEV_HD0 = 6                ; Future support: IDE Drive 0, partition 0
BIOS_DEV_HD1 = 7                ; Future support: IDE Drive 0, partition 1
BIOS_DEV_HD2 = 8                ; Future support: IDE Drive 0, partition 2
BIOS_DEV_HD3 = 9                ; Future support: IDE Drive 0, partition 3