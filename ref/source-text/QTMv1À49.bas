   10 REM QTM v1.49 source code release [now with ARM2 DMA code unroller]
   20 REM
   30 REM currently the ARM2 code unroller, unrolls DMA code on ARM2/ARM250 and ARM3
   40 REM ...but ARM3 would only ever use this if CACHE was switched off (on ARM3 you
   50 REM can easily read the cache status, and switch to unrolled code if cache off).
   60 REM However, very few people will switch ARM3 cache off, except for testing or
   70 REM running very old ARM2 games (which won't use QTM anyhow). So do we need to
   80 REM consider unrolling DMA code for cache-off ARM3's? Probably not. But better
   90 REM idea...default the ARM2/cache off ARM3 DMA jump table to point to cache on
  100 REM routines, then if cache detected as off, trigger a call back to call the
  110 REM unroll routines... save a lot of space if combine sound DMA code into one!
  120 REM
  130 REM Details of release version of QTMModule v1.4x:
  140 REM
  150 ver$="1.49"
  160 date$=MID$(TIME$,5,11)
  170 :
  180 datestamp$="14:54:39 19 Mar 2023"
  190 filetype%=&FFA
  200 filesize%=63064
  210 paulvigay32bitcrc%=&F2B0FC32 :REM use !CRC by Paul Vigay, v1.00 (1990) - v1.03 (2007)
  220 REM
  230 REM LEN Steve Harrison 1993-2023
  240 REM
  250 REM email: sah3000@yahoo.com
  260 REM
  270 REM 32bit compatibility by Jeffrey Lee, me@phlamethrower.co.uk
  280 :
  290 alphatest%=FALSE
  300 betatest%=TRUE
  310 :
  320 ON ERROR REPORT:PRINT" at line ";ERL:END
  330 PRINT"Press R to build QTM v"+ver$+" RasterMan edition, or wait";:key$=INKEY$(200):PRINTCHR$13;STRING$(53," ");CHR$13;
  340 IF key$="R" OR key$="r" THEN qtmrast%=TRUE ELSE qtmrast%=FALSE
  350 IF qtmrast% THEN
  360  PRINT'"Bulding QTM v"+ver$+" RasterMan edition"'
  370  PRINT"Assemble: (a) 24uS, 4-channel version for RasterMan"
  380  PRINT"       or (b) 48uS, 4/8-channel version for RasterMan"
  390  PRINT"Select (a) or (b): ";:choice$=GET$:PRINTchoice$:dmachoice=0
  400  IF choice$="A" OR choice$="a" THEN dmachoice=24:maxchans=4:REM maxchans currently only used by
  410  IF choice$="B" OR choice$="b" THEN dmachoice=48:maxchans=8:REM RasterMan edition of QTM
  420  IF dmachoice=0 THEN ERROR 255,"Bad choice"
  430 ELSE
  440  dmachoice=32:maxchans=8
  450 ENDIF
  460 :
  470 ON ERROR REPORT:PRINT" at line ";ERL:END
  480 PRINT'"* Assembling QTMv"+ver$+" module *";:IF qtmrast% PRINTCHR$8;"for RasterMan, at ";dmachoice;"uS/"+STR$maxchans+"chan *"' ELSE PRINT'
  490 :
  500 DIM lib$(8)
  510 lib$(1)="<QTMAssemble$Dir>.QTM_Play"
  520 lib$(2)="<QTMAssemble$Dir>.QTM_Song"
  530 lib$(3)="<QTMAssemble$Dir>.QTM_DMA"
  540 lib$(4)="<QTMAssemble$Dir>.QTM_Mod"
  550 lib$(5)="<QTMAssemble$Dir>.TextComprs"
  560 lib$(6)="<QTMAssemble$Dir>.QTM_Data"
  570 lib$(7)="<QTMAssemble$Dir>.QTM_VUcode"
  580 lib$(8)="<QTMAssemble$Dir>.QTM_Timer"
  590 OVERLAY lib$()
  600 :
  610 PROCinit
  620 PROCinit_offsets
  630 PROCmodvars
  640 PROCdefinecodes         :REM for text compressor
  650 PROCassm
  660 PROCinit_amiperiods
  670 :
  680 IF generalusebuffer<>(generaluse_addr-song_data) THEN ERROR 255,"Data offsets misaligned!"
  690 :
  700 OSCLI"Load <QTMAssemble$Dir>.LOGdata "+STR$~(loglintab+code%)
  710 :
  720 OSCLI"FX 138,0,"+STR$(ASC"Q"):OSCLI"FX 138,0,"+STR$(ASC"T"):OSCLI"FX 138,0,"+STR$(ASC"M")
  730 OSCLI"FX 138,0,"+STR$(ASC"M"):OSCLI"FX 138,0,"+STR$(ASC"o"):OSCLI"FX 138,0,"+STR$(ASC"d")
  740 OSCLI"FX 138,0,"+STR$(ASC"u"):OSCLI"FX 138,0,"+STR$(ASC"l"):OSCLI"FX 138,0,"+STR$(ASC"e")
  750 PRINT
  760 :
  770 PROCassmcrc
  780 PROCvalidatecrc
  790 :
  800 INPUT'"Save module name: "md$
  810 OSCLI"Save <QTMAssemble$Dir>."+md$+" "+STR$~code%+"+"+STR$~endcode%
  820 OSCLI"Settype <QTMAssemble$Dir>."+md$+" Module"
  830 END
  840 
  850 DEF PROCassm
  860 codelen%=63*1024
  870 DIM code% codelen%
  880 PRINT"Clearing area..."
  890 :
  900 FOR c=code% TO code%+codelen% STEP 4:!c=0:NEXT
  910 PRINT"Assembling..."
  920 :
  930 FOR opt%=12 TO 14 STEP 2
  940 P%=0:O%=code%:L%=O%+codelen%
  950 :
  960 [OPT opt%
  970 
  980 FNassm_mod      ;QTM_Mod  (incl. timer code and VU code)
  990 FNassm_main     ;QTM_Play (v1.48 datablocks now at the end of module)
 1000 FNassm_initsong ;QTM_Song
 1010 FNassm_dma      ;QTM_DMA
 1020 
 1030 
 1040 ; Trial of improved and shorter looped DIV code
 1050 
 1060 ; on entry - R0=A +ve; R1=B +ve >0
 1070 ; on exit - R0=A DIV B; R1=A MOD B
 1080 
 1090 ;R0=num
 1100 ;R1=den
 1110 ;R2=cnt
 1120 ;R3=mod
 1130 
 1140 ; seems to equal the unrolled AU div routine when dividing large 32 bit numbers by 512+
 1150 
 1160 .r0_div_r1
 1170 STMFD R13!,{R1-R3,R14}
 1180 MOV   R2,#28:MOV R3,R0,LSR#4
 1190 CMP   R1,R3,LSR#12:SUBLE R2,R2,#16:MOVLE R3,R3,LSR#16
 1200 CMP   R1,R3,LSR#4 :SUBLE R2,R2,#8 :MOVLE R3,R3,LSR#8
 1210 CMP   R1,R3       :SUBLE R2,R2,#4 :MOVLE R3,R3,LSR#4
 1220 MOV   R0,R0,LSLR2 :RSB   R14,R1,#0
 1230 ADDS  R0,R0,R0
 1240 RSB   R2,R2,#32
 1250 .divloo
 1260 ADCS  R3,R14,R3,LSL#1:SUBLO R3,R3,R14:ADCS R0,R0,R0
 1270 ADCS  R3,R14,R3,LSL#1:SUBLO R3,R3,R14:ADCS R0,R0,R0
 1280 ADCS  R3,R14,R3,LSL#1:SUBLO R3,R3,R14:ADCS R0,R0,R0
 1290 ADCS  R3,R14,R3,LSL#1:SUBLO R3,R3,R14:ADCS R0,R0,R0
 1300 SUB   R2,R2,#4:TEQ R2,#0
 1310 BNE   divloo
 1320 ;MOV   R1,R3
 1330 LDMFD R13!,{R1-R3,PC}
 1340 ;FNAUdiv                         ;assembles R0/R1 -> R0 (*** UNSIGNED!!! ***)
 1350 ;MOV     PC,R14
 1360 
 1370 
 1380 ; Arm type detect v2.60, (c) Phoenix 1995
 1390 ;           updated by Jeffrey Lee to avoid clash with bug in FPE module 4.12-4.31 (2000-2013)
 1400 ;
 1410 ; On entry:
 1420 ;           -
 1430 ;           * Only call from SVC mode *
 1440 ; On exit :
 1450 ;           R0 = processor type (Arm 2, 3 or 6 - for Arm600 and above)
 1460 
 1470 
 1480 .armcheck                       ;v2.60 by Phoenix  / updated by Jeffrey Lee
 1490 MOVS    R0,#0                   ;- sets 'Z' (EQ) flag in CPSR
 1500 EQUD    &E10F0000 ;MRS R0,CPSR  ;Arm 2/3 decodes as 'TST PC,R0'
 1510 CMP     R0,#0
 1520 MOVNE   R0,#6
 1530 MOVNE   PC,R14                  ;32bit will always exit here
 1540 :
 1550 STMFD   R13!,{R1-R3,R14}
 1560 MOV     R0,#(%1<<27) OR %11
 1570 TEQP    R0,#0                   ;no interrupts, as we temporarily poke the undefined inst vector
 1580 :
 1590 MOV     R3,#4
 1600 LDR     R1,addpclr4
 1610 LDR     R2,[R3]                 ;get current vector
 1620 STR     R1,[R3]                 ;replace with "ADD PC,LR,#4"
 1630 MOV     R0,#2                   ;assume ARM2
 1640 FNmrc("","CP15,0,R1,C0,C0")     ;read Arm ID number (designer, manufacture, type, version)
 1650 MOV     R0,#3                   ;this will only execute on arm3!
 1660 STR     R2,[R3]                 ;reset to previous handler
 1670 :
 1680 MOV     R1,#(%0<<27) OR %11
 1690 TEQP    R1,#0
 1700 LDMFD   R13!,{R1-R3,PC}^        ;exit 26bit style
 1710 
 1720 
 1730 .addpclr4
 1740 ADD     PC,R14,#4               ;return from undefined inst vector, skipping the instruction
 1750                                 ;which aborted and the next instruction after it
 1760 
 1770 FNassm_tables   ;QTM_Data
 1780 
 1790 .endcode%
 1800 ]
 1810 NEXT
 1820 ENDPROC
 1830 
 1840 
 1850 REM **********************************************************
 1860 REM *           Variable offsets for data accessing          *
 1870 REM **********************************************************
 1880 
 1890 
 1900 DEF PROCinit
 1910 uS=32               :REM 32 uS default
 1920 :
 1930 dma=208             :REM 208-byte DMA buffer (for 8 bit sound and scopes)
 1940 :
 1950 IF qtmrast% THEN
 1960  REM v1.46 is custom 4-channel, 24uS @ 50Hz refill for RasterMan and !Django
 1970  IF dmachoice=48 THEN
 1980   uS=48:dma=416 :REM v1.43se, use 48uS & 416-byte buffer for 50Hz DMA/rasters
 1990  ELSE
 2000   uS=24:dma=832 :REM v1.46c, use 48uS & 416-byte buffer for 50Hz DMA/rasters
 2010  ENDIF
 2020 ENDIF
 2030 :
 2040 : REM Note: QTM v1.42 and above can use 208, 416 and 832 for DMA buffer size by default.
 2050 : REM However, if you wish to use a different value you need to check the DMA routines (Arm2
 2060 : REM and Arm3+) will work with the new size AND adjust the LSL multipliers 'dmashift1/2/3'.
 2070 :
 2080 dmashift1=0:dmashift2=0:dmashift3=0
 2090 :
 2100 IF dma=208 THEN dmashift1=4:dmashift2=6:dmashift3=7 :REM amount to shift a register left, in
 2110 IF dma=416 THEN dmashift1=5:dmashift2=7:dmashift3=8 :REM order to multiply by the specified
 2120 IF dma=832 THEN dmashift1=6:dmashift2=8:dmashift3=9 :REM dma buffer size.
 2130 :
 2140 IF (1<<dmashift1)+(1<<dmashift2)+(1<<dmashift3) <> dma THEN ERROR 255,"DMA buffer size incorrectly defined"
 2150 :
 2160 accuracy%=12
 2170 accdiff%=16-accuracy%
 2180 qtm_error=&809E00
 2190 ENDPROC
 2200 
 2210 
 2220 REM **********************************************************
 2230 REM *  Set up data tables (vibrato/periods)                  *
 2240 REM **********************************************************
 2250 
 2260 
 2270 DEF PROCinit_amiperiods
 2280 P%=amigaperiodz:O%=P%+code%:L%=code%+P%+2304
 2290 opt%=12
 2300 :
 2310 [OPT opt%
 2320 .fttabstart%
 2330 ; Tuning 0, Normal
 2340 DCW1712:DCW1616:DCW1524:DCW1440:DCW1356:DCW1280:DCW1208:DCW1140:DCW1076:DCW1016:DCW 960:DCW 907
 2350 DCW 856:DCW 808:DCW 762:DCW 720:DCW 678:DCW 640:DCW 604:DCW 570:DCW 538:DCW 508:DCW 480:DCW 453
 2360 DCW 428:DCW 404:DCW 381:DCW 360:DCW 339:DCW 320:DCW 302:DCW 285:DCW 269:DCW 254:DCW 240:DCW 226
 2370 DCW 214:DCW 202:DCW 190:DCW 180:DCW 170:DCW 160:DCW 151:DCW 143:DCW 135:DCW 127:DCW 120:DCW 113
 2380 DCW 107:DCW 101:DCW  95:DCW  90:DCW  85:DCW  80:DCW  75:DCW  71:DCW  67:DCW  63:DCW  60:DCW  56
 2390 DCW  53:DCW  50:DCW  47:DCW  45:DCW  42:DCW  40:DCW  37:DCW  35:DCW  33:DCW  31:DCW  30:DCW  28
 2400 
 2410 ;ft1
 2420 DCW1700:DCW1604:DCW1514:DCW1430:DCW1348:DCW1274:DCW1202:DCW1134:DCW1070:DCW1010:DCW 954:DCW 900
 2430 DCW 850:DCW 802:DCW 757:DCW 715:DCW 674:DCW 637:DCW 601:DCW 567:DCW 535:DCW 505:DCW 477:DCW 450
 2440 DCW 425:DCW 401:DCW 379:DCW 357:DCW 337:DCW 318:DCW 300:DCW 284:DCW 268:DCW 253:DCW 239:DCW 225
 2450 DCW 213:DCW 201:DCW 189:DCW 179:DCW 169:DCW 159:DCW 150:DCW 142:DCW 134:DCW 126:DCW 119:DCW 113
 2460 DCW 106:DCW 100:DCW  94:DCW  89:DCW  84:DCW  79:DCW  75:DCW  71:DCW  67:DCW  63:DCW  59:DCW  56
 2470 DCW  53:DCW  50:DCW  47:DCW  44:DCW  42:DCW  39:DCW  37:DCW  35:DCW  33:DCW  31:DCW  29:DCW  28
 2480 
 2490 ;ft2
 2500 DCW1688:DCW1592:DCW1504:DCW1418:DCW1340:DCW1264:DCW1194:DCW1126:DCW1064:DCW1004:DCW 948:DCW 894
 2510 DCW 844:DCW 796:DCW 752:DCW 709:DCW 670:DCW 632:DCW 597:DCW 563:DCW 532:DCW 502:DCW 474:DCW 447
 2520 DCW 422:DCW 398:DCW 376:DCW 355:DCW 335:DCW 316:DCW 298:DCW 282:DCW 266:DCW 251:DCW 237:DCW 224
 2530 DCW 211:DCW 199:DCW 188:DCW 177:DCW 167:DCW 158:DCW 149:DCW 141:DCW 133:DCW 125:DCW 118:DCW 112
 2540 DCW 105:DCW  99:DCW  94:DCW  88:DCW  83:DCW  79:DCW  74:DCW  70:DCW  66:DCW  62:DCW  59:DCW  56
 2550 DCW  52:DCW  49:DCW  47:DCW  44:DCW  41:DCW  39:DCW  37:DCW  35:DCW  33:DCW  31:DCW  29:DCW  28
 2560 
 2570 ;ft3
 2580 DCW1676:DCW1582:DCW1492:DCW1408:DCW1330:DCW1256:DCW1184:DCW1118:DCW1056:DCW 996:DCW 940:DCW 888
 2590 DCW 838:DCW 791:DCW 746:DCW 704:DCW 665:DCW 628:DCW 592:DCW 559:DCW 528:DCW 498:DCW 470:DCW 444
 2600 DCW 419:DCW 395:DCW 373:DCW 352:DCW 332:DCW 314:DCW 296:DCW 280:DCW 264:DCW 249:DCW 235:DCW 222
 2610 DCW 209:DCW 198:DCW 187:DCW 176:DCW 166:DCW 157:DCW 148:DCW 140:DCW 132:DCW 125:DCW 118:DCW 111
 2620 DCW 104:DCW  99:DCW  93:DCW  88:DCW  83:DCW  78:DCW  74:DCW  70:DCW  66:DCW  62:DCW  59:DCW  55
 2630 DCW  52:DCW  49:DCW  46:DCW  44:DCW  41:DCW  39:DCW  37:DCW  35:DCW  33:DCW  31:DCW  29:DCW  27
 2640 
 2650 ;ft4
 2660 DCW1664:DCW1570:DCW1482:DCW1398:DCW1320:DCW1246:DCW1176:DCW1110:DCW1048:DCW 990:DCW 934:DCW 882
 2670 DCW 832:DCW 785:DCW 741:DCW 699:DCW 660:DCW 623:DCW 588:DCW 555:DCW 524:DCW 495:DCW 467:DCW 441
 2680 DCW 416:DCW 392:DCW 370:DCW 350:DCW 330:DCW 312:DCW 294:DCW 278:DCW 262:DCW 247:DCW 233:DCW 220
 2690 DCW 208:DCW 196:DCW 185:DCW 175:DCW 165:DCW 156:DCW 147:DCW 139:DCW 131:DCW 124:DCW 117:DCW 110
 2700 DCW 104:DCW  98:DCW  92:DCW  87:DCW  82:DCW  78:DCW  73:DCW  69:DCW  65:DCW  62:DCW  58:DCW  55
 2710 DCW  52:DCW  49:DCW  46:DCW  43:DCW  41:DCW  39:DCW  36:DCW  34:DCW  32:DCW  31:DCW  29:DCW  27
 2720 
 2730 ;ft5
 2740 DCW1652:DCW1558:DCW1472:DCW1388:DCW1310:DCW1238:DCW1168:DCW1102:DCW1040:DCW 982:DCW 926:DCW 874
 2750 DCW 826:DCW 779:DCW 736:DCW 694:DCW 655:DCW 619:DCW 584:DCW 551:DCW 520:DCW 491:DCW 463:DCW 437
 2760 DCW 413:DCW 390:DCW 368:DCW 347:DCW 328:DCW 309:DCW 292:DCW 276:DCW 260:DCW 245:DCW 232:DCW 219
 2770 DCW 206:DCW 195:DCW 184:DCW 174:DCW 164:DCW 155:DCW 146:DCW 138:DCW 130:DCW 123:DCW 116:DCW 109
 2780 DCW 103:DCW  97:DCW  92:DCW  87:DCW  82:DCW  77:DCW  73:DCW  69:DCW  65:DCW  61:DCW  58:DCW  54
 2790 DCW  51:DCW  48:DCW  46:DCW  43:DCW  41:DCW  38:DCW  36:DCW  34:DCW  32:DCW  30:DCW  29:DCW  27
 2800 
 2810 ;ft6
 2820 DCW1640:DCW1548:DCW1460:DCW1378:DCW1302:DCW1228:DCW1160:DCW1094:DCW1032:DCW 974:DCW 920:DCW 868
 2830 DCW 820:DCW 774:DCW 730:DCW 689:DCW 651:DCW 614:DCW 580:DCW 547:DCW 516:DCW 487:DCW 460:DCW 434
 2840 DCW 410:DCW 387:DCW 365:DCW 345:DCW 325:DCW 307:DCW 290:DCW 274:DCW 258:DCW 244:DCW 230:DCW 217
 2850 DCW 205:DCW 193:DCW 183:DCW 172:DCW 163:DCW 154:DCW 145:DCW 137:DCW 129:DCW 122:DCW 115:DCW 109
 2860 DCW 102:DCW  96:DCW  91:DCW  86:DCW  81:DCW  77:DCW  72:DCW  68:DCW  64:DCW  61:DCW  57:DCW  54
 2870 DCW  51:DCW  48:DCW  45:DCW  43:DCW  40:DCW  38:DCW  36:DCW  34:DCW  32:DCW  30:DCW  28:DCW  27
 2880 
 2890 ;ft7
 2900 DCW1628:DCW1536:DCW1450:DCW1368:DCW1292:DCW1220:DCW1150:DCW1086:DCW1026:DCW 968:DCW 914:DCW 862
 2910 DCW 814:DCW 768:DCW 725:DCW 684:DCW 646:DCW 610:DCW 575:DCW 543:DCW 513:DCW 484:DCW 457:DCW 431
 2920 DCW 407:DCW 384:DCW 363:DCW 342:DCW 323:DCW 305:DCW 288:DCW 272:DCW 256:DCW 242:DCW 228:DCW 216
 2930 DCW 204:DCW 192:DCW 181:DCW 171:DCW 161:DCW 152:DCW 144:DCW 136:DCW 128:DCW 121:DCW 114:DCW 108
 2940 DCW 102:DCW  96:DCW  90:DCW  85:DCW  80:DCW  76:DCW  72:DCW  68:DCW  64:DCW  60:DCW  57:DCW  54
 2950 DCW  51:DCW  48:DCW  45:DCW  42:DCW  40:DCW  38:DCW  36:DCW  34:DCW  32:DCW  30:DCW  28:DCW  27
 2960 
 2970 ;ft-8
 2980 DCW1814:DCW1712:DCW1616:DCW1524:DCW1440:DCW1356:DCW1280:DCW1208:DCW1140:DCW1076:DCW1016:DCW 960
 2990 DCW 907:DCW 856:DCW 808:DCW 762:DCW 720:DCW 678:DCW 640:DCW 604:DCW 570:DCW 538:DCW 508:DCW 480
 3000 DCW 453:DCW 428:DCW 404:DCW 381:DCW 360:DCW 339:DCW 320:DCW 302:DCW 285:DCW 269:DCW 254:DCW 240
 3010 DCW 226:DCW 214:DCW 202:DCW 190:DCW 180:DCW 170:DCW 160:DCW 151:DCW 143:DCW 135:DCW 127:DCW 120
 3020 DCW 113:DCW 107:DCW 101:DCW  95:DCW  90:DCW  85:DCW  80:DCW  75:DCW  71:DCW  67:DCW  63:DCW  60
 3030 DCW  56:DCW  53:DCW  50:DCW  47:DCW  45:DCW  42:DCW  40:DCW  37:DCW  35:DCW  33:DCW  31:DCW  30
 3040 
 3050 ;ft-7
 3060 DCW1800:DCW1700:DCW1604:DCW1514:DCW1430:DCW1350:DCW1272:DCW1202:DCW1134:DCW1070:DCW1010:DCW 954
 3070 DCW 900:DCW 850:DCW 802:DCW 757:DCW 715:DCW 675:DCW 636:DCW 601:DCW 567:DCW 535:DCW 505:DCW 477
 3080 DCW 450:DCW 425:DCW 401:DCW 379:DCW 357:DCW 337:DCW 318:DCW 300:DCW 284:DCW 268:DCW 253:DCW 238
 3090 DCW 225:DCW 212:DCW 200:DCW 189:DCW 179:DCW 169:DCW 159:DCW 150:DCW 142:DCW 134:DCW 126:DCW 119
 3100 DCW 112:DCW 106:DCW 100:DCW  94:DCW  89:DCW  84:DCW  79:DCW  75:DCW  71:DCW  67:DCW  63:DCW  59
 3110 DCW  56:DCW  53:DCW  50:DCW  47:DCW  44:DCW  42:DCW  39:DCW  37:DCW  35:DCW  33:DCW  31:DCW  29
 3120 
 3130 ;ft-6
 3140 DCW1788:DCW1688:DCW1592:DCW1504:DCW1418:DCW1340:DCW1264:DCW1194:DCW1126:DCW1064:DCW1004:DCW 948
 3150 DCW 894:DCW 844:DCW 796:DCW 752:DCW 709:DCW 670:DCW 632:DCW 597:DCW 563:DCW 532:DCW 502:DCW 474
 3160 DCW 447:DCW 422:DCW 398:DCW 376:DCW 355:DCW 335:DCW 316:DCW 298:DCW 282:DCW 266:DCW 251:DCW 237
 3170 DCW 223:DCW 211:DCW 199:DCW 188:DCW 177:DCW 167:DCW 158:DCW 149:DCW 141:DCW 133:DCW 125:DCW 118
 3180 DCW 111:DCW 105:DCW  99:DCW  94:DCW  88:DCW  83:DCW  79:DCW  74:DCW  70:DCW  66:DCW  62:DCW  59
 3190 DCW  55:DCW  52:DCW  49:DCW  47:DCW  44:DCW  41:DCW  39:DCW  37:DCW  35:DCW  33:DCW  31:DCW  29
 3200 
 3210 ;ft-5
 3220 DCW1774:DCW1676:DCW1582:DCW1492:DCW1408:DCW1330:DCW1256:DCW1184:DCW1118:DCW1056:DCW 996:DCW 940
 3230 DCW 887:DCW 838:DCW 791:DCW 746:DCW 704:DCW 665:DCW 628:DCW 592:DCW 559:DCW 528:DCW 498:DCW 470
 3240 DCW 444:DCW 419:DCW 395:DCW 373:DCW 352:DCW 332:DCW 314:DCW 296:DCW 280:DCW 264:DCW 249:DCW 235
 3250 DCW 222:DCW 209:DCW 198:DCW 187:DCW 176:DCW 166:DCW 157:DCW 148:DCW 140:DCW 132:DCW 125:DCW 118
 3260 DCW 111:DCW 104:DCW  99:DCW  93:DCW  88:DCW  83:DCW  78:DCW  74:DCW  70:DCW  66:DCW  62:DCW  59
 3270 DCW  55:DCW  52:DCW  49:DCW  46:DCW  44:DCW  41:DCW  39:DCW  37:DCW  35:DCW  33:DCW  31:DCW  29
 3280 
 3290 ;ft-4
 3300 DCW1762:DCW1664:DCW1570:DCW1482:DCW1398:DCW1320:DCW1246:DCW1176:DCW1110:DCW1048:DCW 988:DCW 934
 3310 DCW 881:DCW 832:DCW 785:DCW 741:DCW 699:DCW 660:DCW 623:DCW 588:DCW 555:DCW 524:DCW 494:DCW 467
 3320 DCW 441:DCW 416:DCW 392:DCW 370:DCW 350:DCW 330:DCW 312:DCW 294:DCW 278:DCW 262:DCW 247:DCW 233
 3330 DCW 220:DCW 208:DCW 196:DCW 185:DCW 175:DCW 165:DCW 156:DCW 147:DCW 139:DCW 131:DCW 123:DCW 117
 3340 DCW 110:DCW 104:DCW  98:DCW  92:DCW  87:DCW  82:DCW  78:DCW  73:DCW  69:DCW  65:DCW  61:DCW  58
 3350 DCW  55:DCW  52:DCW  49:DCW  46:DCW  43:DCW  41:DCW  39:DCW  36:DCW  34:DCW  32:DCW  30:DCW  29
 3360 
 3370 ;ft-3
 3380 DCW1750:DCW1652:DCW1558:DCW1472:DCW1388:DCW1310:DCW1238:DCW1168:DCW1102:DCW1040:DCW 982:DCW 926
 3390 DCW 875:DCW 826:DCW 779:DCW 736:DCW 694:DCW 655:DCW 619:DCW 584:DCW 551:DCW 520:DCW 491:DCW 463
 3400 DCW 437:DCW 413:DCW 390:DCW 368:DCW 347:DCW 328:DCW 309:DCW 292:DCW 276:DCW 260:DCW 245:DCW 232
 3410 DCW 219:DCW 206:DCW 195:DCW 184:DCW 174:DCW 164:DCW 155:DCW 146:DCW 138:DCW 130:DCW 123:DCW 116
 3420 DCW 109:DCW 103:DCW  97:DCW  92:DCW  87:DCW  82:DCW  77:DCW  73:DCW  69:DCW  65:DCW  61:DCW  58
 3430 DCW  54:DCW  51:DCW  48:DCW  46:DCW  43:DCW  41:DCW  38:DCW  36:DCW  34:DCW  32:DCW  30:DCW  29
 3440 
 3450 ;ft-2
 3460 DCW1736:DCW1640:DCW1548:DCW1460:DCW1378:DCW1302:DCW1228:DCW1160:DCW1094:DCW1032:DCW 974:DCW 920
 3470 DCW 868:DCW 820:DCW 774:DCW 730:DCW 689:DCW 651:DCW 614:DCW 580:DCW 547:DCW 516:DCW 487:DCW 460
 3480 DCW 434:DCW 410:DCW 387:DCW 365:DCW 345:DCW 325:DCW 307:DCW 290:DCW 274:DCW 258:DCW 244:DCW 230
 3490 DCW 217:DCW 205:DCW 193:DCW 183:DCW 172:DCW 163:DCW 154:DCW 145:DCW 137:DCW 129:DCW 122:DCW 115
 3500 DCW 108:DCW 102:DCW  96:DCW  91:DCW  86:DCW  81:DCW  77:DCW  72:DCW  68:DCW  64:DCW  61:DCW  57
 3510 DCW  54:DCW  51:DCW  48:DCW  45:DCW  43:DCW  40:DCW  38:DCW  36:DCW  34:DCW  32:DCW  30:DCW  28
 3520 
 3530 ;ft-1
 3540 DCW1724:DCW1628:DCW1536:DCW1450:DCW1368:DCW1292:DCW1220:DCW1150:DCW1086:DCW1026:DCW 968:DCW 914
 3550 DCW 862:DCW 814:DCW 768:DCW 725:DCW 684:DCW 646:DCW 610:DCW 575:DCW 543:DCW 513:DCW 484:DCW 457
 3560 DCW 431:DCW 407:DCW 384:DCW 363:DCW 342:DCW 323:DCW 305:DCW 288:DCW 272:DCW 256:DCW 242:DCW 228
 3570 DCW 216:DCW 203:DCW 192:DCW 181:DCW 171:DCW 161:DCW 152:DCW 144:DCW 136:DCW 128:DCW 121:DCW 114
 3580 DCW 108:DCW 101:DCW  96:DCW  90:DCW  85:DCW  80:DCW  76:DCW  72:DCW  68:DCW  64:DCW  60:DCW  57
 3590 DCW  54:DCW  50:DCW  48:DCW  45:DCW  42:DCW  40:DCW  38:DCW  36:DCW  34:DCW  32:DCW  30:DCW  28
 3600 .fttabend%
 3610 ]
 3620 ENDPROC
 3630 
 3640 
 3650 DEF PROCvalidatecrc
 3660 REM patch up the current date and version $
 3670 REM ********************************************************************
 3680 REM alphatest versions now end in 'a'
 3690 REM betatest versions now end in 'b'
 3700 REM custom versions now end in 'c'
 3710 :
 3720 $(helpdate+code%+1)="("+RIGHT$(datestamp$,11)
 3730 code%?(helpdate+1+12)=ASC")"
 3740 A%=code%:B%=endcode%:crcvalue%=NOT USR(crc32bit)
 3750 REM PRINT ~crcvalue%:ENDPROC
 3760 :
 3770 IF crcvalue%<>paulvigay32bitcrc% OR alphatest% OR betatest% OR qtmrast% THEN
 3780  date$=MID$(TIME$,5,11)
 3790  REM *H.Modules patch up
 3800  $(code%+helpdate)="c ("+date$+") © Steve Harrison"   :REM if not standard QTM, add "c" = custom
 3810  code%?helpchar=0
 3820  IF betatest% code%?helpdate=ASC"b":code%?helpchar=ASC" " :REM if beta, replace "c" with "b"
 3830  IF alphatest% code%?helpdate=ASC"a":code%?helpchar=ASC" ":REM if alpha, replace "c" with "a"
 3840  IF qtmrast% code%?helpdate=ASC"r":code%?helpchar=ASC" ":REM if RM version, replace "c" with "r"
 3850  :
 3860  REM *H.QTMTracker help patch up:
 3870  $(helptextversion+8+code%)="v"+ver$
 3880  code%?(helptextversion+8+5)=code%?helpdate
 3890  :
 3900  custom$="custom"
 3910  IF betatest% THEN custom$="beta test"
 3920  IF alphatest% THEN custom$="alpha test"
 3930  IF qtmrast% THEN custom$="RM "+custom$
 3940  A%=code%:B%=endcode%:crcvalue%=NOT USR(crc32bit)
 3950  PRINT"QTM ";custom$;" version v";ver$;" assembled, CRC &";~crcvalue%
 3960 ELSE
 3970  PRINT"QTM release version v";ver$;" assembled, CRC &";~crcvalue%
 3980 ENDIF
 3990 ENDPROC
 4000 
 4010 
 4020 DEF PROCassmcrc
 4030 crccodelen%=512
 4040 DIM crccode% crccodelen%
 4050 FOR opt%=8 TO 10 STEP 2
 4060 P%=crccode%:L%=P%+crccodelen%
 4070 [OPT opt%
 4080 ;
 4090 ; Optimised implementation of 32bit CRC in Arm code
 4100 ;
 4110 ; (c) Stephen Harrison, 2013
 4120 ;
 4130 
 4140 .crc32bit                     ;On entry R0=data, R1=datalen; On exit R0=32bit crc
 4150 STMFD     R13!,{R1-R5,R14}
 4160 MVN       R4,#0
 4170 LDR       R5,poly
 4180 .crcloop
 4190 LDRB      R2,[R0],#1
 4200 EOR       R4,R4,R2
 4210 MOV       R3,#8
 4220 .bitloop
 4230 MOVS      R4,R4,LSR#1
 4240 EORCS     R4,R4,R5
 4250 SUBS      R3,R3,#1
 4260 BGT       bitloop
 4270 SUBS      R1,R1,#1
 4280 BGT       crcloop
 4290 MVN       R0,R4
 4300 LDMFD     R13!,{R1-R5,PC}
 4310 
 4320 .poly
 4330 EQUD      &EDB88320
 4340 ]
 4350 NEXT
 4360 ENDPROC
 4370 
 4380 
 4390 REM **********************************************************
 4400 REM *         Long addressing routines & FNdiv command       *
 4410 REM **********************************************************
 4420 
 4430 
 4440 REM A set of long addressing routines
 4450 REM v1.22 LEN 1993 Phoenix
 4460 
 4470 REM v1.10 - worked ok
 4480 REM v1.20 - now re-aligns P%/O%, before coding (- works if OS_WriteS mis-aligns P%)
 4490 REM v1.21 - won't stop the assembly if the address is smaller than 256 (in FNlong_adr)
 4500 REM v1.22 - better range errors (now warnings) in both - errors now also give current P%
 4510 
 4520 REM These routines can load the address of ANY location, using either 1,2 or
 4530 REM 3 ADD or SUB instructions - from 0K -> 16384K!!!
 4540 
 4550 REM WARNING: You must use opt%, for the OPT code, or this routine will not
 4560 REM          work correctly
 4570 
 4580 REM For addresses from 0 to 256bytes, just use Basic's 'ADR Rx,<addr>'
 4590 
 4600 REM Syntax for addresses from 256bytes to 64K:
 4610 REM FNlong_adr("<condition>",<dest. reg>,<address>)
 4620 
 4630 REM Syntax for addresses from 64K to 16384K:
 4640 REM FNmega_adr("<condition>",<dest. reg>,<address>)
 4650 
 4660 REM An example:
 4670 REM .....
 4680 REM CMP R0,#65
 4690 REM FNmega_adr("NE",1,FarAway)
 4700 REM .....
 4710 
 4720 DEF FNlong_adr(cond$,reg%,addr%)                :REM v1.23 LEN 1993 Phoenix
 4730 LOCAL cond%,gap%,bit1%,bit2%,optcode%,optcode1%,optcode2%
 4740 IF reg%<0 OR reg%>&F THEN ERROR 255,"FNadr: Bad register"
 4750 IF reg%=&F THEN ERROR 255,"FNadr: Can't handle PC/R15 as a register"
 4760 IF cond$="" OR cond$="  " THEN cond$="AL"
 4770 cond%=INSTR(" EQ NE CS CC MI PL VS VC HI LS GE LT GT LE AL NV",cond$)
 4780 IF cond%=0 THEN cond%=INSTR(" eq ne cs cc mi pl vs vc hi ls ge lt gt le al nv",cond$)
 4790 IF cond%=0 THEN ERROR 255,"FNadr: Bad condition"
 4800 IF (opt% AND 3)=0 OR (opt% AND 3)=1 THEN [OPT opt%:MOV R0,R0:MOV R0,R0:]:=opt%
 4810 :
 4820 [OPT opt%:MOV R0,R0:]   :REM sync P%/O% - make sure on a word boundary
 4830 P%=P%-4:O%=O%-4         :REM get back to last word boundary
 4840 :
 4850 cond%=(cond%+1-3)/3
 4860 gap%=ABS(addr%-P%-8)
 4870 IF gap%<&FF PRINT"FNadr: Range <256 in FNlong_adr at &";~P%;" - ADR would do..."
 4880 IF gap%>&FFFF ERROR 255,"FNadr: Address too large at &"+STR$~P%+", use FNmega_adr instead"
 4890 :
 4900 IF addr%<P% THEN
 4910  optcode%=&02400000
 4920 ELSE
 4930  optcode%=&02800000
 4940 ENDIF
 4950 :
 4960 bit1%=gap% AND &FF
 4970 bit2%=(gap% AND &FF00)>>>8
 4980 :
 4990 IF bit1%=0 THEN PRINT"FNadr: ADR would do... at &";~P%
 5000 :
 5010 optcode%=optcode% OR (cond%<<28)
 5020 optcode%=optcode% OR (reg%<<12)
 5030 optcode1%=optcode% OR (&F<<16)
 5040 optcode1%=optcode1% OR bit1%
 5050 :
 5060 optcode2%=optcode% OR &C<<8
 5070 optcode2%=optcode2% OR (reg%<<16)
 5080 optcode2%=optcode2% OR bit2%
 5090 :
 5100 [OPT opt%:EQUD optcode1%:EQUD optcode2%:]
 5110 =0
 5120 
 5130 DEF FNmega_adr(cond$,reg%,addr%)                :REM v1.23 LEN 1993 Phoenix
 5140 LOCAL cond%,gap%,bit1%,bit2%,bit3%,optcode%,optcode1%,optcode2%,optcode3%
 5150 IF reg%<0 OR reg%>&F THEN ERROR 255,"FNadr: Bad register"
 5160 IF reg%=&F THEN ERROR 255,"FNadr: Can't handle PC/R15 as a register"
 5170 IF cond$="" OR cond$="  " THEN cond$="AL"
 5180 cond%=INSTR(" EQ NE CS CC MI PL VS VC HI LS GE LT GT LE AL NV",cond$)
 5190 IF cond%=0 THEN cond%=INSTR(" eq ne cs cc mi pl vs vc hi ls ge lt gt le al nv",cond$)
 5200 IF cond%=0 THEN ERROR 255,"FNadr: Bad condition"
 5210 IF (opt% AND 3)=0 OR (opt% AND 3)=1 THEN [OPT opt%:MOV R0,R0:MOV R0,R0:MOV R0,R0:]:=opt%
 5220 :
 5230 [OPT opt%:MOV R0,R0:]   :REM sync P%/O% - make sure on a word boundary
 5240 P%=P%-4:O%=O%-4         :REM get back to last word boundary
 5250 :
 5260 cond%=(cond%+1-3)/3
 5270 gap%=ABS(addr%-P%-8)
 5280 IF gap%<&FFFF PRINT"FNadr: Range <64K in FNmega_adr at &";~P%;" - FNlong_adr would do..."
 5290 IF gap%>&FFFFFF ERROR 255,"FNadr: Range >16384K!!! in FNmega_adr at &"+STR$~P%+" - check program..."
 5300 :
 5310 IF addr%<P% THEN
 5320  optcode%=&02400000
 5330 ELSE
 5340  optcode%=&02800000
 5350 ENDIF
 5360 :
 5370 bit1%=gap% AND &FF
 5380 bit2%=(gap% AND &FF00)>>>8
 5390 bit3%=(gap% AND &FF0000)>>>16
 5400 :
 5410 IF bit1%=0 AND bit2%=0 THEN PRINT"FNadr: ADR would do... at &";~P%
 5420 IF bit1%=0 AND bit2%>0 THEN PRINT"FNadr: FNlong_adr would do... at &";~P%
 5430 :
 5440 optcode%=optcode% OR (cond%<<28)
 5450 optcode%=optcode% OR (reg%<<12)
 5460 optcode1%=optcode% OR (&F<<16)
 5470 optcode1%=optcode1% OR bit1%
 5480 :
 5490 optcode2%=optcode% OR &C<<8
 5500 optcode2%=optcode2% OR (reg%<<16)
 5510 optcode2%=optcode2% OR bit2%
 5520 :
 5530 optcode3%=optcode% OR &8<<8
 5540 optcode3%=optcode3% OR (reg%<<16)
 5550 optcode3%=optcode3% OR bit3%
 5560 :
 5570 [OPT opt%:EQUD optcode1%:EQUD optcode2%:EQUD optcode3%:]
 5580 =0
 5590 
 5600 
 5610 REM AU divide routine (from issue 131)
 5620 
 5630 DEF FNAUdiv
 5640 [OPT opt%
 5650 STMFD   R13!,{R1,R2,R3,R4}
 5660 MOV     R2,#0
 5670 MOV     R4,#1
 5680 ;EOR     R3,R0,R1
 5690 ;CMP     R1,#0
 5700 ;RSBMI   R1,R1,#0
 5710 ;CMP     R0,#0
 5720 ;RSBMI   R0,R0,#0
 5730 CMP     R0,#2^24
 5740 BLO     skip1           ;LO (CC) - so it works unsigned!
 5750 FNdiv(31)
 5760 FNdiv(30)
 5770 FNdiv(29)
 5780 FNdiv(28)
 5790 FNdiv(27)
 5800 FNdiv(26)
 5810 FNdiv(25)
 5820 .skip1
 5830 CMP     R0,#2^16
 5840 BLO     skip2
 5850 FNdiv(24)
 5860 FNdiv(23)
 5870 FNdiv(22)
 5880 FNdiv(21)
 5890 FNdiv(20)
 5900 FNdiv(19)
 5910 FNdiv(18)
 5920 FNdiv(17)
 5930 .skip2
 5940 CMP     R0,#2^08
 5950 BLO     skip3
 5960 FNdiv(16)
 5970 FNdiv(15)
 5980 FNdiv(14)
 5990 FNdiv(13)
 6000 FNdiv(12)
 6010 FNdiv(11)
 6020 FNdiv(10)
 6030 FNdiv(09)
 6040 FNdiv(08)
 6050 .skip3
 6060 FNdiv(07)
 6070 FNdiv(06)
 6080 FNdiv(05)
 6090 FNdiv(04)
 6100 FNdiv(03)
 6110 FNdiv(02)
 6120 FNdiv(01)
 6130 FNdiv(00)
 6140 .donediv
 6150 MOV     R0,R2
 6160 ;CMP     R3,#0
 6170 ;RSBMI   R0,R0,#0
 6180 LDMFD   R13!,{R1,R2,R3,R4}
 6190 ]
 6200 =opt%
 6210 
 6220 
 6230 DEF FNdiv(it)
 6240 IF it>0 THEN
 6250  [OPT opt%
 6260  CMP     R1,R0,LSR#it
 6270  ORRLS   R2,R2,R4,LSL#it
 6280  SUBLS   R0,R0,R1,LSL#it
 6290  ]
 6300 ELSE
 6310  [OPT opt%
 6320  CMP     R1,R0
 6330  ORRLS   R2,R2,#1
 6340  SUBLS   R0,R0,R1
 6350  ]
 6360 ENDIF
 6370 =opt%
 6380 
 6390 
 6400 DEF FNmrc(cond$,inst$)
 6410 IF (opt% AND 1<<2)=(1<<2) THEN addr%=O%:O%+=4 ELSE addr%=P%
 6420 IF (addr% AND %11)<>0 THEN [OPT opt%:ALIGN:]
 6430 P%+=4
 6440 :
 6450 IF cond$="" THEN cond$="AL"
 6460 cond%=INSTR("EQNECSCCMIPLVSVCHILSGELTGTLEALNV",cond$)
 6470 IF cond%=0 THEN ERROR 255,"Bad condition"
 6480 cond%=(cond%-1)/2
 6490 :
 6500 CP=FNgetnum(inst$,inst$)
 6510 CPOpc=FNgetnum(inst$,inst$)
 6520 Rd=FNgetnum(inst$,inst$)
 6530 CRn=FNgetnum(inst$,inst$)
 6540 CRm=FNgetnum(inst$,inst$)
 6550 Aux=FNgetnum(inst$,inst$)
 6560 :
 6570 load=1
 6580 :
 6590 mc%=%00001110000000000000000000010000
 6600 REM      ^^^^                   ^     = op
 6610 :
 6620 mc%=mc% OR cond%<<28 OR load<<20
 6630 mc%=mc% OR CPOpc<<21 OR CRn<<16 OR Rd<<12 OR CP<<8 OR Aux<<5 OR CRm<<0
 6640 !addr%=mc%
 6650 =opt%
 6660 
 6670 
 6680 DEF FNmcr(cond$,inst$)
 6690 IF (opt% AND 1<<2)=(1<<2) THEN addr%=O%:O%+=4 ELSE addr%=P%
 6700 IF (addr% AND %11)<>0 THEN [OPT opt%:ALIGN:]
 6710 P%+=4
 6720 :
 6730 IF cond$="" THEN cond$="AL"
 6740 cond%=INSTR("EQNECSCCMIPLVSVCHILSGELTGTLEALNV",cond$)
 6750 IF cond%=0 THEN ERROR 255,"Bad condition"
 6760 cond%=(cond%-1)/2
 6770 :
 6780 CP=FNgetnum(inst$,inst$)
 6790 CPOpc=FNgetnum(inst$,inst$)
 6800 Rd=FNgetnum(inst$,inst$)
 6810 CRn=FNgetnum(inst$,inst$)
 6820 CRm=FNgetnum(inst$,inst$)
 6830 Aux=FNgetnum(inst$,inst$)
 6840 :
 6850 load=0
 6860 :
 6870 mc%=%00001110000000000000000000010000
 6880 REM      ^^^^                   ^     = op
 6890 :
 6900 mc%=mc% OR cond%<<28 OR load<<20
 6910 mc%=mc% OR CPOpc<<21 OR CRn<<16 OR Rd<<12 OR CP<<8 OR Aux<<5 OR CRm<<0
 6920 !addr%=mc%
 6930 =opt%
 6940 
 6950 DEF FNmrs(cond$,inst$)
 6960 IF (opt% AND 1<<2)=(1<<2) THEN addr%=O%:O%+=4 ELSE addr%=P%
 6970 IF (addr% AND %11)<>0 THEN [OPT opt%:ALIGN:]
 6980 P%+=4
 6990 :
 7000 IF cond$="" THEN cond$="AL"
 7010 cond%=INSTR("EQNECSCCMIPLVSVCHILSGELTGTLEALNV",cond$)
 7020 IF cond%=0 THEN ERROR 255,"Bad condition"
 7030 cond%=(cond%-1)/2
 7040 :
 7050 R=FNgetnum(inst$,inst$)
 7060 IF inst$<>"CPSR" THEN ERROR 255,"Bad MRS"
 7070 :
 7080 mc%=%00000001000011110000000000000000
 7090 REM      ^^^^^^^^^^^^    ^^^^^^^^^^^^ = op
 7100 :
 7110 mc%=mc% OR cond%<<28
 7120 mc%=mc% OR R<<12
 7130 !addr%=mc%
 7140 =opt%
 7150 
 7160 DEF FNmsr(cond$,inst$)
 7170 IF (opt% AND 1<<2)=(1<<2) THEN addr%=O%:O%+=4 ELSE addr%=P%
 7180 IF (addr% AND %11)<>0 THEN [OPT opt%:ALIGN:]
 7190 P%+=4
 7200 :
 7210 IF cond$="" THEN cond$="AL"
 7220 cond%=INSTR("EQNECSCCMIPLVSVCHILSGELTGTLEALNV",cond$)
 7230 IF cond%=0 THEN ERROR 255,"Bad condition"
 7240 cond%=(cond%-1)/2
 7250 :
 7260 mc%=%00000001001000001111000000000000
 7270 REM      ^^^^^^^^    ^^^^^^^^^^^^     = op
 7280 :
 7290 IF LEFT$(inst$,5)<>"CPSR_" THEN ERROR 255,"Bad MSR"
 7300 inst$=MID$(inst$,6)
 7310 IF LEFT$(inst$,1)="c" THEN mc%=mc% OR &10000 : inst$=MID$(inst$,2)
 7320 IF LEFT$(inst$,1)="x" THEN mc%=mc% OR &20000 : inst$=MID$(inst$,2)
 7330 IF LEFT$(inst$,1)="s" THEN mc%=mc% OR &40000 : inst$=MID$(inst$,2)
 7340 IF LEFT$(inst$,1)="f" THEN mc%=mc% OR &80000 : inst$=MID$(inst$,2)
 7350 IF LEFT$(inst$,1)<>"," THEN ERROR 255,"Bad MSR"
 7360 inst$=MID$(inst$,2)
 7370 R=FNgetnum(inst$,inst$)
 7380 :
 7390 mc%=mc% OR cond%<<28
 7400 mc%=mc% OR R
 7410 !addr%=mc%
 7420 =opt%
 7430 
 7440 
 7450 DEF FNgetnum(inst$,RETURN inst$)
 7460 pos=INSTR(inst$,",")
 7470 number$=LEFT$(inst$,pos-1)                      :REM get string up to (but not inc.) comma
 7480 inst$=MID$(inst$,pos+1,LEN inst$-(pos-1))        :REM update instruction list from last...
 7490 IF pos=0 THEN inst$="0"
 7500 :
 7510 REPEAT
 7520  pos=INSTR(number$," ")
 7530  IF pos>0 THEN number$=LEFT$(number$,pos-1)+RIGHT$(number$,LEN number$-pos)
 7540 UNTIL pos=0
 7550 :
 7560 IF number$="" THEN ERROR 255,"X Unknown or missing variable X"
 7570 :
 7580 IF LEFT$(number$,1)="#" OR LEFT$(number$,1)="R" OR LEFT$(number$,1)="r" THEN
 7590  number$=RIGHT$(number$,LEN number$-1)
 7600 ENDIF
 7610 IF LEFT$(number$,2)="CR" OR LEFT$(number$,2)="Cr" OR LEFT$(number$,2)="cr" THEN
 7620  number$=RIGHT$(number$,LEN number$-2)
 7630 ENDIF
 7640 IF LEFT$(number$,2)="CP" OR LEFT$(number$,2)="Cp" OR LEFT$(number$,2)="cp" THEN
 7650  number$=RIGHT$(number$,LEN number$-2)
 7660 ENDIF
 7670 IF LEFT$(number$,1)="C" THEN
 7680  number$=RIGHT$(number$,LEN number$-1)
 7690 ENDIF
 7700 :
 7710 =EVAL number$
 7720 
 7730 
 7740 REM data is required here for text compressor
 7750 
 7760 DATA  42
 7770 DATA  0, 0,""
 7780 DATA  9, 1,"Syntax: *"
 7790 DATA -1, 2," the "
 7800 DATA -1, 3,"director"
 7810 DATA -1, 4,"filing system"
 7820 DATA -1, 5,"current"
 7830 DATA -1, 6," to a variable. Other types of value can be assigned with *"
 7840 DATA -1, 7,"file"
 7850 DATA -1, 8,"default "
 7860 DATA -1, 9,"tion"
 7870 DATA -1,10,"*Configure "
 7880 DATA -1,11,"name"
 7890 DATA -1,12," server"
 7900 DATA -1,13,"number"
 7910 DATA  9,14,"Syntax: * <"
 7920 DATA -1,15," one or more files that match the given wildcard"
 7930 DATA -1,16," and "
 7940 DATA -1,17,"relocatable module"
 7950 DATA -1,18,"C(onfirm)	Prompt for confirmation of each "
 7960 DATA -1,19,"sets the "
 7970 DATA  9,20,"Syntax: * [<disc spec.>]"
 7980 DATA -1,21,"} V(erbose)	Print information on each file "
 7990 DATA -1,23,"spriteLandscape [<XScale> [<YScale> [<Margin> [<Threshold>]]]]]"
 8000 DATA -1,24," is used to print a hard copy of the screen on EPSON-"
 8010 DATA -1,25,". Options: (use ~ to force off, eg. ~"
 8020 DATA -1,26,"printe"
 8030 DATA  9,27,"Syntax: * <filename>"
 8040 DATA -1,28,"select"
 8050 DATA -1,29,"xpression"
 8060 DATA  9,30,"Syntax: * ["
 8070 DATA -1,31,"sprite"
 8080 DATA -1,32," displays"
 8090 DATA -1,33,"free space"
 8100 DATA -1,34," {off}"
 8110 DATA -1,35,"library"
 8120 DATA -1,36,"parameter"
 8130 DATA -1,37,"object"
 8140 DATA -1,38," all "
 8150 DATA -1,39,"disc"
 8160 DATA -1,40," to "
 8170 DATA -1,41," is "
 8180 DATA &FF
