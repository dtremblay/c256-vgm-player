.cpu "65816"
.include "macros_inc.asm"
.include "base.asm"
.include "bank_00_inc.asm"
.include "interrupt_def.asm"
.include "keyboard_def.asm"
.include "vicky_def.asm"
.include "kernel_inc.asm"
.include "timer_def.asm"


OPM_BASE_ADDRESS  = $AFF000
PSG_BASE_ADDRESS  = $AFF100
OPN2_BASE_ADDRESS = $AFF200
OPL3_BASE_ADRESS  = $FAE600

VGM_OFFSET        = $34
CURRENT_POSITION  = $70 ; 2 bytes
WAIT_CNTR         = $72 ; 2 bytes

* = $160000

VGM_START
            .as
            .xs
            setas
            setxl
            
            PHB
            LDA #`VGM_FILE
            PHA
            PLB
            .databank `VGM_FILE
            
            ; add the start offset
            setal
            CLC
            LDY #VGM_OFFSET
            LDA VGM_FILE,Y
            ADC #$34
            STA CURRENT_POSITION
            LDA #0
            STA WAIT_CNTR
            setas
            PLB
            
            JSR INIT_TIMER0
                
            LDA #$FF
            STA @lINT_EDGE_REG0
            STA @lINT_EDGE_REG1
            STA @lINT_EDGE_REG2
            STA @lINT_EDGE_REG3
                
            LDA #~( FNX0_INT02_TMR0 )
            STA @lINT_MASK_REG0
            LDA #$FF
            STA @lINT_MASK_REG1
            STA @lINT_MASK_REG2
            STA @lINT_MASK_REG3
            
            LDA #$15
            STA @lOPM_BASE_ADDRESS + $14
            LDA #$30
            STA @lOPM_BASE_ADDRESS + $10
            LDA #$0
            STA @lOPM_BASE_ADDRESS + $11
            ;JSR WRITE_REGISTER  ; the initial load of register should set the timerA
            CLI
            ; loop, waiting for interrupts
        LOOP
            BRA LOOP
            
            
WRITE_REGISTER
            .as
            LDX WAIT_CNTR
            CPX #0
            BEQ STORE_VALUES
            
            DEX
            STX WAIT_CNTR
            
            RTS
            
            
    STORE_VALUES
            
            PHB
            LDA #`VGM_FILE
            PHA
            PLB
            .databank `VGM_FILE
            
            ; first byte is a  command - should be $54 for YM2151
            LDY CURRENT_POSITION
    CHECK_NEXT
            LDA VGM_FILE,Y
            INY
            CMP #$54
            BNE NOT_YM2151
            
            ; the second byte is the register
            LDA #0
            XBA
            LDA VGM_FILE,Y
            TAX
            INY
            
            ; the third byte is the value to write in the register
            LDA VGM_FILE,Y
            STA @lOPM_BASE_ADDRESS,X
            INY
            BRA CHECK_NEXT
            ; wait until the register is no longer busy
            ;JSR WAIT_68CYC
            ;BRA LOAD_CMD
        
    NOT_YM2151
            CMP #$61
            BNE NOT_WAIT
            setal
            LDA VGM_FILE,Y
            TAX
            STX WAIT_CNTR
            setas
            ;JSR DISPLAY_X
            INY
            INY
            ;JSR WAIT
            ;BRA LOAD_CMD
            BRA WR_DONE
            
    NOT_WAIT
            CMP #$62
            BNE NOT_WAIT_60TH
            
            LDX #$2df
            STX WAIT_CNTR

            BRA WR_DONE
            
    NOT_WAIT_60TH
            CMP #$63
            BNE NOT_WAIT_50TH
            
            LDX #$372
            STX WAIT_CNTR

            BRA WR_DONE
            
    NOT_WAIT_50TH
            CMP #$66 ; end of song
            BNE SKIP_CMD
            
            setal
            CLC
            LDY #VGM_OFFSET
            LDA VGM_FILE,Y
            ADC #$34
            TAY
            LDA #0
            STA WAIT_CNTR
            setas
            
            BRA WR_DONE 
            
    SKIP_CMD
            INY
            INY
    WR_DONE
            STY CURRENT_POSITION
            PLB
            RTS
            
INIT_TIMER0
            .as
            PHB
            
            LDA #0
            PHA
            PLB ; set databank to 0
            
            LDA #64
            STA TIMER0_CMP_L
            LDA #1
            STA TIMER0_CMP_M
            
            LDA #0
            STA TIMER0_CMP_H
            
            
            LDA #0    ; set timer0 charge to 0
            STA TIMER0_CHARGE_L
            STA TIMER0_CHARGE_M
            STA TIMER0_CHARGE_H
            
            LDA #TMR0_CMP_RECLR  ; count up from "CHARGE" value to TIMER_CMP
            STA TIMER0_CMP_REG
            
            LDA #(TMR0_EN | TMR0_UPDWN | TMR0_SCLR)
            STA TIMER0_CTRL_REG
            
            LDA #~( FNX0_INT02_TMR0 )
            STA @lINT_MASK_REG0
            
            PLB
            RTS

.include "interrupt_handler.asm"
        
VGM_FILE
;.binary "04 Kalinka.vgm"
;.binary "peddler.vgm"
.binary "troika.vgm"
;.binary "test.vgm"