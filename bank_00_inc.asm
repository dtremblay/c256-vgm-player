; page_00.asm
; Direct Page Addresses
;
;* Addresses are the byte AFTER the block. Use this to confirm block locations and check for overlaps
BANK0_BEGIN      = $000000 ;Start of bank 0 and Direct page
unused_0000      = $000000 ;12 Bytes unused
OPL2_ADDY_PTR_LO = $000008 ; This Points towards the Instruments Database
OPL2_ADDY_PTR_MD = $000009
OPL2_ADDY_PTR_HI = $00000A
SCREENBEGIN      = $00000C ;3 Bytes Start of screen in video RAM. This is the upper-left corrner of the current video page being written to. This may not be what's being displayed by VICKY. Update this if you change VICKY's display page.
COLS_VISIBLE     = $00000F ;2 Bytes Columns visible per screen line. A virtual line can be longer than displayed, up to COLS_PER_LINE long. Default = 80
COLS_PER_LINE    = $000011 ;2 Bytes Columns in memory per screen line. A virtual line can be this long. Default=128
LINES_VISIBLE    = $000013 ;2 Bytes The number of rows visible on the screen. Default=25
LINES_MAX        = $000015 ;2 Bytes The number of rows in memory for the screen. Default=64
CURSORPOS        = $000017 ;3 Bytes The next character written to the screen will be written in this location.
CURSORX          = $00001A ;2 Bytes This is where the blinking cursor sits. Do not edit this direectly. Call LOCATE to update the location and handle moving the cursor correctly.
CURSORY          = $00001C ;2 Bytes This is where the blinking cursor sits. Do not edit this direectly. Call LOCATE to update the location and handle moving the cursor correctly.
CURCOLOR         = $00001E ;1 Byte Color of next character to be printed to the screen.
COLORPOS         = $00001F ;3 Byte address of cursor's position in the color matrix
STACKBOT         = $000022 ;2 Bytes Lowest location the stack should be allowed to write to. If SP falls below this value, the runtime should generate STACK OVERFLOW error and abort.
STACKTOP         = $000024 ;2 Bytes Highest location the stack can occupy. If SP goes above this value, the runtime should generate STACK OVERFLOW error and abort.

; OPL2 Library Variable (Can be shared if Library is not used)
; This will need to move eventually
OPL2_OPERATOR    = $000026 ;
OPL2_CHANNEL     = $000027 ;
OPL2_REG_REGION  = $000028 ; Offset to the Group of Registers
OPL2_REG_OFFSET  = $00002A ; 2 Bytes (16Bits)
OPL2_IND_ADDY_LL = $00002C ; 2 Bytes Reserved (Only need 3)
OPL2_IND_ADDY_HL = $00002E ; 2 Bytes Reserved (Only need 3)
OPL2_NOTE        = $000030 ; 1 Byte
OPL2_OCTAVE      = $000031 ; 1 Byte
OPL2_PARAMETER0  = $000032 ; 1 Byte - Key On/Feedback
OPL2_PARAMETER1  = $000033 ; 1 Byte
OPL2_PARAMETER2  = $000034 ; 1 Byte
OPL2_PARAMETER3  = $000035 ; 1 Byte
OPL2_LOOP        = $000036 ;
OPL2_BLOCK       = $000036 ;

; SD Card (CH376S) Variables
SDCARD_FILE_PTR  = $000038 ; 3 Bytes Pointer to Filename to open
SDCARD_BYTE_NUM  = $00003C ; 2 Bytes
SDCARD_PRSNT_MNT = $00003F ; 1 Byte, Indicate that the SDCard is Present and that it is Mounted

; RAD File Player
RAD_STARTLINE    = $000040 ; 1 Byte
RAD_PATTERN_IDX  = $000041 ; 1 Byte
RAD_LINE         = $000042 ; 1 Byte
RAD_LINENUMBER   = $000043 ; 1 Byte
RAD_CHANNEL_NUM  = $000044 ; 1 Byte
RAD_ISLASTCHAN   = $000045 ; 1 Byte
RAD_Y_POINTER    = $000046 ; 2 Bytes
RAD_ORDER_NUM    = $000048 ; 2 Bytes
RAD_CHANNEL_DATA = $00004A ; 2 Bytes
RAD_CHANNE_EFFCT = $00004C
RAD_TEMP         = $00004E
RAD_EFFECT       = $000050

SDOS_FILE_REC_PTR= $000051 ; 3 byte pointer to a simple file struct
SDOS_LOOP        = $000054 ; variable to count file length
SDOS_FILE_SIZE   = $000055 ; 4 bytes for the file length

