   10 REM QTM_Song v1.49 8-channel compatible init-song routines
   20 REM
   30 REM LEN Steve Harrison 1993-2023
   40 END
   50 
   60 DEF FNassm_initsong
   70 [OPT opt%
   80 .init_type                             ;from v1.44 this checks format valid and initialises type - setting insts and songchans too
   90 STMFD   R13!,{R0-R3,R11,R14}           ;On exit V set if not ProTracker song
  100 FNlong_adr("  ",11,textdata)
  110 :
  120 LDR     R0,[R12,#songaddr]
  130 LDR     R1,[R0,#8]
  140 LDR     R2,TINF
  150 CMP     R1,R2
  160 LDREQ   R1,[R0,#12]
  170 CMPEQ   R1,#4
  180 BEQ     unsupportedformat             ;confirmed Tracker module
  190 :
  200 LDR     R1,[R0]
  210 LDR     R2,BASS
  220 CMP     R1,R2
  230 BEQ     unsupportedformat             ;confirmed Symphony Song/Sample/Mdule file
  240 :
  250 LDRB    R1,[R0,#&1D7]                 ;load byte before max sequence byte (for 15 inst)
  260 CMP     R1,#ASC"x"                    ;if it is 'x' (or possibly 127 too?) then this is probably a 15 inst song
  270 ADDEQ   R1,R0,#472
  280 MOVEQ   R14,#15
  290 ADDNE   R1,R0,#952
  300 MOVNE   R14,#31                       ;EQ = 15 inst, NE = 31 inst
  310 LDRB    R2,[R1,#-2]
  320 CMP     R2,#127                       ;if more than 127 sequences... bye!
  330 BGT     unsupportedformat             ;(but we are allowing 0 sequences at the mo...)
  340 :
  350 MOV     R2,#127                       ;positions to scan...
  360 .scanpatternnos                       ;max. no. patterns is now 100, but we'll allow up to 127!
  370 LDRB    R3,[R1,R2]
  380 CMP     R3,#127
  390 BGT     unsupportedformat             ;no patterns>127 please!
  400 SUBS    R2,R2,#1
  410 BGE     scanpatternnos
  420 :
  430 ;STRB    R14,[R12,#insts]  ;nr, as songtype=0 means 15 insts
  440 :
  450 CMP     R14,#15
  460 MOVEQ   R2,#0                         ;SoundTracker 15 inst compatible
  470 MOVNE   R2,#1                         ;SoundTracker 31 inst compatible
  480 MOV     R14,#4                        ;assume 4 channels until we know otherwise
  490 MOV     R3,#1024                      ;and 1024 byte patterns
  500 BEQ     init_typedone                 ;if 15 insts, skip the rest of the checks
  510 :
  520 LDR     R0,[R0,#1080]
  530 LDR     R1,[R11,#(ch16-textdata)]
  540 CMP     R0,R1
  550 LDRNE   R1,[R11,#(ch24-textdata)]
  560 CMPNE   R0,R1
  570 LDRNE   R1,[R11,#(ch32-textdata)]
  580 CMPNE   R0,R1
  590 LDRNE   R1,[R11,#(flt2-textdata)]
  600 CMPNE   R0,R1
  610 BEQ     unsupportedformat             ;no channels>8 ...yet... ;-) (or <4!)
  620 :
  630 LDR     R1,[R11,#(mk-textdata)]
  640 CMP     R0,R1
  650 MOVEQ   R2,#2                         ;ProTracker
  660 LDR     R1,[R11,#(flt4-textdata)]
  670 CMP     R0,R1
  680 MOVEQ   R2,#3                         ;FLT4 StarTrekker (only 4 channels initially)
  690 LDR     R1,[R11,#(chn4-textdata)]
  700 CMP     R0,R1
  710 MOVEQ   R2,#4                         ;4CHN FastTracker
  720 LDR     R1,[R11,#(flt8-textdata)]
  730 CMP     R0,R1
  740 MOVEQ   R2,#&10                       ;FLT8, 8 channel (temporary type - will convert to StarTrekker, then set origin as 3)
  750 MOVEQ   R14,#8
  760 LDR     R1,[R11,#(chn8-textdata)]
  770 CMP     R0,R1
  780 LDR     R1,[R11,#(cd81-textdata)]
  790 CMPNE   R0,R1
  800 MOVEQ   R2,#4                         ;8CHN FastTracker, new in v1.44! or Octalyser 8 channel, new in v1.45
  810 MOVEQ   R3,#2048
  820 MOVEQ   R14,#8
  830 CMP     R0,R1                         ;only EQ if CD81
  840 MOVEQ   R2,#5
  850 LDR     R1,[R11,#(chn6-textdata)]
  860 CMP     R0,R1
  870 LDR     R1,[R11,#(cd61-textdata)]
  880 CMPNE   R0,R1
  890 MOVEQ   R2,#4                         ;6CHN FastTracker, new in v1.44!
  900 MOVEQ   R3,#1536
  910 MOVEQ   R14,#6
  920 CMP     R0,R1                         ;only EQ if CD61
  930 MOVEQ   R2,#5
  940 :
  950 ]:IF maxchans=4 THEN [OPT opt%:CMP R14,#4:BGT unsupported_only4chan:]
  960 [OPT opt%
  970 .init_typedone
  980 STRB    R2,[R12,#songtype]
  990 TEQ     R2,#4
 1000 TEQNE   R2,#5
 1010 LDREQB  R2,[R12,#songstatus]
 1020 ORREQ   R2,R2,#%1<<3
 1030 STREQB  R2,[R12,#songstatus]          ;set 6-octave flag for FastTracker music
 1040 :
 1050 STR     R3,[R12,#patternlen]
 1060 STRB    R14,[R12,#songchans]
 1070 :
 1080 CMP     R0,R0                         ; Clear V
 1090 LDMFD   R13!,{R0-R3,R11,PC}
 1100 
 1101 
 1110 .unsupportedformat
 1120 LDMFD   R13!,{R0-R3,R11,R14}
 1130 B       stillbadsong
 1140 
 1141 
 1150 ]:IF maxchans=4 THEN
 1160  [OPT opt%
 1170  .unsupported_only4chan
 1180  LDMFD   R13!,{R0-R3,R11,R14}
 1190  MOV     R0,#&80000000
 1200  SUBS    R0,R0,#1 ; Set V
 1210  ADR     R0,err_only4chan
 1220  MOV     PC,R14
 1230 
 1240  .err_only4chan
 1250  EQUD    qtm_error+&01
 1260  EQUS    "This custom QTM only supports 4 channel music, use the full version of QTM for 4/6/8 channels." ;updated v1.46
 1270  EQUB    0
 1280  ALIGN
 1290  ]
 1291 ENDIF
 1292 [OPT opt%
 1310 
 1320 
 1330 .TINF
 1340 EQUS    "TINF"
 1350 .BASS
 1360 EQUB    ASC"S"-64
 1370 EQUB    ASC"S"-64
 1380 EQUB    ASC"A"-64
 1390 EQUB    ASC"B"-64
 1400 
 1410 
 1420 .initsong                       ;init_type must have been called before this is called!
 1430 STMFD   R13!,{R0-R12,R14}
 1440 LDR     R11,[R12,#songaddr]
 1450 LDR     R10,[R12,#songlength]   ;(0 if memory-loaded, or non-RMA transfered)
 1460 :
 1470 BL      workoutlength           ;work out actual song length (from song), *still requires FLT8 checking!*
 1480 CMP     R10,#0
 1490 MOVEQ   R10,R0
 1500 STREQ   R10,[R12,#songlength]
 1510 :
 1520 SUBS    R0,R10,R0               ;work out 'garbage' data
 1530 CMN     R0,R10                  ;is r0 (-ve garbage)<(-ve length) (ie is -100<-10?)
 1540 BLE     badsong                 ;if so, this is a bad song, so error...
 1550 STR     R0,[R12,#garbagedata]
 1560 CMP     R0,#0
 1570 BLMI    resizeRMA               ;if too short, then attempt to get more RMA (if in RMA)
 1580 BVS     initsong_error
 1590 :
 1600 LDRB    R1,[R12,#songtype]
 1610 TEQ     R1,#0
 1620 BLEQ    convert15inst           ;convert 15 inst to 31 inst
 1630 BVS     initsong_error
 1640 :
 1650 TEQ     R1,#&10                 ;R1 still has songtype
 1660 BLEQ    convertFLT8             ;convert StarTrekker to FastTracker format (updates patternlen=2048, songtype=3)
 1670 :
 1680 LDRB    R0,[R11,#950]
 1690 STRB    R0,[R12,#maxsequence]
 1700 BL      findmaxpatt             ;get max pattern into r0
 1710 STRB    R0,[R12,#maxpattern]    ;store it
 1720 MOV     R9,   #(1084 AND &FF00)
 1730 ADD     R9,R9,#(1084 AND &00FF) ;get r9 to pattern start offset
 1740 :
 1750 LDR     R1,[R12,#patternlen]
 1760 MLA     R9,R1,R0,R9             ;add max patt*patternlen to pattern start, gets to sample start
 1770  ;LDRB    R1,[R12,#songtype]      ;v1.45 no longer require FLT8 test
 1780  ;TEQ     R1,#&10                 ;FLT8 type, needs +1024 to length
 1790  ;ADDEQ   R9,R9,#1024             ;...just a fudge-thing, because no. patts*patternlen (1024) is 1024 too few
 1800 :
 1810 ADD     R0,R9,R11               ;r0 - sample start address
 1820 SUBS    R1,R10,R9               ;songlen-sample offset=sample len (in r1)
 1830 BLT     badsong                 ;**** was LE in v1.43 and earlier, but from v1.44 we allow no samples ****
 1840 ADD     R2,R12,#(linlognew-song_data)
 1850 BL      convsamps               ;convert samples from lin to log
 1860 :
 1870 SUB     R10,R10,R9                      ;r10 - songlen-samples offset = samples len
 1880 ADD     R9,R9,R11                       ;r9  - sample start pointer
 1890 ADD     R8,R12,#(sampletable-song_data) ;r8  - pointer to QTM sample data table
 1900 ADD     R7,R11,#20                      ;r7  - pointer to sample data blocks
 1910 MOV     R6,#31                          ;r6  - count down through samples
 1920                                         ;
 1930                                         ;r4  - repeat length
 1940                                         ;r3  - repeat offset
 1950                                         ;r2  - sample length
 1960                                         ;r1  - sample start address
 1970                                         ;r0  - finetune and volume bytes
 1980 .readsamples
 1990 LDRB    R5,[R7,#22]
 2000 LDRB    R1,[R7,#23]
 2010 ORR     R1,R1,R5,LSL#8
 2020 MOV     R1,R1,LSL#1             ;load & correct (*2) sample length into r1
 2030 :
 2040 LDRB    R5,[R7,#28]
 2050 LDRB    R3,[R7,#29]
 2060 ORRS    R3,R3,R5,LSL#8          ;load repeat length
 2070 :
 2080 BNE     skipzerofirsttwo        ;v1.46 test change to improve chip tunes
 2090 CMP     R1,#0                   ; ...if repeat length=0 and sample length>0
 2100 MOVGT   R5,#0                   ; ...clear first two bytes
 2110 STRGTB  R5,[R9,#0]              ; ...this now behaves like PT2.3f, not 2.3a
 2120 STRGTB  R5,[R9,#1]              ; ...which always cleared first two bytes
 2130 :
 2140 .skipzerofirsttwo
 2150 LDRB    R4,[R7,#24]              ;finetune
 2160 AND     R4,R4,#&F
 2170 :
 2180 LDRB    R5,[R7,#25]
 2190 CMP     R5,#64
 2200 MOVGT   R5,#64                  ;load volume, and ensure <= 64
 2210 ORR     R4,R4,R5,LSL#24         ;volume in last byte (<<24) of ft+vol word
 2220 :
 2230 ;CMP     R3,#1
 2240 ;BLE     skip_rep                ; ***** ignore *****  skip the repeat setting routine
 2250 :
 2260 MOV     R3,R3,LSL#1             ;correct repeat length (*2)
 2270 LDRB    R5,[R7,#26]
 2280 LDRB    R2,[R7,#27]
 2290 ORR     R2,R2,R5,LSL#8          ;load repeat offset
 2300 :
 2310 ADD     R5,R3,R2,LSL#1          ;work out repeat offset (corrected!!!) + repeat length
 2320 CMP     R5,R1                   ;is it > sample length???
 2330 MOVLE   R2,R2,LSL#1             ;if not, then use corrected (*2) repeat offset
 2340 :
 2350 MOVGT   R5,R2,LSR#1             ;if it was >, then use unshifted repeat offset
 2360 STRGTB  R5,[R7,#27]             ; ...and store this offset (>>1) back in song itself...
 2370 MOVGT   R5,R5,LSR#8             ; ...(so QTMEditor works ok!!!)
 2380 STRGTB  R5,[R7,#26]
 2390 :
 2400 .skip_rep                       ;all regs ok now? (r0,r1?,r2,r3,r4)
 2410 MOV     R0,R9                   ;r0=sample start
 2420 STMIA   R8!,{R0-R4}
 2430 ADD     R9,R9,R1
 2440 SUB     R10,R10,R1
 2450 ADD     R7,R7,#30
 2460 SUBS    R6,R6,#1
 2470 BNE     readsamples
 2480 LDMFD   R13!,{R0-R12,PC}
 2490 .initsong_error
 2500 STR     R0,[R13,#0]             ;stack up error pointer for r0, if error
 2510 LDMFD   R13!,{R0-R12,PC}
 2520 
 2530 
 2540 .badsong
 2550 LDMFD   R13!,{R0-R12,R14}
 2560 .stillbadsong
 2570 MOV     R0,#&80000000
 2580 SUBS    R0,R0,#1 ; Set V
 2590 ADR     R0,dunnothisone
 2600 MOV     PC,R14
 2610 
 2620 
 2630 .dunnothisone
 2640 EQUD    qtm_error+&01
 2650 EQUS    "Unsupported song format, or corrupt file" ;updated v1.45
 2660 EQUB    0
 2670 ALIGN
 2680 
 2690 
 2700 .workoutlength                  ;init_type must have been called before this! Returns song len in R0, requires song addr in R11
 2710 STMFD   R13!,{R14}
 2720 LDRB    R2,[R12,#songtype]
 2730 CMP     R2,#0                   ;are we 15 inst song?
 2740 MOVNE   R1,#31                  ;set R1 (needed later)
 2750 MOVEQ   R1,#15
 2760 SUBEQ   R11,R11,#480            ;if 15 inst, fix start (as 31 inst) for 'findmaxpatt'
 2770 MOVEQ   R4,   #470+128+2
 2780 MOVNE   R4,   #(950+128+2+4) AND &FF00
 2790 ADDNE   R4,R4,#(950+128+2+4) AND &00FF
 2800 BL      findmaxpatt             ;get max pattern into r0
 2810 :
 2820 CMP     R2,#0                   ;are we 15 inst song?
 2830 ADDEQ   R11,R11,#480
 2840 :
 2850 LDR     R3,[R12,#patternlen]
 2860 MLA     R0,R3,R0,R4             ;add max patt*patternlen to pattern start, gets to sample start
 2870 LDRB    R3,[R12,#songtype]      ;v1.45 the following FLT8 check is still required, as 'workoutlength' called before conversion
 2880 TEQ     R3,#&10                 ; FLT8 type, needs +1024 to length
 2890 ADDEQ   R0,R0,#1024             ; ...just a fudge-thing, because no. patts*patternlen (1024) is 1024 too few
 2900 :
 2910 MOV     R4,R11
 2920 .readlengths
 2930 LDRB    R2,[R4,#42]
 2940 LDRB    R3,[R4,#43]
 2950 ORR     R2,R3,R2,LSL#8
 2960 ADD     R0,R0,R2,LSL#1
 2970 SUBS    R1,R1,#1                ;loop until no. of samples done
 2980 ADDNE   R4,R4,#30
 2990 BNE     readlengths
 3000 LDMFD   R13!,{PC}
 3010 
 3020 
 3030 .resizeRMA                      ;r0=-ve size
 3040 LDRB    R1,[R12,#songstatus]
 3050 TST     R1,#%1<<1
 3060 MOVEQ   PC,R14
 3070 STMFD   R13!,{R14}              ;we're using RMA, so time to re-size
 3080 RSB     R3,R0,#0
 3090 MOV     R0,#13
 3100 LDR     R2,[R12,#songaddr]
 3110 SWI     "XOS_Module"
 3120 ADRVS   R0,err_nospcRMA
 3130 LDMVSFD R13!,{PC}
 3131 STR     R2,[R12,#songaddr]
 3140 ;LDR     R0,[R12,#workspaceptr]
 3160 ;STR     R2,[R0]
 3170 MOV     R11,R2
 3180 ADD     R2,R2,R10
 3190 MOV     R0,#0
 3200 .clearnew
 3210 STRB    R0,[R2],#1
 3220 SUBS    R3,R3,#1
 3230 BGT     clearnew
 3240 LDMFD   R13!,{PC}
 3250 
 3260 
 3270 .findmaxpatt                   ;returns r0=maxpat
 3280 STMFD   R13!,{R1-R3,R14}
 3290 MOV     R0,#0
 3300 MOV     R1,#127
 3310 ADD     R2,R11,#952
 3320 .trypatt
 3330 LDRB    R3,[R2,R1]
 3340 CMP     R3,R0
 3350 MOVGT   R0,R3
 3360 SUBS    R1,R1,#1
 3370 BGE     trypatt
 3380 ADDS    R0,R0,#1 ; Increase maxpat + clear V
 3390 LDMFD   R13!,{R1-R3,PC}
 3400 
 3410 
 3420 .convertFLT8                    ;convert StarTrekker to FastTracker format (updates patternlen=2048, songtype=3)
 3430 STMFD   R13!,{R0-R3,R14}        ;r10=track length (will be altered...)  r11=song addr
 3440 MOV     R0,#0
 3450 MOV     R1,#127
 3460 ADD     R2,R11,#952
 3470 .convertFLTseq
 3480 LDRB    R3,[R2,R1]
 3490 MOV     R3,R3,LSR#1             ;divide pattern number by 2
 3500 STRB    R3,[R2,R1]
 3510 CMP     R3,R0
 3520 MOVGT   R0,R3
 3530 SUBS    R1,R1,#1
 3540 BGE     convertFLTseq
 3550 ADD     R1,R0,#1                ;increase maxpat
 3560 :
 3570 SUB     R2,R11,#-(1084-2048)    ;using pattern 1 to max, so sub 2048 from patt start
 3580 .convertFLTpatts
 3590 ADD     R0,R2,R1,LSL#11         ;pattern*2048
 3600 BL      shufflepattern
 3610 SUBS    R1,R1,#1
 3620 BGT     convertFLTpatts         ;loop UNTIL pattern=0
 3630 :
 3640 :
 3650 FNlong_adr("  ",0,textdata)
 3660 LDR     R0,[R0,#(chn8-textdata)]
 3670 STR     R0,[R11,#1080]          ;store an '8CHN' at 1080, to show that this is now FastTracker
 3680 :
 3690 MOV     R0,#2048
 3700 STR     R0,[R12,#patternlen]
 3710 MOV     R0,#3
 3720 STRB    R0,[R12,#songtype]
 3730 LDMFD   R13!,{R0-R3,PC}
 3740 
 3750 
 3760 .convert15inst                  ;as of v1.44 this is only called if songype=0 = 15 insts
 3770 STMFD   R13!,{R0-R3,R14}        ;r10=track length (will be altered...)  r11=song addr
 3780 LDRB    R0,[R12,#songstatus]    ;
 3790 TST     R0,#%1<<1               ; v1.44 - note if userload 15 inst, need 484 bytes free
 3800 :                               ; after...check documentation states this
 3810 MOVNE   R0,#13
 3820 MOV     R2,R11                  ;put address in r2, even if not altering
 3830 MOVNE   R3,#484                 ;if we're in rma, then extend it by 484 bytes...
 3840 SWINE   "XOS_Module"
 3850 ADRVS   R0,err_nospcRMA
 3860 BVS     doconvert_error
 3870 :
 3880 CMP     R11,R2
 3890 MOVNE   R11,R2
 3900 STRNE   R11,[R12,#songaddr]
 3910 ;LDRNE   R0,[R12,#workspaceptr]
 3920 ;STRNE   R2,[R0]
 3930 :
 3940 ADD     R0,R11,#470+128+2       ;r0=start of 15 inst patterns
 3950 ADD     R1,R0,#484              ;r1=start of new (31 inst patterns=+484)
 3960 SUB     R2,R10,#470+128+2       ;r2=length to move
 3970 BL      movebackwards           ;move patterns and samples to 31 inst position
 3980 :
 3990 ADD     R0,R11,#(470 AND &FF00)
 4000 ADD     R0,R0,#(470 AND &00FF)
 4010 ADD     R1,R0,#480
 4020 MOV     R2,#128+2
 4030 BL      movebackwards           ;move sequence to 31 inst position
 4040 :
 4050 MOV     R1,#480                 ;r1=length to blank (r0 is already in position)
 4060 BL      blankout                ;blank the gap where the extra 16 insts go
 4070 :
 4080 FNlong_adr("  ",0,textdata)
 4090 LDR     R0,[R0,#(mk-textdata)]
 4100 STR     R0,[R11,#1080]          ;store an 'M,K,' at 1080, to show that this is now 31 inst
 4110 :
 4120 ADD     R10,R10,#484            ;update track length!!!
 4130 STR     R10,[R12,#songlength]
 4140 CMP     R0,R0 ; Clear V
 4150 LDMFD   R13!,{R0-R3,PC}
 4160 .doconvert_error
 4170 STR     R0,[R13,#0]
 4180 LDMFD   R13!,{R0-R3,PC}
 4190 
 4200 
 4210 .err_nospcRMA
 4220 EQUD    qtm_error+&06
 4230 EQUS    "Not enough space in RMA to initialise song" ;update v1.45
 4240 EQUB    0
 4250 ALIGN
 4260 
 4270 
 4280 .movebackwards                  ;r0=oldstart  r1=new start  r2=length
 4290 STMFD   R13!,{R0-R3,R14}
 4300 .moveb_loop
 4310 SUBS    R2,R2,#1
 4320 LDRGEB  R3,[R0,R2]
 4330 STRGEB  R3,[R1,R2]
 4340 BGT     moveb_loop
 4350 LDMFD   R13!,{R0-R3,PC}
 4360 
 4370 
 4380 .blankout                       ;r0=start  r1=length
 4390 STMFD   R13!,{R1-R2,R14}
 4400 MOV     R2,#0
 4410 .blank_loop
 4420 SUBS    R1,R1,#1
 4430 STRGEB  R2,[R0,R1]
 4440 BGT     blank_loop
 4450 LDMFD   R13!,{R1-R2,PC}
 4460 
 4470 
 4480 .convsamps                      ;r0=addr, r1=length (0 or below exits), r2=conversion table pointer (lintable, loglintab)
 4490 STMFD   R13!,{R0-R12,R14}
 4500 .convsample_36
 4510 SUBS    R1,R1,#36
 4520 BLT     endconvert
 4530 LDMIA   R0,{R3-R11}
 4540 :
 4550 AND     R14,R11,#&000000FF
 4560 LDRB    R12,[R2,R14]
 4570 AND     R14,R11,#&0000FF00
 4580 LDRB    R14,[R2,R14,LSR#8]
 4590 ORR     R12,R12,R14,LSL#8
 4600 AND     R14,R11,#&00FF0000
 4610 LDRB    R14,[R2,R14,LSR#16]
 4620 ORR     R12,R12,R14,LSL#16
 4630 LDRB    R14,[R2,R11,LSR#24]
 4640 ORR     R12,R12,R14,LSL#24
 4650 :
 4660 AND     R14,R10,#&000000FF
 4670 LDRB    R11,[R2,R14]
 4680 AND     R14,R10,#&0000FF00
 4690 LDRB    R14,[R2,R14,LSR#8]
 4700 ORR     R11,R11,R14,LSL#8
 4710 AND     R14,R10,#&00FF0000
 4720 LDRB    R14,[R2,R14,LSR#16]
 4730 ORR     R11,R11,R14,LSL#16
 4740 LDRB    R14,[R2,R10,LSR#24]
 4750 ORR     R11,R11,R14,LSL#24
 4760 :
 4770 AND     R14,R9,#&000000FF
 4780 LDRB    R10,[R2,R14]
 4790 AND     R14,R9,#&0000FF00
 4800 LDRB    R14,[R2,R14,LSR#8]
 4810 ORR     R10,R10,R14,LSL#8
 4820 AND     R14,R9,#&00FF0000
 4830 LDRB    R14,[R2,R14,LSR#16]
 4840 ORR     R10,R10,R14,LSL#16
 4850 LDRB    R14,[R2,R9,LSR#24]
 4860 ORR     R10,R10,R14,LSL#24
 4870 :
 4880 AND     R14,R8,#&000000FF
 4890 LDRB    R9,[R2,R14]
 4900 AND     R14,R8,#&0000FF00
 4910 LDRB    R14,[R2,R14,LSR#8]
 4920 ORR     R9,R9,R14,LSL#8
 4930 AND     R14,R8,#&00FF0000
 4940 LDRB    R14,[R2,R14,LSR#16]
 4950 ORR     R9,R9,R14,LSL#16
 4960 LDRB    R14,[R2,R8,LSR#24]
 4970 ORR     R9,R9,R14,LSL#24
 4980 :
 4990 AND     R14,R7,#&000000FF
 5000 LDRB    R8,[R2,R14]
 5010 AND     R14,R7,#&0000FF00
 5020 LDRB    R14,[R2,R14,LSR#8]
 5030 ORR     R8,R8,R14,LSL#8
 5040 AND     R14,R7,#&00FF0000
 5050 LDRB    R14,[R2,R14,LSR#16]
 5060 ORR     R8,R8,R14,LSL#16
 5070 LDRB    R14,[R2,R7,LSR#24]
 5080 ORR     R8,R8,R14,LSL#24
 5090 :
 5100 AND     R14,R6,#&000000FF
 5110 LDRB    R7,[R2,R14]
 5120 AND     R14,R6,#&0000FF00
 5130 LDRB    R14,[R2,R14,LSR#8]
 5140 ORR     R7,R7,R14,LSL#8
 5150 AND     R14,R6,#&00FF0000
 5160 LDRB    R14,[R2,R14,LSR#16]
 5170 ORR     R7,R7,R14,LSL#16
 5180 LDRB    R14,[R2,R6,LSR#24]
 5190 ORR     R7,R7,R14,LSL#24
 5200 :
 5210 AND     R14,R5,#&000000FF
 5220 LDRB    R6,[R2,R14]
 5230 AND     R14,R5,#&0000FF00
 5240 LDRB    R14,[R2,R14,LSR#8]
 5250 ORR     R6,R6,R14,LSL#8
 5260 AND     R14,R5,#&00FF0000
 5270 LDRB    R14,[R2,R14,LSR#16]
 5280 ORR     R6,R6,R14,LSL#16
 5290 LDRB    R14,[R2,R5,LSR#24]
 5300 ORR     R6,R6,R14,LSL#24
 5310 :
 5320 AND     R14,R4,#&000000FF
 5330 LDRB    R5,[R2,R14]
 5340 AND     R14,R4,#&0000FF00
 5350 LDRB    R14,[R2,R14,LSR#8]
 5360 ORR     R5,R5,R14,LSL#8
 5370 AND     R14,R4,#&00FF0000
 5380 LDRB    R14,[R2,R14,LSR#16]
 5390 ORR     R5,R5,R14,LSL#16
 5400 LDRB    R14,[R2,R4,LSR#24]
 5410 ORR     R5,R5,R14,LSL#24
 5420 :
 5430 AND     R14,R3,#&000000FF
 5440 LDRB    R4,[R2,R14]
 5450 AND     R14,R3,#&0000FF00
 5460 LDRB    R14,[R2,R14,LSR#8]
 5470 ORR     R4,R4,R14,LSL#8
 5480 AND     R14,R3,#&00FF0000
 5490 LDRB    R14,[R2,R14,LSR#16]
 5500 ORR     R4,R4,R14,LSL#16
 5510 LDRB    R14,[R2,R3,LSR#24]
 5520 ORR     R4,R4,R14,LSL#24
 5530 :
 5540 STMIA   R0!,{R4-R12}
 5550 BGT     convsample_36
 5560 LDMEQFD R13!,{R0-R12,PC}
 5570 :
 5580 .endconvert
 5590 ADD     R1,R1,#36
 5600 .convsample_1
 5610 SUBS    R1,R1,#1
 5620 LDRGEB  R3,[R0]
 5630 LDRGEB  R3,[R2,R3]
 5640 STRGEB  R3,[R0],#1
 5650 BGT     convsample_1
 5660 LDMFD   R13!,{R0-R12,PC}
 5670 
 5680 
 5690 ;.linlogtab     ;this is filled on module init -> move to RAM databank? v1.48
 5700 ;]
 5710 ;P%+=256;O%+=256
 5720 ;[OPT opt%
 5730 
 5740 
 5750 .init_author
 5760 STMFD   R13!,{R0-R3,R14}
 5770 BL      findauthor
 5780 CMP     R0,#0
 5790 STREQB  R0,[R12,#(author_new-song_data)]
 5800 LDMEQFD R13!,{R0-R3,PC}         ;if no name found
 5810 ADD     R1,R12,#(author_new-song_data) AND &FF00
 5820 ADD      R1,R1,#(author_new-song_data) AND &00FF
 5830 MOV     R2,#0
 5840 .copy_author
 5850 LDRB    R3,[R0,R2]
 5860 CMP     R3,#0
 5870 CMPNE   R3,#32
 5880 MOVLT   R3,#32
 5890 STRB    R3,[R1,R2]
 5900 ADD     R2,R2,#1
 5910 CMP     R2,#22
 5920 BLT     copy_author
 5930 LDMFD   R13!,{R0-R3,PC}
 5940 
 5950 
 5960 .findauthor             ;r12=song data, r11=text data
 5970 STMFD   R13!,{R1-R4,R14}
 5980 LDR     R0,[R12,#songaddr]
 5990 ADD     R0,R0,#20
 6000 LDRB    R3,[R12,#songtype]  ;was R12,#insts here
 6010 TEQ     R3,#0  ;15 inst?
 6020 MOVEQ   R3,#15 ;yes
 6030 MOVNE   R3,#31
 6040 :
 6050 MOV     R2,#22
 6060 .authorloop
 6070 ADD     R1,R11,#(by-textdata)
 6080 BL      search          ;return with (C)arry set and r0=sample addr, if found
 6090 LDMCSFD R13!,{R1-R4,PC}
 6100 :
 6110 ADD     R1,R11,#(of-textdata)
 6120 BL      search          ;return with (C)arry set and r0=sample addr, if found
 6130 LDMCSFD R13!,{R1-R4,PC}
 6140 :
 6150 ADD     R1,R11,#(copyright-textdata)
 6160 BL      search          ;return with (C)arry set and r0=sample addr, if found
 6170 LDMCSFD R13!,{R1-R4,PC}
 6180 :
 6190 ADD     R1,R11,#(cpy-textdata)
 6200 BL      search          ;return with (C)arry set and r0=sample addr, if found
 6210 LDMCSFD R13!,{R1-R4,PC}
 6220 :
 6230 ADD     R1,R11,#(hash-textdata)
 6240 BL      search          ;return with (C)arry set and r0=sample addr, if found
 6250 LDMCSFD R13!,{R1-R4,PC}
 6260 :
 6270 ADD     R1,R11,#(back-textdata)
 6280 BL      search          ;return with (C)arry set and r0=sample addr, if found
 6290 LDMCSFD R13!,{R1-R4,PC}
 6300 :
 6310 ADD     R0,R0,#30
 6320 SUBS    R3,R3,#1
 6330 BNE     authorloop
 6340 MOV     R0,#0
 6350 LDMFD   R13!,{R1-R4,PC}
 6360 
 6370 
 6380 .search                 ;r0=search string, r1=string to look for, r2=length of (r0)
 6390 STMFD   R13!,{R3-R7}
 6400 MOV     R3,#0
 6410 .searchloop
 6420 MOV     R4,R3           ;current string offset
 6430 MOV     R5,R1
 6440 .bytecompare
 6450 LDRB    R7,[R5],#1
 6460 CMP     R7,#0
 6470 BEQ     foundstring     ;if we've been through the whole sub string - we've found it...
 6480 CMP     R4,R2           ;has the offset into the main string overflowed?
 6490 BGE     notfound        ;if so, we can't find it...
 6500 LDRB    R6,[R0,R4]
 6510 CMP     R6,#ASC"A"      ; }
 6520 ADDGE   R6,R6,#32       ; }_ set letters A-Z **ON LY**           *** FAST
 6530 CMP     R6,#ASC"Z"+32   ; }  to lower case (+32)                *** method!!!
 6540 SUBGT   R6,R6,#32       ; }
 6550 ADD     R4,R4,#1
 6560 CMP     R6,R7           ;are the bytes from the main- and sub-strings the same?
 6570 BEQ     bytecompare     ;if so, better check some more...
 6580 ADD     R3,R3,#1
 6590 CMP     R3,R2           ;run out of place to look?
 6600 BLT     searchloop      ;- no, so loop back!
 6610 .notfound
 6620 MOVS    R3,R3,LSR #1 ; Clear C
 6630 LDMFD   R13!,{R3-R7}
 6640 MOV     PC,R14
 6650 .foundstring
 6660 LDMFD   R13!,{R3}       ;don't need r3 any more, so load it with the sample count
 6670 .getnamestart
 6680 CMP     R4,R2           ;has the offset into the main string overflowed?
 6690 BGE     trynewline
 6700 LDRB    R6,[R0,R4]
 6710 ADD     R4,R4,#1
 6720 CMP     R6,#32
 6730 CMPGT   R6,#ASC"."
 6740 CMPGT   R6,#ASC":"
 6750 BLE     getnamestart
 6760 MOV     R4,#1
 6770 MOVS    R4,R4,RRX ; Set carry
 6780 LDMFD   R13!,{R4-R7}
 6790 MOV     PC,R14
 6800 
 6810 .trynewline
 6820 MOV     R4,#0
 6830 SUBS    R3,R3,#1
 6840 ADDGT   R0,R0,#30
 6850 BGT     getnamestart
 6860 MOV     R4,#1
 6870 MOVS    R4,R4,RRX ; Set carry
 6880 LDMFD   R13!,{R4-R7}    ;no more samples to check, so it must be this one?
 6890 MOV     PC,R14
 6900 
 6910 
 6920 .init_title             ;r11=text data, r12=song data
 6930 STMFD   R13!,{R0-R3,R14}
 6940 ADD     R0,R12,#(songtitle_new-song_data)
 6950 LDR     R1,[R12,#songaddr]
 6960 MOV     R2,#20
 6970 .copytitle
 6980 LDRB    R3,[R1],#1
 6990 CMP     R3,#0
 7000 CMPNE   R3,#32
 7010 MOVLT   R3,#32
 7020 STRB    R3,[R0],#1
 7030 SUBS    R2,R2,#1
 7040 BNE     copytitle
 7050 LDMFD   R13!,{R0-R3,PC}
 7060 
 7070 
 7080 .deinit_samples                 ;convert back to lin samples
 7090 STMFD   R13!,{R0-R2,R14}
 7100 LDRB    R0,[R12,#maxpattern]
 7110 :
 7120 LDR     R1,[R12,#patternlen]
 7130 MUL     R0,R1,R0                ;max patt*patternlen
 7140  ;LDRB    R1,[R12,#songtype]      ;v1.45 no need for this any more...
 7150  ;TEQ     R1,#&10                 ;FLT8 type, needs +1024 to length
 7160  ;ADDEQ   R0,R0,#1024             ;...just a fudge-thing, because no. patts*patternlen (1024) is 1024 too few
 7170 :
 7180 ADD     R0,R0,#(1084 AND &FF00) ;***mega bug fix 8/4/97, was 1080!***
 7190 ADD     R0,R0,#(1084 AND &00FF) ;now at sample start offset
 7200 :
 7210 LDR     R1,[R12,#songlength]
 7220 SUB     R1,R1,R0                ;length to convert
 7230 LDR     R2,[R12,#songaddr]
 7240 ADD     R0,R0,R2
 7250 ADR     R2,loglintab
 7260 BL      convsamps
 7270 LDMFD   R13!,{R0-R2,PC}
 7280 
 7290 
 7300 .loglintab     ;this is precalculated and loaded from a data file at assembly
 7310 ]
 7320 P%+=256:O%+=256
 7330 [OPT opt%
 7340 
 7350 ;
 7360 ; Ultra compact pattern-shuffle, (c) STEP Harrison 2013
 7370 ;
 7380 ; uses precalculated table (64 bytes) and 80 bytes of code = 144 bytes total
 7390 ; in order to reshuffle 2048 bytes of pattern data using no additional memory
 7400 ;
 7410 ; input pattern format c1-4 events 0,1,2...63 then c5-8 events 0,1,2...63
 7420 ; output pattern format c1-8 events 0,1,2,3....61,62,63
 7430 ;
 7440 ; shuffle example input  0,1,2,3,4,5.....124,125,126,127
 7450 ;         example output 0,64,1,65,2,66,3,67,4....125,62,126,63,127
 7460 ;
 7470 ; shuffle table calculated by hand/using spreadsheet...is there a better way?
 7480 ;
 7490 
 7500 .shufflepattern             ;reorder StarTrekker patters into FastTracker format
 7510 STMFD   R13!,{R0-R12,R14}   ;R0=start addr of 8 channel pattern to reshuffe
 7520 ADR     R2,shuffletable     ;(alternate one offset from table, one from R1)
 7530 :                           ;if table byte=0, skip, if table byte=255 end
 7540 ADD     R1,R0,#64*16        ;(64 to 127, use inbetween table bytes)
 7550 MOV     R3,R0               ;output address
 7560 .shuffleloop
 7570 LDRB    R4,[R2],#1          ;load table byte
 7580 TEQ     R4,#0               ;0=skip
 7590 ADDEQ   R3,R3,#1*16         ;get to next event position
 7600 BEQ     skipthisshuffle
 7610 :
 7620 TEQ     R4,#255             ;255=exit
 7630 LDMEQFD R13!,{R0-R12,PC}
 7640 :
 7650 LDMIA   R3,{R5,R6,R7,R8}    ;load 4 channels from current event
 7660 ADD     R4,R0,R4,LSL#4
 7670 LDMIA   R4,{R9,R10,R11,R12} ;load 4 channels from destination event
 7680 STMIA   R4,{R5,R6,R7,R8}
 7690 STMIA   R3!,{R9,R10,R11,R12};swap them round and increment to next event
 7700 .skipthisshuffle
 7710 LDMIA   R3,{R5,R6,R7,R8}    ;...do the next event using R1 as swap address
 7720 LDMIA   R1,{R9,R10,R11,R12}
 7730 STMIA   R1!,{R5,R6,R7,R8}
 7740 STMIA   R3!,{R9,R10,R11,R12}
 7750 B       shuffleloop         ;keep going until end of table
 7760 
 7770 
 7780 .shuffletable
 7790 DCB 0  ;1
 7800 DCB 64
 7810 DCB 64
 7820 DCB 65
 7830 DCB 64
 7840 DCB 66
 7850 DCB 65
 7860 DCB 67
 7870 DCB 64
 7880 DCB 68
 7890 DCB 66
 7900 DCB 69
 7910 DCB 65
 7920 DCB 70
 7930 DCB 67
 7940 DCB 71 ;16
 7950 DCB 64
 7960 DCB 72
 7970 DCB 68
 7980 DCB 73
 7990 DCB 66
 8000 DCB 74
 8010 DCB 69
 8020 DCB 75
 8030 DCB 65
 8040 DCB 76
 8050 DCB 70
 8060 DCB 77
 8070 DCB 67
 8080 DCB 78
 8090 DCB 71
 8100 DCB 79 ;32
 8110 DCB 64
 8120 DCB 80
 8130 DCB 72
 8140 DCB 81
 8150 DCB 0
 8160 DCB 82
 8170 DCB 100
 8180 DCB 83
 8190 DCB 0
 8200 DCB 84
 8210 DCB 0
 8220 DCB 106
 8230 DCB 98
 8240 DCB 106
 8250 DCB 101
 8260 DCB 107 ;48
 8270 DCB 0
 8280 DCB 0
 8290 DCB 0
 8300 DCB 108
 8310 DCB 0
 8320 DCB 0
 8330 DCB 0
 8340 DCB 118
 8350 DCB 0
 8360 DCB 0
 8370 DCB 0
 8380 DCB 0
 8390 DCB 0
 8400 DCB 0
 8410 DCB 0
 8420 DCB 255 ;64
 8430 ]
 8440 ENDIF
 8450 =opt%
