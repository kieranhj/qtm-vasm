   10 REM QTM v1.48 4/6/8-channel compatible timer code
   20 REM
   30 REM LEN Steve Harrison 1994-2023
   40 END
   50 
   60 
   70 DEF FNtimercode
   80 [OPT opt%
   90 .swi_qtmplayingtime
  100 STMFD   R13!,{R14}
  110 BL      ensuresong
  120 LDMVSFD R13!,{PC}
  130 :
  140 STMFD   R13!,{R3-R5}
  150 CMN     R0,#1                             ;v1.45 are we returning centiseconds (=-1)?
  160 MOVEQ   R5,#1<<12                         ;if so, multiplier =1
  170 MOVNE      R5,#((1<<12)*0.01) AND &FF00   ;...otherwise return seconds, multiplier =0.01
  180 ADDNE   R5,R5,#((1<<12)*0.01) AND &00FF   ;...this will only work up to 9.1 hours!
  190 :
  200 SWI     "XOS_ReadMonotonicTime"
  210 LDR     R1,[R12,#start_time]
  220 LDR     R2,[R12,#total_time]
  230 LDR     R3,[R12,#pause_time]
  240 LDRB    R4,[R12,#songstatus]    ;v1.44 spotted this was LDR - bug, but was ok as aligned...
  250 TST     R4,#1<<2                ;playing?
  260 SUBEQ   R1,R3,R1                ;if stopped, time from last QTM_Start to QTM_Pause in r1
  270 MOVEQ   R0,R2                   ;            accumulated total time in r0
  280 SUBNE   R1,R0,R1                ;if playing, calc current time since last QTM_Start in r1
  290 ADDNE   R0,R2,R1                ;            calc current total time in r0
  300 :
  310 MUL     R0,R5,R0
  320 MOV     R0,R0,LSR#12
  330 MUL     R1,R5,R1                ;v1.45 improvement (was shifted 16 - only up to 18 mins!)
  340 MOV     R1,R1,LSR#12            ;      now shifted 12 = works up to 2.9 hours (174 mins)
  350 :
  360 LDR     R2,[R12,#est_time]
  370 CMP     R2,#0
  380 BLEQ    calctime                ;v1.45 now returns r2 in centiseconds
  390 STREQ   R2,[R12,#est_time]
  400 MUL     R2,R5,R2
  410 MOV     R2,R2,LSR#12
  420 LDMFD R13!,{R3-R5,PC}
  430 
  440 
  450 ;
  460 ;  QTM v1.22 timer code (c) 1993/4/5 Phoenix/Quantum
  470 ;
  480 
  490 
  500 .tmr_crashed
  510 MOV     R0,#&80000000
  520 SUBS    R0,R0,#1 ; Set V
  530 LDMFD   R13!,{R0-R1,R3-R11,R14}
  540 ADR     R0,err_worktime
  550 MOV     PC,R14
  560 
  570 .err_worktime
  580 EQUD    qtm_error+&0E
  590 EQUS    "Song time could not be calculated or song lasts over 9 hours!"+CHR$0
  600 ALIGN
  610 
  620 
  630 .tmr_setlinetime
  640 ;
  650 ; R9  s=speed
  660 ; R10 c=CIA tempo
  670 ;
  680 ; equation; time per line=10s/4c (*65536 for accuracy)
  690 ;
  700 STMFD   R13!,{R0-R1,R14}
  710 MOV     R0,#&28000
  720 MUL     R0,R9,R0
  730 MOV     R1,R10
  740 BL      r0_div_r1               ;do (10s<<16)/4c - result in r0<<16
  750 MOV     R8,R0
  760 LDMFD   R13!,{R0-R1,PC}
  770 
  780 
  790 ; R12=song_data
  800 ; R11=address of current word
  810 ; R10=CIA tempo (32-255)
  820 ; R9=speed (1-31)
  830 ; R8=time per line = (10*speed/4*cia tempo)*65536
  840 ; R7=time so far
  850 ; R6=channel-1 (0-4/6/8)
  860 ; R5=current word
  870 ; R4=sequence
  880 ; R3=event
  890 
  900 
  910 .calctime
  920 STMFD   R13!,{R0-R1,R3-R11,R14}
  930 BL      tmr_resetvars
  940 MOV     R10,#125
  950 MOV     R9,#6
  960 BL      tmr_setlinetime         ;R8=line time
  970 MOV     R7,#0                   ;R7=total time
  980 MOV     R4,#0
  990 MOV     R3,#0
 1000 :
 1010 .tmr_mainloop
 1020 LDRB    R0,[R12,#tm_patterndelay]
 1030 CMP     R0,#0
 1040 BNE     tmr_checkpattdel        ;...pattern delayed...
 1050 :
 1060 LDR     R3,[R12,#tm_currentevent];r3=sequence (16-24) event (0-7)
 1070 MOV     R4,R3,LSR#16
 1080 AND     R3,R3,#&FF
 1090 STRB    R4,[R12,#tm_lastsequence]
 1100 :
 1110 LDR     R11,[R12,#songaddr]     ;r11=song address
 1120 ADD     R11,R11,#952            ;r11=sequence table address
 1130 LDRB    R0,[R11,R4]             ;r0=pattern
 1140 ADD     R11,R11,#132            ;add 132, to get to start of patterns, and put in r11
 1150 :
 1160 LDR     R6,[R12,#patternlen]    ;v1.44 support for 8CHN and 6CHN
 1170 MLA     R11,R0,R6,R11           ;add current patt*patternlen to pattern start
 1180 MOV     R6,R6,LSR#6             ;patternlen/64=eventlen (16/24/32 for 4, 8FLT/6/8)
 1190 MLA     R11,R3,R6,R11           ;add on current event*event length (no longer just 16)
 1200 :
 1210 MOV     R6,#0                   ;r6=channel-1
 1220 .tmr_dochannels
 1230  ;TEQ     R6,#4                   ;v1.45 update, no longer need this...
 1240  ;LDREQB  R5,[R12,#songtype]      ;if chan 4 we must be > 4 chans (0-3) so either 6 or 8
 1250  ;TEQEQ   R5,#&10                 ;if also 'FLT8' type, need to get to next patt, add 1024
 1260  ;ADDEQ   R11,R11,#1024-16        ;...just a fudge-thing really
 1270 :
 1280 LDR     R5,[R11,R6,LSL#2]       ;load note word for this channel (r5)
 1290 AND     R0,R5,#&000F0000        ; \
 1300 CMP        R0,#&000B0000        ;  \_ if effects B,D,E,F
 1310 CMPNE      R0,#&000D0000        ;  /  then deal with them...
 1320 BLGE    tmr_checkoutFX          ; /
 1330 :
 1340 LDRB    R0,[R12,#songchans]
 1350 ADD     R6,R6,#1                ;add 1 to the channel counter
 1360 CMP     R6,R0                   ;is <4 or 8 (no more channels to do)?
 1370 BLT     tmr_dochannels          ;if not, then loop back
 1380 :
 1390 CMP     R9,#0                   ;is speed 0, after doing all channels?
 1400 BEQ     tmr_gottime             ;if so, we've got the time!
 1410 :
 1420 .tmr_checkpattdel
 1430 LDRB    R0,[R12,#tm_patterndelay]
 1440 SUBS    R0,R0,#1
 1450 STRGEB  R0,[R12,#tm_patterndelay];take off pattern delay (if running)
 1460 :
 1470 LDR     R3,[R12,#tm_currentevent];load r3 with sequence (16-23) event (0-7)
 1480 ADDLE   R3,R3,#1                ;add 1 to event counter
 1490 MOV     R4,R3,LSR#16
 1500 :
 1510 LDRB    R0,[R12,#tm_breakflags] ;load the break flag byte
 1520 CMP     R0,#0                   ;is it 0?
 1530 BNE     tmr_checkjumps          ;if so, go to jump checking routine...
 1540 .tmr_checkevent
 1550 TST     R3,#64                  ;are we still in this pattern (- is bit 6 clear)?
 1560 STREQB  R3,[R12,#tm_currentevent];if so, so store event counter
 1570 BEQ     tmr_nextline
 1580 :
 1590 MOV     R3,#0                   ;set event counter to 0, because we are at a new pattern
 1600 .tmr_brokepattern               ;  **-{pattern break code entry}-**
 1610 ADD     R4,R4,#1                ;add 1 to current sequence
 1620 .tmr_jumped2seq                 ; **-{jump to sequence code entry}-** <<< unused now >>>
 1630 LDRB    R0,[R12,#maxsequence]
 1640 CMP     R4,R0                   ;is current sequence > max sequence?
 1650 BGE     tmr_gottime
 1660 LDRB    R2,[R12,#tm_lastsequence];load last sequence num
 1670 CMP     R4,R2                   ;is current sequence < last sequence?
 1680 BLE     tmr_gottime
 1690 ORR     R3,R3,R4,LSL#16
 1700 STR     R3,[R12,#tm_currentevent];store sequence and event together
 1710 .tmr_nextline
 1720 ADDS    R7,R7,R8
 1730 BPL     tmr_mainloop
 1740 B       tmr_crashed             ;if number has got too large and become negative, bad...
 1750 
 1760 
 1770 .tmr_gottime
 1780 ADDLE   R7,R7,R8                ;v1.45 previously forgot to add time for the final line!!!
 1790 MOV     R2,R7,LSR#7             ;
 1800 MOV     R0,#100                 ;v1.45 return value in centiseconds, for improved accuracy
 1810 MUL     R2,R0,R2                ;      (may be better to redo linetime calc...consider...)
 1820 MOV     R2,R2,LSR#9             ;put total time, in centiseconds, into r2...
 1830 LDMFD   R13!,{R0-R1,R3-R11,PC}  ;                                     ...and exit
 1840 
 1850 
 1860 .tmr_checkjumps                 ; ** r4=sequence r3=event **
 1870 MOV     R1,#0
 1880 STRB    R1,[R12,#tm_breakflags] ;clear breakflags
 1890 :
 1900 TST     R0,#%1                  ;is bit 1 set (='jump to seq')?
 1910 LDRNEB  R3,[R12,#tm_pattbreakpos] ;for this code to be reached!!!
 1920 BNE     tmr_brokepattern        ;then go to update sequence code...
 1930 :
 1940 ;TST     R0,#%10                ;no need to test for loop flags - this is the only one
 1950 LDRB    R3,[R12,#tm_pattbreakpos] ;if bit 2 set (='pattern loop') then load loop pos
 1960 STRB    R3,[R12,#tm_currentevent]
 1970 B       tmr_nextline
 1980 
 1990 
 2000 ;**********************************************************
 2010 ;*          'check out effects' routine next...           *
 2020 ;**********************************************************
 2030 
 2040 
 2050 .tmr_checkoutFX                 ;r5=note word, r6=channel
 2060 STMFD   R13!,{R0-R6,R14}        ;only called with effects B,D,E,F
 2070 :
 2080 AND     R0,R5,#&000F0000
 2090 MOV     R0,R0,LSR#16
 2100 MOV     R1,R5,LSR#24
 2110 LDR     R2,[R12,#FXflags]       ;load effect status flags
 2120 MOV     R3,#1
 2130 TST     R2,R3,LSLR0             ;is this effect's flag set on?
 2140 BEQ     tmr_badFX               ;if not, skip it...
 2150 :
 2160 CMP     R0,#&B
 2170 BEQ     tmr_jump2seq            ;B - jump to sequence
 2180 CMP     R0,#&D
 2190 BEQ     tmr_patternbreak        ;D - pattern break
 2200 CMP     R0,#&E
 2210 BEQ     tmr_E_effects           ;E - E effects/commands
 2220 BNE     tmr_setspeed            ;F - set speed/tempo
 2230 :
 2240 .tmr_badFX
 2250 LDMFD   R13!,{R0-R6,PC}
 2260 
 2270 
 2280 ;**********************************************************
 2290 ;*         'check out E effects' routine next...          *
 2300 ;**********************************************************
 2310 
 2320 
 2330 .tmr_E_effects                  ;r0=effect number (always &E!!!), r1=FX data, r9=channel
 2340 MOV     R0,R1,LSR#4             ;r0 now has E effect number
 2350 AND     R1,R1,#&0F              ;r1 now has data nibble for E effect
 2360 LDR     R2,[R12,#E_FXflags]     ;load E effect status flags
 2370 MOV     R3,#1
 2380 TST     R2,R3,LSLR0             ;is this effect's flag set on?
 2390 BEQ     tmr_badFX               ;if not, skip it...
 2400 :
 2410 CMP     R0,#&6
 2420 BEQ     tmr_pattloop            ;E6 - pattern loop
 2430 CMP     R0,#&E
 2440 BEQ     tmr_pattdelay           ;EE - pattern delay
 2450 B       tmr_badFX
 2460 
 2470 
 2480 .tmr_jump2seq                   ; ***** 0B - jump to sequence *****
 2490 MOV     R0,#%1
 2500 STRB    R0,[R12,#tm_breakflags]
 2510 SUB     R1,R1,#1
 2520 STRB    R1,[R12,#tm_currentseq]
 2530 MOV     R0,#0
 2540 STRB    R0,[R12,#tm_pattbreakpos]
 2550 LDMFD   R13!,{R0-R6,PC}
 2560 
 2570 
 2580 .tmr_patternbreak               ; ***** 0D - pattern break *****
 2590 MOV     R0,#%1
 2600 STRB    R0,[R12,#tm_breakflags]
 2610 MOV     R0,R1,LSR#4
 2620 AND     R1,R1,#&F
 2630 ADD     R1,R1,R0,LSL#3
 2640 ADD     R1,R1,R0,LSL#1
 2650 CMP     R1,#63
 2660 MOVGT   R1,#0                   ;if >63, set it to 0, but don't clear break flags
 2670 STRB    R1,[R12,#tm_pattbreakpos]
 2680 LDMFD   R13!,{R0-R6,PC}
 2690 
 2700 
 2710 .tmr_setspeed                   ; ***** 0F - set speed/tempo *****
 2720 CMP     R1,#32
 2730 MOVGE   R10,R1
 2740 MOVLT   R9,R1
 2750 CMP     R1,#0
 2760 ;BEQ     tmr_stopspeed          ;check stop speed after ALL channels done!
 2770 BLNE    tmr_setlinetime         ;(?don't set time, if speed 0?)
 2780 LDMFD   R13!,{R0-R6,PC}
 2790 
 2800 
 2810 ;.tmr_stopspeed
 2820 ;LDMFD   R13!,{R0-R6,R14}
 2830 ;B       tmr_gottime
 2840 
 2850 
 2860 .tmr_pattloop                   ; ***** E6 - pattern loop *****
 2870 ADD     R2,R12,#tm_pattloopstart AND &FF00
 2880 ADD     R2,R2,#tm_pattloopstart AND &00FF
 2890 ADD     R3,R2,#(tm_pattloopcount-tm_pattloopstart)
 2900 CMP     R1,#0
 2910 LDREQB  R0,[R12,#tm_currentevent]
 2920 STREQB  R0,[R2,R6]
 2930 LDMEQFD R13!,{R0-R6,PC}         ;if 'set loop', load event and put it in loop start
 2940 :
 2950 LDRB    R0,[R3,R6]
 2960 SUBS    R0,R0,#1                ;load current loop value, sub 1
 2970 MOVMIS  R0,R1                   ; if now <0 then it was 0 (so not in a loop) so set new
 2980 STRGEB  R0,[R3,R6]              ; if new value used or (value-1)>=0, then store new value
 2990 LDMEQFD R13!,{R0-R6,PC}         ; if (value-1)=0 then loop has ended, so exit
 3000 :
 3010 LDRB    R0,[R2,R6]
 3020 STRB    R0,[R12,#tm_pattbreakpos] ;store loop position in break pos
 3030 LDRB    R0,[R12,#tm_breakflags]
 3040 ORR     R0,R0,#%10
 3050 STRB    R0,[R12,#tm_breakflags]   ;set break flags
 3060 LDMFD   R13!,{R0-R6,PC}
 3070 
 3080 
 3090 .tmr_pattdelay                  ; ***** EE - pattern delay *****
 3100 LDRB    R0,[R12,#tm_patterndelay]
 3110 CMP     R0,#0
 3120 ADDEQ   R1,R1,#1
 3130 STREQB  R1,[R12,#tm_patterndelay];add 1 to delay, and only store if not already in a delay!
 3140 LDMFD   R13!,{R0-R6,PC}
 3150 
 3160 
 3170 ;.tmr_pattloopstart EQUD 0       ;w  - 1b per chan
 3180 ;                   EQUD 0       ;w  - 1b per chan
 3190 ;.tmr_pattloopcount EQUD 0       ;w  - 1b per chan
 3200 ;                   EQUD 0       ;w  - 1b per chan
 3210 ;.tmr_currentevent  EQUW 0       ;2b
 3220 ;.tmr_currentseq    EQUW 0       ;2b
 3230 ;.tmr_patterndelay  EQUB 0       ;b
 3240 ;.tmr_breakflags    EQUB 0       ;b
 3250 ;.tmr_pattbreakpos  EQUB 0       ;b
 3260 ;.tmr_lastsequence  EQUB 0       ;b
 3270 ;ALIGN
 3280 
 3290 .tmr_resetvars
 3300 STMFD   R13!,{R0,R14}
 3310 MOV     R0,#0
 3320 STR     R0,[R12,#tm_pattloopstart]
 3330 STR     R0,[R12,#tm_pattloopstart+4]
 3340 STR     R0,[R12,#tm_pattloopcount]
 3350 STR     R0,[R12,#tm_pattloopcount+4]
 3360 STR     R0,[R12,#tm_currentevent]  ;& seq
 3370 STR     R0,[R12,#tm_patterndelay]  ;_
 3380 ;STRB    R0,[R12,#tm_breakflags]   ; } \
 3390 ;STRB    R0,[R12,#tm_pattbreakpos] ; }  }- all blanked by STR R0,tmr_patterndelay
 3400 ;STRB    R0,[R12,#tm_lastsequence] ; } /
 3410 LDMFD   R13!,{R0,PC}
 3420 ]
 3430 =opt%