;Empty Region
;XXX             = $000060
; * = $60
; MIDI_COUNTER    .byte 0
; MIDI_REG        .byte 0
; MIDI_CTRL       .byte 0
; MIDI_CHANNEL    .byte 0
; MIDI_DATA1      .byte 0
; MIDI_DATA2      .byte 0
; TIMING_CNTR     .byte 0
; INSTR_ADDR      .fill 3,0
; INSTR_NUMBER    .byte $17, 0
; LINE_NUM_HEX    .byte 0
; TAB_COUNTER     .byte 1
; REM_LINES       .byte 1
; DEC_MEM         .byte 1
; PTRN_ADDR       .long 0
; LINE_ADDR       .long 0
; CONV_VAL        .byte 0

;..
;..
;..
;YYY             = $0000EE

MOUSE_PTR        = $0000E0
MOUSE_POS_X_LO   = $0000E1
MOUSE_POS_X_HI   = $0000E2
MOUSE_POS_Y_LO   = $0000E3
MOUSE_POS_Y_HI   = $0000E4



RAD_ADDR         = $0000F0 ; 3 bytes to avoid OPL2 errors.
RAD_PATTRN       = $0000F3 ; 1 bytes - offset to pattern
RAD_PTN_DEST     = $0000F4 ; 3 bytes - where to write the pattern data
RAD_CHANNEL      = $0000F7 ; 2 bytes - 0 to 8 
RAD_LAST_NOTE    = $0000F9 ; 1 if this is the last note
RAD_LINE_PTR     = $0000FA ; 2 bytes - offset to memory location

;;///////////////////////////////////////////////////////////////
;;; NO CODE or Variable ought to be Instantiated in this REGION
;; BEGIN
;;///////////////////////////////////////////////////////////////
GAVIN_BLOCK      = $000100 ;256 Bytes Gavin reserved, overlaps debugging registers at $1F0

;;///////////////////////////////////////////////////////////////
;;; NO CODE or Variable ought to be Instantiated in this REGION
;; END
;;///////////////////////////////////////////////////////////////
CPU_REGISTERS    = $000240 ; Byte
CPUPC            = $000240 ;2 Bytes Program Counter (PC)
CPUPBR           = $000242 ;2 Bytes Program Bank Register (K)
CPUA             = $000244 ;2 Bytes Accumulator (A)
CPUX             = $000246 ;2 Bytes X Register (X)
CPUY             = $000248 ;2 Bytes Y Register (Y)
CPUSTACK         = $00024A ;2 Bytes Stack Pointer (S)
CPUDP            = $00024C ;2 Bytes Direct Page Register (D)
CPUDBR           = $00024E ;1 Byte  Data Bank Register (B)
CPUFLAGS         = $00024F ;1 Byte  Flags (P)

MONITOR_VARS     = $000250 ; Byte  MONITOR Variables. BASIC variables may overlap this space
MCMDADDR         = $000250 ;3 Bytes Address of the current line of text being processed by the command parser. Can be in display memory or a variable in memory. MONITOR will parse up to MTEXTLEN characters or to a null character.
MCMP_TEXT        = $000253 ;3 Bytes Address of symbol being evaluated for COMPARE routine
MCMP_LEN         = $000256 ;2 Bytes Length of symbol being evaluated for COMPARE routine
MCMD             = $000258 ;3 Bytes Address of the current command/function string
MCMD_LEN         = $00025B ;2 Bytes Length of the current command/function string
MARG1            = $00025D ;4 Bytes First command argument. May be data or address, depending on command
MARG2            = $000261 ;4 Bytes First command argument. May be data or address, depending on command. Data is 32-bit number. Address is 24-bit address and 8-bit length.
MARG3            = $000265 ;4 Bytes First command argument. May be data or address, depending on command. Data is 32-bit number. Address is 24-bit address and 8-bit length.
MARG4            = $000269 ;4 Bytes First command argument. May be data or address, depending on command. Data is 32-bit number. Address is 24-bit address and 8-bit length.
MARG5            = $00026D ;4 Bytes First command argument. May be data or address, depending on command. Data is 32-bit number. Address is 24-bit address and 8-bit length.
MARG6            = $000271 ;4 Bytes First command argument. May be data or address, depending on command. Data is 32-bit number. Address is 24-bit address and 8-bit length.
MARG7            = $000275 ;4 Bytes First command argument. May be data or address, depending on command. Data is 32-bit number. Address is 24-bit address and 8-bit length.
MARG8            = $000279 ;4 Bytes First command argument. May be data or address, depending on command. Data is 32-bit number. Address is 24-bit address and 8-bit length.

