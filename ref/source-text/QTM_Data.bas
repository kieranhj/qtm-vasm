   10 REM QTM v1.49 data blocks
   20 REM
   30 REM LEN Steve Harrison 1993-2023
   40 END
   50 
   60 DEF FNassm_tables
   70 [OPT opt%
   80 ;**********************************************************
   90 ;*            Init data & other vars routine...           *
  100 ;**********************************************************
  110 
  120 
  130 .clearsongvars                  ;clear all vars except song addr and mod vars
  140 STMFD   R13!,{R0-R12,R14}
  150 MOV     R11,#1
  160 B       continueinit
  170 
  180 .init                           ;R12 already set up on entry
  190 STMFD   R13!,{R0-R12,R14}       ;
  200 MOV     R11,#0                  ;clear all vars
  210 .continueinit
  220 ;
  230 ;  Reset song data to default
  240 ;
  250 CMP     R11,#1                  ;0 (NE) if a full re-init
  260 MOV     R0,#2<<16               ;CIA delay (100th sec takes off 1<<16, so 2<<16 gives 50Hz)
  270 MOV     R1,#0                   ;CIA counter
  280 MOV        R2,#&00000006        ;speed (6), counter, pattern delay }_ bytes in the
  290 ORR     R2,R2,#&7D000000        ;CIA tempo (&7D = 125)             }  same word
  300 MOVNE   R3,#0
  310 STRNE   R3,[R12,#patternlen]    ;if full init, reset pattern length to 0
  320 LDREQ   R3,[R12,#songaddr]
  330 MOV     R4,#0                   ;current event, sequence
  340 MOV     R5,#0                   ;last event, pattern, sequence
  350 LDR     R6,[R12,#vuflags]       ;don't wipe vu flags/state/gravity
  360 BIC     R6,R6,#&FF000000        ;            ...but wipe last byte (songstopflags)
  370 MOVNE   R7,#0                   ;if init, clear break flags/pos & max sequence/pattern
  380 LDREQ   R7,[R12,#breakflags]    ;
  390 BICEQ   R7,R7,#&000000FF        ;if 'clear song vars', clear break flags/pos, but not
  400 BICEQ   R7,R7,#&0000FF00        ;  max sequence/pattern
  410 :
  420 STMIA   R12,{R0-R7}             ;reset/blank first 32 bytes
  430 :
  440 ADDNE   R10,R12,#8*4+16         ;skip first 32b & effect flags & vu heights - don't reset these!
  450 MOVNE   R0,#0                   ;
  460 MOVNE   R2,#0                   ;
  470 MOVNE   R3,#0                   ;clear start/pause times
  480 STMNEIA R10!,{R0-R3}            ;that's the first 64 bytes reset (only if full init)
  490 ADDNE   R10,R10,#4              ;don't overwrite 'workspaceptr'
  500 MOVNE   R0,#0                   ;song state/type/actual_dma/chans (4+64) - ok to blank actual dma, resets in init_db
  510 MOVNE   R1,#0                   ;song length (8+64)
  520 MOVNE   R2,#0                   ;garbage data (12+64)
  530 STMNEIA R10!,{R0-R2}            ;(wipe above if full init)
  540 :                               ;don't wipe rest of module vars (like clock speeds etc.)
  550 :                               ; + skip all sound data vars
  560 ADD     R0,R12,#(channeldata-song_data)
  570 MOV     R1,#512
  580 BL      blankmemory             ;v1.48 this replaces clearmusicblocks
  590 MOV     R1,#0
  600 BL      clearDMAchans           ;if R1=0 clear ALL channel sample DMA output data
  610 LDMFD   R13!,{R0-R12,PC}        ;(  R1=&FF to only clear music channels)
  620 
  630 
  640 .clearDMAchans                  ;on entry R1=0 to clear all, R1=&FF to clear music only
  650 STMFD   R13!,{R0,R2-R7,R12,R14}
  660 MOV     R0,#0
  670 MOV     R2,#0
  680 MOV     R3,#0
  690 MOV     R4,#0
  700 MOV     R5,#0
  710 MOV     R6,#0
  720 MOV     R14,#8
  730 ADD     R12,R12,#(DMA_blocks-song_data)
  740 .clearDMAchanloop
  750 LDRB    R7,[R12,#DMA_sampleflag];R7=0 for music sample, &FF for user sample
  760 ANDS    R7,R7,R1                ;now always EQ if R1=0 (all), if R1=&FF only EQ if R7=0 (music)
  770 STMEQIA R12,{R0,R2-R6}          ;clear channel if required
  780 ADD     R12,R12,#24
  790 SUBS    R14,R14,#1
  800 BGT     clearDMAchanloop        ;loop for next
  810 LDMFD   R13!,{R0,R2-R7,R12,PC}
  820 ]
  830 =opt%
  840 
  850 
  860 DEF FNtableoffsets
  870 [OPT opt%
  880 ;**********************************************************
  890 ;*          Song data & other offsets this bit...         *
  900 ;**********************************************************
  910 
  920 .song_data
  930 EQUS    STRING$(64,CHR$0)       ; \_ variables for song
  940 EQUS    STRING$(64,CHR$0)       ; /  and module (r12 is ptr)
  950 EQUS    STRING$(64,CHR$0)       ; ...and sound info
  960 .channeldata
  970 EQUS    STRING$(64,CHR$0)       ; \
  980 EQUS    STRING$(64,CHR$0)       ;  \_ channel variables 0-3, song
  990 EQUS    STRING$(64,CHR$0)       ;  /
 1000 EQUS    STRING$(64,CHR$0)       ; /
 1010 EQUS    STRING$(64,CHR$0)       ; \
 1020 EQUS    STRING$(64,CHR$0)       ;  \_ channel variables 4-7, song
 1030 EQUS    STRING$(64,CHR$0)       ;  /
 1040 EQUS    STRING$(64,CHR$0)       ; /
 1050 .DMA_blocks
 1060 EQUS    STRING$(24,CHR$0)       ; \
 1070 EQUS    STRING$(24,CHR$0)       ;  \
 1080 EQUS    STRING$(24,CHR$0)       ;   \
 1090 EQUS    STRING$(24,CHR$0)       ;    \_ DMA data for channels 1-8
 1100 EQUS    STRING$(24,CHR$0)       ;    /
 1110 EQUS    STRING$(24,CHR$0)       ;   /
 1120 EQUS    STRING$(24,CHR$0)       ;  /
 1130 EQUS    STRING$(24,CHR$0)       ; /
 1140 .volumetable
 1150 EQUS    STRING$(68,CHR$0)       ;un-scaled volume table
 1160 .musicvoltable
 1170 EQUS    STRING$(68,CHR$0)       ;scaled volume table for music samples
 1180 :
 1190 ; general buffer space, used for temporary variables eg. number buffer, and song time calc vars
 1200 :
 1210 .generaluse_addr
 1220                   EQUD 0        ;00 tm_pattloopstart, 8 bytes
 1230                   EQUD 0        ;04
 1240 .numberbuf_new                  ;   16-byte number text buffer, overlaps timer calc variables
 1250                   EQUD 0        ;08 tm_pattloopcount, 8 bytes
 1260                   EQUD 0        ;12
 1270                   EQUD 0        ;16 tm_currentevent,tm_currentseq, 2 bytes each
 1280                   EQUD 0        ;20 tm_patterndelay,tm_breakflags,tm_pattbreakpos,tm_lastsequence
 1290 .rm_use_word      EQUD 0        ;24 4-byte used for RasterMan
 1300 .rm_use_byte      EQUB 0        ;28 1-byte used for RasterMan
 1310 .unused_byte_a    EQUB 0        ;29
 1320 .unused_byte_b    EQUB 0        ;30
 1330 .unused_byte_c    EQUB 0        ;31
 1340 :
 1350 .fakeDMAspace
 1360 EQUS    STRING$(24,CHR$0)       ;fake DMA addr (for switched off chans) + aligns position
 1370                                 ;to start of next block of 64 (DMA only uses 24 bytes!)
 1380 .sampletable
 1390 ]:P%+=1280:O%+=1280:[OPT opt%   ;64 entry sample table (0-30 song, 31-63 game fx)
 1400 .div1notetable
 1410 ]:P%+=160:O%+=160:[OPT opt%     ;use for periods < 150, divide by 1
 1420 .div8notetable
 1430 ]:P%+=240:O%+=240:[OPT opt%     ;use for periods >= 150, divide by 8
 1440 .songtitle_new EQUS STRING$(20+1,CHR$0) ;uses 20 characters + 1 byte }_ 44 bytes total
 1450 .author_new    EQUS STRING$(22+1,CHR$0) ;uses 22 characters + 1 byte }
 1460 .unused_e      EQUD 0
 1470 .arcperiods
 1480 ]:P%+=4096:O%+=4096:[OPT opt%   ;amiga to arc period conversion table
 1490 .linlognew
 1500 ]:P%+=256:O%+=256:[OPT opt%
 1510 .qtmoldinfo_new
 1520 ]:P%+=24*8:O%+=24*8:[OPT opt%
 1530 .samplevoltable
 1540 EQUS    STRING$(68,CHR$0)       ;scaled volume table for sound effects
 1541 
 1542 ALIGN
 1550 .song_data_end
 1560 ]
 1570 =opt%
 1580 
 1590 
 1600 DEF PROCinit_offsets
 1610 LOCAL dataoffs,dataoffs_size
 1620 dataoffs_size=10*1024
 1630 DIM dataoffs dataoffs_size
 1640 :
 1650 opt%=12
 1660 P%=0:O%=dataoffs:L%=O%+dataoffs_size
 1670 [OPT opt%
 1680 FNtableoffsets
 1690 ]
 1691 REM PRINTsong_data_end-song_data
 1740 :
 1750 REM
 1760 REM layout of song workspace
 1770 REM
 1780 REM x=reset on init, o=retain on partial init, i=reset in init_datab, m=machinedetect
 1790 REM z=module init routime, v=initVIDCandpitch (not16bit)
 1800 REM
 1810 CIAdelay        =00     :REM x 00 w - CIA delay (100Hz decrement <<16)            \
 1820 CIAcounter      =04     :REM x 04 w - CIA counter (count down from delay)         /
 1830 speed           =08     :REM x 08 b - speed
 1840 counter         =09     :REM x 09 b - counter
 1850 patterndelay    =10     :REM x 10 b - pattern delay timer
 1860 CIAtempo        =11     :REM x 11 b - CIA tempo value
 1870 songaddr        =12     :REM o 12 w - song address                                \
 1880 currentevent    =16     :REM x 16 b - current event (ie. next to play)             }
 1890                         :REM x 17 b - (current pattern is unused, must be 0)       }
 1900 currentseq      =18     :REM x 18 b - current sequence                             }
 1910                         :REM x 19 b - (must be 0)                                 /
 1920 lastevent       =20     :REM x 20 b - last played event                           \
 1930 lastpattern     =21     :REM x 21 b - pattern from last event                      }
 1940 lastsequence    =22     :REM x 22 b - sequence from last event                     }
 1950                         :REM x 23 b - (must be 0)                                 /
 1960 vuflags         =24     :REM   24 b - vu bar flags (1 bit per channel)
 1970 vustate         =25     :REM   25 b - vu controller state (0-off, 1-fake, 2-effct, 3-real)
 1980 vugravity       =26     :REM i 26 b - vu gravity / vsync
 1990 songstopflags   =27     :REM x 27 b - flags for song stop interrupt
 2000 breakflags      =28     :REM x 28 b - break reason flags
 2010 pattbreakpos    =29     :REM x 29 b - pattern break position
 2020 maxsequence     =30     :REM o 30 b - max sequence position
 2030 maxpattern      =31     :REM o 31 b - max pattern number
 2040 FXflags         =32     :REM x 32 w - effect status flags
 2050 E_FXflags       =36     :REM x 36 w - E effect status flags
 2060 vuheights       =40     :REM   40 w - vu heights, 1 byte per channel (chans 1-4)
 2070 vuheights58     =44     :REM   44 w - vu heights58, 1 byte per channel (chans 5-8)
 2080 start_time      =48     :REM x 48 w -
 2090 pause_time      =52     :REM x 52 w -
 2100 total_time      =56     :REM x 56 w -
 2110 est_time        =60     :REM x 60 w -
 2120 :
 2130 :
 2140 REM
 2150 REM  layout of module workspace (song workspace+64)
 2160 REM
 2170 modworkspace    =00+64  :REM z 00 w - addr of QTM module workspace pointer
 2180 songstatus      =04+64  :REM x 04 b - song status byte:
 2190                         :REM
 2200                         :REM              bit   state if set     state if clear
 2210                         :REM
 2220                         :REM                0 - song loaded      no song loaded
 2230                         :REM                1 - loaded to RMA    user load
 2240                         :REM                2 - playing          stopped/paused
 2250                         :REM                3 - use 6-octaves    use 3-octaves (PT)
 2260                         :REM                4 - song has looped  not yet looped/ended
 2270                         :REM
 2280 songtype        =05+64  :REM x 05 b - song type:
 2290                         :REM
 2300                         :REM         0 - 15 inst sound tracker, 4 channel
 2310                         :REM         1 - 31 inst sound tracker, 4 channel
 2320                         :REM         2 - 31 inst (M.K.) sound/pro tracker, 4 channel
 2330                         :REM         3 - 31 inst, 4/8 channel (FLT4/8) StarTrekker 1024 byte pat
 2340                         :REM         4 - 31 inst, 4/6/8 channel (8/6/4CHN) FastTracker 1024 byte pat, extended octave
 2350                         :REM
 2360 actual_dma      =06+64  :REM x 06 b - actual dma size in use (eg. 256 for RPi)
 2370 songchans       =07+64  :REM x 07 b - channels used by song (4/6/8)
 2380 songlength      =08+64  :REM x 08 w - song length (usually read from disc)
 2390 garbagedata     =12+64  :REM x 12 w - (disc song length)-(actual song length)
 2400 :
 2410 : REM not blanked on init after garbage data
 2420 :
 2430 clockspeed      =16+64  :REM v 16 w - current VIDC clk speed*1000 (unused if 16bit snd HW)
 2440 shiftclock      =20+64  :REM v 20 w - current VIDC clk speed*4096 (unused if 16bit snd HW)
 2450 actual_uS       =24+64  :REM   24 w - actual sample speed used (*4096)
 2460 chanendflags    =28+64  :REM   28 w - channel end flags (no space for this in sound_data)
 2470 DMAinterrupts   =32+64  :REM   32 w - count of DMA interrupts, while recalculating clock
 2480 ClockCalcEnd    =36+64  :REM   36 w - time to end counting of DMA interrupts (after 1 sec)
 2490 armchip         =40+64  :REM m 40 b - arm chip number
 2500 musicoptbyte    =41+64  :REM i 41 b - music options byte
 2510 oldchansused    =42+64  :REM   42 b - chans_use before current song started playing
 2520 osversion       =43+64  :REM m 43 b - osversion-&A0 (as from OS_Byte 129 minus &A0)
 2530 musicintaddr    =44+64  :REM i 44 w - address of music interrupt code
 2540 musicintr12     =48+64  :REM i 48 w - value of R12 to call interrupt with
 2550 tempaddrptr     =52+64  :REM i 52
 2560 fake8bitDMA     =56+64  :REM i 56
 2570 patternlen      =60+64  :REM o 60 w - 1024 (4 chan), 1536 (6 chan) or 2048 (8 chan)
 2580 :
 2590 :
 2600 REM
 2610 REM  layout of sound workspace (song workspace+128)
 2620 REM
 2630 debugbyte       =00+128 :REM   00 b - used by swi_qtmdebug
 2640 QTMstereos      =00+128 :REM   00 b \   [first byte 00 unused by setstereos]
 2650                         :REM   |     }- stereo positions 8 bytes +1 sync (at start)
 2660                         :REM   08 b /
 2670 oldinfoinuse    =09+128 :REM   09 b - <>0 means "qtmoldinfo" backup DMA area is in use
 2680 oldstereos      =09+128 :REM   09 b \   [first byte 09 unused by setstereos]
 2690                         :REM   |     }- old stereo positions 8 bytes +1 sync (at start)
 2700                         :REM   17 b /
 2710 chans_use       =18+128 :REM i 18 b - default channels in use must be 4 *OR* 8
 2720                         :REM          so a +ve check for NOT 4 means 8 selected!
 2730 current_uS      =19+128 :REM i 19 b - sample period
 2740 current_dma     =20+128 :REM i 20 b - dma buffer length/16 (13=208 bytes, 26=416 bytes)
 2750 soundflags      =21+128 :REM m 21 b - sound flags:
 2760                         :REM
 2770                         :REM              bit   state if set    state if clear
 2780                         :REM
 2790                         :REM                0 - sound on        sound off
 2800                         :REM (default off ) 1 - trans sound on  trans sound off
 2810                         :REM (- unless RO5) 2 - new VIDC        old VIDC (don't use OS)
 2820                         :REM                3 - recalcing clock not recalcing clock
 2830                         :REM                4 - quick recalc    full (slow) recalc
 2840                         :REM (experimental) 5 - song uses 5-8   4 chan songs on chans 1-3
 2850                         :REM (v1.49)        6 - leave on        turn off after QTM_Pause
 2860                         :REM                7 - 16bit sound HW  8bit sound HW
 2870                         :REM
 2880 musicvolume     =22+128 :REM i 22 b - overall music volume scaler
 2890 samplevolume    =23+128 :REM i 23 b - overall sample/sound effects volume scaler
 2900 channelstate    =24+128 :REM i 24 w - 1 bit for 8 channels 1/0 -> MUSIC on/off, shifted<<1
 2910                         :REM
 2920 REM   >>>>>   ************** see DMA filler section before altering channelstate *************
 2930                         :REM
 2940 oldConfigure    =28+128 :REM   28 w \
 2950                         :REM   |     }- 4 words of old configure state
 2960                         :REM   40 w /
 2970 QTMblock        =44+128 :REM   44 w \
 2980                         :REM   |     }- 4 words, QTM configure block
 2990                         :REM   56 w /
 3000 DMABuffer       =60+128 :REM   60 w - DMA buffer address
 3010 :
 3020 generalusebuffer=64*3+64*8+24*8+68*2 :REM v1.48 this is 32 bytes and sits after musicvoltable
 3030 :
 3040 tm_pattloopstart=generalusebuffer+00 :REM 1b per chan, 8 chans
 3050 tm_pattloopcount=generalusebuffer+08 :REM 1b per chan, 8 chans }
 3060 tm_currentevent =generalusebuffer+16 :REM 2b                    }
 3070 tm_currentseq   =generalusebuffer+18 :REM 2b                     }
 3080 tm_patterndelay =generalusebuffer+20 :REM 1b                      }- overlaps number buffer
 3090 tm_breakflags   =generalusebuffer+21 :REM 1b                     }
 3100 tm_pattbreakpos =generalusebuffer+22 :REM 1b                    }
 3110 tm_lastsequence =generalusebuffer+23 :REM 1b                   }
 3120 :
 3130 rm_CIAdec       =generalusebuffer+24 :REM 4b RasterMan DMA only
 3140 rm_dmainprogress=generalusebuffer+28 :REM 1b RasterMan DMA only
 3150 :
 3160 dma_calls =tm_pattloopstart
 3170 dma_efv   =tm_pattloopstart+4
 3180 dma_eav   =tm_patterndelay
 3190 dma_clc   =generalusebuffer+32+24+1280+160+240+44
 3200 dma_rnv   =00+generalusebuffer+32 :REM overlaps fakeDMAbuff
 3210 dma_rfv   =04+generalusebuffer+32
 3220 dma_rav   =08+generalusebuffer+32
 3230 dma_ce    =12+generalusebuffer+32
 3240 dma_fv    =16+generalusebuffer+32
 3250 dma_an    =20+generalusebuffer+32
 3260 :
 3270 : REM channel blocks are blanked on init...
 3280 :
 3290 REM
 3300 REM  layout of channel data blocks
 3310 REM
 3320 smp_addr        =00     :REM   00 w - current sample end address
 3330 smp_length      =04     :REM   04 w - current sample length
 3340 smp_replen      =08     :REM   08 w - current sample repeat length  (offset not needed!)
 3350 finetune        =12     :REM   12 b - finetune byte
 3360                         :REM   13 b - must be 0
 3370                         :REM   14 b - must be 0
 3380 currentvol      =15     :REM   15 b - current linear volume         }  }  DMA for backup
 3390 invaddress      =16     :REM   16 w - current sample repeat start addr (used by invert loop only)
 3400                         :REM   20 w - unused
 3410                         :REM   24 w - unused
 3420 samplenumber    =28     :REM   28 b - sample number                 } \
 3430 currentFXnum    =29     :REM   29 b - current effect number         }  }  These have to be
 3440 currentFXdata   =30     :REM   30 b - current effect data           }  }- aligned next to
 3450                         :REM   31 b - unused
 3460 amigaperiod     =32     :REM   32 w - amiga period                  } / *****************
 3470 vibrato_speed   =36     :REM   36 b - vibrato speed
 3480 vibrato_wave    =37     :REM   37 b - vibrato wave type
 3490                         :REM   38 b - (must be 0)
 3500 vibrato_pos     =39     :REM   39 b - position in vibrato wave
 3510 tremolo_speed   =40     :REM   40 b - tremolo speed
 3520 tremolo_wave    =41     :REM   41 b - tremolo wave type
 3530                         :REM   42 b - (must be 0)
 3540 tremolo_pos     =43     :REM   43 b - position in tremolo wave
 3550 tportawanted    =44     :REM   44 w - tporta wanted amiga note
 3560 tportaspeed     =48     :REM   48 b - tporta speed
 3570 glissando       =49     :REM   49 b - glissando (tporta type)
 3580 setsampoff      =50     :REM   50 b - last used sample offsets
 3590 retrigtimer     =51     :REM   51 b - retrig note timer
 3600 notecuttimer    =52     :REM   52 b - note cut timer
 3610 notedeltimer    =53     :REM   53 b - note delay timer
 3620 pattloopstart   =54     :REM   54 b - pattern loop start event
 3630 pattloopcount   =55     :REM   55 b - pattern loop counter
 3640 arpeggiovars    =56     :REM   56 b - arpeggio timer
 3650 notenumber      =57     :REM   57 b - current note number (0-35)
 3660 invloopspd      =58     :REM   58 b - invert loop speed
 3670 invloopoff      =59     :REM   59 b - invert loop current offset
 3680                         :REM   60 w - unused
 3690 :
 3700 :
 3710 REM
 3720 REM  layout of DMA data blocks
 3730 REM
 3740 DMA_address     =00     :REM 00 w - sample (or rep) end address     } \
 3750 DMA_offset      =04     :REM 04 w - sample offset (-ve)             }  \
 3760 DMA_pitch       =08     :REM 08 w - amiga pitch increment           }   \
 3770 DMA_volume      =12     :REM 12 b - sample volume (linear 0-64)     }    }- Used by DMA
 3780 DMA_sampleflag  =13     :REM 13 b - music sample=0 sound effect=&FF }   /
 3790 DMA_repaddr     =16     :REM 16 w - repeat end address              }  /
 3800 DMA_replen      =20     :REM 20 w - repeat length (+ve)             } /
 3810 :
 3820 : REM *** ONLY *** 24 bytes are used by DMA block
 3830 :
 3840 REM  format of sample table:
 3850 REM
 3860 REM
 3870 REM  | 00 w | address of sample     |
 3880 REM  | 04 w | sample length         |
 3890 REM  | 08 w | repeat offset         | (or 0)
 3900 REM  | 12 w | repeat length         | (or 0-2)
 3910 REM  | 16 b | fine tune byte        | (0-15, -8 to 7)
 3920 REM  | 17 b | (unused)              |
 3930 REM  | 18 b | (unused)              |
 3940 REM  | 19 b | volume                | (0-64)
 3950 ENDPROC
 3960 
