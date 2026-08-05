   10 REM QTM v1.49 ARM2 auto-unrolling dma interface
   20 REM
   30 REM LEN Steve Harrison 1993-2023
   40 END
   50 
   60 DEF FNassm_dma
   70 [OPT opt%
   80 
   90 ; on entry:
  100 ;          R0          \  sample end address            - sample end address
  110 ;          R1           } -ve sample offset             - -ve sample offset
  120 ;          R2           } (amiga type) pitch            - sample pitch increment (Arc)
  130 ;          R3           } linear volume (0-64)          - sample volume (0-255)
  140 ;          R4           } -ve repeat offset             - -ve repeat offset
  150 ;          R5          /                                - load/store sample byte
  160 ;          R6      -ve if channel handler changed       - channel counter (0->channel-1)
  170 ;          R7      <unknown>                            -
  180 ;          R8      uS <? - unknown>                     - ptr to 'DMA_blocks'
  190 ;          R9      ptr to initblock                     - ptr to 'song_data' (usually R12)
  200 ;          R10     DMA end                              - DMA end
  210 ;          R11     DMA gap                              - DMA gap
  220 ;          R12     DMA start                            - DMA ptr
  230 ;          R13     stack                                - stack
  240 ;          R14     exit                                 - end
  250 
  260 .a3_DMAsound
  270 STMFD   R13!,{R14}
  280 SUB     R9,R9,#QTMblock         ;R9=start of QTM vars block (R12 usually)
  290 STR     R12,[R9,#DMABuffer]
  300 :
  310 LDRB    R0,[R9,#armchip]
  320 CMP     R0,#3                   ;* cache detection only works on Arm 3  *
  330 FNmrc("EQ","CP15,0,R0,C2,C0")   ;* read Arm3 control state (cache etc.) *
  340 TSTLE   R0,#%1                  ;* and so no need to worry about 32-bitting Arm2 code ;) *
  350 BEQ     a2_DMAsnd_in
  360 :
  370 LDRB    R0,[R9,#soundflags]
  380 TST     R0,#%1<<3               ;are we manually calculating the clock speed (pre-A5000 only)?
  390 BLNE    checkclockcalc
  400 :
  410 ]:IF qtmrast% THEN
  420  [OPT opt%
  430  LDRB    R0,[R9,#rm_dmainprogress];
  440  TEQ     R0,#0                  ;
  450  LDMNEFD R13!,{PC}              ;* v1.45se RasterMan - quit if DMA alread in progress (reentrant)
  460  MOV     R0,#1                  ;
  470  STRB    R0,[R9,#rm_dmainprogress];
  480  :                              ;
  490  MOV     R12,R9                 ;* v1.43se RasterMan special release (2013)
  500  LDRB    R0,[R9,#songstatus]    ;* are we playing the song?
  510  TST     R0,#%1<<2              ;*
  520  BLNE    CIAhandler             ;* if so, sort the music first
  530  :                              ;*
  540  LDRB    R0,[R9,#vustate]       ;* 1.43se_a 27/5/13
  550  CMP     R0,#0                  ;*
  560  MOVNE   R0,#4                  ;*
  570  BLNE    VUcontroller           ;*
  580  LDR     R12,[R9,#DMABuffer]    ;* v1.45se reload R12
  590  ]
  600 ENDIF
  610 [OPT opt%
  620 :
  630 ADD     R8,R9,#(DMA_blocks-song_data)
  640 MOVS    R6,#0                   ;put channel count as 0
  650 LDRB    R5,[R9,#chans_use]
  660 LDR     R4,[R9,#chanendflags]
  670 :
  680 .a3_DMAchannels
  690 BL      a3_chanctrl
  700 STR     R1,[R8,#DMA_offset]     ;a3_chanend may skip this on return from a3_chanctrl
  710 .a3_DMAnextchan
  720 MOV     R4,R4,LSR#2
  730 ADD     R8,R8,#24
  740 ADD     R12,R12,#1
  750 ADD     R6,R6,#1
  760 CMP     R6,R5
  770 BNE     a3_DMAchannels
  780 ]:IF qtmrast% THEN [OPT opt%:MOV R0,#0:STRB R0,[R9,#rm_dmainprogress]:]
  790 [OPT opt%
  800 LDMFD   R13!,{PC}
  810 
  820 
  830 .a3_chanctrl                    ;r6=channel number
  840 STMFD   R13!,{R4-R6,R12,R14}    ;
  850 LDMIA   R8,{R0-R5}              ;r0=end addr r1=-ve offset r2=pitch r3=vol/flag r4=raddr r5=rlen
  860 CMN     R1,#4096                ;is offset >-4096? (ie. offset>>12 <1)?   (remember -ve!)
  870 MOVGT   R7,#3                   ; <put min loop len in r7>
  880 CMPGT   R7,R5                   ; <backwards!!! this does CMP 3,len so LE if valid!!!)
  890 BGT     a3_chanend              ;if offset>-4096 and 3>repeat len, then exit
  900 :
  910 CMP     R0,#0                   ;v1.45 fixed huge bug, can't believe addr=0 worked for so long!
  920 CMPNE   R2,#0
  930 BLE     a3_chanend
  940 :
  950 .a3_chanrunning
  960 MOVS    R3,R3,LSL#24                    ;if DMA_sampleflag set, CS because &FF shifted off
  970 ADDCC   R7,R9,#(musicvoltable-song_data)
  980 ADDCS   R7,R9,#(samplevoltable-song_data)
  990 LDRB    R3,[R7,R3,LSR#24]               ;load Arc scaled volume
 1000 :
 1010 CMP     R2,#1024                        ;
 1020 ADDLT   R7,R9,#(arcperiods-song_data)
 1030 LDRLT   R2,[R7,R2,LSL#2]                ;load Arc pitch increment
 1040 BLGE    amigatoarcpitch_1024            ;for high periods, use calculation - returns r2=arc pitch
 1050 :
 1060 MOV     R7,#%11                 ;testing flags...
 1070                                 ;** R6 STILL has channel number in it!!! **
 1080 MOV     R6,R6,LSL#1             ;channel * 2 (2 flags per channel!)
 1090 MOV     R7,R7,LSLR6             ;shift flags << (channel*2)
 1100 LDR     R6,[R9,#chanendflags]   ;load current channel ending flags
 1110 TST     R6,R7                   ;are either of the 'ending/ended' bits set?
 1120 BICNE   R6,R6,R7                ;if so, clear them, cos this channel IS running!
 1130 STRNE   R6,[R9,#chanendflags]   ;...and store them
 1140 :
 1150 LDRB    R6,[R9,#actual_dma]     ;v1.45 load the actual DMA size set by Sound_Configure
 1160 MOV     R6,R6,LSL#4             ;...because we don't know what DMA size might be on RPi etc...
 1170 MLAS    R6,R2,R6,R1             ;...mul to get ptr to offset at end of fill (10 cycles vs 3 prev)
 1180 BLT     a3_not_ending           ;if still<0 then we haven't ended/looped, so don't check
 1190 :
 1200 ; CMP R5,#3
 1210 ; BGE a2_repeating -> a2 checks for repeating here
 1220 ;
 1230 :
 1240 CMP     R3,#254                 ;if volume is too low
 1250 BGE     a3_endnovol             ;go to clear the channel...
 1260 CMP     R3,#0                   ;
 1270 BEQ     a3_endfullvol           ;if vol is max. use max. vol fill routines
 1280 :
 1290 .a3_endanyvol                   ;*** sample HAS TO end/repeat this TIME  ***
 1300 LDRB    R6,[R0,R1,ASR#12]       ;*** so we DON'T have to check to see if ***
 1310 SUBS    R6,R6,R3                ;*** DMA ends - sample MUST end first!!! ***
 1320 MOVMI   R6,#0                   ;
 1330 STRB    R6,[R12],R11            ;
 1340 ADDS    R1,R1,R2                ;have we ended (offset becomes GE)?
 1350 BLT     a3_endanyvol            ;if not... loop back
 1360 :
 1370 CMP     R5,#2                   ;
 1380 BGT     a3_repanyvol            ;are we looping this time? - if so, lets go!
 1390 :
 1400 MOV     R6,#0                   ;
 1410 .a3_endclear                    ;
 1420 STRB    R6,[R12],R11            ;
 1430 CMP     R12,R10                 ;
 1440 STRLTB  R6,[R12],R11            ;
 1450 CMPLT   R12,R10                 ;
 1460 STRLTB  R6,[R12],R11            ;
 1470 CMPLT   R12,R10                 ;
 1480 STRLTB  R6,[R12],R11            ;
 1490 CMPLT   R12,R10                 ;only using 4 blankings per loop...
 1500 BLT     a3_endclear             ;...cleared rest of channel
 1510 LDMFD   R13!,{R4-R6,R12,PC}     ;exit
 1520 
 1530 
 1540 .a3_endfullvol                  ;*** sample HAS to end/repeat this time  ***
 1550 LDRB    R6,[R0,R1,ASR#12]       ;*** so we DON'T have to check to see if ***
 1560 STRB    R6,[R12],R11            ;*** DMA ends - sample MUST end first!!! ***
 1570 ADDS    R1,R1,R2                ;have we ended (offset becomes GE)?
 1580 LDRLTB  R6,[R0,R1,ASR#12]
 1590 STRLTB  R6,[R12],R11
 1600 ADDLTS  R1,R1,R2
 1610 BGE     a3_endedfv
 1620 LDRB    R6,[R0,R1,ASR#12]
 1630 STRB    R6,[R12],R11
 1640 ADDS    R1,R1,R2
 1650 LDRLTB  R6,[R0,R1,ASR#12]
 1660 STRLTB  R6,[R12],R11
 1670 ADDLTS  R1,R1,R2                ;only using 4 stores per loop...
 1680 BLT     a3_endfullvol           ;if not... loop back
 1690 :
 1700 .a3_endedfv
 1710 CMP     R5,#2                   ;
 1720 BGT     a3_repfullvol           ;are we looping this time? - if so, lets go!
 1730 :
 1740 MOV     R6,#0                   ;
 1750 .a3_endfvclear                  ;
 1760 STRB    R6,[R12],R11            ;
 1770 CMP     R12,R10                 ;
 1780 STRLTB  R6,[R12],R11            ;
 1790 CMPLT   R12,R10                 ;
 1800 STRLTB  R6,[R12],R11            ;
 1810 CMPLT   R12,R10                 ;
 1820 STRLTB  R6,[R12],R11            ;
 1830 CMPLT   R12,R10                 ;only using 4 blankings per loop...
 1840 BLT     a3_endfvclear           ;...cleared rest of channel
 1850 LDMFD   R13!,{R4-R6,R12,PC}     ;exit
 1860 
 1870 
 1880 .a3_endnovol
 1890 CMP     R5,#2
 1900 BGT     a3_repnovol
 1910 BL      a3_clearchannel
 1920 MOV     R1,#0                   ;set offset to 0, so it will call 'chanend' next time
 1930 LDMFD   R13!,{R4-R6,R12,PC}
 1940 
 1950 
 1960 .a3_repanyvol                   ;** NEW repeat handler **
 1970 SUB     R1,R1,R5,LSL#12         ;ready to repeat... set offset back to repeat start...
 1980 .a3_repavloop                   ;
 1990 LDRB    R6,[R4,R1,ASR#12]       ;** remember to use REPEAT end address **
 2000 SUBS    R6,R6,R3                ;
 2010 MOVMI   R6,#0                   ;
 2020 STRB    R6,[R12],R11            ;
 2030 ADDS    R1,R1,R2                ;finished repeat?
 2040 :
 2050 CMPLT   R12,R10                 ;if NOT finished, then check DMA end...
 2060 BLT     a3_repavloop            ;if DMA ok and still repeating, then loop back
 2070 TST     R1,#%1<<31              ;was it sample that ended? (this WON'T alter C flag)
 2080 SUBEQ   R1,R1,R5,LSL#12         ;...if so, get back to repeat start
 2090 CMP     R12,R10                 ;(could both end at same time as well!)
 2100 BLT     a3_repavloop            ;if C is clear (& DMA not finished) then loop back...
 2110 STR     R4,[R8,#DMA_address]    ;store repeat address as DMA address now!
 2120 LDMFD   R13!,{R4-R6,R12,PC}
 2130 
 2140 
 2150 .a3_repfullvol
 2160 SUB     R1,R1,R5,LSL#12         ;ready to repeat... set offset back to repeat start...
 2170 .a3_repfvloop                   ;
 2180 LDRB    R6,[R4,R1,ASR#12]
 2190 STRB    R6,[R12],R11
 2200 ADDS    R1,R1,R2
 2210 :
 2220 CMPLT   R12,R10
 2230 BLT     a3_repfvloop
 2240 TST     R1,#%1<<31              ;was it sample that ended? (this WON'T alter C flag)
 2250 SUBEQ   R1,R1,R5,LSL#12         ;...if so, get back to repeat start
 2260 CMP     R12,R10
 2270 BLT     a3_repfvloop            ;if C is clear (ie. DMA not finished) then loop back...
 2280 STR     R4,[R8,#DMA_address]    ;store repeat address as DMA address now!
 2290 LDMFD   R13!,{R4-R6,R12,PC}
 2300 
 2310 
 2320 .a3_repnovol
 2330 MOV     R6,#0
 2340 .a3_repnovolloop
 2350 STRB    R6,[R12],R11
 2360 ADDS    R1,R1,R2
 2370 CMPLT   R12,R10
 2380 STRLTB  R6,[R12],R11
 2390 ADDLTS  R1,R1,R2
 2400 :
 2410 CMPLT   R12,R10
 2420 BLT     a3_repnovolloop
 2430 TST     R1,#%1<<31              ;was it sample that ended? (this WON'T alter C flag)
 2440 SUBEQ   R1,R1,R5,LSL#12         ;...if so, get back to repeat start
 2450 CMP     R12,R10
 2460 BLT     a3_repnovolloop         ;if C is clear (ie. DMA not finished) then loop back...
 2470 STR     R4,[R8,#DMA_address]    ;store repeat address as DMA address now!
 2480 LDMFD   R13!,{R4-R6,R12,PC}
 2490 
 2500 
 2510 .a3_clearchannel
 2520 STMFD   R13!,{R6}
 2530 MOV     R6,#0
 2540 .a3_clearing
 2550 STRB    R6,[R12],R11
 2560 STRB    R6,[R12],R11
 2570 STRB    R6,[R12],R11
 2580 STRB    R6,[R12],R11
 2590 STRB    R6,[R12],R11
 2600 STRB    R6,[R12],R11
 2610 STRB    R6,[R12],R11
 2620 STRB    R6,[R12],R11            ;do 8
 2630 STRB    R6,[R12],R11
 2640 STRB    R6,[R12],R11
 2650 STRB    R6,[R12],R11
 2660 STRB    R6,[R12],R11
 2670 STRB    R6,[R12],R11
 2680 STRB    R6,[R12],R11
 2690 STRB    R6,[R12],R11
 2700 STRB    R6,[R12],R11            ;do 16
 2710 CMP     R12,R10
 2720 BLT     a3_clearing
 2730 LDMFD   R13!,{R6}
 2740 MOV     PC,R14
 2750 
 2760 
 2770 .a3_not_ending                  ;on entry r5 = end offset
 2780 CMP     R3,#254                 ;volume too low?
 2790 MOVGE   R1,R6                   ;yup, so put end offset in offset reg...
 2800 BLGE    a3_clearchannel         ;...and clear the channel!
 2810 LDMGEFD R13!,{R4-R6,R12,PC}     ;...then exit
 2820 :
 2830 CMP     R3,#0                   ;
 2840 BEQ     a3_fullvolume           ;max. vol, so use max. routines
 2850 :
 2860 .a3_anyvolume
 2870 LDRB    R6,[R0,R1,ASR#12]
 2880 SUBS    R6,R6,R3
 2890 MOVMI   R6,#0
 2900 STRB    R6,[R12],R11            ;store 1
 2910 ADD     R1,R1,R2
 2920 LDRB    R6,[R0,R1,ASR#12]
 2930 SUBS    R6,R6,R3
 2940 MOVMI   R6,#0
 2950 STRB    R6,[R12],R11            ;store 2
 2960 ADD     R1,R1,R2
 2970 LDRB    R6,[R0,R1,ASR#12]
 2980 SUBS    R6,R6,R3
 2990 MOVMI   R6,#0
 3000 STRB    R6,[R12],R11            ;store 3
 3010 ADD     R1,R1,R2
 3020 LDRB    R6,[R0,R1,ASR#12]
 3030 SUBS    R6,R6,R3
 3040 MOVMI   R6,#0
 3050 STRB    R6,[R12],R11            ;store 4
 3060 ADD     R1,R1,R2
 3070 LDRB    R6,[R0,R1,ASR#12]
 3080 SUBS    R6,R6,R3
 3090 MOVMI   R6,#0
 3100 STRB    R6,[R12],R11            ;store 5
 3110 ADD     R1,R1,R2
 3120 LDRB    R6,[R0,R1,ASR#12]
 3130 SUBS    R6,R6,R3
 3140 MOVMI   R6,#0
 3150 STRB    R6,[R12],R11            ;store 6
 3160 ADD     R1,R1,R2
 3170 LDRB    R6,[R0,R1,ASR#12]
 3180 SUBS    R6,R6,R3
 3190 MOVMI   R6,#0
 3200 STRB    R6,[R12],R11            ;store 7
 3210 ADD     R1,R1,R2
 3220 LDRB    R6,[R0,R1,ASR#12]
 3230 SUBS    R6,R6,R3
 3240 MOVMI   R6,#0
 3250 STRB    R6,[R12],R11            ;store 8
 3260 ADD     R1,R1,R2
 3270 CMP     R12,R10
 3280 BLT     a3_anyvolume
 3290 LDMFD   R13!,{R4-R6,R12,PC}
 3300 
 3310 
 3320 .a3_fullvolume
 3330 LDRB    R6,[R0,R1,ASR#12]
 3340 STRB    R6,[R12],R11            ;1
 3350 ADD     R1,R1,R2
 3360 LDRB    R6,[R0,R1,ASR#12]
 3370 STRB    R6,[R12],R11            ;2
 3380 ADD     R1,R1,R2
 3390 LDRB    R6,[R0,R1,ASR#12]
 3400 STRB    R6,[R12],R11            ;3
 3410 ADD     R1,R1,R2
 3420 LDRB    R6,[R0,R1,ASR#12]
 3430 STRB    R6,[R12],R11            ;4
 3440 ADD     R1,R1,R2
 3450 LDRB    R6,[R0,R1,ASR#12]
 3460 STRB    R6,[R12],R11            ;5
 3470 ADD     R1,R1,R2
 3480 LDRB    R6,[R0,R1,ASR#12]
 3490 STRB    R6,[R12],R11            ;6
 3500 ADD     R1,R1,R2
 3510 LDRB    R6,[R0,R1,ASR#12]
 3520 STRB    R6,[R12],R11            ;7
 3530 ADD     R1,R1,R2
 3540 LDRB    R6,[R0,R1,ASR#12]
 3550 STRB    R6,[R12],R11            ;8
 3560 ADD     R1,R1,R2
 3570 CMP     R12,R10
 3580 BLT     a3_fullvolume
 3590 LDMFD   R13!,{R4-R6,R12,PC}
 3600 
 3610 
 3620 ; channel ending flags:
 3630 ;                       %11 per channel (should be CLEAR when playing the sample)
 3640 ;                       /  \
 3650 ;   cleared DMA buffer 1    cleared DMA buffer 2 (so sample has REALLY finished - exit)
 3660 
 3670 
 3680 .a3_chanend
 3690 LDR     R4,[R13,#0]             ;load channel end flags (r4)
 3700 MOVS    R4,R4,LSR#1             ;shift off the first bit (REALLY ended test)
 3710 LDMCSFD R13!,{R4-R6,R12,R14}    ;if it had 'REALLY ended' then reload (inc. r4) and exit
 3720 ADDCS   PC,R14,#4               ;Skip STR R1,[R8,#DMA_offset] instruction
 3730 :
 3740 BL      a3_clearchannel         ;clear this DMA buffer
 3750 :
 3760 LDR     R6,[R13,#8]             ;load current channel (-1)
 3770 MOV     R6,R6,LSL#1             ;channel*2
 3780 MOVS    R4,R4,LSR#1             ;test 2nd bit of channel end flags
 3790 LDR     R4,[R9,#chanendflags]   ;(+load FULL current flags word, for alteration)
 3800 MOVCC   R5,#%10                 ;if 2nd bit was clear, then channel has JUST ended
 3810 MOVCS   R5,#%01                 ;if 2nd bit was set, then it ended 1 DMA fill ago (ie.done)
 3820 ORR     R4,R4,R5,LSLR6          ;set altered flags in flag word
 3830 STR     R4,[R9,#chanendflags]   ;store flag word
 3840 LDMFD   R13!,{R4-R6,R12,PC}     ;reload+exit WITHOUT C flag set (so new offset is stored)
 3850 
 3860 
 3870 ;
 3880 ;
 3890 ;
 3900 ;
 3910 
 3920 
 3930 .a3_TRNSsound
 3940 STMFD   R13!,{R9,R14}
 3950 SUB     R9,R9,#QTMblock         ;R9=start of QTM vars block (R12 usually)
 3960 STR     R12,[R9,#DMABuffer]
 3970 :
 3980 LDRB    R0,[R9,#armchip]
 3990 CMP     R0,#3                   ;* cache detection only works on Arm 3 *
 4000 FNmrc("EQ","CP15,0,R0,C2,C0")   ;read Arm3 control state (cache etc.)
 4010 TSTEQ   R0,#%1
 4020 BEQ     a2_TRNSsnd_in
 4030 :
 4040 LDR     R9,[R9,#oldConfigure+12];transparent sound...!
 4050 MOV     R14,PC                  ;
 4060 LDR     PC,[R9,#0]              ;go... and then back to QTM...
 4070 :
 4080 LDMFD   R13!,{R9}               ;v1.49 replace FNlong_adr("  ",9,song_data)
 4090 SUB     R9,R9,#QTMblock         ;R9=start of QTM vars block (R12 usually)
 4100 LDRB    R0,[R9,#soundflags]
 4110 TST     R0,#%1<<3
 4120 BLNE    checkclockcalc
 4130 :
 4140 ]:IF qtmrast% THEN
 4150  [OPT opt%
 4160  LDRB    R0,[R9,#rm_dmainprogress];
 4170  TEQ     R0,#0                  ;
 4180  LDMNEFD R13!,{PC}              ;* v1.45se RasterMan - quit if DMA alread in progress (reentrant)
 4190  MOV     R0,#1                  ;
 4200  STRB    R0,[R9,#rm_dmainprogress];
 4210  :                              ;
 4220  MOV     R12,R9                 ;* v1.43se RasterMan special release (2013)
 4230  LDRB    R0,[R9,#songstatus]    ;* are we playing the song?
 4240  TST     R0,#%1<<2              ;*
 4250  BLNE    CIAhandler             ;* if so, sort the music first
 4260  :                              ;*
 4270  LDRB    R0,[R9,#vustate]       ;* 1.43se_a 27/5/13
 4280  CMP     R0,#0                  ;*
 4290  MOVNE   R0,#4                  ;*
 4300  BLNE    VUcontroller           ;*
 4310  LDR     R12,[R9,#DMABuffer]    ;* v1.45se reload R12
 4320  ]
 4330 ENDIF
 4340 [OPT opt%
 4350 :
 4360 ADD     R8,R9,#(DMA_blocks-song_data)
 4370 MOV     R6,#0                   ;put channel count as 0
 4380 LDRB    R5,[R9,#chans_use]
 4390 LDR     R4,[R9,#chanendflags]
 4400 :
 4410 LDRB    R0,[R9,#armchip]
 4420 CMP     R0,#6
 4430 BGE     a6_TRNSchannels
 4440 .a3_TRNSchannels
 4450 TEQP    PC,#(1<<27) OR %11      ;-> SVC, no interrupts
 4460 ADD     R0,R6,#1
 4470 MOV     R1,#0
 4480 STMFD   R13!,{R14}
 4490 SWI     "XSound_ReadControlBlock"
 4500 LDMFD   R13!,{R14}
 4510 TEQP    PC,#(1<<27) OR %10      ;-> IRQ, no interrupts
 4520 :
 4530 TST     R2,#%00001000<<24       ;Q  K  I  F  A  V F2 F1
 4540 ADR     R14,a3_TRNSnextchan     ;
 4550 BNE     an_TRNSchan             ;            * - TSS chan active, don't fill DMA, update off/rep
 4560 B       a3_chanctrl             ;              - TSS chan not active, fill with QTM sample
 4570 .a3_TRNSnextchan
 4580 STR     R1,[R8,#4]
 4590 MOV     R4,R4,LSR#2
 4600 ADD     R8,R8,#24
 4610 ADD     R12,R12,#1
 4620 ADD     R6,R6,#1
 4630 CMP     R6,R5
 4640 BNE     a3_TRNSchannels
 4650 ]:IF qtmrast% THEN [OPT opt%:MOV R0,#0:STRB R0,[R9,#rm_dmainprogress]:]
 4660 [OPT opt%
 4670 LDMFD   R13!,{PC}               ;v1.43 removed ^ - to enable Arthur OS compatibility!
 4680 
 4690 
 4700 .a6_TRNSchannels                ;32bit compatible code for ARM6+
 4710 FNmrs("","R0,CPSR")
 4720 ORR     R1,R0,#(1<<7)+3         ;-> SVC, no interrupts
 4730 FNmsr("","CPSR_c,R1")
 4740 STMFD   R13!,{R0,R14}
 4750 ADD     R0,R6,#1                ;r0=channel
 4760 MOV     R1,#0
 4770 SWI     "XSound_ReadControlBlock"
 4780 LDMFD   R13!,{R0,R14}
 4790 FNmsr("","CPSR_c,R0")           ;-> IRQ, no interrupts
 4800 :
 4810 TST     R2,#%00001000<<24       ;Q  K  I  F  A  V F2 F1
 4820 ADR     R14,a6_TRNSnextchan     ;
 4830 BNE     an_TRNSchan             ;            * - TSS chan active, don't fill DMA, update off/rep
 4840 B       a3_chanctrl             ;              - TSS chan not active, fill with QTM sample
 4850 .a6_TRNSnextchan
 4860 STR     R1,[R8,#4]              ;store updated sample offset
 4870 MOV     R4,R4,LSR#2             ;next block of chanendflags
 4880 ADD     R8,R8,#24               ;next QTM DMA block
 4890 ADD     R12,R12,#1              ;next DMA buffer offset
 4900 ADD     R6,R6,#1                ;channel counter 0-3 or 0-7
 4910 CMP     R6,R5                   ;have we reached chans_use?
 4920 BNE     a6_TRNSchannels         ;no, so loop
 4930 LDMFD   R13!,{PC}
 4940 
 4950 
 4960 .an_TRNSchan                    ;this code does not fill DMA, just updates sample offset/repeats
 4970 STMFD   R13!,{R4-R6,R12,R14}
 4980 LDMIA   R8,{R0-R5}              ;r0=end addr r1=-ve offset r2=pitch r3=vol/flag r4=raddr r5=rlen
 4990 CMN     R1,#4096                ;is offset >-4096? (ie. offset>>12 <1)?   (remember -ve!)
 5000 MOVGT   R7,#3                   ; <put min rep len in r7>
 5010 CMPGT   R7,R5                   ; <backwards!!! this does CMP 3,rlen so LE if valid!!!)
 5020 ;BGT     a3_chanend              ;if offset>-4096 and 3>rep len, then exit **?v1.45 fixed bug?**
 5030 LDMGTFD R13!,{R4-R6,R12,PC}     ;if offset>-4096 and 3>repeat len, then exit
 5040 :
 5050 CMP     R0,#0                   ;v1.45 fixed huge bug, can't believe addr=0 worked for so long!
 5060 CMPNE   R2,#0
 5070 LDMLEFD R13!,{R4-R6,R12,PC}     ;(another bug fix v1.45) note <=0, exit
 5080 :
 5090 ; no need for volume setting code
 5100 :
 5110 CMP     R2,#1024                        ;
 5120 ADDLT   R7,R9,#(arcperiods-song_data)
 5130 LDRLT   R2,[R7,R2,LSL#2]                ;load Arc pitch increment
 5140 BLGE    amigatoarcpitch_1024            ;for high periods, use calculation - returns r2=arc pitch
 5150 :
 5160 ; no need for DMA channel ending code
 5170 :
 5180 LDRB    R12,[R9,#actual_dma]    ;v1.45 load the actual DMA size set by Sound_Configure
 5190 MOV     R12,R12,LSL#4           ;...because we don't know what DMA size might be on RPi etc...
 5200 MLAS    R6,R2,R12,R1            ;...mul to get ptr to offset at end of fill (10 cycles vs 3 prev)
 5210 MOVLT   R1,R6                   ;
 5220 LDMLTFD R13!,{R4-R6,R12,PC}     ;if still<0 then we haven't ended/looped, so don't check
 5230 :
 5240 CMP     R5,#2                   ;
 5250 MOVLE   R1,#0                   ;
 5260 LDMLEFD R13!,{R4-R6,R12,PC}     ;exit with r1 offset=0 if no repeat
 5270 :
 5280 :                               ;bug fix v1.49, was MOV R12,#208 (DMA) now R12=actual DMA (above)
 5290 .an_TRNSrepeat                  ;if repeat length>2 then we're repeating...
 5300 ADDS    R1,R1,R2
 5310 SUBGE   R1,R1,R5,LSL#12
 5320 ADDS    R1,R1,R2
 5330 SUBGE   R1,R1,R5,LSL#12
 5340 ADDS    R1,R1,R2
 5350 SUBGE   R1,R1,R5,LSL#12
 5360 ADDS    R1,R1,R2
 5370 SUBGE   R1,R1,R5,LSL#12
 5380 ADDS    R1,R1,R2
 5390 SUBGE   R1,R1,R5,LSL#12
 5400 ADDS    R1,R1,R2
 5410 SUBGE   R1,R1,R5,LSL#12
 5420 ADDS    R1,R1,R2
 5430 SUBGE   R1,R1,R5,LSL#12
 5440 ADDS    R1,R1,R2
 5450 SUBGE   R1,R1,R5,LSL#12
 5460 SUBS    R12,R12,#8              ;do this 8 times, for best Arm3/Arm2 looping speeds
 5470 BGT     an_TRNSrepeat           ; - though Arm2 looses out a bit!
 5480 STR     R4,[R8,#DMA_address]    ;store repeat address as DMA address now!
 5490 LDMFD   R13!,{R4-R6,R12,PC}
 5500 
 5510 
 5520 
 5530 
 5540 .a2_TRNSsound
 5550 STMFD   R13!,{R9,R14}
 5560 SUB     R9,R9,#QTMblock
 5570 STR     R12,[R9,#DMABuffer]
 5580 :
 5590 .a2_TRNSsnd_in
 5600 LDR     R9,[R9,#oldConfigure+12]        ;transparent sound...!
 5610 MOV     R14,PC                          ;
 5620 LDR     PC,[R9,#0]                      ;go... and then back to QTM...
 5630 :
 5640 LDMFD   R13!,{R9}                       ;v1.49 replace FNlong_adr("  ",9,song_data)
 5650 SUB     R9,R9,#QTMblock                 ;R9=start of QTM vars block (R12 usually)
 5660 LDRB    R0,[R9,#soundflags]
 5670 TST     R0,#%1<<3
 5680 BLNE    checkclockcalc
 5690 :
 5700 ]:IF qtmrast% THEN
 5710  [OPT opt%
 5720  LDRB    R0,[R9,#rm_dmainprogress];
 5730  TEQ     R0,#0                 ;
 5740  LDMNEFD R13!,{PC}             ;* v1.45se RasterMan - quit if DMA alread in progress (reentrant)
 5750  MOV     R0,#1                 ;
 5760  STRB    R0,[R9,#rm_dmainprogress];
 5770  :                             ;
 5780  MOV     R12,R9                ;* v1.43se RasterMan special release (2013)
 5790  LDRB    R0,[R9,#songstatus]   ;* are we playing the song?
 5800  TST     R0,#%1<<2             ;*
 5810  BLNE    CIAhandler            ;* if so, sort the music first
 5820  :                             ;*
 5830  LDRB    R0,[R9,#vustate]      ;* 1.43se_a 27/5/13
 5840  CMP     R0,#0                 ;*
 5850  MOVNE   R0,#4                 ;*
 5860  BLNE    VUcontroller          ;*
 5870  LDR     R12,[R9,#DMABuffer]   ;* v1.45se reload R12
 5880  ]
 5890 ENDIF
 5900 [OPT opt%
 5910 :
 5920 ADD     R8,R9,#(DMA_blocks-song_data)
 5930 MOV     R6,#0                           ;put channel count as 0
 5940 LDRB    R5,[R9,#chans_use]
 5950 LDR     R4,[R9,#chanendflags]
 5960 :
 5970 .a2_TRNSchannels
 5980 TEQP    PC,#(1<<27) OR %11
 5990 ADD     R0,R6,#1
 6000 MOV     R1,#0
 6010 STMFD   R13!,{R14}
 6020 SWI     "XSound_ReadControlBlock"
 6030 LDMFD   R13!,{R14}
 6040 TEQP    PC,#(1<<27) OR %10
 6050 :
 6060 TST     R2,#%00001000<<24       ;Q  K  I  F  A  V F2 F1
 6070 ADR     R14,a2_TRNSnextchan     ;v1.48 bug fix...
 6080 BNE     an_TRNSchan             ;...ARM3 already fixed, but previous ARM2 code did BLNE then BL
 6090 BL      a2_chanctrl             ;...so prioritised QTM over RISC OS, now RISC OS prioritised!
 6100 .a2_TRNSnextchan
 6110 STR     R1,[R8,#4]
 6120 MOV     R4,R4,LSR#2
 6130 ADD     R8,R8,#24
 6140 ADD     R12,R12,#1
 6150 ADD     R6,R6,#1
 6160 CMP     R6,R5
 6170 BNE     a2_TRNSchannels
 6180 ]:IF qtmrast% THEN [OPT opt%:MOV R0,#0:STRB R0,[R9,#rm_dmainprogress]:]
 6190 [OPT opt%
 6200 LDMFD   R13!,{PC}              ;v1.43 removed ^ - to enable Arthur OS compatibility!
 6210 
 6220 
 6230 ;                       **********************
 6240 ;                       ***   Arm 2 code   ***
 6250 ;                       **********************
 6260 
 6270 
 6280 .a2_DMAsound
 6290 STMFD   R13!,{R14}
 6300 SUB     R9,R9,#QTMblock
 6310 STR     R12,[R9,#DMABuffer]
 6320 :
 6330 .a2_DMAsnd_in
 6340 LDRB    R0,[R9,#soundflags]
 6350 TST     R0,#%1<<3
 6360 BLNE    checkclockcalc
 6370 :
 6380 ]:IF qtmrast% THEN
 6390  [OPT opt%
 6400  LDRB    R0,[R9,#rm_dmainprogress];
 6410  TEQ     R0,#0                 ;
 6420  LDMNEFD R13!,{PC}             ;* v1.45se RasterMan - quit if DMA alread in progress (reentrant)
 6430  MOV     R0,#1                 ;
 6440  STRB    R0,[R9,#rm_dmainprogress];
 6450  :                             ;
 6460  MOV     R12,R9                ;* v1.43se RasterMan special release (2013)
 6470  LDRB    R0,[R9,#songstatus]   ;* are we playing the song?
 6480  TST     R0,#%1<<2             ;*
 6490  BLNE    CIAhandler            ;* if so, sort the music first
 6500  :                             ;*
 6510  LDRB    R0,[R9,#vustate]      ;* 1.43se_a 27/5/13
 6520  CMP     R0,#0                 ;*
 6530  MOVNE   R0,#4                 ;*
 6540  BLNE    VUcontroller          ;*
 6550  LDR     R12,[R9,#DMABuffer]   ;* v1.45se reload R12
 6560  ]
 6570 ENDIF
 6580 [OPT opt%
 6590 :
 6600 ADD     R8,R9,#(DMA_blocks-song_data)
 6610 MOVS    R6,#0                           ;put channel count as 0
 6620 LDRB    R5,[R9,#chans_use]
 6630 LDR     R4,[R9,#chanendflags]
 6640 :
 6650 MOVS    R6,R6,LSL#1                     ;(move 0>>1 - clear C flag)
 6660 .a2_DMAchannels                         ;relys on C flag CLEAR at this point!!!
 6670 BL      a2_chanctrl
 6680 STRCC   R1,[R8,#4]
 6690 .a2_DMAnextchan
 6700 MOV     R4,R4,LSR#2
 6710 ADD     R8,R8,#24
 6720 ADD     R12,R12,#1
 6730 ADD     R6,R6,#1
 6740 CMP     R6,R5                   ;this will CLEAR the C flag if R6-R5 < 0 (all the time)!
 6750 BNE     a2_DMAchannels
 6760 ]:IF qtmrast% THEN [OPT opt%:MOV R0,#0:STRB R0,[R9,#rm_dmainprogress]:]
 6770 [OPT opt%
 6780 LDMFD   R13!,{PC}               ;v1.43 removed ^ - to enable Arthur OS compatibility!
 6790 
 6800 
 6810 .a2_chanctrl
 6820 STMFD   R13!,{R4-R6,R12,R14}
 6830 ]:IF alphatest% THEN [OPT opt%:LDR R14,[R9,#dma_calls]:ADD R14,R14,#1:STR R14,[R9,#dma_calls]:]
 6840 [OPT opt%
 6850 LDMIA   R8,{R0-R5}              ;r0=end addr, r1=-ve offset, r2=pitch, r3=vol/flag, r4=rlen
 6860 CMN     R1,#4096                ;is offset >-4096? (ie. offset>>12 <1)?   (remember -ve!)
 6870 MOVGT   R7,#3                   ; <put min loop len in r7>
 6880 CMPGT   R7,R5                   ; <backwards!!! this does CMP 3,len so LE if valid!!!)
 6890 .bgt_a2_chanend
 6900 BGT     a2_chanend              ;if offset>-4096 and 3>repeat len, then exit
 6910 :
 6920 CMP     R0,#0                   ;v1.45 - huge bug - can't believe address=0 has worked for so long!
 6930 CMPNE   R2,#0
 6940 BLE     a2_chanend
 6950 :
 6960 .a2_chanrunning
 6970 MOVS    R3,R3,LSL#24                    ;if DMA_sampleflag set, CS because &FF shifted off
 6980 ADDCC   R7,R9,#(musicvoltable-song_data)
 6990 ADDCS   R7,R9,#(samplevoltable-song_data)
 7000 LDRB    R3,[R7,R3,LSR#24]               ;load Arc scaled volume
 7010 :
 7020 CMP     R2,#1024                        ;
 7030 ADDLT   R7,R9,#(arcperiods-song_data)
 7040 LDRLT   R2,[R7,R2,LSL#2]                ;load Arc pitch increment
 7050 BLGE    amigatoarcpitch_1024            ;for high periods, use calculation - returns r2=arc pitch
 7060 :
 7070 MOV     R7,#%11                 ;testing flags...
 7080                                 ;** R6 STILL has channel number in it!!! **
 7090 MOV     R6,R6,LSL#1             ;channel * 2 (2 flags per channel!)
 7100 MOV     R7,R7,LSLR6             ;shift flags << (channel*2)
 7110 LDR     R6,[R9,#chanendflags]   ;load current channel ending flags
 7120 TST     R6,R7                   ;are either of the 'ending/ended' bits set?
 7130 BICNE   R6,R6,R7                ;if so, clear them, cos this channel IS running!
 7140 STRNE   R6,[R9,#chanendflags]   ;...and store them
 7150 :
 7160 :                               ;v1.45 leave DMAshift for Arm2 machines - fast as possible here
 7170 ADD     R6,R1,R2,LSL#dmashift1  ;4 * 2013  ;  \
 7180 ADD     R6,R6,R2,LSL#dmashift2  ;6 * v1.42 ;   } - pitch inc.*dma = DMA length (SHOULD BE!!!)
 7190 ADDS    R6,R6,R2,LSL#dmashift3  ;7 * =208  ;work out where the offset pointer will be after this fill
 7200 BLT     a2_not_ending           ;if still<0 then we haven't ended/looped, so don't check
 7210 :
 7220 CMP     R5,#3                   ;
 7230 ;CMPGE   R4,R0                   ;
 7240 BGE     a2_repeating     ;EQ       ;if repeat length>0 AND we've got same addr then use rep...
 7250 :
 7260 CMP     R3,#254                 ;if volume is too low
 7270 BGE     a2_endnovol             ;go to clear the channel...
 7280 CMP     R3,#0                   ;
 7290 ]:IF alphatest% THEN [OPT opt%:LDREQ R14,[R9,#dma_efv]:ADDEQ R14,R14,#1:STREQ R14,[R9,#dma_efv]:]
 7300 [OPT opt%
 7310 LDREQ   PC,jmp_a2_endfullvol    ;if vol is max. use max. vol fill routines
 7320 :
 7330 ]:IF alphatest% THEN [OPT opt%:LDR R14,[R9,#dma_eav]:ADD R14,R14,#1:STR R14,[R9,#dma_eav]:]
 7340 [OPT opt%
 7350 LDR     PC,jmp_a2_endanyvol
 7360 
 7370 
 7380 .a2_endnovol
 7390 BL      a2_clearchannel
 7400 MOV     R1,#0                   ;set offset to 0, so it will call 'chanend' next time
 7410 LDMFD   R13!,{R4-R6,R12,PC}^
 7420 
 7430 
 7440 .a2_repeating
 7450 CMP     R3,#254                 ;if volume is too low
 7460 ]:IF alphatest% THEN [OPT opt%:LDRGE R14,[R9,#dma_rnv]:ADDGE R14,R14,#1:STRGE R14,[R9,#dma_rnv]:]
 7470 [OPT opt%
 7480 LDRGE   PC,jmp_a2_repnovol      ;go to clear the channel...
 7490 CMP     R3,#0                   ;
 7500 ]:IF alphatest% THEN [OPT opt%:LDREQ R14,[R9,#dma_rfv]:ADDEQ R14,R14,#1:STREQ R14,[R9,#dma_rfv]:]
 7510 [OPT opt%
 7520 LDREQ   PC,jmp_a2_repfullvol    ;if vol is max, use max. fill routines
 7530 :
 7540 ]:IF alphatest% THEN [OPT opt%:LDR R14,[R9,#dma_rav]:ADD R14,R14,#1:STR R14,[R9,#dma_rav]:]
 7550 [OPT opt%
 7560 LDR     PC,jmp_a2_repanyvol
 7570 
 7580 
 7590 .a2_clearchannel
 7600 STMFD   R13!,{R6,R14}
 7610 MOV     R6,#0
 7620 ]:IF alphatest% THEN [OPT opt%:LDR R14,[R9,#dma_clc]:ADD R14,R14,#1:STR R14,[R9,#dma_clc]:]
 7630 [OPT opt%
 7640 LDR     PC,jmp_a2_clearing
 7650 
 7660 
 7670 .a2_not_ending                  ;on entry r5 = end offset
 7680 CMP     R3,#254                 ;volume too low?
 7690 MOVGE   R1,R6                   ;yup, so put end offset in offset reg...
 7700 BLGE    a2_clearchannel         ;...and clear the channel!
 7710 LDMGEFD R13!,{R4-R6,R12,PC}^    ;...then exit
 7720 :
 7730 CMP     R3,#0                   ;
 7740 ]:IF alphatest% THEN [OPT opt%:LDREQ R14,[R9,#dma_fv]:ADDEQ R14,R14,#1:STREQ R14,[R9,#dma_fv]:]
 7750 [OPT opt%
 7760 LDREQ   PC,jmp_a2_fullvolume    ;max. vol, so use max. routines
 7770 :
 7780 ]:IF alphatest% THEN [OPT opt%:LDR R14,[R9,#dma_an]:ADD R14,R14,#1:STR R14,[R9,#dma_an]:]
 7790 [OPT opt%
 7800 LDR     PC,jmp_a2_anyvolume
 7810 
 7820 
 7830 ; channel ending flags:
 7840 ;                       %11 per channel (should be CLEAR when playing the sample)
 7850 ;                       /  \
 7860 ;   cleared DMA buffer 1    cleared DMA buffer 2 (so sample has REALLY finished - exit)
 7870 
 7880 
 7890 .a2_chanend
 7900 LDR     R4,[R13,#0]             ;load channel end flags (r4)
 7910 MOVS    R4,R4,LSR#1             ;shift off the first bit (REALLY ended test)
 7920 ]:IF alphatest% THEN [OPT opt%:LDRCS R14,[R9,#dma_ce]:ADDCS R14,R14,#1:STRCS R14,[R9,#dma_ce]:]
 7930 [OPT opt%
 7940 LDMCSFD R13!,{R4-R6,R12,PC}     ;if it had 'REALLY ended' then reload (inc. r4) and exit
 7950 :
 7960 BL      a2_clearchannel         ;clear this DMA buffer
 7970 :
 7980 LDR     R6,[R13,#8]             ;load current channel (-1)
 7990 MOV     R6,R6,LSL#1             ;channel*2
 8000 MOVS    R4,R4,LSR#1             ;test 2nd bit of channel end flags
 8010 LDR     R4,[R9,#chanendflags]   ;(+load FULL current flags word, for alteration)
 8020 MOVCC   R5,#%10                 ;if 2nd bit was clear, then channel has JUST ended
 8030 MOVCS   R5,#%01                 ;if 2nd bit was set, then it ended 1 DMA fill ago (ie.done)
 8040 ORR     R4,R4,R5,LSLR6          ;set altered flags in flag word
 8050 STR     R4,[R9,#chanendflags]   ;store flag word
 8060 LDMFD   R13!,{R4-R6,R12,PC}^    ;reload+exit WITHOUT C flag set (so new offset is stored)
 8070 
 8080 
 8090 ;                    ***************************
 8100 ;                    *** Sound INIT routines ***
 8110 ;                    ***************************
 8120 
 8130 
 8140 .initQTMsound                   ;r12=song_data
 8150 STMFD   R13!,{R0-R4,R14}
 8160 LDRB    R0,[R12,#soundflags]
 8170 TST     R0,#%1<<0               ;are we already switched on?
 8180 LDMNEFD R13!,{R0-R4,R14}        ; * v1.42 * bug fix
 8190 BNE     checknewchannels        ;yup!, but we'ed better make sure the chans are set...then exit
 8200 :                               ;(v1.41 did 'BLNE checknewchannels' then 'LDMNEFD...' expecting same flags)
 8210 :
 8220 ORR     R0,R0,#%1<<0            ;
 8230 STRB    R0,[R12,#soundflags]    ;set 'we're on now' flag
 8240 :
 8250 BL      readstereos             ;read previous users stereo settings
 8260 BL      setDMAblock             ;set up the channel handler block (inc. TRNS/DMA control)
 8270 :
 8280 MOV     R0,#0                   ;
 8290 STR     R0,[R12,#chanendflags]  ;set 'clear channels' flags
 8300 :                               ;v1.45 - read OS settings first, so can set up TSS *before*
 8310 MOV     R1,#0                   ;        enabling QTM DMA
 8320 MOV     R2,#0                   ;
 8330 MOV     R3,#0                   ;
 8340 MOV     R4,#0                   ;
 8350 SWI     "XSound_Configure"      ;        this WILL briefly suffer the OS 3 bug, but QTM takes
 8360 :                               ;        over in a sec
 8370 ADD     R4,R12,#oldConfigure
 8380 STMIA   R4,{R0-R3}              ;        store old configuration before enabling QTM DMA
 8390 ADD     R4,R12,#QTMblock+8      ;         - need on Beaglebd
 8400 ADD     R3,R3,#8
 8410 LDMIA   R3,{R0-R1}              ;        read conversion tables from OS
 8420 STMIA   R4,{R0-R1}              ;        set OS tables in QTM's sound block
 8430 :
 8440 BL      setsoundconfig          ;set up the system, and the stereos!
 8450 LDMFD   R13!,{R0-R4,PC}         ;exit
 8460 
 8470 
 8480 .setsoundconfig                 ;sets sound system to current QTM settings (and stereos!)
 8490 STMFD   R13!,{R4,R14}           ;returns previous system settings R0-R3 (R4 not required!)
 8500 BL      makeuSok                ;this will make sure the sample speed is always ok!
 8510 LDRB    R0,[R12,#soundflags]
 8520 TST     R0,#%1<<0
 8530 LDMEQFD R13!,{R4,PC}            ;if called from SWI SetSampleSpeed QTM may not be DMA controller
 8540 :                               ;exit if QTM isn't active (after checking sample speed ok)!
 8550 LDRB    R1,[R12,#osversion]
 8560 CMP     R1,#&A3-&A0
 8570 BLT     doOS2setsound           ;OS 2 bug - only sets sample speed if < chans*15.75!
 8580 LDRB    R2,[R12,#current_uS]
 8590 :
 8600 .noOS2setproblem
 8610 LDRB    R0,[R12,#chans_use]     ;
 8620 LDRB    R1,[R12,#current_dma]   ; * dma size/16
 8630 MOV     R1,R1,LSL#4             ; * v1.42 change!
 8640 :
 8650 :                               ; - OS 3.xx new comp BUG! <soln. - put R2=uS> - but OS2 bug!
 8660 ADD     R3,R12,#QTMblock        ;
 8670 MOV     R4,#0                   ;
 8680 SWI     "XSound_Configure"      ;ensure correct settings, and read sound system
 8690 :
 8700 STMFD   R13!,{R2}
 8710 ADD     R2,R12,#QTMstereos      ;stereo pointer in r2
 8720 BL      setstereos              ;set the stereos! (and set actual_dma)
 8730 :
 8740 LDRB    R2,[R12,#soundflags]
 8750 TST     R2,#1<<7
 8760 BLNE    recalc_uS_4clock_16bit ;JL-not sure how non-16bit version gets by without recalcing
 8770 :                              ;   clock speeds here
 8780 :                              ;SH-easy, either the calling SWI (setsamplespeed) calls it ;-)
 8790 LDMFD   R13!,{R2,R4,PC}        ;   or it's set up from initqtm on startup (initVIDCandpitch)
 8800 
 8810 
 8820 .doOS2setsound
 8830 MOV     R0,#1                   ;incase of risc os 2 bug (only sets uS<chans*15.75!)
 8840 LDRB    R1,[R12,#current_dma]   ; * dma size/16
 8850 MOV     R1,R1,LSL#4             ; * v1.42 change!
 8860 LDRB    R2,[R12,#current_uS]
 8870 MOV     R3,#0                   ;don't set handler yet (- not designed for only 1 channel)
 8880 MOV     R4,#0
 8890 SWI     "XSound_Configure"      ;this always sets correct sample speed
 8900 :
 8910 STMFD   R13!,{R0-R3}            ;put old OS configuration on stack
 8920 LDRB    R0,[R12,#chans_use]
 8930 MOV     R1,#0
 8940 MOV     R2,#0
 8950 ADD     R3,R12,#QTMblock
 8960 MOV     R4,#0
 8970 SWI     "XSound_Configure"      ;v1.45 could store 'actual_dma' from R2 here (but n/r on RO2)
 8980 :
 8990 ADD     R2,R12,#QTMstereos      ;stereo pointer in r2
 9000 BL      setstereos              ;set the stereos! (and set actual_dma)
 9010 LDMFD   R13!,{R0-R4,PC}         ;finally set channels correcty, and stereos, then exit
 9020 
 9030 
 9040 .twangsoundsystem               ;called to 'twang' the system! (for stereos & RISC OS 3 bug)
 9050 STMFD   R13!,{R1-R4,R14}        ;returns R0=old channels
 9060 LDRB    R0,[R12,#soundflags]
 9070 TST     R0,#1
 9080 BEQ     twangOSsound            ;this is for when resetting OS stereos!
 9090 :
 9100 LDRB    R1,[R12,#osversion]
 9110 CMP     R1,#&A3-&A0             ;read OS
 9120 MOVLT   R2,#0                   ;don't reset uS if on OS 2 (avoids uS<chans*15.75 bug!)
 9130 LDRGEB  R2,[R12,#current_uS]    ;** but we MUST reset uS to get round OS 3 bug! **
 9140 :
 9150 LDRB    R0,[R12,#chans_use]     ;
 9160 LDRB    R1,[R12,#current_dma]   ; * dma size/16
 9170 MOV     R1,R1,LSL#4             ; * v1.42 change!
 9180 :
 9190 :                               ; - OS 3.xx new comp BUG! <soln. - put R2=uS> - but messes OS2!
 9200 ADD     R3,R12,#QTMblock        ;
 9210 MOV     R4,#0                   ;
 9220 SWI     "XSound_Configure"      ;ensure correct settings, and read sound system
 9230 :
 9240 ; v1.45 now we store 'actual_dma' size, because on RPi/etc. setting DMA size to 208 doesn't work
 9250 ;   reading actual DMA works because we already tried setting to 'current_dma' before we got here
 9260 ;   so value returned in R1 is actual value Sound_Configure previously set DMA to when we tried.
 9270 :
 9280 MOV     R1,R1,LSR#4
 9290 STRB    R1,[R12,#actual_dma]    ;in practice QTM DMA handler will be on for few uS before we set
 9300 LDMFD   R13!,{R1-R4,PC}         ;this correctly but should be OK as we set to current_dma on init
 9310 
 9320 
 9330 .twangOSsound
 9340 MOV     R0,#0
 9350 MOV     R1,#0
 9360 MOV     R2,#0
 9370 MOV     R3,#0
 9380 MOV     R4,#0
 9390 SWI     "XSound_Configure"      ;this WILL suffer the OS 3 bug, but it's only the OS!!!
 9400 LDMFD   R13!,{R1-R4,PC}
 9410 
 9420 
 9430 .checknewchannels               ;r12=song_data
 9440 STMFD   R13!,{R0-R3,R14}        ;*bug fix v1.43* previously corrupt R3 (via BL setsoundconfig)!
 9450 BL      setsoundconfig          ;sets chans to QTM chans & set stereos, returns old setup *R0-R3*
 9460 LDRB    R1,[R12,#chans_use]     ;load QTM channels
 9470 CMP     R0,R1                   ;old chans same as QTM chans? (ie. did we just change no. chans?)
 9480 LDMEQFD R13!,{R0-R3,PC}         ;same channels, so exit
 9490 :
 9500 MOV     R0,#0                   ;** new number of channels ** so we'ed better ensure that
 9510 STR     R0,[R12,#chanendflags]  ; they are cleared (else they'll buzz!) so clear 'ended'
 9520 ;LDRB    R0,[R12,#soundflags]    ;v1.44
 9530 ;TST     R0,#%1<<5               ;  |
 9540 ;BL      update14or58chans       ;  | if channels changed and using 5-8 for song, update DMA data
 9550 TEQ     R1,#4
 9560 ADDEQ   R0,R12,#(DMA_blocks+24*4-song_data)
 9570 MOVEQ   R1,#24*4                 ;...next, if change to 4 chans, wipe DMA data for channels 5-8
 9580 BLEQ    blankmemory              ;v1.48 this replaces clearupperchans
 9590 LDMFD   R13!,{R0-R3,PC}
 9600 
 9610 
 9620 ;.update14or58chans              ;v1.44 call after changing channels or altering bit 5 of soundflags
 9630 ;STMFD   R13!,{R0-R12,R14}
 9640 ;LDRB    R0,[R12,#soundflags]
 9650 ;TST     R0,#%1<<5
 9660 ;:
 9670 ;FNlong_adr("NE",10,DMA_blocks)
 9680 ;ADDNE   R11,R10,#24*4           ;if set, copy 1-4 to 5-8
 9690 ;FNlong_adr("EQ",11,DMA_blocks)
 9700 ;ADDEQ   R10,R11,#24*4           ;if clear, copy 5-8 to 1-4
 9710 ;MOV     R9,#4
 9720 ;MOV     R7,#0
 9730 ;MOV     R8,#0
 9740 ;.copymusicchannels
 9750 ;LDRB    R0,[R10,#DMA_sampleflag]
 9760 ;TEQ     R0,#0
 9770 ;LDMEQIA R10,{R1-R6}
 9780 ;STMEQIA R11,{R1-R6}
 9790 ;MOVEQ   R3,#0 MOVEQ R4,#0 MOVEQ R5,#0 MOVEQ R6,#0
 9800 ;STMEQIA R10,{R3-R8}
 9810 ;ADD     R10,R10,#24
 9820 ;ADD     R11,R11,#24
 9830 ;SUBS    R9,R9,#1
 9840 ;BGT     copymusicchannels
 9850 ;LDMFD   R13!,{R0-R12,PC}        ;v1.44
 9860 
 9870 
 9880 .makeuSok                       ;this ensures the sample speed (uS) is ok for the channels
 9890 STMFD   R13!,{R0-R1,R14}        ;called every time the sample speed is altered!
 9900 LDRB    R0,[R12,#current_uS]
 9910 LDRB    R1,[R12,#chans_use]
 9920 MOV     R14,#%11                ;(updated with v1.30a code on 16/4/2001)
 9930 ORR     R14,R14,R1,LSR#1        ;R14 now has %111 for 8 channels, %11 for 4 channels
 9940 TST     R0,R14                  ;any bad bits set in sample speed?
 9950 BIC     R0,R0,R14
 9960 ADDNE   R0,R0,R1                ;(eg. for 8 chans, 49 BIC %111 = 48, 48+8 = 56 - ok)
 9970 ;
 9980 ; minimum uS for n channels is n*3
 9990 ;
10000 ADD     R1,R1,R1,LSL#1          ;=R1*3!!! =channels*3 (n+n*2=n*3!)
10010 CMP     R0,R1
10020 MOVLT   R0,R1                   ;R0 now has totally legal uS for this number of channels!
10030 STRB    R0,[R12,#current_uS]
10040 LDMFD   R13!,{R0-R1,PC}
10050 
10060 
10070 .setDMAblock                    ;this **should** affect the DMA controller in real time...
10080 STMFD   R13!,{R0-R4,R14}        ;
10090 LDRB    R0,[R12,#armchip]       ;Arm2/3/6 chip
10100 LDRB    R1,[R12,#soundflags]    ;load current sound flags (TRNS state is bit1)
10110 :
10120 CMP     R0,#3                   ;was it an Arm3+? (if R0-3 >=0 then C flag is SET)
10130 TST     R1,#%1<<1               ;is bit1 of sound flags set (ie.TRNS) (sets Z flag, not C)
10140 FNlong_adr("CS",0,a3_DMAsound)  ;C set               (ie. Arm3+               )
10150 FNlong_adr("CC",0,a2_DMAsound)  ;C clear             (ie. Arm2                )
10160 FNlong_adr("NE",0,a2_TRNSsound) ;          Z clear   (ie.           TRNS bit=1)
10170 FNlong_adr("HI",0,a3_TRNSsound) ;C set and Z clear   (ie. Arm3+ and TRNS bit=1) works?????
10180 ADR     R1,overruncode          ;overrun fixup code
10190 ;                               ;R2=OS linear-to-log table
10200 ;                               ;R3=OS log-scale table
10210 ADD     R2,R12,#QTMblock        ;address of 'channel handler block'
10220 STMIA   R2,{R0-R1}              ;set up block, except OS tables - done by initQTMsound!
10230 LDMFD   R13!,{R0-R4,PC}         ;exit...
10240 
10250 
10260 .overruncode
10270 MOV     PC,R14                  ;apparently unused now
10280 
10290 
10300 .readstereos
10310 STMFD   R13!,{R0-R4,R14}
10320 LDR     R3,[R12,#channelstate]  ;see DMA filler section before altering c-state
10330 MOV     R4,#1
10340 ADD     R2,R12,#oldstereos
10350 MOV     R0,#1
10360 .readstloop
10370 TST     R3,R4,LSLR0
10380 MVNNE   R1,#127
10390 SWINE   "XSound_Stereo"
10400 STRNEB  R1,[R2,R0]              ;if QTM's going to use this channel, read and store it's stereo
10410 ADD     R0,R0,#1                ;(^^^ *** should get stereo's using 8 bytes rather than 9 ***)
10420 CMP     R0,#8
10430 BLE     readstloop
10440 LDMFD   R13!,{R0-R4,PC}         ;all OS stereos read
10450 
10460 
10470 .setstereos                     ;set to pointer in r2, r12=song_data
10480 STMFD   R13!,{R0-R4,R14}
10490 LDR     R3,[R12,#channelstate]  ;see DMA filler section before altering c-state
10500 MOV     R4,#1
10510 MOV     R0,#1
10520 .stereoloop
10530 TST     R3,R4,LSLR0             ;check channel is in use by QTM
10540 LDRNEB  R1,[R2,R0]
10550 MOVNE   R1,R1,LSL#24
10560 MOVNE   R1,R1,ASR#24            ;make 8bit -ve to 32bit -ve value
10570 SWINE   "XSound_Stereo"
10580 ADD     R0,R0,#1
10590 CMP     R0,#8
10600 BLE     stereoloop
10610 :
10620 BL      twangsoundsystem        ;remember to force OS to update (internally) stereos (OS bug?)
10630 LDMFD   R13!,{R0-R4,PC}
10640 
10650 
10660 .resetsound                     ;r12=song_data
10670 STMFD   R13!,{R0-R4,R11,R14}
10680 LDRB    R0,[R12,#soundflags]
10690 TST     R0,#%1<<0
10700 LDMEQFD R13!,{R0-R4,R11,PC}     ;QTM wasn't using the sound system
10710 :
10720 BIC     R0,R0,#%1<<0
10730 STRB    R0,[R12,#soundflags]    ;clear sound flags, so next DMA buffer will clear next interrupt
10740 :
10750 LDRB    R0,[R12,#chans_use]
10760 LDRB    R1,[R12,#actual_dma]    ;dma/16
10770 MOV     R1,R1,LSL#4             ;*16
10780 MUL     R1,R0,R1                ;v1.45 this should reduce pops on the Pi
10790 LDR     R0,[R12,#DMABuffer]     ;-added for F-00 crash bug (maybe due to v1.30a bug^^) fix12/9/97
10800 BL      blankmemory             ;clear *current* DMA buffer incase no interrupt before switch-off
10810 :
10820 ADD     R1,R12,#oldConfigure+4
10830 LDMIA   R1,{R1-R3}
10840 MOV     R0,#1                   ;only set uS with 1 chan active (bug only in RO2)
10850 MOV     R4,#0
10860 SWI     "XSound_Configure"      ;*** USED TO DO THIS BEFORE BUFFER CLEAR, ok??? *** 16/4/2001
10870 :
10880 LDRB    R0,[R12,#oldConfigure]  ;ok to set chans now
10890 BL      clearoldSCCB
10900 MOV     R1,#0
10910 MOV     R2,#0                   ;OS 3.xx new comp BUG! But unlikely to affect OS settings!
10920 MOV     R3,#0
10930 MOV     R4,#0
10940 SWI     "XSound_Configure"      ;r0=old chans
10950 :
10960 ADD     R2,R12,#oldstereos
10970 BL      setstereos              ;reset stereos to OS settings
10980 LDMFD   R13!,{R0-R4,R11,PC}
10990 
11000 
11010 .clearoldSCCB                   ;r0=chans to clear
11020 STMFD   R13!,{R0-R4,R14}
11030 MOV     R4,R0
11040 MOV     R1,#12
11050 .clearSCCBloop
11060 MOV     R0,R4
11070 MOV     R2,#0
11080 SWI     "XSound_WriteControlBlock"
11090 SUBS    R4,R4,#1
11100 BNE     clearSCCBloop
11110 LDMFD   R13!,{R0-R4,PC}
11120 
11130 
11140 
11150 .amigatoarcpitch_1024               ;R2=amiga note (>=1024) to convert, returns R2=arc pitch
11160 STMFD   R13!,{R0-R1,R3-R11,R14}     ; called by DMA and VU code only, and both use
11170 LDR     R10,Amiga_multiplier        ; R9=block ptr (not R12!)
11180 LDR     R9,[R9,#actual_uS]          ;actual uS<<12
11190 :
11200 ;MOV     R7,#19       ;default accuracy is 19bits
11210 ;CMP     R2,#2        ;from amiga pitch 2, use 18bit accuracy
11220 ;MOVGE   R7,#18
11230 ;CMP     R2,#3        ;from amiga pitch 3, use 17bit
11240 ;MOVGE   R7,#17
11250 ;CMP     R2,#6        ;from amiga pitch 6, use 16bit
11260 ;MOVGE   R7,#16
11270 ;CMP     R2,#11       ;from amiga pitch 11, use 15bit
11280 ;MOVGE   R7,#15
11290 ;CMP     R2,#22       ;from amiga pitch 22, use 14bit
11300 ;MOVGE   R7,#14
11310 ;CMP     R2,#43       ;from amiga pitch 43, use 13bit
11320 ;MOVGE   R7,#13
11330 ;CMP     R2,#86       ;from amiga pitch 86, use 12bit
11340 ;MOVGE   R7,#12
11350 ;CMP     R2,#172      ;from amiga pitch 172, use 11bit
11360 ;MOVGE   R7,#11
11370 ;CMP     R2,#344      ;from amiga pitch 344, use 10bit
11380 ;MOVGE   R7,#10
11390 ;CMP     R2,#688      ;from amiga pitch 688, use 9bit
11400 ;MOVGE   R7,#9
11410 :
11420 MOV     R7,#9        ;default accuracy is 9bits
11430 CMP     R2,#1376     ;from amiga pitch 1376, use 8bit
11440 MOVGE   R7,#8
11450 CMP     R2,#2752     ;from amiga pitch 2752, use 7bit (next would be from 5504, 6bit)
11460 MOVGE   R7,#7
11470 RSB     R6,R7,#30               ;30-x
11480 :
11490 MOV     R0,R10
11500 MOV     R1,R2
11510 BL      r0_div_r1
11520 :
11530 MOV     R0,R0,LSRR7
11540 MOV     R1,R9
11550 MUL     R0,R1,R0
11560 :
11570 MOV     R2,R0,LSRR6
11580 LDMFD   R13!,{R0-R1,R3-R11,PC}
11590 
11600 
11610 .Amiga_multiplier
11620 EQUD    &E3005235               ;PAL timing! ((7093789.2/2*1024)/1E6)*2^20!!! - unsigned
11630                                 ;v1.44 corrected, but error was insignificant so no difference
11640 
11650 .reinit_arcpitch                ;R0 = amiga note to convert
11660 STMFD   R13!,{R0-R1,R8-R11,R14}
11670 ADD     R11,R12,#(arcperiods-song_data)
11680 LDR     R10,Amiga_multiplier
11690 LDR     R9,[R12,#actual_uS]     ;actual uS<<12
11700 ;MOV     R9,#(32*4096 AND &FF0000)
11710 ;ADD  R9,R9,#(32*4096 AND &00FF00)
11720 ;ADD  R9,R9,#(32*4096 AND &0000FF)
11730 MOV     R8,#1        ;amiga pitch counter into 1024 table
11740 MOV     R7,#19       ;default accuracy is 19bits
11750 .workouttable
11760 CMP     R8,#2        ;from amiga pitch 2, use 18bit accuracy
11770 MOVGE   R7,#18
11780 CMP     R8,#3        ;from amiga pitch 3, use 17bit
11790 MOVGE   R7,#17
11800 CMP     R8,#6        ;from amiga pitch 6, use 16bit
11810 MOVGE   R7,#16
11820 CMP     R8,#11       ;from amiga pitch 11, use 15bit
11830 MOVGE   R7,#15
11840 CMP     R8,#22       ;from amiga pitch 22, use 14bit
11850 MOVGE   R7,#14
11860 CMP     R8,#43       ;from amiga pitch 43, use 13bit
11870 MOVGE   R7,#13
11880 CMP     R8,#86       ;from amiga pitch 86, use 12bit
11890 MOVGE   R7,#12
11900 CMP     R8,#172      ;from amiga pitch 172, use 11bit
11910 MOVGE   R7,#11
11920 CMP     R8,#344      ;from amiga pitch 344, use 10bit
11930 MOVGE   R7,#10
11940 CMP     R8,#688      ;from amiga pitch 688, use 9bit (next would be from 1376, 8bit)
11950 MOVGE   R7,#9
11960 RSB     R6,R7,#30               ;30-x
11970 :
11980 MOV     R0,R10
11990 MOV     R1,R8
12000 BL      r0_div_r1
12010 :
12020 MOV     R0,R0,LSRR7
12030 MOV     R1,R9
12040 MUL     R0,R1,R0
12050 :
12060 MOV     R0,R0,LSRR6
12070 STR     R0,[R11,R8,LSL#2]
12080 ADD     R8,R8,#1
12090 CMP     R8,#1024
12100 BLT     workouttable
12110 LDMFD   R13!,{R0-R1,R8-R11,PC}
12120 
12130 
12140 .readclock
12150 EQUD    172
12160 EQUD    -1
12170 
12180 
12190 .recalc_uS_4clock               ;Note - Don't use if 16bit sound available!
12200 STMFD   R13!,{R0-R6,R14}
12210 ADR     R0,readclock
12220 ADD     R1,R12,#(numberbuf_new-song_data)
12230 SWI     "XOS_ReadVduVariables"  ;OS 2.00 (and below?) returns 0 as clock speed
12240 LDR     R0,[R1]                 ;v1.48 moved answer to databank
12250 LDR     R1,[R12,#clockspeed]
12260 CMP     R0,R1                   ;if NE, VIDC is clocked differently to what OS thinks!
12270 BNE     oldVIDCcalc             ; - so calculate as for an old machine with VIDC enhancer
12280 .newVIDCcalc
12290 LDR     R2,[R12,#shiftclock]
12300 LDRB    R3,[R12,#current_uS]
12310 LDRB    R4,[R12,#chans_use]
12320 MOV     R5,#24
12330 MUL     R0,R2,R3
12340 MUL     R1,R4,R5
12350 BL      r0_div_r1
12360 :
12370 MOV     R6,R0,LSR#12
12380 MUL     R6,R4,R6
12390 MOV     R0,R6,LSL#22
12400 MOV     R1,R2,LSR#2
12410 BL      r0_div_r1
12420 MUL     R0,R5,R0
12430 :
12440 LDR     R1,[R12,#actual_uS]
12450 CMP     R0,R1
12460 STRNE   R0,[R12,#actual_uS]
12470 BLNE    reinit_arcpitch
12480 LDMFD   R13!,{R0-R6,PC}
12490 
12500 
12510 .oldVIDCcalc
12520 MOV     R0,#&C0000000           ;&C0000000 = 24*4096*4096*8
12530 LDR     R1,[R12,#shiftclock]
12540 MOV     R1,R1,LSR#2             ;make shiftclock from <<12 to <<10
12550 BL      r0_div_r1               ;24*4096*4096*8/(actual clock speed*1024)
12560 LDRB    R1,[R12,#current_uS]
12570 MUL     R0,R1,R0                ;*wanted us = real uS<<17
12580 MOV     R0,R0,LSR#5             ;real uS<<12 = 'actual_uS'
12590 :
12600 LDR     R1,[R12,#actual_uS]
12610 CMP     R0,R1
12620 STRNE   R0,[R12,#actual_uS]
12630 BLNE    reinit_arcpitch
12640 LDMFD   R13!,{R0-R6,PC}
12650 
12660 
12670 .recalc_uS_4clock_16bit         ;JL-Only use if 16bit sound available!
12680 STMFD   R13!,{R0-R3,R14}
12690 MOV     R0,#1
12700 SWI     "XSound_6"              ;v1.42 fix, was XSound_SampleRate - RO3.6+ only
12710 ; R2 = sample rate in Hz, *1024
12720 ; We want sample period in uS, *4096
12730 ; period=1000000*1024*4096/R2
12740 MOV     R0,#&F4000
12750 ORR     R0,R0,#&240 ; =1000000
12760 MOV     R1,#22
12770 MOV     R3,#0
12780 ; cheapo division loop, relies on R0<R2
12790 .recalc16bit_loop
12800 RSBS    R0,R2,R0,LSL #1
12810 ADC     R3,R3,R3
12820 ADDLO   R0,R0,R2
12830 SUBS    R1,R1,#1
12840 BNE     recalc16bit_loop
12850 LDR     R0,[R12,#actual_uS]
12860 CMP     R0,R3
12870 STRNE   R3,[R12,#actual_uS]
12880 BLNE    reinit_arcpitch
12890 LDMFD   R13!,{R0-R3,PC}
12900 
12910 
12920 .checkclockcalc                 ;does this ever get called by >ARM3? (does it really need 32bit?)
12930 STMFD   R13!,{R0-R12,R14}       ;...probably not! Should only be called by pre-A5000 computers!
12940 MOV     R12,R9
12950 LDR     R2,[R12,#DMAinterrupts]
12960 ADD     R2,R2,#1
12970 STR     R2,[R12,#DMAinterrupts]
12980 :
12990 TEQ     PC,PC
13000 FNmrs("EQ","R9,CPSR")
13010 MOVNE   R9,PC
13020 ORREQ   R8,R9,#(%1<<7) OR %11   ; SVC, no interrupts
13030 ORRNE   R8,R9,#(%1<<27) OR %11
13040 FNmsr("EQ","CPSR_c,R8")
13050 TEQNEP  R8,#0
13060 MOV     R0,R0
13070 STMFD   R13!,{R14}
13080 SWI     "XOS_ReadMonotonicTime"
13090 LDMFD   R13!,{R14}
13100 TEQ     PC,PC
13110 FNmsr("EQ","CPSR_c,R9")         ; Restore original mode (IRQ, no interrupts)
13120 TEQNEP  R9,#0
13130 MOV     R0,R0
13140 :
13150 LDR     R1,[R12,#ClockCalcEnd]
13160 CMP     R1,#0
13170 BEQ     initclockcalc           ;if "ClockCalcEnd" is 0, we're just starting out, so set up!
13180 CMP     R0,R1
13190 BGE     doclockcalc             ;if we've we're reached the end - let's do calculation
13200 LDMFD   R13!,{R0-R12,PC}
13210 
13220 
13230 .initclockcalc                  ;R0=current time, R2=DMAinterrupts
13240 ADD     R0,R0,#20
13250 STR     R0,[R12,#ClockCalcEnd]  ;set quick calc end time to 200mS (20cS) for initial calculation
13260 LDRB    R0,[R12,#soundflags]
13270 ORR     R0,R0,#%1<<4            ;set bit 4 for 'quick calc'
13280 STRB    R0,[R12,#soundflags]
13290 LDMFD   R13!,{R0-R12,PC}
13300 
13310 
13320 .doclockcalc                    ;R0=current time, R2=DMAinterrupts
13330 MOV     R6,#0                   ;use R6 as flag for quick calc or not!
13340 LDRB    R1,[R12,#soundflags]
13350 TST     R1,#%1<<4
13360 BICEQ   R1,R1,#%1<<3            ;if 'quick calc' clear, we're at end of full calc, so clear flag!
13370 BEQ     continuecalc
13380 BIC     R1,R1,#%1<<4            ;if we get here we're at end of quick calc, so set full calc
13390 ADD     R0,R0,#100
13400 STR     R0,[R12,#ClockCalcEnd]  ;set full calc end time for 1 second (100cS)
13410 MOV     R0,#0
13420 STR     R0,[R12,#DMAinterrupts] ;clear DMAinterrupts *why?* could add these to full for 1.2s calc
13430 MOV     R0,#5
13440 MUL     R2,R0,R2                ;for quick calc (20cS), use 5 * DMAinterrupts (for 100cS)
13450 MOV     R6,#1                   ;flag as now doing a quick calc
13460 :
13470 .continuecalc
13480 STRB    R1,[R12,#soundflags]    ;update sound flags, altered above
13490 MOV     R0,#24*dma              ;v1.42 this now allows for varying DMA sizes, prev. fixed at 4992
13500 MUL     R2,R0,R2                ;v1.49 must change "*dma" to multiply by current_dma for RM!!!
13510 :
13520 LDRB    R0,[R12,#current_uS]
13530 MUL     R0,R2,R0
13540 MOV     R1,#1000                ;dividing by 1000mS (change to 1200mS if add quick calc to full)
13550 BL      r0_div_r1               ;R0=clock speed, in KHz (ie. 25175KHz for 25.175MHz)
13560 :
13570 MOV        R1,#(48000 AND &FF00)
13580 ADD     R1,R1,#(48000 AND &00FF)
13590 MOV        R2,#(40000 AND &FF00)
13600 ADD     R2,R2,#(40000 AND &00FF)
13610 CMP     R0,R2
13620 MOVLT      R1,#(36000 AND &FF00)
13630 ADDLT   R1,R1,#(36000 AND &00FF)
13640 MOV        R2,#(30000 AND &FF00)
13650 ADD     R2,R2,#(30000 AND &00FF)
13660 CMP     R0,R2
13670 MOVLT      R1,#(25175 AND &FF00)
13680 ADDLT   R1,R1,#(25175 AND &00FF)
13690 MOV        R2,#(24800 AND &FF00)
13700 ADD     R2,R2,#(24800 AND &00FF)
13710 CMP     R0,R2
13720 MOVLT      R1,#(24000 AND &FF00)
13730 ADDLT   R1,R1,#(24000 AND &00FF);R1 has our estimated real clock speed!!!
13740 :
13750 LDR     R2,[R12,#clockspeed]
13760 CMP     R2,R1
13770 LDMEQFD R13!,{R0-R12,PC}
13780 :
13790 CMP     R6,#1                   ;quick calc?
13800 MOVEQ      R3,#(24000 AND &FF00)
13810 ADDEQ   R3,R3,#(24000 AND &00FF)
13820 CMPEQ   R3,R2
13830 MOVEQ      R3,#(25175 AND &FF00)
13840 ADDEQ   R3,R3,#(25175 AND &00FF)
13850 CMPEQ   R3,R1                   ;give up if quick calc and current = 24MHz but new = 25.175MHz
13860 LDMEQFD R13!,{R0-R12,PC}        ;(quick calc routine isn't accurate enough for this!)
13870 :
13880 STR     R1,[R12,#clockspeed]
13940 :
13950 ]:IF qtmrast% THEN
13960  [OPT opt%
13970  :                              ;v1.49 bug fix (used R0 for clockspeed, should be R1!)
13980  AND    R0,R1,#&FF00            ;v1.43se for RasterMan... adjust CIA dec value for VGA or other
13990  CMP       R0,#&6200            ;are we currently 25175MHz? (well anywhere between 25088-25343)
14000  MOVNE  R0,#1<<16               ;if not, use CIA decrement value for 24/36/48MHz
14010  MOVEQ     R0,#&F400            ;if 25175MHz then..
14020  ORREQ  R0,R0,#&000D            ;..use CIA dec value for 25175MHz [CIAdec is n/r for normal QTM]
14030  STR    R0,[R12,#rm_CIAdec]     ;store
14040 ]
14050 ENDIF
14060 [OPT opt%
14061 :
14062 MOV     R0,R1,LSL#12            ;R1 is still clockspeed at this point
14063 MOV     R1,#1000
14064 BL      r0_div_r1
14065 STR     R0,[R12,#shiftclock]
14070 :
14080 TEQ     PC,PC                   ;v1.49 this should only be called from ARM2/ARM3 no need for 32b
14090 FNmrs("EQ","R9,CPSR")
14100 MOVNE   R9,PC
14110 ORREQ   R8,R9,#(%1<<7) OR %11   ; SVC, no interrupts
14120 ORRNE   R8,R9,#(%1<<27) OR %11
14130 FNmsr("EQ","CPSR_c,R8")
14140 TEQNEP  R8,#0                   ;we have to be in svc if 'recalc_uS_4clock' is called (for SWIs)
14150 MOV     R0,R0
14160 STMFD   R13!,{R14}
14170 BL      recalc_uS_4clock
14180 LDMFD   R13!,{R14}
14190 TEQ     PC,PC
14200 FNmsr("EQ","CPSR_c,R9")         ; Back to original mode (IRQ, no interrupts)
14210 TEQNEP  R9,#0
14220 MOV     R0,R0
14230 LDMFD   R13!,{R0-R12,PC}
14240 
14250 
14260 ; v1.48 test ARM2/3 unroll loops on loading
14270 
14280 
14290 .a2_jumptable                   ;**THIS EDITS MODULE** should move to RMA...
14300 .jmp_a2_endanyvol  EQUD 0       ;*
14310 .jmp_a2_endfullvol EQUD 0       ;*
14320 .jmp_a2_repanyvol  EQUD 0       ;*
14330 .jmp_a2_repfullvol EQUD 0       ;*
14340 .jmp_a2_repnovol   EQUD 0       ;*
14350 .jmp_a2_clearing   EQUD 0       ;*
14360 .jmp_a2_anyvolume  EQUD 0       ;*
14370 .jmp_a2_fullvolume EQUD 0       ;*
14380 EQUD    0                       ;terminate with 0-word
14390 
14400 ;.rm_a2_endanyvol_unroll ;div 4
14410 ; -> ADR     R14,endanyvol_loop  ;ADD/SUB R14,PC,#0
14420 ;LDRB    R6,[R0,R1,ASR#12]       ;*** sample HAS to end this time ***
14430 ;:
14440 ;.endanyvol_loop
14450 ;SUBS    R6,R6,R3
14460 ;MOVMI   R6,#0
14470 ;STRB    R6,[R12],R11
14480 ;ADDS    R1,R1,R2                ;CS if -ve cleared, VS if +ve gets too large (becomes -ve)
14490 ;LDRLTB  R6,[R0,R1,ASR#12]
14500 ;MOVGE   R6,#0                   ;v1.48 optimised to avoid BGE a2_clearend
14510 ;:
14520 ; -> CMP     R12,R10
14530 ; -> MOVLT   PC,R14
14540 ;LDMFD   R13!,{R4-R6,R12,PC}^
14550 
14560 
14570 .a2_endanyvol_unroll            ;code must be unrolled before use!
14580 ]:IF qtmrast% THEN [OPT opt%:ADR R14,a2_endanyvol_loop:]:REM allow 416 and 832 DMA fill to loop
14590 [OPT opt%
14600 LDRB    R6,[R0,R1,ASR#12]       ;*** sample HAS to end this time ***
14610 :
14620 .a2_endanyvol_loop
14630 SUBS    R6,R6,R3
14640 MOVMI   R6,#0
14650 STRB    R6,[R12],R11
14660 ADDS    R1,R1,R2                ;CS if -ve cleared, VS if +ve gets too large (becomes -ve)
14670 LDRLTB  R6,[R0,R1,ASR#12]
14680 MOVGE   R6,#0                   ;v1.48 optimised to avoid BGE a2_clearend
14690 :
14700 ]:IF qtmrast% THEN [OPT opt%:CMP R12,R10:MOVLT PC,R14:] :REM allow 416 and 832 DMA fill to loop
14710 [OPT opt%
14720 LDMFD   R13!,{R4-R6,R12,PC}^
14730 
14740 
14750 .a2_endfullvol_unroll
14760 ]:IF qtmrast% THEN [OPT opt%:ADR R14,a2_endfullvol_loop:]:REM allow 416 and 832 DMA fill to loop
14770 [OPT opt%
14780 CMP     R11,#&0FF00000          ;ensure LT flags are set (r11 is ALWAYS <&0FF00000 chans!)
14790 :
14800 .a2_endfullvol_loop
14810 LDRLTB  R6,[R0,R1,ASR#12]
14820 STRB    R6,[R12],R11
14830 ADDLTS  R1,R1,R2
14840 MOVGE   R6,#0                   ;put data=0 after sample has ended
14850 :
14860 ]:IF qtmrast% THEN [OPT opt%:CMP R12,R10:MOVLT PC,R14:] :REM allow 416 and 832 DMA fill to loop
14870 [OPT opt%
14880 LDMFD   R13!,{R4-R6,R12,PC}^
14890 
14900 
14910 .a2_repanyvol_unroll
14920 ]:IF qtmrast% THEN [OPT opt%:ADR R14,a2_repanyvol_loop:]:REM allow 416 and 832 DMA fill to loop
14930 [OPT opt%
14940 .a2_repanyvol_loop
14950 LDRB    R6,[R4,R1,ASR#12]
14960 SUBS    R6,R6,R3
14970 MOVMI   R6,#0
14980 STRB    R6,[R12],R11
14990 ADDS    R1,R1,R2
15000 SUBGE   R1,R1,R5,LSL#12         ;********** ron addr
15010 :
15020 ]:IF qtmrast% THEN [OPT opt%:CMP R12,R10:MOVLT PC,R14:] :REM allow 416 and 832 DMA fill to loop
15030 [OPT opt%
15040 STR     R4,[R8,#DMA_address]    ;store repeat address as DMA address now!
15050 LDMFD   R13!,{R4-R6,R12,PC}^
15060 
15070 
15080 .a2_repfullvol_unroll
15090 ]:IF qtmrast% THEN [OPT opt%:ADR R14,a2_repfullvol_loop:]:REM allow 416 and 832 DMA fill to loop
15100 [OPT opt%
15110 .a2_repfullvol_loop
15120 LDRB    R6,[R4,R1,ASR#12]
15130 STRB    R6,[R12],R11
15140 ADDS    R1,R1,R2
15150 SUBGE   R1,R1,R5,LSL#12         ;********** ron addr
15160 :
15170 ]:IF qtmrast% THEN [OPT opt%:CMP R12,R10:MOVLT PC,R14:] :REM allow 416 and 832 DMA fill to loop
15180 [OPT opt%
15190 STR     R4,[R8,#DMA_address]    ;store repeat address as DMA address now!
15200 LDMFD   R13!,{R4-R6,R12,PC}^
15210 
15220 
15230 .a2_repnovol_unroll
15240 MOV     R6,#0
15250 ]:IF qtmrast% THEN [OPT opt%:ADR R14,a2_repnovol_loop:]:REM allow 416 and 832 DMA fill to loop
15260 [OPT opt%
15270 .a2_repnovol_loop
15280 STRB    R6,[R12],R11
15290 ADDS    R1,R1,R2
15300 SUBGE   R1,R1,R5,LSL#12
15310 :
15320 ]:IF qtmrast% THEN [OPT opt%:CMP R12,R10:MOVLT PC,R14:] :REM allow 416 and 832 DMA fill to loop
15330 [OPT opt%
15340 STR     R4,[R8,#DMA_address]    ;store repeat address as DMA address now!
15350 LDMFD   R13!,{R4-R6,R12,PC}^
15360 
15370 
15380 .a2_clearing_unroll
15390 ]:IF qtmrast% THEN [OPT opt%:ADR R14,a2_clearing_loop:]:REM allow 416 and 832 DMA fill to loop
15400 [OPT opt%
15410 .a2_clearing_loop
15420 STRB    R6,[R12],R11
15430 :
15440 ]:IF qtmrast% THEN [OPT opt%:CMP R12,R10:MOVLT PC,R14:] :REM allow 416 and 832 DMA fill to loop
15450 [OPT opt%
15460 LDMFD   R13!,{R6,PC}^
15470 
15480 
15490 .a2_anyvolume_unroll
15500 ]:IF qtmrast% THEN [OPT opt%:ADR R14,a2_anyvol_loop:]:REM allow 416 and 832 DMA fill to loop
15510 [OPT opt%
15520 .a2_anyvol_loop
15530 LDRB    R6,[R0,R1,ASR#12]
15540 SUBS    R6,R6,R3
15550 MOVMI   R6,#0
15560 STRB    R6,[R12],R11
15570 ADD     R1,R1,R2
15580 :
15590 ]:IF qtmrast% THEN [OPT opt%:CMP R12,R10:MOVLT PC,R14:] :REM allow 416 and 832 DMA fill to loop
15600 [OPT opt%
15610 LDMFD   R13!,{R4-R6,R12,PC}^
15620 
15630 
15640 .a2_fullvolume_unroll
15650 ]:IF qtmrast% THEN [OPT opt%:ADR R14,a2_fullvol_loop:]:REM allow 416 and 832 DMA fill to loop
15660 [OPT opt%
15670 .a2_fullvol_loop
15680 LDRB    R6,[R0,R1,ASR#12]
15690 STRB    R6,[R12],R11
15700 ADD     R1,R1,R2
15710 :
15720 ]:IF qtmrast% THEN [OPT opt%:CMP R12,R10:MOVLT PC,R14:] :REM allow 416 and 832 DMA fill to loop
15730 [OPT opt%
15740 LDMFD   R13!,{R4-R6,R12,PC}^
15750 
15760 
15770 .unroll_a2_DMA
15780 STMFD   R13!,{R1-R2,R14}
15790 ADR     R1,unroll_table
15800 ADR     R0,a2_endanyvol_unroll :BL   unroll_code:STRVC R0,jmp_a2_endanyvol
15810 ADRVC   R0,a2_endfullvol_unroll:BLVC unroll_code:STRVC R0,jmp_a2_endfullvol
15820 ADRVC   R0,a2_repanyvol_unroll :BLVC unroll_code:STRVC R0,jmp_a2_repanyvol
15830 ADRVC   R0,a2_repfullvol_unroll:BLVC unroll_code:STRVC R0,jmp_a2_repfullvol
15840 ADRVC   R0,a2_repnovol_unroll  :BLVC unroll_code:STRVC R0,jmp_a2_repnovol
15850 ADRVC   R0,a2_clearing_unroll  :BLVC unroll_code:STRVC R0,jmp_a2_clearing
15860 ADRVC   R0,a2_anyvolume_unroll :BLVC unroll_code:STRVC R0,jmp_a2_anyvolume
15870 ADRVC   R0,a2_fullvolume_unroll:BLVC unroll_code:STRVC R0,jmp_a2_fullvolume
15880 LDMFD   R13!,{R1-R2,PC}
15890 
15900 
15910 .release_a2_DMA
15920 STMFD   R13!,{R0-R2,R14}
15930 ADR     R1,a2_jumptable
15940 .release_a2_loop
15950 LDR     R0,[R1],#4
15960 TEQ     R0,#0
15970 LDMEQFD R13!,{R0-R2,PC}^
15980 BL      releaseRMA
15990 BVC     release_a2_loop
16000 STR     R0,[R13,#0]
16010 LDMFD   R13!,{R0-R2,PC}
16020 
16030 
16040 .unroll_code
16050 STMFD   R13!,{R2-R10,R14}       ;r0=unroll addr, r1=unroll table; return r0=RMA addr, r1=next tab
16060 MOV     R9,R0                   ;copy from addr
16070 MOV     R14,R1                  ;temp store R1 (table) in R14
16080 :
16090 MOV     R0,#0
16100 .unroll_findsize
16110 LDR     R3,[R1],#4
16120 ANDS    R2,R3,#&FF              ;number insts
16130 MOVNE   R3,R3,LSR#8             ;number reps
16140 MOVNE   R2,R2,LSL#2             ;size of insts
16150 MLANE   R0,R3,R2,R0             ;size of unrolled
16160 BNE     unroll_findsize
16170 :
16180 MOV     R1,R14                  ;restore R1 to top of this decode data table
16190 BL      claimRMA                ;R0=size in bytes
16200 LDMVSFD R13!,{R2-R10,PC}
16210 :
16220 MOV     R7,R0                   ;destination addr
16230 .unroll_block
16240 LDR     R8,[R1],#4
16250 TEQ     R8,#0                   ;number insts and repeats, =0 if end of entry
16260 LDMEQFD R13!,{R2-R10,PC}
16270 :
16280 MOV     R6,R8,LSR#8             ;r6=number reps
16290 .unroll_codeloop
16300 MOV     R4,R9                   ;r4=copy from address
16310 AND     R5,R8,#&FF              ;r5=number insts to copy per loop
16320 .unroll_copyinsts
16330 LDR     R3,[R4],#4
16340 STR     R3,[R7],#4
16350 SUBS    R5,R5,#1
16360 BGT     unroll_copyinsts
16370 SUBS    R6,R6,#1
16380 BGT     unroll_codeloop
16390 MOV     R9,R4                   ;next inst to copy
16400 B       unroll_block
16410 
16420 
16430 ]:IF qtmrast% THEN dmarep=dma/4 ELSE dmarep=dma
16440 [OPT opt%
16450 
16460 
16470 .unroll_table                      ;a2_endanyvol_unroll
16480 EQUD (1<<8) + 1 + 1*(-1*qtmrast%)  ;rep 1 time, first inst, if qtmrast% add 1 more inst (ADR R14)
16490 EQUD (dmarep<<8) + 6               ;repeat dmarep times (208 for non-RM QTM), 6 insts
16500 EQUD (1<<8) + 1 + 2*(-1*qtmrast%)  ;rep 1 time, 1 inst, if qtmrast% add 2 more insts (CMP, MOVLT)
16510 EQUD 0
16520 :
16530 EQUD (1<<8) + 1 + 1*(-1*qtmrast%)  ;a2_endfullvol_unroll, if qtmrast% add 1 more inst (ADR R14)
16540 EQUD (dmarep<<8) + 4
16550 EQUD (1<<8) + 1 + 2*(-1*qtmrast%)  ;if qtmrast% this adds 2 more insts (CMP, MOVLT PC,R14)
16560 EQUD 0
16570 :
16580 ]:IF qtmrast% THEN [OPT opt%:EQUD (1<<8) + 1 ;repeat 1 time, first 1 inst (ADR R14,loop):]
16590 [OPT opt%
16600 EQUD (dmarep<<8) + 6               ;a2_repanyvol_unroll
16610 EQUD (1<<8) + 2 + 2*(-1*qtmrast%)  ;if qtmrast% this adds 2 more insts (CMP, MOVLT PC,R14)
16620 EQUD 0
16630 :
16640 ]:IF qtmrast% THEN [OPT opt%:EQUD (1<<8) + 1 ;repeat 1 time, first 1 inst (ADR R14,loop):]
16650 [OPT opt%
16660 EQUD (dmarep<<8) + 4               ;a2_repfullvol_unroll
16670 EQUD (1<<8) + 2 + 2*(-1*qtmrast%)  ;if qtmrast% this adds 2 more insts (CMP, MOVLT PC,R14)
16680 EQUD 0
16690 :
16700 EQUD (1<<8) + 1 + 1*(-1*qtmrast%)  ;a2_repnovol_unroll, if qtmrast% add 1 more inst (ADR R14)
16710 EQUD (dmarep<<8) + 3
16720 EQUD (1<<8) + 2 + 2*(-1*qtmrast%)  ;if qtmrast% this adds 2 more insts (CMP, MOVLT PC,R14)
16730 EQUD 0
16740 :
16750 ]:IF qtmrast% THEN [OPT opt%:EQUD (1<<8) + 1 ;repeat 1 time, first 1 inst (ADR R14,loop):]
16760 [OPT opt%
16770 EQUD (dmarep<<8) + 1               ;a2_clearing_unroll
16780 EQUD (1<<8) + 1 + 2*(-1*qtmrast%)  ;if qtmrast% this adds 2 more insts (CMP, MOVLT PC,R14)
16790 EQUD 0
16800 :
16810 ]:IF qtmrast% THEN [OPT opt%:EQUD (1<<8) + 1 ;repeat 1 time, first 1 inst (ADR R14,loop):]
16820 [OPT opt%
16830 EQUD (dmarep<<8) + 5               ;a2_anyvolume_unroll
16840 EQUD (1<<8) + 1 + 2*(-1*qtmrast%)  ;if qtmrast% this adds 2 more insts (CMP, MOVLT PC,R14)
16850 EQUD 0
16860 :
16870 ]:IF qtmrast% THEN [OPT opt%:EQUD (1<<8) + 1 ;repeat 1 time, first 1 inst (ADR R14,loop):]
16880 [OPT opt%
16890 EQUD (dmarep<<8) + 3               ;a2_fullvolume_unroll
16900 EQUD (1<<8) + 1 + 2*(-1*qtmrast%)  ;if qtmrast% this adds 2 more insts (CMP, MOVLT PC,R14)
16910 EQUD 0
16920 
16930 ]
16940 =opt%