LOADFILE_VARS    = $000300 ; Byte
LOADFILE_NAME    = $000300 ;3 Bytes (addr) Name of file to load. Address in Data Page
LOADFILE_LEN     = $000303 ;1 Byte  Length of filename. 0=Null Terminated
LOADPBR          = $000304 ;1 Byte  First Program Bank of loaded file ($05 segment)
LOADPC           = $000305 ;2 Bytes Start address of loaded file ($05 segment)
LOADDBR          = $000307 ;1 Byte  First data bank of loaded file ($06 segment)
LOADADDR         = $000308 ;2 Bytes FIrst data address of loaded file ($06 segment)
LOADFILE_TYPE    = $00030A ;3 Bytes (addr) File type string in loaded data file. Actual string data will be in Bank 1. Valid values are BIN, PRG, P16
BLOCK_LEN        = $00030D ;2 Bytes Length of block being loaded
BLOCK_ADDR       = $00030F ;2 Bytes (temp) Address of block being loaded
BLOCK_BANK       = $000311 ;1 Byte  (temp) Bank of block being loaded
BLOCK_COUNT      = $000312 ;2 Bytes (temp) Counter of bytes read as file is loaded

; $00:0320 to $00:06FF - Reserved for CH376S SDCard Controller
SDOS_LINE_SELECT = $00031F ; used by the file menu to track which item is selected (0-37)


; TODO - Fix the following - do we really need them?
SDOS_BYTE_NUMBER = $00032C ; Number of Byte to Read or Write before changing the Pointer

SDOS_BYTE_PTR    = $000334
SDOS_FILE_NAME   = $000380 ; // Max of 128 Chars for the file path

; COMMAND PARSER Variables
; Command Parser Stuff between $000F00 -> $000F84 (see CMD_Parser.asm)
KEY_BUFFER       = $000F00 ;64 Bytes keyboard buffer
KEY_BUFFER_SIZE  = $0080 ;128 Bytes (constant) keyboard buffer length
KEY_BUFFER_END   = $000F7F ;1 Byte  Last byte of keyboard buffer
KEY_BUFFER_CMD   = $000F83 ;1 Byte  Indicates the Command Process Status
COMMAND_SIZE_STR = $000F84 ; 1 Byte
COMMAND_COMP_TMP = $000F86 ; 2 Bytes
KEYBOARD_SC_FLG  = $000F87 ;1 Bytes that indicate the Status of Left Shift, Left CTRL, Left ALT, Right Shift
KEYBOARD_SC_TMP  = $000F88 ;1 Byte, Interrupt Save Scan Code while Processing



TEST_BEGIN       = $001000 ;28672 Bytes Test/diagnostic code for prototype.
TEST_END         = $007FFF ;0 Byte

STACK_BEGIN      = $008000 ;32512 Bytes The default beginning of stack space
STACK_END        = $00FEFF ;0 Byte  End of stack space. Everything below this is I/O space

ISR_BEGIN        = $38FF00 ; Byte  Beginning of CPU vectors in Direct page
HRESET           = $38FF00 ;16 Bytes Handle RESET asserted. Reboot computer and re-initialize the kernel.
HCOP             = $38FF10 ;16 Bytes Handle the COP instruction. Program use; not used by OS
HBRK             = $38FF20 ;16 Bytes Handle the BRK instruction. Returns to BASIC Ready prompt.
HABORT           = $38FF30 ;16 Bytes Handle ABORT asserted. Return to Ready prompt with an error message.
HNMI             = $38FF40 ;32 Bytes Handle NMI
HIRQ             = $38FF60 ;32 Bytes Handle IRQ
Unused_FF80      = $38FF80 ;End of direct page Interrrupt handlers

VECTORS_BEGIN    = $38FFE0 ;0 Byte  Interrupt vectors
JMP_READY        = $00FFE0 ;4 Bytes Jumps to ROM READY routine. Modified whenever alternate command interpreter is loaded.
VECTOR_COP       = $00FFE4 ;2 Bytes Native COP Interrupt vector
VECTOR_BRK       = $00FFE6 ;2 Bytes Native BRK Interrupt vector
VECTOR_ABORT     = $00FFE8 ;2 Bytes Native ABORT Interrupt vector
VECTOR_NMI       = $00FFEA ;2 Bytes Native NMI Interrupt vector
VECTOR_RESET     = $00FFEC ;2 Bytes Unused (Native RESET vector)
VECTOR_IRQ       = $00FFEE ;2 Bytes Native IRQ Vector
RETURN           = $00FFF0 ;4 Bytes RETURN key handler. Points to BASIC or MONITOR subroutine to execute when RETURN is pressed.
VECTOR_ECOP      = $00FFF4 ;2 Bytes Emulation mode interrupt handler
VECTOR_EBRK      = $00FFF6 ;2 Bytes Emulation mode interrupt handler
VECTOR_EABORT    = $00FFF8 ;2 Bytes Emulation mode interrupt handler
VECTOR_ENMI      = $00FFFA ;2 Bytes Emulation mode interrupt handler
VECTOR_ERESET    = $00FFFC ;2 Bytes Emulation mode interrupt handler
VECTOR_EIRQ      = $00FFFE ;2 Bytes Emulation mode interrupt handler
VECTORS_END      = $200000 ;*End of vector space
BANK0_END        = $00FFFF ;End of Bank 00 and Direct page
;
