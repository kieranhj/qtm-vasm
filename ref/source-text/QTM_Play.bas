   10 REM QTM v1.49 play routine code (4/6/8-channel compatible) incl. RasterMan optional code
   20 REM
   30 REM LEN Steve Harrison 1993-2023
   40 END
   50 
   60 DEF FNassm_main
   70 [OPT opt%
   80 
   90 ;  __________________________________________
  100 ; |                                          |\
  110 ; | QTM v1.49 (c) 1993-2013 Phoenix/Quantum  | |
  120 ; |__________________________________________| |
  130 ;  \__________________________________________\|
  140 ;
  150 
  160 ]:IF qtmrast% THEN
  170  [OPT opt%
  180  .CIAhandler                    ;r12 = song_data on entry
  190  STMFD   R13!,{R0-R2,R14}       ; * stack r0,r1,r14 and for v1.43se RasterMan, also store r2
  200  LDMIA   R12,{R0-R1}            ;r0=CIA delay, r1=CIA counter
  210  LDR     R2,[R12,#rm_CIAdec]    ; * v1.43se RasterMan
  220  :
  230  SUBS    R1,R1,R2               ; * take 1st lump (50Hz) of accurate time off CIA counter
  240  ADDLE   R1,R1,R0               ;if counter<=0 then add total CIA delay to it
  250  STR     R1,[R12,#CIAcounter]   ;store CIA counter
  260  BLLE    ControlSong            ; * as we're now at 50Hz (but code expects 100Hz) so call twice!
  270  :
  280  SUBS    R1,R1,R2               ; * take 2nd lump (50Hz) of accurate time off CIA counter
  290  ADDLE   R1,R1,R0               ;if counter<=0 then add total CIA delay to it
  300  STR     R1,[R12,#CIAcounter]   ;store CIA counter
  310  LDMFD   R13!,{R0-R2,R14}       ; * reload r0,r1,r14 and r2
  320  MOVGT   PC,R14                 ;if CIA counter didn't run out, then exit
  330  ]
  340 ELSE
  350  [OPT opt%
  360  .CIAhandler                    ;r12 = song_data on entry
  370  STMFD   R13!,{R0-R1}           ;stack r0,r1
  380  LDMIA   R12,{R0-R1}            ;r0=CIA delay, r1=CIA counter
  390  SUBS    R1,R1,#1<<16           ;take 1 lump of accurate time off CIA counter
  400  ADDLE   R1,R1,R0               ;if counter<=0 then add total CIA delay to it
  410  STR     R1,[R12,#CIAcounter]   ;store CIA counter
  420  LDMFD   R13!,{R0-R1}           ;reload r0,r1
  430  MOVGT   PC,R14                 ;if CIA counter didn't run out, then exit
  440  ]
  450 ENDIF
  460 [OPT opt%
  470 :
  480 .ControlSong
  490 STMFD   R13!,{R0-R11,R14}
  500 LDRB    R0,[R12,#counter]       ;load speed counter
  510 SUBS    R0,R0,#1                ;take off 1 (can be <0 if speed 0 used to stop song?)
  520 LDRLEB  R0,[R12,#speed]         ;if counter<=0 then reload it with the speed
  530 STRB    R0,[R12,#counter]       ;store counter
  540 BGT     doFX                    ;if counter didn't get to 0, then go and do the effects...
  550 :
  560 LDRB    R0,[R12,#patterndelay]  ;load pattern delay time
  570 CMP     R0,#0                   ;is it 0?
  580 BNE     waitdelay               ;if not, then go to the delay effects/count down routine
  590 :
  600 .GetNewNote
  610 LDRB    R1,[R12,#songstopflags] ;now all channels have been checked, test for stop-speed
  620 TEQ     R1,#0
  630 BLNE    stopflagset             ;returns if we don't stop
  640 :
  650 ADD     R11,R12,#songaddr       ;r11=addr of song address, then current event vars
  660 LDMIA   R11,{R0,R1}             ;r0=song address, r1=sequence (16-24) event (0-7)
  670 ADD     R0,R0,#952              ;r0=sequence table address
  680 LDRB    R2,[R0,R1,LSR#16]       ;r2=pattern
  690 ORR     R1,R1,R2,LSL#8          ;r1=sequence (16-24) pattern (8-15) event (0-7)
  700 STR     R1,[R12,#lastevent]     ;store a copy of the position vars
  710 AND     R1,R1,#&FF              ;r1=event
  720 :
  730 ADD     R8,R0,#132              ;add 132 to r0, to get to start of patterns, and put in r10
  740 LDR     R0,[R12,#patternlen]    ;v1.44 support for 8CHN and 6CHN
  750 MLA     R8,R2,R0,R8             ;add current patt*patternlen to pattern start, gets to this pattern start
  760 MOV     R0,R0,LSR#6             ;patternlen/64 = event length (16/24/32 for 4, 8 FLT/6/8)
  770 MLA     R8,R1,R0,R8             ;add on current event*event length (no longer just 16)
  780 STR     R8,[R12,#tempaddrptr]
  790 :
  800 ADD     R11,R12,#(channeldata-song_data)-64 ;r11=addr of channel blocks
  810 MOV     R9,#0                               ;r9=channel-1
  820 .dochannels
  830 ADD     R10,R12,#(DMA_blocks-song_data)     ;work out each time, incase of fake DMA!!!
  840 ADD     R10,R10,R9,LSL#4
  850 ADD     R10,R10,R9,LSL#3                    ;(channel DMA blocks are 24 bytes long)
  860 LDRB    R0,[R12,#songchans]  ;v1.44
  870 TEQ     R0,#4                ; |   if 4 channels
  880 LDREQB  R0,[R12,#soundflags] ;v1.44  load sound flags
  890 TST     R0,#%1<<5            ; |   is b5 (play on c5-8) set? (songchans<32 chans, will be 0)
  900 LDRNEB  R0,[R12,#chans_use]  ; |
  910 TEQNE   R0,#4                ; |  (***not checking for 8, but checking NOT 4!***)
  920 ADDNE   R10,R10,#4*24        ; |  if 'play on chan5-8' and 8 chans selected, do so! 28/6/96
  930 ADD     R11,R11,#64          ;...now at this channel's 64 byte channel data block
  940 LDR     R8,[R12,#tempaddrptr]
  950 LDR     R8,[R8,R9,LSL#2]     ;load note word for this channel (r8)
  960 :
  970 LDR     R0,[R12,#channelstate]                  ; *****              ** R8 must have note word
  980 MOV     R1,#%10                                 ;      *****        **     by this point
  990 TST     R0,R1,LSLR9                             ;      *****    ** **
 1000 ADDEQ   R10,R12,#(fakeDMAspace-song_data) AND &FF00      ; *****          ***
 1010 ADDEQ   R10,R10,#(fakeDMAspace-song_data) AND &00FF      ; *****          ***
 1020 BEQ     skipall                                 ;using fake DMA slot, so chan is left ok...
 1030 :
 1040 TEQ     R8,#0                ;fix v1.46 18/1/22, only reset period for music
 1050 BNE     checksampleset       ;                   (v1.44/5 didn't reset any!)
 1060 LDRB    R0,[R10,#DMA_sampleflag] ;R0=0 music sample, 255=sound sample
 1070 TEQ     R0,#255
 1080 BNE     skipnote             ;skipnote resets period (needed for music FX)
 1090 B       skipall              ;skipall doesn't reset period (use for sound sample)
 1100 :
 1110 .checksampleset
 1120 AND     R0,R8,#&00000010     ;upper 1 bit of sample number
 1130 AND     R1,R8,#&00F00000     ;lower 4 bits of sample number
 1140 ORRS    R7,R0,R1,LSR#20      ;r7 = sample number
 1150 BEQ     donesample           ;if sample number was 0, then skip sample setting bit...
 1160 :
 1170 STRB    R7,[R11,#samplenumber]  ;store (new) sample number in channel's block
 1180 :
 1190 SUB     R0,R7,#1                        ;r0=sample-1
 1200 ADD     R7,R12,#(sampletable-song_data) ;get addr of sample data table in r5
 1210 ADD     R7,R7,R0,LSL#4                  ;add (sample-1)*16 = correct info block for sample
 1220 ADD     R7,R7,R0,LSL#2                  ;(+4) ******************* -(*20)
 1230 :
 1240 LDMIA   R7,{R0-R4}              ;r0=addr, r1=len, r2=rep off, r3=rep len, r4=ftune/volume
 1250 ADD     R5,R2,R0                ; v1.48 -> R5 = rep address -> used by invertloop
 1260 CMP     R3,#2                   ;if we are repeating we'd better use replen+off as the real
 1270 ADDGT   R1,R3,R2                ;...length - so the repeat is started at the right place!!!
 1280 ADD     R0,R0,R1                ;turn address to end address
 1290 STMIA   R11,{R0,R1,R3,R4,R5}    ;***{NOTE} don't need to store the repeat offset now***
 1300 :
 1310 MOV     R4,R4,LSR#24            ;
 1320 STR     R4,[R10,#DMA_volume]    ;set volume for DMA   *** And clear sample flag ***
 1330 :
 1340 .donesample
 1350 AND     R0,R8,#&00000007        ;**v1.44 test for 8CHN** upper 3 (was 2) bits of note period
 1360 AND     R1,R8,#&0000FF00        ;lower 8 bits of note period
 1370 MOV     R0,R0,LSL#8             ;
 1380 ORRS    R7,R0,R1,LSR#8          ;r7 = amiga note period (1-4095)
 1390 ;
 1400 ; could disallow >1023 if not FastTracker (as would have been previous behaviour)
 1410 ;
 1420 BEQ     skipnote                ;if note is 0, skip the note setting bit...
 1430 :
 1440 CMP     R7,#1920                ;v1.44 if >=1920, revert to notenumber=0 (lowest note)
 1450 MOVGE   R6,#0                   ;
 1460 ADDLT   R6,R12,#(div8notetable-song_data)
 1470 ADDLT   R6,R6,R7,LSR#3          ;if <1920, use 'div8' table
 1480 CMP     R7,#150                 ;
 1490 ADDLT   R6,R12,#(div1notetable-song_data)
 1500 ADDLT   R6,R6,R7                ;if <150, use 'div1' table
 1510 LDRB    R6,[R6]                 ;load note number - this is only used for finetuning
 1520 :            ;...could check if notenum=255 to skip processing if illegal note (not implemented)
 1530 :
 1540 AND     R0,R8,#&000F0000        ;mask off effect number into r0
 1550 CMP        R0,#&000E0000        ;is it 'E'?
 1560 ANDEQ   R0,R8,#&F0000000        ;if so, mask off effect data into r0...
 1570 CMPEQ      R0,#&50000000        ;...is the command 'E5' (set fine tune)?
 1580 MOVEQ   R0,R8,LSR#24            ;...if it is, then get data shifted into r0
 1590 ANDEQ   R0,R0,#&F               ;...and mask out the new fine tune byte
 1600 BEQ     gotfinetune             ;...then go to 'gotfinetune' routine...
 1610 :
 1620 LDRB    R0,[R11,#finetune]      ;load this sample's fine tune byte, from the channel data
 1630 CMP     R0,#0                   ;is it 0?
 1640 BEQ     nofinetune              ;if so, skip the fine tune setting bit...
 1650 :
 1660 .gotfinetune
 1670 ADR     R7,amigaperiodz         ;get addr of amiga period tables
 1680 MOV     R1,R0,LSL#4             ;fine tune *16  }_
 1690 ADD     R0,R1,R0,LSL#7          ;          *128 }  *144 = offset for correct tuning DCW table
 1700 ADD     R7,R7,R0                ;get to address of table (r7)
 1710 MOVS    R1,R6,LSR#1             ;CS if odd numbered note
 1720 LDR     R7,[R7,R1,LSL#2]        ;fine tuned note (table+note number/2*4) b0-15=even, b16-31 odd
 1730 MOVCC   R7,R7,LSL#16            ;
 1740 MOV     R7,R7,LSR#16            ;v1.48 half size note tables
 1750 :
 1760 .nofinetune
 1770 AND     R0,R8,#&000F0000        ;mask in effect number
 1780 CMP        R0,#&00030000        ;is it command 3?
 1790 CMPNE      R0,#&00050000        ;or command 5?
 1800 BEQ     settoneporta            ;if so, then go and set the tone portamento    ;
 1810 :                                                                              ;
 1820 STR     R7,[R11,#amigaperiod]   ;store (finetuned) amiga period                ;
 1830 STRB    R6,[R11,#notenumber]    ;store note number                             ;
 1840 :                                                                              ;
 1850 MOV     R2,#1                                                                  ;
 1860 LDRB    R1,[R12,#vuflags]                                                      ;
 1870 ORR     R1,R1,R2,LSLR9                                                         ;
 1880 STRB    R1,[R12,#vuflags]       ;new note, so set VU flag                      ;
 1890 :                                                                              ;
 1900 CMP        R0,#&000E0000        ;^^^ r0 should still have effect number in it /
 1910 ANDEQ   R0,R8,#&F0000000
 1920 CMPEQ      R0,#&D0000000        ;if note delay (ED) then clear DMA data ****NO! (ex VOL/PD)
 1930 BEQ     skipall                 ; + don't do the vibrato/tremelo wave retrigging (no need!)
 1940 :                               ;******** fix 26/2/95 - DON'T SET PERIOD! or blank DMA!
 1950 :                               ;                     - leave previous note playing!
 1960 MOV     R0,#0
 1970 LDRB    R1,[R11,#vibrato_wave]  ;load vibrato wave config
 1980 TST     R1,#%100                ;is the "Don't restart wave each note" bit set?
 1990 STREQB  R0,[R11,#vibrato_pos]   ;if not, then reset the wave offset
 2000 LDRB    R1,[R11,#tremolo_wave]  ;load tremolo wave config
 2010 TST     R1,#%100                ;is the "Don't restart wave each note" bit set?
 2020 STREQB  R0,[R11,#tremolo_pos]   ;if not, then reset the wave offset
 2030 :
 2040 LDMIA   R11,{R0-R1}             ;r0=addr, r1=len
 2050 MOV     R1,R1,LSL#12            ;
 2060 RSB     R1,R1,#0                ;
 2070 STMIA   R10,{R0-R1}             ;new note, so reset addr and offset for sample
 2080 :
 2090 .skipnote
 2100  LDRB    R0,[R12,#songtype]      ; **
 2110  CMP     R0,#2                   ; ** v1.49 is this a PT M.K. mod?
 2120  LDREQB  R0,[R12,#musicoptbyte]  ; **
 2121  TSTEQ   R0,#%1<<3               ; ** if so, is musicopt bit 3 set (no reset) or clear (reset)?
 2131  LDREQB  R0,[R11,#currentvol]    ; ** v1.49 - bit 3 clear, do as PT 2.3D editor and reset vol on
 2140  STREQB  R0,[R10,#DMA_volume]    ; **         each event note, needed for 4mat's Django2 track!
 2160 :
 2170 LDR     R0,[R11,#amigaperiod]   ;load the (altered) amiga note for this channel
 2180 STR     R0,[R10,#DMA_pitch]     ;store it as the DMA increment
 2190 :
 2200 .skipall                        ;if channel disabled, this is jumped to, with fake DMA r10
 2210 ;
 2220 ; v1.46 check if (R8 AND &FF0F0000) is zero = no need to check effects...!
 2230 ;
 2240 AND     R0,R8,#&000F0000        ;v1.46 moved from checkoutFX, to save CPU cycles if no FX
 2250 MOVS    R0,R0,LSR#16            ;r0=effect num (and set EQ if 0)
 2260 MOV     R1,R8,LSR#24            ;r1=effect data
 2270 STRB    R0,[R11,#currentFXnum]  ;store effect number
 2280 STRB    R1,[R11,#currentFXdata] ;store effect data
 2290 TSTEQ   R1,#&FF                 ;if effect num was 0, is effect data?
 2300 BLNE    checkoutFX              ;deal with the effects (needs r0=FX, r1=data)...if any...
 2310 :
 2320 LDR     R0,[R11,#smp_addr]      ;load end address
 2330 LDR     R1,[R11,#smp_replen]    ;load repeat length
 2340 ADD     R2,R10,#DMA_repaddr     ;
 2350 STMIA   R2,{R0-R1}              ;store as repeat end address and repeat length
 2360 :
 2361 ; PT2.3F sets DMA volume to sample vol here (and doesn't set in effects)
 2370 :
 2371 .dontsetrepeats
 2380 LDRB    R0,[R12,#songchans]
 2390 ADD     R9,R9,#1                ;add 1 to the channel counter
 2400 CMP     R9,R0                   ;is >=max (no more channels to do)?
 2410 BLT     dochannels              ;if not, then loop back
 2420 :
 2430 :                               ;used to check for stop-speed here, but now do it on next note
 2440 :
 2450 LDR     R7,[R12,#currentevent]  ;load r7 with sequence (16-23) event (0-7)
 2460 :
 2470 .check_pattdel
 2480 LDRB    R0,[R12,#patterndelay]
 2490 SUBS    R0,R0,#1
 2500 STRGEB  R0,[R12,#patterndelay]  ;take off pattern delay (if running)
 2510 :
 2520 ADDLE   R7,R7,#1                ;add 1 to event counter
 2530 MOV     R9,R7,LSR#16            ;put sequence in r9 < this is here so ok for patt delay!!!
 2540 :
 2550 LDRB    R0,[R12,#breakflags]    ;load the break flag byte
 2560 CMP     R0,#0                   ;is it 0?
 2570 BNE     checkjumps              ;if so, go to jump checking routine...
 2580 .checkevent
 2590 TST     R7,#64                  ;are we still in this pattern (- is bit 6 clear)?
 2600 :
 2610 STREQB  R7,[R12,#currentevent]  ;if so, so store event counter
 2620 LDMEQFD R13!,{R0-R11,PC}        ; and exit... no "...PC}^" because of pattern delay
 2630 :
 2640 MOV     R7,#0                   ;set event counter to 0, because we are at a new pattern
 2650 .brokepattern                   ;  **-{pattern break code entry}-**
 2660 ADD     R9,R9,#1                ;add 1 to current sequence
 2670 .jumped2seq                     ; **-{jump to sequence code entry}-** <<< unused now >>>
 2680 LDRB    R0,[R12,#maxsequence]
 2690 CMP     R9,R0                   ;is current sequence > max sequence?
 2700 ORRLT   R7,R7,R9,LSL#16         ;if not, merge sequence and event, ready to store...
 2710 STR     R7,[R12,#currentevent]  ;store sequence (16-23) event (0-7)
 2720 :
 2730 LDRB    R0,[R12,#songstopflags] ;'songstopflags' bit 0 end, bit 1 repeating, bit 2 F-00
 2740 ORRGE   R0,R0,#%001             ;bit 0 lowest priority (song ended), bit 2 highest (F-00)
 2750 LDRB    R1,[R12,#lastsequence]
 2760 CMP     R9,R1
 2770 ORRLE   R0,R0,#%010             ;if current <= last we've repeated...
 2780 STRB    R0,[R12,#songstopflags]
 2790 LDMFD   R13!,{R0-R11,PC}        ; and exit... no "...PC}^" because of pattern delay
 2800 
 2810 
 2820 .checkjumps                     ; ** r0=breakflags, r7=sequence (16-23) event (0-7) **
 2830 MOV     R1,#0
 2840 STRB    R1,[R12,#breakflags]    ;clear breakflags
 2850 :
 2860 TST     R0,#%1                  ;is bit 1 set (='jump to seq')?
 2870 LDRNEB  R7,[R12,#pattbreakpos]  ; for this code to be reached!!!
 2880 BNE     brokepattern            ;then go to update sequence code...
 2890 :
 2900 ;TST     R0,#%10                ;no need to test for loop flags - this is the only one
 2910 LDRB    R7,[R12,#pattbreakpos]  ;if bit 2 set (='pattern loop') then load loop pos
 2920 STRB    R7,[R12,#currentevent]  ; store it as current event
 2930 LDMFD   R13!,{R0-R11,PC}        ; and exit... no "...PC}^" because of pattern delay
 2940 
 2950 
 2960 .waitdelay                      ;r0-r11,r14 stored
 2970 LDR     R7,[R12,#currentevent]
 2980 :
 2990 ADR     R14,doFX
 3000 STMFD   R13!,{R0-R11,R14}
 3010 B       check_pattdel
 3020 
 3030 
 3040 
 3050 
 3060 
 3070 ;**********************************************************
 3080 ;*           'process effects' routine next...            *
 3090 ;**********************************************************
 3100 
 3110 
 3120 .doFX                           ;r0-r11,r14 stored
 3130 MOV     R9,#0                   ;r9=channel-1
 3140 .checkchannels
 3150 ADD     R11,R12,#(channeldata-song_data)    ;r11=addr of channel blocks
 3160 ADD     R11,R11,R9,LSL#6       ;...now at this channel's 64 byte channel data block
 3170 ADD     R10,R12,#(DMA_blocks-song_data)     ;r10=addr of DMA blocks
 3180 ADD     R10,R10,R9,LSL#4
 3190 ADD     R10,R10,R9,LSL#3       ;...now at this channel's 24 byte DMA block
 3200 :
 3210 LDRB    R0,[R12,#songchans]     ;v1.44
 3220 TEQ     R0,#4                   ; |    if 4 channels
 3230 LDREQB  R0,[R12,#soundflags]    ;v1.44 load sound flags
 3240 TST     R0,#%1<<5               ; |    is bit 5 (play on c5-8) set? (songchans<32, will be 0)
 3250 LDRNEB  R0,[R12,#chans_use]     ; |
 3260 TEQNE   R0,#4                   ; |  (***not checking for 8, but checking NOT 4!***)
 3270 ADDNE   R10,R10,#4*24           ; |  if 'play on channels 5-8' and 8 channels selected, do so!
 3280 :
 3290 LDRB    R0,[R11,#invloopspd]    ;v1.48
 3300 TEQ     R0,#0                   ; |
 3310 BLNE    updatefunk              ; | invert loop **needs R0=invloopspd**
 3320 :
 3330 LDR     R0,[R12,#channelstate]  ;disabled channel (ie. effects only?)
 3340 MOV     R1,#2                   ;
 3350 TST     R0,R1,LSLR9             ;
 3360 BEQ     nextFX                  ;if so, skip effects processing
 3370 :
 3380 LDRB    R0,[R11,#currentFXnum]  ;load effect number
 3390 LDRB    R1,[R11,#currentFXdata] ;load effect data
 3400 LDR     R2,[R12,#FXflags]       ;load effect status flags
 3410 MOV     R3,#1
 3420 TST     R2,R3,LSLR0             ;is this effect's flag set on?
 3430 BEQ     nextFX                  ;if not, skip it...
 3440 :
 3450 CMP     R0,#(end_doFXtbl-strt_doFXtbl)
 3460 ADDCC   PC,PC,R0,LSL#2
 3470 B       nextFX
 3480 :
 3490 .strt_doFXtbl                   ;may corrupt R0-R8, on entry R0=FX num, R1=FX data, R2=FX flags
 3500 :                               ;*must* preserve - R9=chan, R10=DMA blk, R11=chan data blk, R12=song_data
 3510 B       do_arpeggio             ;0 - arpeggio
 3520 B       do_portaup              ;1 - portamento up
 3530 B       do_portadown            ;2 - portamento down
 3540 B       do_toneporta            ;3 - tone portamento
 3550 B       do_vibrato              ;4 - vibrato
 3560 B       do_tonevol              ;5 - tone portamento & volume slide
 3570 B       do_vibvol               ;6 - vibrato & volume slide
 3580 B       do_tremolo              ;7 - tremolo
 3590 B       nextFX                  ;8 - unused
 3600 B       nextFX                  ;9 - set sample offset
 3610 B       do_volslide             ;A - volume slide
 3620 B       nextFX                  ;B - jump to sequence
 3630 B       nextFX                  ;C - set sample volume
 3640 B       nextFX                  ;D - pattern break
 3650 B       do_E_effects            ;E - E effects/commands
 3660 B       nextFX                  ;F - set speed/tempo
 3670 .end_doFXtbl
 3680 :
 3690 .nextFX
 3700 ADD     R9,R9,#1                ;add 1 to channel counter
 3710 LDRB    R0,[R12,#songchans]     ;v1.44 check up to max channels for track!
 3720 CMP     R9,R0                   ;has it done chans 0-3? <-was huge bug v1.40-1.43, no FX chans>4!
 3730 BLT     checkchannels           ;if note, loop back...
 3740 LDMFD   R13!,{R0-R11,PC}        ;exit
 3750 
 3760 
 3770 ;**********************************************************
 3780 ;*          'process E effects' routine next...           *
 3790 ;**********************************************************
 3800 
 3810 
 3820 .do_E_effects                   ;r0=effect number (always &E!!!) r1=FX data r6=channel
 3830 MOV     R2,R1,LSR#4             ;r2 now has E effect number
 3840 LDR     R3,[R12,#E_FXflags]     ;load E effect status flags
 3850 MOV     R4,#1
 3860 TST     R3,R4,LSLR2             ;is this effect's flag set on?
 3870 BEQ     nextFX                  ;if not, skip it...
 3880 :
 3890 CMP     R2,#(end_E_FXtbl-strt_E_FXtbl)
 3900 ADDCC   PC,PC,R2,LSL#2
 3910 B       nextFX
 3920 :
 3930 .strt_E_FXtbl
 3940 B       do_setfilter            ;E0 - set filter
 3950 B       do_fineslideup          ;E1 - fine slide up
 3960 B       do_fineslidedown        ;E2 - fine slide down
 3970 B       do_glissando            ;E3 - set glissando
 3980 B       do_setvibratowave       ;E4 - set vibrato waveform
 3990 B       do_setfinetuning        ;E5 - set fine tuning
 4000 B       do_patternloop          ;E6 - pattern loop
 4010 B       do_settremolowave       ;E7 - set tremolo waveform
 4020 B       nextFX                  ;E8 - unused
 4030 B       do_retrignote           ;E9 - retrig note
 4040 B       do_finevolumeup         ;EA - fine volume slide up
 4050 B       do_finevolumedown       ;EB - fine volume slide down
 4060 B       do_notecut              ;EC - note cut
 4070 B       do_notedelay            ;ED - note delay
 4080 B       do_patterndelay         ;EE - pattern delay
 4090 B       do_invertloop           ;EF - invert loop
 4100 .end_E_FXtbl
 4110 
 4120 ;the program should never get here!!!
 4130 
 4140 
 4150 ;**********************************************************
 4160 ;*          'check out effects' routine next...           *
 4170 ;**********************************************************
 4180 
 4190 
 4200 .checkoutFX                     ;r0=FX, r1=data, r8=note wd, r9=chan, r10=DMA addr, r11=chan blk
 4210 STMFD   R13!,{R0-R7,R14}
 4220 :
 4230 ;AND     R0,R8,#&000F0000       ;v1.46 moved to calling code...test if no effects before calling
 4240 ;MOV     R0,R0,LSR#16
 4250 ;MOV     R1,R8,LSR#24
 4260 ;STRB    R0,[R11,#currentFXnum] ;store effect number
 4270 ;STRB    R1,[R11,#currentFXdata];store effect data
 4280 LDR     R2,[R12,#FXflags]       ;load effect status flags
 4290 MOV     R3,#1
 4300 TST     R2,R3,LSLR0             ;is this effect's flag set on?
 4310 BEQ     unknownFX               ;if not, skip it...
 4320 :
 4330 CMP     R0,#(end_chkFXtbl-strt_chkFXtbl)
 4340 ADDCC   PC,PC,R0,LSL#2
 4350 B       unknownFX
 4360 :
 4370 .strt_chkFXtbl
 4380 B       set_arpeggio            ;0 - arpeggio
 4390 B       set_portaup             ;1 - portamento up
 4400 B       set_portadown           ;2 - portamento down
 4410 B       set_toneporta           ;3 - tone portamento
 4420 B       set_vibrato             ;4 - vibrato
 4430 B       set_tonevol             ;5 - tone portamento & volume slide
 4440 B       set_vibvol              ;6 - vibrato & volume slide
 4450 B       set_tremolo             ;7 - tremolo
 4460 B       musicint_unused         ;8 - unused, so call unused effect routine
 4470 B       set_setsampleoff        ;9 - set sample offset
 4480 B       set_volslide            ;A - volume slide
 4490 B       set_jump2seq            ;B - jump to sequence
 4500 B       set_setsampvol          ;C - set sample volume
 4510 B       set_patternbreak        ;D - pattern break
 4520 B       set_E_effects           ;E - E effects/commands
 4530 B       set_setspeed            ;F - set speed/tempo
 4540 .end_chkFXtbl
 4550 :
 4560 .unknownFX
 4570 LDMFD   R13!,{R0-R7,PC}
 4580 
 4590 
 4600 ;**********************************************************
 4610 ;*         'check out E effects' routine next...          *
 4620 ;**********************************************************
 4630 
 4640 
 4650 .set_E_effects                  ;r0=effect number (always &E!!!), r1=FX data, r9=channel
 4660 MOV     R0,R1,LSR#4             ;r0 now has E effect number
 4670 AND     R1,R1,#&0F              ;r1 now has data nibble for E effect
 4680 LDR     R2,[R12,#E_FXflags]     ;load E effect status flags
 4690 MOV     R3,#1
 4700 TST     R2,R3,LSLR0             ;is this effect's flag set on?
 4710 BEQ     unknownFX               ;if not, skip it...
 4720 :
 4730 CMP     R0,#(end_chkE_FXtbl-strt_chkE_FXtbl)
 4740 ADDCC   PC,PC,R0,LSL#2
 4750 B       unknownFX
 4760 :
 4770 .strt_chkE_FXtbl
 4780 B       set_setfilter           ;E0 - set filter
 4790 B       set_fineslideup         ;E1 - fine slide up
 4800 B       set_fineslidedown       ;E2 - fine slide down
 4810 B       set_glissando           ;E3 - set glissando
 4820 B       set_setvibratowave      ;E4 - set vibrato waveform
 4830 B       set_setfinetuning       ;E5 - set fine tuning
 4840 B       set_patternloop         ;E6 - pattern loop
 4850 B       set_settremolowave      ;E7 - set tremolo waveform
 4860 B       unknownFX               ;E8 - unused
 4870 B       set_retrignote          ;E9 - retrig note
 4880 B       set_finevolumeup        ;EA - fine volume slide up
 4890 B       set_finevolumedown      ;EB - fine volume slide down
 4900 B       set_notecut             ;EC - note cut
 4910 B       set_notedelay           ;ED - note delay
 4920 B       set_patterndelay        ;EE - pattern delay
 4930 B       set_invertloop          ;EF - invert loop
 4940 .end_chkE_FXtbl
 4950 
 4960 ;the program should never get here!!!
 4970 
 4980 
 4990 .set_arpeggio                   ; ***** 00 - arpeggio *****
 5000 CMP     R1,#0
 5010 LDMEQFD R13!,{R0-R7,PC}
 5020 MOV     R0,#2
 5030 STRB    R0,[R11,#arpeggiovars]  ;if arpeggio, reset its timer
 5040 LDMFD   R13!,{R0-R7,PC}
 5050 
 5060 
 5070 .set_toneporta                  ; ***** 03 - tone portamento *****
 5080 CMP     R1,#0
 5090 STRNEB  R1,[R11,#tportaspeed]
 5100 LDMFD   R13!,{R0-R7,PC}
 5110 
 5120 
 5130 .set_vibrato                    ; ***** 04 - vibrato *****
 5140 CMP     R1,#0
 5150 LDMEQFD R13!,{R0-R7,PC}
 5160 LDRB    R0,[R11,#vibrato_speed]
 5170 ANDS    R2,R1,#&0F              ;r2=depth
 5180 ANDNE   R0,R0,#&F0              ;r0=old speed, but not depth
 5190 ORRNE   R0,R0,R2
 5200 ANDS    R2,R1,#&F0              ;r2=speed
 5210 ANDNE   R0,R0,#&0F              ;r1=(old) depth, but not speed
 5220 ORRNE   R0,R0,R2
 5230 STRB    R0,[R11,#vibrato_speed]
 5240 LDMFD   R13!,{R0-R7,PC}
 5250 
 5260 
 5270 .set_tremolo                    ; ***** 07 - tremolo *****
 5280 CMP     R1,#0
 5290 LDMEQFD R13!,{R0-R7,PC}
 5300 LDRB    R0,[R11,#tremolo_speed]
 5310 ANDS    R2,R1,#&0F              ;r2=depth
 5320 ANDNE   R0,R0,#&F0              ;r0=old speed, but not depth
 5330 ORRNE   R0,R0,R2
 5340 ANDS    R2,R1,#&F0              ;r2=speed
 5350 ANDNE   R0,R0,#&0F              ;r1=(old) depth, but not speed
 5360 ORRNE   R0,R0,R2
 5370 STRB    R0,[R11,#tremolo_speed]
 5380 LDMFD   R13!,{R0-R7,PC}
 5390 
 5400 
 5410 .set_setsampleoff               ; ***** 09 - set sample offset *****
 5420 ;TST     R8,#&00000007           ;v1.44 anything in upper 3 (was 2) bits of note period?
 5430 ;TSTEQS  R8,#&0000FF00           ;no!, so anything in lower 8 bits of note period?...
 5440 ;LDMEQFD R13!,{R0-R7,PC}         ;still no! - so we're not going to set the offset!
 5450 ; - moved down to the end, for v1.47 bug fix, this stops retrig effect...
 5460 :
 5470 CMP     R1,#0
 5480 LDREQB  R1,[R11,#setsampoff]
 5490 STRNEB  R1,[R11,#setsampoff]
 5500 :
 5510 ; bug fix v1.47, must set new DMA offset and set shorter len in channel data block
 5520 ; or next note played with no sample number, will reset to base -ve len
 5530 :
 5540 LDR     R0,[R11,#smp_length]
 5550 CMP     R0,R1,LSL#8
 5560 MOVLE   R1,#0       ;* if offset too large, then use 0 as off to force loop *
 5570 MOVLE   R2,#2
 5580 :                   ;* ...as on PT, which sets len=2 bytes *
 5590 :                   ;* by set len=2 bytes, off=0 should do same here!  *
 5600 :
 5610 SUBGT   R2,R0,R1,LSL#8          ; } smp_length-new offset
 5620 STR     R2,[R11,#smp_length]    ; } v1.47 bug fix [mod.way to rude, pos 32]
 5630 MOVGT   R3,R0,LSL#12
 5640 RSBGT   R3,R3,#0
 5650 ADDGT   R3,R3,R1,LSL#8+12       ;if value was ok, get to new sample offset
 5660 :
 5670 TST     R8,#&00000007           ;v1.44 anything in upper 3 (was 2) bits of note period?
 5680 TSTEQS  R8,#&0000FF00           ;no!, so anything in lower 8 bits of note period?...
 5690 LDMEQFD R13!,{R0-R7,PC}         ;no new note, so exit
 5700 :
 5710 STR     R3,[R10,#DMA_offset]    ;only set DMA_offset if new note this time... v1.47 fudge fix
 5720 ;
 5730 ; now add offset a second time (PT2.3D bug? calls mt_CheckMoreFX twice if new note and FX=9!)
 5740 ;
 5750 SUBS    R2,R2,R1,LSL#8
 5760 MOVLE   R2,#2
 5770 STR     R2,[R11,#smp_length]
 5780 LDMFD   R13!,{R0-R7,PC}
 5790 
 5800 
 5810 .set_jump2seq                   ; ***** 0B - jump to sequence *****
 5820 MOV     R0,#%1
 5830 STRB    R0,[R12,#breakflags]
 5840 SUB     R1,R1,#1
 5850 STRB    R1,[R12,#currentseq]
 5860 MOV     R0,#0
 5870 STRB    R0,[R12,#pattbreakpos]
 5880 LDMFD   R13!,{R0-R7,PC}
 5890 
 5900 
 5910 .set_setsampvol                 ; ***** 0C - set sample volume *****
 5920 CMP     R1,#64
 5930 MOVGT   R1,#64
 5940 STRB    R1,[R11,#currentvol]
 5950 STRB    R1,[R10,#DMA_volume]
 5960 LDMFD   R13!,{R0-R7,PC}
 5970 
 5980 
 5990 .set_patternbreak               ; ***** 0D - pattern break *****
 6000 MOV     R0,#%1
 6010 STRB    R0,[R12,#breakflags]
 6020 MOV     R0,R1,LSR#4
 6030 AND     R1,R1,#&F
 6040 ADD     R1,R1,R0,LSL#3
 6050 ADD     R1,R1,R0,LSL#1
 6060 CMP     R1,#63
 6070 MOVGT   R1,#0                   ;if >63, set it to 0, but don't clear break flags
 6080 STRB    R1,[R12,#pattbreakpos]
 6090 LDMFD   R13!,{R0-R7,PC}
 6100 
 6110 
 6120 .set_setspeed                   ; ***** 0F - set speed/tempo *****
 6130 LDRB    R2,[R12,#musicoptbyte]
 6140 TST     R2,#%1<<0
 6150 BNE     skipciatest             ;if vblank flag set, skip the check for cia tempos
 6160 CMP     R1,#32
 6170 BGE     setCIA
 6180 .skipciatest
 6190 CMP     R1,#0
 6200 STRNEB  R1,[R12,#speed]
 6210 STRNEB  R1,[R12,#counter]       ;if not speed 0, store new speed in counter as well...
 6220 :
 6230 LDRB    R1,[R12,#songstopflags]
 6240 TSTEQ   R2,#%1<<2
 6250 BICNE   R1,R1,#%100             ;clear stop flag if ignore flag set in options or not speed 0...
 6260 ORREQ   R1,R1,#%100
 6270 STRB    R1,[R12,#songstopflags]
 6280 LDMFD   R13!,{R0-R7,PC}
 6290 :
 6300 .setCIA
 6310 STRB    R1,[R12,#CIAtempo]
 6320 MOV     R1,R1,LSL#2             ;temp*4
 6330 MOV     R0,#1000<<16
 6340 BL      r0_div_r1
 6350 STR     R0,[R12,#CIAdelay]
 6360 ;STR     R0,[R12,#CIAcounter]   ;- hum...? resetting accurate counter - will this lower accuracy??
 6370 LDMFD   R13!,{R0-R7,PC}
 6380 
 6390 
 6400 .stopflagset                    ;entry R1=cause of stoppage, %001=end, %010 repeat, %100=speed 0
 6410 STMFD   R13!,{R14}
 6420 LDRB    R0,[R12,#songstatus]
 6430 ORR     R0,R0,#%1<<4
 6440 STRB    R0,[R12,#songstatus]    ;v1.49 set songstatus bit4 to indicate song has looped/ended
 6450 :
 6460 MOV     R0,#0
 6470 BL      musicinterrupt          ;QTMv1.45d re-enabled music interrupts
 6480 LDMFD   R13!,{R14}              ;  ...these should be OK if used correctly
 6490 :
 6500 MOV     R0,#0
 6510 STRB    R0,[R12,#songstopflags]
 6520 :
 6530 TST     R1,#%100
 6540 BNE     stopthesong             ;if caused by F-00
 6550 TST     R1,#%010
 6560 MOVNE   PC,R14                  ;if caused by repeating, exit
 6570 :
 6580 LDRB    R2,[R12,#musicoptbyte]  ;if caused by song end, check if we are ending or repeating...
 6590 TST     R2,#%1<<1
 6600 MOVEQ   PC,R14                  ;if stop-on-end flag clear, then exit
 6610 :
 6620 .stopthesong                    ;** v1.43 added 32bit compatibility ;)
 6630 ]:IF qtmrast% THEN [OPT opt%:MOV PC,R14:]
 6640 [OPT opt%                       ;no stopping on QTM RasterMan edition v1.45se
 6650 TEQ     PC,PC                   ;* Test 32bit
 6660 FNmrs("EQ","R7,CPSR")           ;*      32bit PSR in R7
 6670 ORREQ   R8,R7,#(%1<<7) OR %11   ;*      32bit SVC, no IRQs
 6680 FNmsr("EQ","CPSR_c,R8")         ;*      32bit set
 6690 TEQNEP  PC,#(%1<<27) OR %11     ;* 26bit SVC mode with ints disabled *not32bit!
 6700 MOV     R0,R0
 6710 STMFD   R13!,{R14}
 6720 BL      swi_qtmpause            ;note - qtmpause must not wait for DMA to clear, or this hangs!
 6730 LDMFD   R13!,{R14}
 6740 TEQ     PC,PC                   ;* Test 32bit
 6750 FNmsr("EQ","CPSR_c,R7")         ;*      32bit restore original mode
 6760 TEQNEP  PC,#(%1<<27) OR %10     ;* 26bit irq mode, ints off (next must be NOP)
 6770 :
 6780 MOV     R0,#0
 6790 STRB    R0,[R12,#counter]       ;set counter to 0 if song stopped, so it can restart instantly
 6800 LDMFD   R13!,{R0-R11,PC}
 6810 
 6820 
 6830 .set_fineslideup                ; ***** E1 - fine slide up *****
 6840 LDR     R0,[R11,#amigaperiod]
 6850 CMP     R0,#0                   ;ensure period>0!
 6860 LDMEQFD R13!,{R0-R7,PC}
 6870 :
 6880 LDRB    R7,[R12,#songstatus]    ;v1.44 need to test bit 3, for 3 or 6 octaves
 6890 TST     R7,#%1<<3               ;
 6900 MOVNE   R7,#28                  ;
 6910 MOVEQ   R7,#113                 ;if 3-octaves, max amiga period is 113, if 6-octaves, max is 28
 6920 :
 6930 SUB     R0,R0,R1
 6940 CMP     R0,R7
 6950 MOVLT   R0,R7                   ;load period, sub decrement (increase pitch), ensure >= max
 6960 STR     R0,[R11,#amigaperiod]
 6970 STR     R0,[R10,#DMA_pitch]
 6980 LDMFD   R13!,{R0-R7,PC}
 6990 
 7000 
 7010 .set_fineslidedown              ; ***** E2 - fine slide down *****
 7020 LDR     R0,[R11,#amigaperiod]
 7030 CMP     R0,#0                   ;ensure period>0!
 7040 LDMEQFD R13!,{R0-R7,PC}
 7050 :
 7060 LDRB    R7,[R12,#songstatus]    ;v1.44 need to test bit 3, for 3 or 6 octaves
 7070 TST     R7,#%1<<3               ;
 7080 MOVNE   R7,#1712                ;
 7090 MOVEQ   R7,#856                 ;if 3-octaves, min amiga period is 856, if 6-octaves, min is 1712
 7100 :
 7110 ADD     R0,R0,R1
 7120 CMP     R0,R7
 7130 MOVGT   R0,R7                   ;load period, add increment (decrease pitch), ensure <= min
 7140 STR     R0,[R11,#amigaperiod]
 7150 STR     R0,[R10,#DMA_pitch]
 7160 LDMFD   R13!,{R0-R7,PC}
 7170 
 7180 
 7190 .set_glissando                  ; ***** E3 - set glissando *****
 7200 STRB    R1,[R11,#glissando]
 7210 LDMFD   R13!,{R0-R7,PC}
 7220 
 7230 
 7240 .set_setvibratowave             ; ***** E4 - set vibrato waveform *****
 7250 AND     R1,R1,#%111             ; v1.49 only 0=sine,1=sawtooth,2=sqr supported (pt treats 3 as 2)
 7260 STRB    R1,[R11,#vibrato_wave]  ; +bit 2 set (4,5,6) = don't reset wave on each note
 7270 LDMFD   R13!,{R0-R7,PC}
 7280 
 7290 
 7300 .set_setfinetuning              ; ***** E5 - set fine tuning *****
 7310 STRB    R1,[R11,#finetune]
 7320 LDMFD   R13!,{R0-R7,PC}
 7330 
 7340 
 7350 .set_patternloop                ; ***** E6 - set pattern loop *****
 7360 CMP     R1,#0
 7370 LDREQB  R0,[R12,#currentevent]
 7380 STREQB  R0,[R11,#pattloopstart]
 7390 LDMEQFD R13!,{R0-R7,PC}         ;if 'set loop', load event and put it in loop start
 7400 :
 7410 LDRB    R0,[R11,#pattloopcount]
 7420 SUBS    R0,R0,#1                ;load current loop value, sub 1
 7430 MOVMIS  R0,R1                   ; if now <0 then it was 0 (so not in a loop) so set new
 7440 STRGEB  R0,[R11,#pattloopcount] ; if new value used or (value-1)>=0, then store new value
 7450 LDMEQFD R13!,{R0-R7,PC}         ; if (value-1)=0 then loop has ended, so exit
 7460 :
 7470 LDRB    R0,[R11,#pattloopstart]
 7480 STRB    R0,[R12,#pattbreakpos]  ;store loop position in break pos
 7490 LDRB    R0,[R12,#breakflags]
 7500 ORR     R0,R0,#%10
 7510 STRB    R0,[R12,#breakflags]    ;set break flags
 7520 LDMFD   R13!,{R0-R7,PC}
 7530 
 7540 
 7550 .set_settremolowave             ; ***** E7 - set tremolo waveform *****
 7560 AND     R1,R1,#%111             ; v1.49 only 0=sine,1=sawtooth,2=sqr supported (pt treats 3 as 2)
 7570 STRB    R1,[R11,#tremolo_wave]  ; +bit 2 set (4,5,6) = don't reset wave on each note
 7580 LDMFD   R13!,{R0-R7,PC}
 7590 
 7600 
 7610 .set_retrignote                 ; ***** E9 - set retrig note *****
 7620 STRB    R1,[R11,#retrigtimer]
 7630 CMP     R1,#0
 7640 LDMEQFD R13!,{R0-R7,PC}         ;store retrig value - if 0, exit
 7650 :
 7660 AND     R0,R8,#&00000007        ;v1.44 upper 3 (was 2) bits of note period
 7670 AND     R2,R8,#&0000FF00        ;lower 8 bits of note period
 7680 MOV     R0,R0,LSL#8
 7690 ORRS    R0,R0,R2,LSR#8          ;r0 = amiga note
 7700 STREQB  R0,[R11,#retrigtimer]   ;if no new note on this line, then don't allow retrig!!!
 7710 LDMFD   R13!,{R0-R7,PC}
 7720 
 7730 
 7740 .set_finevolumeup               ; ***** EA - set fine volume slide up *****
 7750 LDRB    R0,[R11,#currentvol]
 7760 ADD     R0,R0,R1
 7770 CMP     R0,#64
 7780 MOVGT   R0,#64                  ;load volume, add increment, ensure <=64
 7790 STRB    R0,[R11,#currentvol]
 7800 STRB    R0,[R10,#DMA_volume]
 7810 LDMFD   R13!,{R0-R7,PC}
 7820 
 7830 
 7840 .set_finevolumedown             ; ***** EB - set fine volume slide down *****
 7850 LDRB    R0,[R11,#currentvol]
 7860 SUBS    R0,R0,R1
 7870 MOVMI   R0,#0                   ;load volume, sub decrement, ensure >=0
 7880 STRB    R0,[R11,#currentvol]
 7890 STRB    R0,[R10,#DMA_volume]
 7900 LDMFD   R13!,{R0-R7,PC}
 7910 
 7920 
 7930 .set_notecut                    ; ***** EC - set note cut *****
 7940 STRB    R1,[R11,#notecuttimer]
 7950 LDMFD   R13!,{R0-R7,PC}
 7960 
 7970 
 7980 .set_notedelay                  ; ***** ED - set note delay *****
 7990 STRB    R1,[R11,#notedeltimer]
 8000 CMP     R1,#0
 8010 LDMEQFD R13!,{R0-R7,PC}         ;store note delay value, if 0, exit
 8020 :
 8030 AND     R0,R8,#&00000007        ;v1.44 upper 3 (was 2) bits of note period
 8040 AND     R2,R8,#&0000FF00        ;lower 8 bits of note period
 8050 MOV     R0,R0,LSL#8
 8060 ORRS    R0,R0,R2,LSR#8          ;r0 = amiga note
 8070 STREQB  R0,[R11,#notedeltimer]  ;if no new note on this line, then don't allow note delay!
 8080 :
 8090 ;MOVNE   R0,#0
 8100 ;STRNE   R0,[R10,#DMA_offset]    ; ***** fix 26/2/95 - DONT BLANK DMA! or set Period!
 8110 ;STRNE   R0,[R10,#DMA_replen]    ;if there was a new note, then blank it for the delay
 8120 LDMFD   R13!,{R0-R7,R14}        ;...and DON'T exit back to main routine...
 8130 B       dontsetrepeats          ;<- MUST NOT set the repeats, or sample starts anyway!!!
 8140 
 8150 
 8160 .set_patterndelay               ; ***** EE - pattern delay *****
 8170 LDRB    R0,[R12,#patterndelay]
 8180 CMP     R0,#0
 8190 ADDEQ   R1,R1,#1
 8200 STREQB  R1,[R12,#patterndelay]  ;add 1 to delay, and only store if not already in a delay!
 8210 LDMFD   R13!,{R0-R7,PC}
 8220 
 8230 
 8240 ; ** These effects are only called every 'beat' - *not* on the new-note interrupt **
 8250 
 8260 .set_setfilter                  ;E0 - set filter (not possible on RISC OS!)
 8270 .set_invertloop                 ;EF - invert loop
 8280 :
 8290 .set_portaup                    ;1 - portamento up
 8300 .set_portadown                  ;2 - portamento down
 8310 .set_tonevol                    ;5 - tone portamento & volume slide
 8320 .set_vibvol                     ;6 - vibrato & volume slide
 8330 .set_volslide                   ;A - volume slide
 8340 LDMFD   R13!,{R0-R7,PC}
 8350 
 8360 
 8370 .do_retrignote                  ; ***** E9 - retrig note *****
 8380 LDRB    R0,[R11,#retrigtimer]
 8390 SUBS    R0,R0,#1
 8400 ANDEQ   R0,R1,#&F               ;*v1.46 fix 17/1/22, was MOVEQ R0,R1 but R1=&9x...!*
 8410 STRGEB  R0,[R11,#retrigtimer]   ;sub 1 from retrig timer, if 0, then reset for next
 8420 BNE     nextFX
 8430 :
 8440 LDR     R1,[R11,#smp_length]
 8450 MOV     R1,R1,LSL#12
 8460 RSB     R1,R1,#0
 8470 STR     R1,[R10,#DMA_offset]    ;...and do retrig (not sure - should reset addr too??) ****
 8480 B       nextFX
 8490 
 8500 
 8510 .do_notecut                     ; ***** EC - note cut *****
 8520 LDRB    R0,[R11,#notecuttimer]
 8530 SUBS    R0,R0,#1
 8540 BMI     nextFX                  ;sub 1 from note cut timer, if <0 then no cutting to do
 8550 STRB    R0,[R11,#notecuttimer]
 8560 STREQB  R0,[R10,#DMA_volume]
 8570 STREQB  R0,[R11,#currentvol]    ;if timer=0 then do the note cut (set vol to 0)
 8580 B       nextFX
 8590 
 8600 
 8610 .do_notedelay                   ; ***** ED - note delay *****
 8620 LDRB    R0,[R11,#notedeltimer]
 8630 SUBS    R0,R0,#1
 8640 BMI     nextFX                  ;sub 1 from delay timer - if <0 then no delay, so exit
 8650 STRB    R0,[R11,#notedeltimer]
 8660 BNE     nextFX                  ;if delay >0 then still time to wait, so exit
 8670 :
 8680 LDMIA   R11,{R0-R2}             ;r0=end addr, r1=len, r2=rlen
 8690 MOV     R1,R1,LSL#12
 8700 RSB     R1,R1,#0
 8710 STMIA   R10,{R0-R1}             ;delay ended, so set addr, length and replen to start...
 8720 ADD     R3,R10,#DMA_repaddr
 8730 STMIA   R3,{R0,R2}              ;set repeat addr and len
 8740 LDR     R0,[R11,#amigaperiod]   ;load the amiga note for this channel ******}_ Not in PT,
 8750 STR     R0,[R10,#DMA_pitch]     ;store it as the DMA increment        ******}  BUT IS reqd?
 8760 B       nextFX
 8770 
 8780 
 8790 .do_invertloop                  ; ***** EF - invert loop ***** -<( NOT PRESENT IN QTMv1.29 )>-
 8800 :                               ; r0=effect num (&E) r1=FX data (&Fx) r2=E FX num (&F) r6=chan
 8810 ANDS    R0,R1,#&F               ; r1=E FX data r11=chan data block r10=DMA
 8820 STRB    R0,[R11,#invloopspd]
 8830 BLNE    updatefunk
 8840 B       nextFX
 8850 :
 8860 .updatefunk                     ;R0=invloopspeed, not called if spd=0 (check above and in do_FX)
 8870 STMFD   R13!,{R0-R2,R14}
 8880 ADR     R14,funktable
 8890 LDRB    R0,[R14,R0]
 8900 LDRB    R1,[R11,#invloopoff]
 8910 ADD     R1,R1,R0
 8920 STRB    R1,[R11,#invloopoff]
 8930 TST     R1,#%1<<7
 8940 LDMEQFD R13!,{R0-R2,PC}
 8950 :
 8960 MOV     R1,#0
 8970 STRB    R1,[R11,#invloopoff]
 8980 :
 8990 LDR     R0,[R11,#smp_addr]      ;end address
 9000 LDR     R1,[R11,#invaddress]
 9010 ADD     R1,R1,#1
 9020 CMP     R1,R0
 9030 LDRGT   R1,[R11,#smp_replen]
 9040 SUBGT   R1,R0,R1
 9050 STR     R1,[R11,#invaddress]
 9060 LDRB    R0,[R1]
 9070 EOR     R0,R0,#1                ;invert bit 0 = change sign!
 9080 STRB    R0,[R1]
 9090 LDMFD   R13!,{R0-R2,PC}
 9100                                 ; - this very rare effect inverts actual sample data (in memory),
 9110                                 ;   and is the only effect NOT included in QTM<v1.48. Although I
 9120                                 ;   coded the routine, I never found a song which uses it, until
 9130                                 ;   4mat provided a test track ;) thanks! Now fully implememnted.
 9140                                 ;                                                             SH
 9150 .funktable
 9160 EQUB   0:EQUB   5:EQUB   6:EQUB   7:EQUB   8:EQUB  10:EQUB  11:EQUB  13
 9170 EQUB  16:EQUB  19:EQUB  22:EQUB  26:EQUB  32:EQUB  43:EQUB  64:EQUB 128
 9180 ALIGN
 9190 
 9200 
 9210 
 9220 ; ** These effects are called *only* on the new-note interrupt **
 9230 
 9240 .do_setfilter                   ;E0 - set filter
 9250 .do_fineslideup                 ;E1 - fine slide up
 9260 .do_fineslidedown               ;E2 - fine slide down
 9270 .do_glissando                   ;E3 - set glissando
 9280 .do_setvibratowave              ;E4 - set vibrato waveform
 9290 .do_setfinetuning               ;E5 - set fine tuning
 9300 .do_patternloop                 ;E6 - pattern loop
 9310 .do_settremolowave              ;E7 - set tremolo waveform
 9320 .do_finevolumeup                ;EA - fine volume slide up
 9330 .do_finevolumedown              ;EB - fine volume slide down
 9340 .do_patterndelay                ;EE - pattern delay
 9350 :
 9360 .do_setsampleoff                ;9 - set sample offset
 9370 .do_jump2seq                    ;B - jump to sequence
 9380 .do_setsampvol                  ;C - set sample volume
 9390 .do_patternbreak                ;D - pattern break
 9400 .do_setspeed                    ;F - set speed/tempo
 9410 B       nextFX
 9420 
 9430 
 9440 .do_arpeggio                    ; ***** 00 - arpeggio *****
 9450 CMP     R1,#0
 9460 BEQ     nextFX                  ;nothing to do, so skip the code...
 9470 LDRB    R0,[R11,#arpeggiovars]
 9480 SUBS    R0,R0,#1
 9490 MOVLT   R0,#2
 9500 STRB    R0,[R11,#arpeggiovars]
 9510 LDRLT   R0,[R11,#amigaperiod]
 9520 BLT     endarpeg                ;if counter = 2, then no alteration
 9530 :
 9540 LDRB    R2,[R11,#finetune]
 9550 ADR     R6,amigaperiodz
 9560 ADD     R6,R6,R2,LSL#7
 9570 ADD     R6,R6,R2,LSL#4
 9580 LDR     R2,[R11,#amigaperiod]
 9590 :
 9600 LDRB    R3,[R12,#songstatus]    ;v1.44 need to test bit 3, for 3 or 6 octaves
 9610 TST     R3,#%1<<3               ;
 9620 MOVNE   R3,#0                   ;if 6-octaves, use range 0-71
 9630 MOVNE   R5,#71
 9640 MOVEQ   R3,#12                  ;if 3-octaves, use range 12-47
 9650 MOVEQ   R5,#47
 9660 .arpegloop
 9670 MOVS    R4,R3,LSR#1
 9680 LDR     R4,[R6,R4,LSL#2]
 9690 MOVCC   R4,R4,LSL#16
 9700 MOV     R4,R4,LSR#16            ;v1.48 half size note tables *combine with CMP below?*
 9710 :
 9720 CMP     R4,R2
 9730 BLE     arpeggot
 9740 CMP     R3,R5                   ;v1.44 fix - previously had '36' should have been 35 or overrun next table
 9750 ADDLT   R3,R3,#1
 9760 BLT     arpegloop
 9770 :
 9780 .arpeggot
 9790 CMP     R0,#1
 9800 ADDEQ   R3,R3,R1,LSR#4          ;if counter = 1, then add top 4 bits of data
 9810 ANDLT   R4,R1,#&0F
 9820 ADDLT   R3,R3,R4                ;if counter < 1 (0), then add bottom 4 bits
 9830 :
 9840 MOVS    R0,R3,LSR#1
 9850 LDR     R0,[R6,R0,LSL#2]        ;load amiga period
 9860 MOVCC   R0,R0,LSL#16
 9870 MOV     R0,R0,LSR#16            ;v1.48 half size note tables
 9880 .endarpeg
 9890 STR     R0,[R10,#DMA_pitch]     ;store in DMA block - don't alter non-DMA period or number
 9900 B       nextFX
 9910 
 9920 
 9930 .do_portaup                     ; ***** 01 - portamento up *****
 9940 LDRB    R2,[R12,#songstatus]    ;v1.44 need to test bit 3, for 3 or 6 octaves
 9950 TST     R2,#%1<<3               ;
 9960 MOVNE   R2,#28                  ;
 9970 MOVEQ   R2,#113                 ;if 3-octaves, max amiga period is 113, if 6-octaves, max is 28
 9980 :
 9990 LDR     R0,[R11,#amigaperiod]
10000 SUB     R0,R0,R1
10010 CMP     R0,R2
10020 MOVLT   R0,R2
10030 STR     R0,[R11,#amigaperiod]
10040 STR     R0,[R10,#DMA_pitch]
10050 B       nextFX
10060 
10070 
10080 .do_portadown                   ; ***** 02 - portamento down *****
10090 LDRB    R2,[R12,#songstatus]    ;v1.44 need to test bit 3, for 3 or 6 octaves
10100 TST     R2,#%1<<3               ;
10110 MOVNE   R2,#1712                ;
10120 MOVEQ   R2,#856                 ;if 3-octaves, min amiga period is 856, if 6-octaves, min is 1712
10130 :
10140 LDR     R0,[R11,#amigaperiod]
10150 ADD     R0,R0,R1
10160 CMP     R0,R2
10170 MOVGT   R0,R2
10180 STR     R0,[R11,#amigaperiod]
10190 STR     R0,[R10,#DMA_pitch]
10200 B       nextFX
10210 
10220 
10230 .do_toneporta                   ; ***** 03 - tone portamento *****
10240 LDR     R0,[R11,#tportawanted]
10250 LDR     R1,[R11,#amigaperiod]
10260 CMP     R0,#0
10270 CMPNE   R1,#0
10280 BEQ     nextFX                  ;if target period, or current period = 0, nothing to do
10290 :
10300 LDRB    R2,[R11,#tportaspeed]
10310 CMP     R0,R1
10320 BGT     tporta_add
10330 SUB     R1,R1,R2
10340 CMP     R0,R1
10350 MOVGT   R1,R0
10360 MOVGE   R0,#0
10370 STRGE   R0,[R11,#tportawanted]  ;blank target, once we've got there
10380 STR     R1,[R11,#amigaperiod]   ;store target note, now we're here
10390 LDRB    R0,[R11,#glissando]
10400 CMP     R0,#1
10410 BEQ     tporta_setgliss         ;if gliss, do that
10420 STR     R1,[R10,#DMA_pitch]
10430 B       nextFX
10440 
10450 .tporta_add
10460 ADD     R1,R1,R2
10470 CMP     R0,R1
10480 MOVLT   R1,R0
10490 MOVLE   R0,#0
10500 STRLE   R0,[R11,#tportawanted]  ;blank target, once we've got there
10510 STR     R1,[R11,#amigaperiod]   ;store target note, now we're here
10520 LDRB    R0,[R11,#glissando]
10530 CMP     R0,#1
10540 BEQ     tporta_setgliss         ;if gliss, do that
10550 STR     R1,[R10,#DMA_pitch]
10560 B       nextFX
10570 
10580 .tporta_setgliss
10590 ADR     R3,amigaperiodz
10600 LDRB    R4,[R11,#finetune]
10610 ADD     R3,R3,R4,LSL#4
10620 ADD     R3,R3,R4,LSL#7
10630 :
10640 LDRB    R0,[R12,#songstatus]    ;v1.44 need to test bit 3, for 3 or 6 octaves
10650 TST     R0,#%1<<3               ;
10660 MOVNE   R0,#0                   ;if 6-octaves, use range 0-71
10670 MOVNE   R5,#71
10680 MOVEQ   R0,#12                  ;if 3-octaves, use range 12-47
10690 MOVEQ   R5,#47
10700 .glissloop
10710 MOVS    R4,R0,LSR#1
10720 LDR     R4,[R3,R4,LSL#2]
10730 MOVCC   R4,R4,LSL#16            ;
10740 MOV     R4,R4,LSR#16            ;v1.48 half size note tables
10750 :
10760 CMP     R1,R4
10770 BGE     foundgliss
10780 ADD     R0,R0,#1
10790 CMP     R0,R5
10800 BLE     glissloop
10810 .foundgliss
10820 STR     R4,[R10,#DMA_pitch]
10830 B       nextFX
10840 
10850 
10860 .settoneporta                   ;(called from note decode) R7=(fine tuned) note period R6=notenum
10870 LDR     R0,[R11,#amigaperiod]   ;
10880 CMP     R0,#0                   ;must store new wanted note, EVEN if it is the same as the
10890 STRNE   R7,[R11,#tportawanted]  ;current period, because tporta may not have found last one
10900 B       skipnote                ;return to channel routine
10910 
10920 
10930 .do_vibrato                     ; ***** 04 - vibrato *****
10940 LDR     R0,[R11,#amigaperiod]
10950 CMP     R0,#0
10960 BEQ     nextFX
10970 LDR     R1,[R11,#vibrato_speed] ;0-7 speed/depth, 8-15 wave, 26-31 pos (signed)
10980 AND     R3,R1,#&1F<<26          ;get pos in bits 26-30 (bit 31 is sign, so clear it)
10990 TST     R1,#1<<8
11000 BNE     vib_rampdown            ;
11010 TST     R1,#2<<8
11020 MOVNE   R3,#255
11030  ;ADDEQ   R4,R12,#(vibratotable-song_data) AND &FF00
11040  ;ADDEQ   R4,R4,#(vibratotable-song_data) AND &00FF
11050  ADREQ   R4,vibratotable_new
11060  LDREQB  R3,[R4,R3,LSR#26]
11070 .vib_set
11080 AND     R4,R1,#&0F
11090 MUL     R3,R4,R3
11100  ANDS    R2,R1,#&FF000000        ;26-31 pos (+sign) (bits 24 & 25 are 0, because shifted 2)
11110 ADDGE   R0,R0,R3,LSR#7
11120 SUBMI   R0,R0,R3,LSR#7
11130 :
11140 STR     R0,[R10,#DMA_pitch]
11150 :
11160 MOV     R1,R1,LSR#2
11170 AND     R1,R1,#&F<<2
11180 ADD     R2,R1,R2,ASR#24          ;v1.46a this should probably be ASR#24 (was LSR)
11190 STRB    R2,[R11,#vibrato_pos]
11200 B       nextFX
11210 
11220 .vib_rampdown
11230 MOV     R3,R3,LSR#23
11240 TST     R1,#1<<31
11250 RSBNE   R3,R3,#255
11260 B       vib_set
11270 
11280 
11290 .do_tonevol                     ; ***** 05 - tone portamento & volume slide *****
11300 LDRB    R0,[R11,#currentvol]
11310 TST     R1,#&F0
11320 ADDNE   R0,R0,R1,LSR#4
11330 ANDEQ   R1,R1,#&0F
11340 SUBEQ   R0,R0,R1
11350 CMP     R0,#0
11360 MOVMI   R0,#0
11370 CMP     R0,#64
11380 MOVGT   R0,#64
11390 STRB    R0,[R11,#currentvol]
11400 STRB    R0,[R10,#DMA_volume]
11410 B       do_toneporta
11420 
11430 
11440 .do_vibvol                      ; ***** 06 - vibrato & volume slide *****
11450 LDRB    R0,[R11,#currentvol]
11460 TST     R1,#&F0
11470 ADDNE   R0,R0,R1,LSR#4
11480 ANDEQ   R1,R1,#&0F
11490 SUBEQ   R0,R0,R1
11500 CMP     R0,#0
11510 MOVMI   R0,#0
11520 CMP     R0,#64
11530 MOVGT   R0,#64
11540 STRB    R0,[R11,#currentvol]
11550 STRB    R0,[R10,#DMA_volume]
11560 B       do_vibrato
11570 
11580 
11590 .vibratotable_new               ; v1.48 no longer pre-build this in the databank area
11600 EQUB 000:EQUB 024:EQUB 049:EQUB 074:EQUB 097:EQUB 120:EQUB 141:EQUB 161
11610 EQUB 180:EQUB 197:EQUB 212:EQUB 224:EQUB 235:EQUB 244:EQUB 250:EQUB 253
11620 EQUB 255:EQUB 253:EQUB 250:EQUB 244:EQUB 235:EQUB 224:EQUB 212:EQUB 197
11630 EQUB 180:EQUB 161:EQUB 141:EQUB 120:EQUB 097:EQUB 074:EQUB 049:EQUB 024
11640 ALIGN
11650 
11660 
11670 .do_tremolo                     ; ***** 07 - tremolo *****
11680 LDRB    R0,[R11,#currentvol]
11690 LDR     R1,[R11,#tremolo_speed] ;0-3 depth, 4-7 speed, 8-9 wave, 10=no reset, 26-30 pos, 31 sign
11700 AND     R3,R1,#&1F<<26          ;=&7C<<24 ;get pos in bits 26-30 (bit 31 is sign, so clear it)
11710 TST     R1,#%11<<8
11720  ;ADDEQ   R4,R12,#(vibratotable-song_data) AND &FF00
11730  ;ADDEQ   R4,R4,#(vibratotable-song_data) AND &00FF
11740 ADREQ   R4,vibratotable_new
11750 LDREQB  R3,[R4,R3,LSR#26]       ;not ASR, as b31 just used to flag add/sub value
11760 BEQ     trem_set                ;PT prioritises 0/4 (sine)
11770 :
11780 TST R1,#%01<<8                  ;...then 1/5 (sawtooth)
11790 BNE trem_rampdown
11800 MOV R3,#255 ;1 seems to work with 4mat test track  ;...then 2/6 (sqr, and 3/7 treated as 2/6)
11810 .trem_set
11820 AND     R4,R1,#&0F              ;depth
11830 MUL     R3,R4,R3                ;depth*value
11840 ANDS    R2,R1,#&FF000000        ;R2=bits 26-30 pos (+b31 sign) (b24 & b25=0, because pos 26-30)
11850 ADDPL   R0,R0,R3,LSR#6
11860 SUBMIS  R0,R0,R3,LSR#6
11870 MOVMI   R0,#0
11880 CMP     R0,#64
11890 MOVGT   R0,#64
11900 :
11910 STRB    R0,[R10,#DMA_volume]
11920 :
11930 AND     R1,R1,#&F0       ;=speed in bits %11110000
11940 ADD     R2,R2,R1,LSL#(24-2) ;add speed to pos (bits 26-30 + b31 sign)
11950 MOV     R2,R2,ASR#24     ;keep sign, move to bits 0-7 (v1.49 fix - vibrato was fixed in 1.46a!)
11960 STRB    R2,[R11,#tremolo_pos]
11970 B       nextFX
11980 
11990 .trem_rampdown
12000 MOV     R3,R3,LSR#23
12010 TST     R1,#1<<31
12020 RSBNE   R3,R3,#255
12030 B       trem_set
12040 
12050 
12060 .do_volslide                    ; ***** 0A - volume slide *****
12070 LDRB    R0,[R11,#currentvol]
12080 TST     R1,#&F0
12090 ADDNE   R0,R0,R1,LSR#4
12100 ANDEQ   R1,R1,#&0F
12110 SUBEQ   R0,R0,R1
12120 CMP     R0,#0
12130 MOVMI   R0,#0
12140 CMP     R0,#64
12150 MOVGT   R0,#64
12160 STRB    R0,[R11,#currentvol]
12170 STRB    R0,[R10,#DMA_volume]
12180 B       nextFX
12190 
12200 
12210 .musicint_unused                ;R1 has data byte here
12220 MOV     R0,#&108
12230 BL      musicinterrupt
12240 LDMFD   R13!,{R0-R7,PC}
12250 
12260 
12270 ; align so ADR works with next table
12280 ;EQUD 0;EQUD 0:EQUD 0
12290 ]:IF NOT qtmrast% THEN [OPT opt%:EQUD 0:]
12300 [OPT opt%
12310 
12320 .amigaperiodz
12330 ]:P%+=4608/2:O%+=4608/2:[OPT opt%   ;tables of amiga fine tuned/normal periods (half size DCW)
12340 
12350 
12360 
12370 ]
12380 =opt%
