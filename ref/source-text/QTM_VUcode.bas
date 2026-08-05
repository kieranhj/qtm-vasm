   10 REM QTM 1.48 VU code and fake DMA buffer filler routine
   20 REM
   30 REM 8 channel compatible (from v1.30a 8/4/97)
   40 REM New fake DMA filler and real VUs code (18/4/2001)
   50 REM
   60 REM LEN Steve Harrison 1994-2023
   70 END
   80 
   90 DEF FNvucode
  100 [OPT opt%
  110 .swi_qtmreadvulevels               ;R0=0 for 1-4 only, &80 for 1-8
  120 STMFD   R13!,{R14}
  130 CMP     R0,#0
  140 CMPNE   R0,#&80
  150 BLNE    checkchannel
  160 LDMVSFD R13!,{PC}
  170 :
  180 TEQ     R0,#0
  190 TEQNE   R0,#&80
  200 BEQ     loadvuaswords
  210 :
  220 LDRB    R14,[R12,#chans_use]
  230 CMP     R0,R14
  240 MOVGT   R0,#0
  250 :
  260 ADDLE   R14,R12,#vuheights-1
  270 LDRLEB  R0,[R14,R0]
  280 CMP     R0,R0 ; Clear V
  290 LDMFD   R13!,{PC}
  300 :
  310 .loadvuaswords
  320 TEQ     R0,#&80
  330 LDR     R0,[R12,#vuheights]
  340 LDREQ   R1,[R12,#vuheights58]
  350 CMP     R0,R0 ; Clear V
  360 LDMFD   R13!,{PC}
  370 
  380 
  390 .swi_qtmvubarctrl               ;R0=0-3 or -1,  R1=gravity or -1
  400 STMFD   R13!,{R14}              ;can be internally called (eg. exit code)
  410 CMN     R0,#1
  420 BLT     err_swi_qtmvubarctrl
  430 CMP     R0,#3
  440 BGT     err_swi_qtmvubarctrl
  450 :
  460 STMFD   R13!,{R2-R3}
  470 LDRB    R2,[R12,#vustate]
  480 LDRB    R3,[R12,#vugravity]
  490 :
  500 CMN     R0,#1                   ;if not -1
  510 CMPNE   R0,R2                   ;and not same as current
  520 BLNE    switchVUsoff            ;switch vus off (will return if current=0)
  530 LDMVSFD R13!,{R2-R3,PC}
  540 CMP     R0,#1
  550 CMPNE   R0,#2
  560 CMPNE   R0,#3
  570 BLEQ    switchVUson
  580 LDMVSFD R13!,{R2-R3,PC}
  590 MOV     R0,R2
  600 :
  610 CMP     R1,#0
  620 STRGTB  R1,[R12,#vugravity]
  630 MOV     R1,R3
  640 CMP     R0,R0 ; Clear V
  650 LDMFD   R13!,{R2-R3,PC}
  660 .err_swi_qtmvubarctrl
  670 MOV     R0,#&8000000
  680 SUBS    R0,R0,#1 ; Set V
  690 ADR     R0,err_vustate
  700 LDMFD   R13!,{PC}
  710 
  720 
  730 .err_vustate
  740 EQUD    qtm_error+&0F
  750 EQUS    "Bad VU controller state"
  760 EQUB    0
  770 ALIGN
  780 
  790 
  800 .switchVUsoff
  810 CMP     R2,#0
  820 MOVEQ   PC,R14
  830 STMFD   R13!,{R0-R2,R14}
  840 :
  850 ]:IF NOT qtmrast% THEN
  851 [OPT opt%
  870 MOV     R0,#16                  ;Event not used in RasterMan version, this is called from DMA IRQ
  880 ADR     R1,VUcontroller
  890 MOV     R2,R12
  900 SWI     "XOS_Release"
  910 BVS     vus_err
  920 :
  930 MOV     R0,#13
  940 MOV     R1,#4
  950 SWI     "XOS_Byte"
  960 ]
  961 ENDIF
  962 [OPT opt%
  970 MOV     R1,#0
  980 STRB    R1,[R12,#vustate]
  990 LDMVCFD R13!,{R0-R2,PC}
 1000 .vus_err
 1010 STR     R0,[R13]
 1020 LDMFD   R13!,{R0-R2,PC}
 1030 
 1040 
 1050 .switchVUson
 1060 CMP     R2,R0
 1070 MOVEQ   PC,R14                  ;exit if new=current
 1080 STMFD   R13!,{R0-R2,R14}
 1090 STRB    R0,[R12,#vustate]
 1100 :
 1101 ]:IF NOT qtmrast% THEN
 1102 [OPT opt%
 1110 MOV     R0,#16                  ;Event not used in RasterMan version, this is called from DMA IRQ
 1120 ADR     R1,VUcontroller
 1130 MOV     R2,R12
 1140 SWI     "XOS_Claim"
 1150 BVS     vus_err
 1160 :
 1170 MOV     R0,#14
 1180 MOV     R1,#4
 1190 SWI     "XOS_Byte"
 1191 ]
 1192 ENDIF
 1193 [OPT opt%
 1200 LDMFD   R13!,{R0-R2,PC}
 1210 
 1220 
 1230 .VUcontroller
 1240 STMFD   R13!,{R14}
 1250 CMP     R0,#4
 1260 LDMNEFD R13!,{PC}
 1270 LDRB    R14,[R12,#vustate]
 1280 CMP     R14,#3
 1290 BEQ     realVUs
 1300 CMP     R14,#2
 1310 BEQ     effectVUs
 1320 B       fakeVUs
 1330 
 1340 
 1350 .fakeVUs                        ;r14 stored, r12=song_data
 1360 STMFD   R13!,{R0-R5}
 1370 LDRB    R0,[R12,#vuflags]
 1380 LDRB    R1,[R12,#vugravity]
 1390 LDR     R2,[R12,#vuheights]
 1400 MOV     R14,#8
 1410 .fakevuloop
 1420 MOV     R5,R2,LSR#24
 1430 MOV     R4,R2,LSR#16
 1440 AND     R4,R4,#&FF
 1450 MOV     R3,R2,LSR#8
 1460 AND     R3,R3,#&FF
 1470 AND     R2,R2,#&FF
 1480 :
 1490 TST     R0,#%1<<0       ;1st/5th chan
 1500 MOVNE   R2,#64
 1510 SUBEQ   R2,R2,R1
 1520 CMP     R2,#0
 1530 MOVMI   R2,#0
 1540 TST     R0,#%1<<1       ;2nd/6th chan
 1550 MOVNE   R3,#64
 1560 SUBEQ   R3,R3,R1
 1570 CMP     R3,#0
 1580 ORRGT   R2,R2,R3,LSL#8
 1590 TST     R0,#%1<<2       ;3rd/7th chan
 1600 MOVNE   R4,#64
 1610 SUBEQ   R4,R4,R1
 1620 CMP     R4,#0
 1630 ORRGT   R2,R2,R4,LSL#16
 1640 TST     R0,#%1<<3       ;4th/8th chan
 1650 MOVNE   R5,#64
 1660 SUBEQ   R5,R5,R1
 1670 CMP     R5,#0
 1680 ORRGT   R2,R2,R5,LSL#24
 1690 :
 1700 SUBS    R14,R14,#8
 1710 STRGE   R2,[R12,#vuheights]
 1720 MOVGE   R2,#0
 1730 STRGEB  R2,[R12,#vuflags]
 1740 LDRGE   R2,[R12,#vuheights58]
 1750 MOVGE   R0,R0,LSR#4
 1760 BGE     fakevuloop
 1770 STR     R2,[R12,#vuheights58]
 1780 LDMFD   R13!,{R0-R5,PC}
 1790 
 1800 
 1810 .effectVUs                      ;r14 stored, r12=song_data
 1820 STMFD   R13!,{R0-R6,R10,R11}
 1830 ADD     R11,R12,#(channeldata-song_data)
 1840 ADD     R10,R12,#(DMA_blocks-song_data)
 1850 LDRB    R0,[R12,#vuflags]
 1860 LDRB    R1,[R12,#vugravity]
 1870 MOV     R2,#1
 1880 ADD     R3,R12,#vuheights
 1890 MOV     R4,#0
 1900 .seteffectVUs
 1910 LDRB    R5,[R3,R4]
 1920 TST     R0,R2,LSLR4
 1930 LDRNEB  R5,[R11,#currentvol]
 1940 BNE     doneeffectVU            ;note just played, so set to current volume
 1950 :
 1960 LDRB    R6,[R11,#currentFXnum]
 1970 CMP     R6,#&5
 1980 CMPNE   R6,#&6
 1990 CMPNE   R6,#&A
 2000 CMPNE   R6,#&C
 2010 LDREQB  R5,[R11,#currentvol]    ;any of those effects, then set height to current volume
 2020 BEQ     doneeffectVU
 2030 CMP     R6,#&7                  ;volume wobble? - set to actual (DMA) volume
 2040 LDREQB  R5,[R10,#DMA_volume]    ;fixed 29/6/97 (applied 16/4/01!)-didn't read from correct DMA addr
 2050 BEQ     doneeffectVU
 2060 :
 2070 CMP     R6,#&E
 2080 BNE     graveffectVU            ;VU not affected by any effects...
 2090 LDRB    R6,[R11,#currentFXdata]
 2100 MOV     R6,R6,LSR#4
 2110 CMP     R6,#&A
 2120 CMPNE   R6,#&B
 2130 CMPNE   R6,#&C
 2140 CMPNE   R6,#&D
 2150 LDREQB  R5,[R11,#currentvol]
 2160 BEQ     doneeffectVU
 2170 :
 2180 .graveffectVU
 2190 SUBS    R5,R5,R1
 2200 MOVMI   R5,#0
 2210 .doneeffectVU
 2220 STRB    R5,[R3,R4]
 2230 ADD     R4,R4,#1
 2240 ADD     R11,R11,#64
 2250 ADD     R10,R10,#24
 2260 CMP     R4,#8
 2270 BLT     seteffectVUs
 2280 :
 2290 MOV     R0,#0
 2300 STRB    R0,[R12,#vuflags]
 2310 LDMFD   R13!,{R0-R6,R10,R11,PC}
 2320 
 2330 
 2340 ;
 2350 ; New real VU code 18/4/2001
 2360 ;
 2370 ; This code calculates the VU levels by examining the samples QTM is currently playing
 2380 ; rather than scanning the RISC OS DMA buffer data and calculating the levels from there.
 2390 ;
 2400 ; The new routine produces identical output to scanning the DMA buffer (on 8bit sound comps)
 2410 ; however now works on RiscPCs with 16bit sound, which do not have an 8bit sound buffer!
 2420 ;
 2430 
 2440 
 2450 .realVUs                                ;new realVUs code (gives correct result on 16bit sound)
 2460 STMFD   R13!,{R0-R12}                   ;r14 stored already
 2470 MOV     R0,#0
 2480 STRB    R0,[R12,#vuflags]
 2490 :
 2500 MOV     R9,R12                          ;R9=start of QTM vars block (R12 usually)
 2510 ADD     R8,R9,#(DMA_blocks-song_data)   ;R8=channel DMA data
 2520 LDRB    R11,[R9,#chans_use]             ;R11=4 or 8 chans (=4 or 8 bytes to skip each chan byte)
 2530 :
 2540 LDR     R2,[R9,#vuheights]              ;old heights for channels 1-4
 2550 MOV     R3,#0                           ;new heights for channels 1-4, 5-8
 2560 MOV     R6,#0
 2570 .realvu_channelloop
 2580 BL      realvu_chanctrl                 ;returns R0=new average vu height for this channel
 2590 AND     R1,R2,#&FF                      ;old average vu height for this channel
 2600 ADD     R1,R1,R0
 2610 ORR     R3,R3,R1,LSR#1                  ;put averaged value in R3
 2620 MOV     R3,R3,ROR#8
 2630 MOV     R2,R2,ROR#8
 2640 :
 2650 ADD     R8,R8,#24
 2660 ADD     R6,R6,#1
 2670 TEQ     R6,#4
 2680 STREQ   R3,[R9,#vuheights]              ;store new heights for channels 1-4
 2690 MOVEQ   R3,#0
 2700 LDREQ   R2,[R9,#vuheights58]            ;old heights for channels 5-8
 2710 CMP     R6,R11
 2720 BLT     realvu_channelloop
 2730 :
 2740 STR     R3,[R9,#vuheights58]            ;store new heights for channels 5-8
 2750 LDMFD   R13!,{R0-R12,PC}
 2760 
 2770 
 2780 .realvu_chanctrl                ;r6=channel-1 (0-7)
 2790 STMFD   R13!,{R1-R12,R14}       ;
 2800 LDMIA   R8,{R0-R5}              ;r0=end addr, r1=-ve offset, r2=pitch, r3=vol/flag, r4=rlen
 2810 CMN     R1,#4096                ;is offset >-4096? (ie. offset>>12 <1)?   (remember -ve!)
 2820 MOVGT   R7,#3                   ; <put min loop len in r7>
 2830 CMPGT   R7,R5                   ; <backwards!!! this does CMP 3,len so LE if valid!!!)
 2840 BGT     realvu_blankchannel     ;if offset>-4096 and 3>repeat len, then exit
 2850 :
 2860 CMP     R0,#0                   ;v1.45 - huge bug - can't believe address=0 worked for so long!
 2870 CMPNE   R2,#0
 2880 BLE     realvu_blankchannel     ;pitch is 0, so sample is blank
 2890 :
 2900 .realvu_chanrunning
 2910 MOVS    R3,R3,LSL#24            ;if DMA_sampleflag set, CS because &FF shifted off
 2920 ADDCC   R7,R9,#(musicvoltable-song_data)
 2930 ADDCS   R7,R9,#(samplevoltable-song_data)
 2940 LDRB    R3,[R7,R3,LSR#24]       ;load Arc scaled volume
 2950 :
 2960 CMP     R3,#254                 ;if volume is too low
 2970 BGE     realvu_blankchannel     ;channel is blank....
 2980 :
 2990 CMP     R2,#1024                        ;
 3000 ADDLT   R7,R9,#(arcperiods-song_data)
 3010 LDRLT   R2,[R7,R2,LSL#2]                ;load Arc pitch increment
 3020 BLGE    amigatoarcpitch_1024            ;for high periods, use calculation - returns r2=arc pitch
 3030 :
 3040 CMP     R5,#2                   ;is this sample a looping sample?
 3050 MOVLT   R5,#2                   ;if not, make repoff=2, so when sample ends, last 2 bytes repeat
 3060 :
 3070 FNlong_adr("  ",10,loglintab)
 3080 MOV     R11,#0
 3090 MOV     R12,#128                ;get average real vu height from 128 bytes of DMA data
 3100 :
 3110 .realvu_sampleloop              ;this code handles samples which play/repeat/end at any vol
 3120 LDRB    R14,[R0,R1,ASR#12]      ;load a byte of sample data
 3130 SUBS    R14,R14,R3              ;scale for volume
 3140 BICGT   R14,R14,#%00000001      ;make +ve log (=even no.s)
 3150 LDRGTB  R14,[R10,R14]           ;load +ve linear byte (0-127)
 3160 ADDGT   R11,R11,R14             ;if>0 accumulate
 3170 ADDS    R1,R1,R2,LSL#1          ;add pitch*2, have we ended? (offset becomes GE)?
 3180 SUBGES  R1,R1,R5,LSL#12         ;...if so, get back to repeat start (and check offset now ok)
 3190 SUBGE   R1,R1,R5,LSL#12         ;...if offset still -ve, get back to repeat start
 3200 :
 3210 SUBS    R12,R12,#2
 3220 BGT     realvu_sampleloop       ;if fake DMA ok and still playing, then loop back
 3230 :
 3240 ; now R11 has 64*bytes (0 to 127), so need to divide by 128 (= >>7)to get value 0-63
 3250 :
 3260 MOV     R0,R11,LSR#7            ;return R0=average vu level (0-64) for this DMA fill
 3270 :
 3280 ;ADD     R0,R0,R0,LSR#2          ;**old** linear scale-up so the vu fills 0-64 better
 3290 ;AND     R0,R0,#63               ; (..this on does 0-80, then clips down to 0-63!)
 3300 :
 3310 RSB     R0,R0,#64               ;better log sq'd scale-up routine (T's ;-)
 3320 MOV     R1,R0                   ;
 3330 MUL     R0,R1,R0                ;
 3340 MOV     R0,R0,LSR#6             ;
 3350 RSB     R0,R0,#64               ;this does 0-64 on a log (sq'd) curve, so low vols are more amp'd
 3360 CMP     R0,R0 ; Clear V
 3370 LDMFD   R13!,{R1-R12,PC}
 3380 
 3390 
 3400 .realvu_blankchannel
 3410 MOV     R0,#0
 3420 LDMFD   R13!,{R1-R12,PC}        ;exit with R0=vu height for this channel
 3430 
 3440 
 3450 ;
 3460 ; SWI QTM_DMABuffer and fake DMA Buffer creation routine for 16bit sound RiscPCs
 3470 ;
 3480 
 3490 
 3500 .swi_qtmdmabuffer
 3510 LDR     R0,[R12,#fake8bitDMA]
 3520 TEQ     R0,#0
 3530 LDREQ   R0,[R12,#DMABuffer]
 3540 MOVEQ   PC,R14
 3550 :
 3560 STMFD   R13!,{R14}
 3570 BL      calcscope               ;update fake DMA block for 16bit-sound RiscPCs
 3580 LDMFD   R13!,{PC}
 3590 
 3600 
 3610 .calcscope                              ;called by SWI QTM_DMABuffer on 16bit sound RiscPCs
 3620 STMFD   R13!,{R0-R12,R14}               ;to generate a fake 8bit sound DMA buffer for progs use!
 3630 MOV     R9,R12                          ;R9=start of QTM vars block (R12 usually)
 3640 LDR     R12,[R9,#fake8bitDMA]           ;R12=fake DMA address
 3650 :
 3660 ADD     R8,R9,#(DMA_blocks-song_data)   ;R8=channel DMA data
 3670 LDRB    R11,[R9,#chans_use]             ;R11=4 or 8 chans (=4 or 8 bytes to skip each chan byte)
 3680 ADD     R10,R12,R11,LSL#4
 3690 ADD     R10,R10,R11,LSL#6               ;v1.45
 3700 ADD     R10,R10,R11,LSL#7               ;***** fake DMA is always 208 bytes * no. of channels
 3710 :
 3720 MOV     R6,R11
 3730 .calcscope_channelloop
 3740 BL      calcscope_chanctrl
 3750 :
 3760 ADD     R8,R8,#24
 3770 ADD     R12,R12,#1
 3780 SUBS    R6,R6,#1
 3790 BGT     calcscope_channelloop
 3800 LDMFD   R13!,{R0-R12,PC}
 3810 
 3820 
 3830 .calcscope_chanctrl
 3840 STMFD   R13!,{R0-R12,R14}       ;
 3850 LDMIA   R8,{R0-R5}              ;r0=end addr, r1=-ve offset, r2=pitch, r3=vol/flag, r4=rlen
 3860 CMN     R1,#4096                ;is offset >-4096? (ie. offset>>12 <1)?   (remember -ve!)
 3870 MOVGT   R7,#3                   ; <put min loop len in r7>
 3880 CMPGT   R7,R5                   ; <backwards!!! this does CMP 3,len so LE if valid!!!)
 3890 BGT     calcscope_blankchannel  ;if offset>-4096 and 3>repeat len, then exit
 3900 :
 3910 CMP     R0,#0                   ;v1.45 - huge bug - can't believe address=0 worked for so long!
 3920 CMPNE   R2,#0
 3930 BLE     calcscope_blankchannel
 3940 :
 3950 .calcscope_chanrunning
 3960 MOVS    R3,R3,LSL#24            ;if DMA_sampleflag set, CS because &FF shifted off
 3970 ADDCC   R7,R9,#(musicvoltable-song_data)
 3980 ADDCS   R7,R9,#(samplevoltable-song_data)
 3990 LDRB    R3,[R7,R3,LSR#24]       ;load Arc scaled volume
 4000 :
 4010 CMP     R3,#254                 ;if volume is too low
 4020 BGE     calcscope_blankchannel  ;go to clear the channel...
 4030 :
 4040 :
 4050 CMP     R2,#1024                        ;
 4060 ADDLT   R7,R9,#(arcperiods-song_data)
 4070 LDRLT   R2,[R7,R2,LSL#2]                ;load Arc pitch increment
 4080 BLGE    amigatoarcpitch_1024            ;for high periods, use calculation - returns r2=arc pitch
 4090 :
 4100 CMP     R5,#2                   ;is this sample a looping sample?
 4110 MOVLT   R5,#2                   ;if not, make repoff=2, so when sample ends, last 2 bytes repeat
 4120 :
 4130 .calcscope_sampleloop           ;this code handles samples which play/repeat/end at any vol
 4140 LDRB    R6,[R0,R1,ASR#12]       ;load a byte of sample data
 4150 SUBS    R6,R6,R3                ;scale for volume
 4160 MOVMI   R6,#0                   ;reset to 0 if vol too low
 4170 STRB    R6,[R12],R11            ;store in fake DMA block
 4180 ADDS    R1,R1,R2                ;have we ended (offset becomes GE)?
 4190 SUBGE   R1,R1,R5,LSL#12         ;...if so, get back to repeat start
 4200 :
 4210 CMP     R12,R10                 ;check fake DMA end...
 4220 BLT     calcscope_sampleloop    ;if fake DMA ok and still playing, then loop back
 4230 LDMFD   R13!,{R0-R12,PC}
 4240 
 4250 
 4260 .calcscope_blankchannel
 4270 MOV     R6,#0                   ;
 4280 .calcscope_clear                ;
 4290 STRB    R6,[R12],R11            ;
 4300 CMP     R12,R10                 ;
 4310 STRLTB  R6,[R12],R11            ;
 4320 CMPLT   R12,R10                 ;
 4330 STRLTB  R6,[R12],R11            ;
 4340 CMPLT   R12,R10                 ;
 4350 STRLTB  R6,[R12],R11            ;
 4360 CMPLT   R12,R10                 ;only using 4 blankings per loop...
 4370 BLT     calcscope_clear         ;...cleared rest of channel
 4380 LDMFD   R13!,{R0-R12,PC}        ;exit
 4390 ]
 4400 =opt%
