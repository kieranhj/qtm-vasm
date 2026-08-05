   10 REM QTM v1.49 module code
   20 REM
   30 REM LEN Steve Harrison 1993-2023
   40 END
   50 
   60 DEF FNassm_mod
   70 REM alphatest% and version moved to QTMv1-xx file
   80 [OPT opt%
   90 .uservariablespace
  100 .userprivateword
  110 EQUD    0               ;start code             00
  120 .userR14store
  130 EQUD    initqtm         ;init code              04
  140 .userPSRstore
  150 EQUD    exitqtm         ;exit code              08
  160 EQUD    services        ;service code           12
  170 EQUD    title           ;title                  16
  180 EQUD    help            ;help                   20
  190 EQUD    commands        ;commands               24
  200 EQUD    &47E40          ;SWI number             28
  210 EQUD    SWIcode         ;SWI code               32
  220 EQUD    SWItable        ;SWI table              36
  230 EQUD    0               ;SWI decoding code      40
  240 EQUD    0               ;MessageTrans file      44
  250 EQUD    flagsword       ;Flags word ptr         48
  260 
  270 B       user_initqtm    ;                       52
  280 B       user_swicode    ;                       56
  290 B       user_services   ;                       60
  300 B       user_exitqtm    ;                       64
  310 
  320 
  330 .user_initqtm                   ;should be called only in SVC or User
  340 STR     R14,userR14store
  350 FNmrs("AL","R14,CPSR")
  360 STR     R14,userPSRstore
  370 TST     R14,#3
  380 SWIEQ   "OS_EnterOS"
  390 LDR     R14,userR14store
  400 STMFD   R13!,{R0-R6,R10-R12,R14}
  410 ADR     R12,userprivateword     ;this is first word of module header - OK to edit as we're not
  420 MOV     R11,#0                  ;   loaded as a module or from ROM, we're in user code...
  430 ADR     R10,nullenviroment      ;this is a ptr to a null string, as R10 would be on loading
  440 BL      initqtm
  450 STRVS   R0,[R13]
  460 LDMFD   R13!,{R0-R6,R10-R12,R14}
  470 TEQ     PC,PC
  480 BEQ     user_exit32
  490 BICVCS  PC,R14,#1<<28
  500 ORRVSS  PC,R14,#1<<28           ;back to original mode & exit
  510 
  520 
  530 .user_swicode                   ;R11=swi offset
  540 STR     R14,userR14store
  550 FNmrs("AL","R14,CPSR")
  560 STR     R14,userPSRstore
  570 TST     R14,#3
  580 SWIEQ   "OS_EnterOS"
  590 LDR     R14,userR14store
  600 STMFD   R13!,{R10-R12,R14}
  610 ADR     R12,userprivateword
  620 BL      SWIcode
  630 LDMFD   R13!,{R10-R12,R14}
  640 TEQ     PC,PC
  650 BEQ     user_exit32
  660 BICVCS  PC,R14,#1<<28
  670 ORRVSS  PC,R14,#1<<28           ;back to original mode & exit
  680 
  690 
  700 .user_services                  ;R1=service number
  710 STR     R14,userR14store
  720 FNmrs("AL","R14,CPSR")
  730 STR     R14,userPSRstore
  740 TST     R14,#3
  750 SWIEQ   "OS_EnterOS"
  760 LDR     R14,userR14store
  770 STMFD   R13!,{R12,R14}
  780 ADR     R12,userprivateword
  790 BL      services
  800 LDMFD   R13!,{R12,R14}
  810 TEQ     PC,PC
  820 BEQ     user_exit32
  830 BICVCS  PC,R14,#1<<28
  840 ORRVSS  PC,R14,#1<<28           ;back to original mode & exit
  850 
  860 
  870 .user_exitqtm
  880 STR     R14,userR14store
  890 FNmrs("AL","R14,CPSR")
  900 STR     R14,userPSRstore
  910 TST     R14,#3
  920 SWIEQ   "OS_EnterOS"
  930 LDR     R14,userR14store
  940 STMFD   R13!,{R0-R6,R10-R12,R14}
  950 ADR     R12,userprivateword
  960 MOV     R11,#0
  970 MOV     R10,#1                  ;fatal finalisation!
  980 BL      exitqtm                 ;(could also attempt to release RMA in private word, but NR)
  990 LDMFD   R13!,{R0-R6,R10-R12,R14}
 1000 TEQ     PC,PC
 1010 BEQ     user_exit32
 1020 BICS    PC,R14,#1<<28           ;never return error on exit, no point in user control!
 1030 
 1040 
 1050 .user_exit32                    ;common exit code for 32bit machines
 1060 LDR     R14,userPSRstore
 1070 ORRVS   R14,R14,#1<<28
 1080 BICVC   R14,R14,#1<<28
 1090 FNmsr("AL","CPSR_cf,R14")
 1100 LDR     PC,userR14store
 1110 
 1120 
 1130 .flagsword
 1140 EQUD    1               ;32bit!
 1150 
 1160 .textdata
 1170 .by
 1180 EQUS    "by"
 1190 .nullenviroment
 1200 EQUB    0
 1210 .of
 1220 EQUS    "of"
 1230 EQUB    0
 1240 .copyright
 1250 EQUS    "copyright"
 1260 EQUB    0
 1270 .cpy
 1280 EQUS    "(c)"
 1290 EQUB    0
 1300 .hash
 1310 EQUS    "#"
 1320 EQUB    0
 1330 .back
 1340 EQUS    "/"
 1350 EQUB    0
 1360 ALIGN
 1370 .mk
 1380 EQUS    "M.K."
 1390 .flt4
 1400 EQUS    "FLT4"
 1410 .flt8
 1420 EQUS    "FLT8"                  ;8 channels!
 1430 .chn8
 1440 EQUS    "8CHN"                  ;FastTracker 8 channels!
 1450 .chn6
 1460 EQUS    "6CHN"                  ;FastTracker 6 channels!
 1470 .cd81
 1480 EQUS    "CD81"                  ;Octalyser 8 channels
 1490 .cd61
 1500 EQUS    "CD61"                  ;Octalyser 6 channels (not seen one of these...)
 1510 .chn4
 1520 EQUS    "4CHN"                  ;4 channel FastTracker
 1530 .flt2
 1540 EQUS    "FLT2"                  ;2 channel StarTrekker ** not supported (not seen one of these)
 1550 .ch16
 1560 EQUS    "16CH"                  ;16 channel FastTracker ** not supported
 1570 .ch24
 1580 EQUS    "24CH"                  ;24 channel FastTracker ** not supported
 1590 .ch32
 1600 EQUS    "32CH"                  ;32 channel FastTracker ** not supported
 1610 
 1620 
 1630 .initqtm
 1640 STMFD   R13!,{R7-R12,R14}
 1650 ]
 1660 IF qtmrast% OR alphatest% OR betatest% THEN [OPT opt%:SWI "XOS_WriteS":EQUS "QTM v"+ver$:]
 1670 IF qtmrast% THEN [OPT opt%:EQUB ASC"r":]
 1680 IF alphatest% THEN [OPT opt%:EQUS " alpha-test ":]
 1690 IF betatest% THEN [OPT opt%:EQUS " beta-test ":]
 1700 IF qtmrast% THEN
 1710  [OPT opt%:EQUS STR$maxchans+"-chan/"+CHR$0:ALIGN
 1720  FNlong_adr("",0,qtmrmtext):MOV R1,#41:SWI "XOS_WriteN":SWI "XOS_NewLine":]
 1730 ELSE
 1740  IF alphatest% OR betatest% THEN [OPT opt%:EQUS "version loaded."+CHR$13+CHR$10+CHR$0:]
 1750 ENDIF
 1760 [OPT opt%
 1770 ALIGN
 1780 :
 1790 MOV     R1,#(song_data_end-song_data) AND &00FF ;v1.49 RMA datablock
 1800 ORR  R1,R1,#(song_data_end-song_data) AND &FF00
 1810 MOV     R0,R1
 1820 BL      claimRMA                ;claim RMA for datablock
 1830 BL      blankmemory             ;R0=RMA datablock!
 1840 :
 1850 MOV     R11,R12                 ;R11=module workspace ptr
 1860 MOV     R12,R0                  ;FNlong_adr("  ",12,song_data)
 1870 BL      init                    ;R12 needs to be set up by here
 1880 STR     R11,[R12,#modworkspace]
 1890 STR     R12,[R11]      ;v1.49 finally we can try storing datablock addr in workspace ptr!
 1900 BL      init_databanks ;sets up tables, volumes and vars incl. current_uS to 'uS' (32 default)
 1910 BL      machinedetect  ;sets osversion, turns TSS to 'On' for RO5 (no longer uS=48 for RPCEmu)
 1920 :
 1930 MOV     R0,#0
 1940 MOV     R1,#0
 1950 BL      swi_qtmstereo           ;v1.48 this avoids needing to preset default stereo in databanks
 1960 :
 1970 LDRB    R0,[R12,#armchip]       ;v1.48
 1980 CMP     R0,#3                   ;
 1990 BLLE    unroll_a2_DMA           ;if Arm2 or Arm3, unroll the DMA code for Arm2/cache-off Arm3
 2000 LDMVSFD R13!,{R7-R12,PC}
 2010 :
 2020 LDRB    R1,[R12,#osversion]
 2030 CMP     R1,#&A6-&A0             ;check for OS 3.6 or above (16bit sound possible)
 2040 MOVLT   R0,#0                   ; ..this should really move to 'machinedetect' and only
 2050 STRLT   R0,[R12,#fake8bitDMA]   ; ..allocate fakeDMA if 16bit sound actually in use...?
 2060 BLT     finishinit              ; ..
 2070 :                               ; ..
 2080 MOV     R1,#208*8               ; v1.45 reverted to fixed 'fakeDMA' as 208x8 -no need for larger!
 2090 MOV     R0,R1                   ; ..
 2100 BL      claimRMA                ; ..
 2110 BL      blankmemory             ; ..should only need if actually using 16bit sound..
 2120 STR     R0,[R12,#fake8bitDMA]   ;if we're on a RISC OS 3.6+ machine, use fake DMA buffer
 2130 :
 2140 .finishinit
 2150 BL      initVIDCandpitch        ;sets Arc pitch tables based on uS etc.
 2160 LDMFD   R13!,{R7-R12,PC}
 2170 
 2180 
 2190 .initVIDCandpitch               ;call AFTER 'machinedetect'
 2200 STMFD   R13!,{R0-R1,R12,R14}
 2210 ]:IF qtmrast% THEN [OPT opt%:MOV R0,#1<<16:STR R0,[R12,#rm_CIAdec]:]
 2220 [OPT opt%                       ;v1.43se RasterMan - store default 24MHz CIA dec value (for
 2230 :                               ;                    music on DMA IRQ, not altered again if 16bt)
 2240 LDRB    R14,[R12,#soundflags]
 2250 TST     R14,#1<<7
 2260 BNE     initVIDCandpitch16bit
 2270 TST     R14,#1<<2               ;test for new VIDC clock
 2280 BNE     newmachinemode          ;new-clock flag set, so use its routine
 2290 :
 2300 MOV        R0,#(24000 AND &FF00)
 2310 ADD     R0,R0,#(24000 AND &00FF)
 2320 STR     R0,[R12,#clockspeed]
 2330 MOV     R0,#24000/1000*4096
 2340 STR     R0,[R12,#shiftclock]    ;not a new clock machine, so assume 24MHz at start
 2350 BL      recalc_uS_4clock
 2360 B       oldmachinemode
 2370 :
 2380 .initVIDCandpitch16bit
 2390 BL      recalc_uS_4clock_16bit
 2400 LDMFD   R13!,{R0-R1,R12,PC}     ;v1.48 fix, was ...R14} meaning machinedetect was called twice!
 2410 
 2420 
 2430 .machinedetect
 2440 STMFD   R13!,{R0-R6,R14}
 2450 MOV     R6,#0                   ;default for soundflags = 0
 2460 :
 2470 BL      armcheck                ;R0=Arm number (2, 3 or 6)
 2480 STRB    R0,[R12,#armchip]
 2490 :
 2500 MOV     R0,#129
 2510 MOV     R1,#0
 2520 MOV     R2,#&FF
 2530 SWI     "XOS_Byte"
 2540 SUB     R1,R1,#&A0
 2550 STRB    R1,[R12,#osversion]     ;set OS version-&A0
 2560 CMP     R1,#&A2-&A0             ;check for OS 2.01 or above
 2570 ORREQ   R6,R6,#1<<2             ;EQ = RO2.01, so A540 with new VIDC
 2580 BLE     setmachinetype          ;...if OS <=2.01, old so exit!
 2590 :
 2600 CMP     R1,#&AA-&A0             ;RISC OS 5? (handles 'Tuning' of OS sounds correctly)
 2610 ORRGE   R6,R6,#%000010          ; ...if so, enable TSS by default
 2620 LDRGEB  R0,[R12,#musicvolume]   ; ...scale vol to 3/4 for RO5 to make TSS sounds louder
 2630 ADDGE   R0,R0,R0,LSL#1          ; ...musicvolume already scaled to sys volume, in initdatabanks
 2640 MOVGE   R0,R0,LSR#2             ; ...now scale music volume to 3/4 by r1=(music vol * 3) / 4
 2650 BLGE    swi_qtmvolume           ; ...BUG'd before v1.48, as coded didn't call swi_qtmvol!!!
 2660 :
 2670 CMP     R1,#&A5-&A0             ;v1.44 test for RPCEmu
 2680 BLT     testRO3oldnewVIDC       ;if <RO3.5, then not RPCEmu
 2690 ;ADR     R1,rpcemuhostfs         ;removed in v1.48 becuase latest RPCEmu0.9.4 seems ok with
 2700 ;MOV     R0,#18                  ;sample speed <>48...
 2710 ;SWI     "XOS_Module"            ;test for RPCEmuHostFS (wipes R5!)
 2720 ;MOVVC   R0,#48                  ;
 2730 ;STRVCB  R0,[R12,#current_uS]    ;if VC (module present) then set uS to 48
 2740 :
 2750 .test16bitsound
 2760 MOVS    R0,#0                   ;test for 16bit sound
 2770 SWI     "XSound_4"              ;v1.42 fix, was XSound_Mode - so compiles on RO3.6+ only
 2780 CMP     R0,#1                   ;returns VS and R0<>1 if error unknown SWI
 2790 ORREQ   R6,R6,#1<<7             ;16bit sound available!
 2800 BEQ     setmachinetype          ;don't care about VIDC type if 16bit
 2810 :
 2820 .testRO3oldnewVIDC
 2830 MOV     R0,#2                   ;OS 3+ (only) old/new detection coming up!
 2840 SWI     "XOS_ReadSysInfo"       ;*this detects RO3 A540 as 'old' which is ok, but should be 'new'
 2850 CMP     R0,#0
 2860 CMPEQ   R1,#0
 2870 CMPEQ   R2,#0
 2880 CMPEQ   R3,#0
 2890 CMPEQ   R4,#0
 2900 ORRNE   R6,R6,#1<<2             ;above call returned non-zero, so set as a new machine VIDC
 2910 .setmachinetype
 2920 STRB    R6,[R12,#soundflags]
 2930 LDMFD   R13!,{R0-R6,PC}
 2940 
 2950 
 2960 ;.rpcemuhostfs
 2970 ;EQUS    "RPCEmuHostFS"
 2980 ;EQUB    0
 2990 ;ALIGN
 3000 
 3010 
 3020 .SWIcode                        ;wrapper to allow flag preservation on 26bit systems
 3030 STMFD   R13!,{R14}
 3040 BL      origSWIcode
 3050 LDMFD   R13!,{R14}
 3060 TEQ     PC,PC
 3070 MOVEQ   PC,R14                  ;SWIs don't preserve flags under 32bit RO
 3080 BICVCS  PC,R14,#1<<28
 3090 ORRS    PC,R14,#1<<28
 3100 
 3110 .origSWIcode
 3120 LDR     R12,[R12]               ;v1.49 FNlong_adr("  ",12,song_data)
 3130 CMP     R11,#(endSWItable-startSWItable)/4
 3140 ADDLO   PC,PC,R11,LSL#2
 3150 B       UnknownSWIerror
 3160 .startSWItable
 3170 B       swi_qtmload             ;0
 3180 B       swi_qtmstart            ;1
 3190 B       swi_qtmstop             ;2
 3200 B       swi_qtmpause            ;3
 3210 B       swi_qtmclear            ;4
 3220 B       swi_qtminfo             ;5
 3230 B       swi_qtmpos              ;6
 3240 B       swi_qtmeffectctrl       ;7
 3250 B       swi_qtmvolume           ;8
 3260 B       swi_qtmsetsamplespeed   ;9
 3270 B       swi_qtmdmabuffer        ;10
 3280 B       swi_qtmremovechan       ;11
 3290 B       swi_qtmrestorechan      ;12
 3300 B       swi_qtmstereo           ;13
 3310 B       swi_qtmsonglength       ;14
 3320 B       swi_qtmreadsequence     ;15
 3330 B       swi_qtmvubarctrl        ;16
 3340 B       swi_qtmreadvulevels     ;17
 3350 B       swi_qtmreadsample       ;18
 3360 B       swi_qtmreadspeed        ;19
 3370 B       swi_qtmplaysample       ;20
 3380 B       swi_qtmsongstatus       ;21
 3390 B       swi_qtmplayingtime      ;22
 3400 B       swi_qtmplayraw          ;23
 3410 B       swi_qtmsoundctrl        ;24
 3420 B       swi_qtmswitableaddr     ;25
 3430 B       swi_qtmregistersmp      ;26
 3440 B       swi_qtmsetspeed         ;27
 3450 B       swi_qtmmusicvolume      ;28
 3460 B       swi_qtmsamplevolume     ;29
 3470 B       swi_qtmmusicoptions     ;30
 3480 B       swi_qtmmusicinterrupt   ;31
 3490 B       swi_qtmreadchanneldata  ;32
 3500 B       swi_qtmreadnoteword     ;33
 3510 B       swi_qtmdmahandler       ;34
 3520 ]:IF alphatest% THEN [OPT opt%:B swi_qtmdebug:]
 3530 [OPT opt%
 3540 .endSWItable
 3550 .UnknownSWIerror
 3560 MOV     R0,#&80000000
 3570 SUBS    R0,R0,#1
 3580 ADR     R0,swierror
 3590 MOV     PC,R14
 3600 .swierror
 3610 EQUD    486                     ;<-- ???? wot a c**p error number
 3620 EQUS    "Unknown QTMTracker operation"
 3630 EQUB    0
 3640 ALIGN
 3650 
 3660 
 3670 .exitqtm
 3680 STMFD   R13!,{R12,R14}
 3690 LDR     R12,[R12]               ;v1.49 FNlong_adr("  ",12,song_data)
 3700 MOV     R0,#0
 3710 MVN     R1,#0
 3720 BL      swi_qtmvubarctrl
 3730 BL      swi_qtmclear
 3740 :
 3750 LDRB    R0,[R12,#armchip]       ;v1.48
 3760 CMP     R0,#3                   ;
 3770 BLLE    release_a2_DMA          ;
 3780 LDMVSFD R13!,{R12,PC}           ;if Arm2 or Arm3, release RMA for all the unrolled DMA code
 3790 :
 3800 LDR     R0,[R12,#fake8bitDMA]
 3810 TEQ     R0,#0
 3820 BLNE    releaseRMA
 3830 :
 3840 MOV     R0,R12                  ;v1.49 last thing we do is...
 3850 BL      releaseRMA              ;...release RMA for datablock ;-)
 3860 LDMFD   R13!,{R12,PC}
 3870 
 3880 
 3890 .claimRMA                       ;r0=size
 3900 STMFD   R13!,{R1-R3,R14}
 3910 MOV     R3,R0
 3920 MOV     R0,#6
 3930 SWI     "XOS_Module"            ;address in R2
 3940 MOVVC   R0,R2
 3950 LDMFD   R13!,{R1-R3,PC}         ;returns r0=addr or VS
 3960 
 3970 
 3980 .releaseRMA
 3990 STMFD   R13!,{R1-R3,R14}
 4000 MOV     R2,R0
 4010 MOV     R0,#7
 4020 SWI     "XOS_Module"
 4030 MOVVC   R0,#0
 4040 LDMFD   R13!,{R1-R3,PC}
 4050 
 4060 
 4070 .blankmemory
 4080 STMFD   R13!,{R0-R12,R14}       ;address in R0, length in R1
 4090 MOV     R2,#0
 4100 MOV     R3,R2
 4110 MOV     R4,R2
 4120 MOV     R5,R2
 4130 MOV     R6,R2
 4140 MOV     R7,R2
 4150 MOV     R8,R2
 4160 MOV     R9,R2
 4170 MOV     R10,R2
 4180 MOV     R11,R2
 4190 MOV     R12,R2
 4200 MOV     R14,R2
 4210 .blank256
 4220 SUBS    R1,R1,#256
 4230 BMI     blankwords
 4240 STMIA   R0!,{R2-R12,R14}        ;48
 4250 STMIA   R0!,{R2-R12,R14}        ;96
 4260 STMIA   R0!,{R2-R12,R14}        ;144
 4270 STMIA   R0!,{R2-R12,R14}        ;192
 4280 STMIA   R0!,{R2-R12,R14}        ;240
 4290 STMIA   R0!,{R2-R5}             ;256
 4300 BGT     blank256
 4310 LDMFD   R13!,{R0-R12,PC}
 4320 .blankwords
 4330 ADD     R1,R1,#256
 4340 .blank8
 4350 SUBS    R1,R1,#4
 4360 STRGE   R2,[R0],#4
 4370 SUBS    R1,R1,#4
 4380 STRGE   R2,[R0],#4
 4390 BGT     blank8
 4400 LDMFD   R13!,{R0-R12,PC}
 4410 
 4420 
 4430 ; RISC OS 4 service call table
 4440 .servicetable
 4450 EQUD    0                       ;Flag word
 4460 EQUD    servicedispatch         ;Dispatch code
 4470 EQUD    &27                     ;Services, listed in increasing order
 4480 ;EQUD    &46                     ;v1.49 fix, ModeChange service n/r on RO3.5+
 4490 EQUD    0                       ;Terminator
 4500 EQUD    servicetable            ;Pointer to table in word before .services
 4510 .services
 4520 MOV     R0,R0                   ;Magic marker for OS 4 service call table to work
 4530 .servicedispatch
 4540 CMP     R1,#&46
 4550 BEQ     domodechange            ;R2,R3 = mode and monitor type on OS 3.1+, but not user call!
 4560 CMP     R1,#&27
 4570 BEQ     handlereset
 4580 MOV     PC,R14
 4590 
 4600 
 4610 .handlereset                    ;&27
 4620 STMFD   R13!,{R0,R12,R14}
 4630 LDR     R12,[R12]               ;v1.49 FNlong_adr("  ",12,song_data)
 4640 :
 4650 LDRB    R0,[R12,#songstatus]
 4660 TST     R0,#%1<<2               ;are we playing?
 4670 BICNE   R0,R0,#%1<<2
 4680 STRNEB  R0,[R12,#songstatus]    ;if playing, clear 'playing' flag - so qtm_start will work!
 4690 BLNE    swi_qtmstart
 4700 CMP     R0,R0                   ;don't return errors (clear V)
 4710 LDMFD   R13!,{R0,R12,PC}
 4720 
 4730 
 4740 .domodechange                   ;&46 n/r on RO3.5+
 4750 STMFD   R13!,{R0-R1,R12,R14}
 4760 LDR     R12,[R12]               ;v1.49 FNlong_adr("  ",12,song_data)
 4770 LDRB    R1,[R12,#osversion]
 4780 CMP     R1,#&A5-&A0             ;RO3.5+? v1.49 fix - previously checked for 16bit sound...
 4790 LDMGEFD R13!,{R0-R1,R12,PC}     ;...but RO3.5+ won't affect pitch on mode change (even if 8bit!)
 4800 :
 4810 BL      twangsoundsystem        ;force RISC OS 2/3 to update sound system after mode change!
 4820 LDRB    R1,[R12,#soundflags]
 4830 TST     R1,#1<<2
 4840 BEQ     oldmachinemode          ;if new VIDC clock flag clear, use pre-A5000 timed calc routine
 4850 :
 4860 .newmachinemode                 ;*** also jumped here from 'initVIDCandpitch' ***
 4870 FNlong_adr("  ",0,readclock)    ;for A5000 and later, we simply read the new mode's clock speed
 4880 ADD     R1,R12,#(numberbuf_new-song_data);then go and see if pitches need recalcing!
 4890 SWI     "XOS_ReadVduVariables"  ;RiscPC and later should always return 24MHz (no impact to sound)
 4900 LDR     R0,[R1]
 4910 LDR     R1,[R12,#clockspeed]
 4920 CMP     R0,R1
 4930 LDMEQFD R13!,{R0-R1,R12,PC}     ;if same clock speed, just exit!
 4940 STR     R0,[R12,#clockspeed]
 4950 ]:IF qtmrast% THEN
 4960  [OPT opt%
 4970  AND    R1,R0,#&FF00            ;v1.43se for RasterMan... adjust CIA dec value for VGA or other
 4980  CMP       R1,#&6200            ;are we currently 25175MHz? (well anywhere between 25088-25343)
 4990  MOVNE  R1,#1<<16               ;if not, use CIA decrement value for 24/36/48MHz
 5000  MOVEQ     R1,#&F400            ;if 25175MHz then..
 5010  ORREQ  R1,R1,#&000D            ;..use CIA dec value for 25175MHz [CIAdec is n/r for normal QTM]
 5020  STR    R1,[R12,#rm_CIAdec]     ;store
 5030 ]
 5040 ENDIF
 5050 [OPT opt%
 5060 MOV     R0,R0,LSL#12            ;if not RasterMan, we don't use CIAdec, since running off 100Hz
 5070 MOV     R1,#1000
 5080 BL      r0_div_r1
 5090 STR     R0,[R12,#shiftclock]    ;else, recalc 'shiftclock' and go to recalc pitches!
 5100 :
 5110 BL      recalc_uS_4clock
 5120 LDMFD   R13!,{R0-R1,R12,PC}
 5130 
 5140 
 5150 .oldmachinemode                 ;for pre-A5000 "old" machines, we manually calc the clock speed
 5160 MOV     R0,#0                   ;using timed # of DMA IRQs, before calcing the pitches... this
 5170 STR     R0,[R12,#DMAinterrupts] ;allows QTM to determine correct pitch even if VIDC enhancer used
 5180 STR     R0,[R12,#ClockCalcEnd]
 5190 :
 5200 LDRB    R0,[R12,#soundflags]
 5210 ORR     R0,R0,#1<<3             ;flag for manual VIDC clock calc (pre-A5000 only!)
 5220 STRB    R0,[R12,#soundflags]
 5230 LDMFD   R13!,{R0-R1,R12,PC}
 5240 
 5250 
 5260 .cmd_qtmstart
 5270 LDR     R12,[R12]               ;v1.49 FNlong_adr("  ",12,song_data)
 5280 B       swi_qtmstart
 5290 .cmd_qtmstop
 5300 LDR     R12,[R12]               ;v1.49 FNlong_adr("  ",12,song_data)
 5310 B       swi_qtmstop
 5320 .cmd_qtmpause
 5330 LDR     R12,[R12]               ;v1.49 FNlong_adr("  ",12,song_data)
 5340 B       swi_qtmpause
 5350 .cmd_qtmclear
 5360 LDR     R12,[R12]               ;v1.49 FNlong_adr("  ",12,song_data)
 5370 B       swi_qtmclear
 5380 .cmd_qtmload
 5390 LDR     R12,[R12]               ;v1.49 FNlong_adr("  ",12,song_data)
 5400 STMFD   R13!,{R1-R2,R14}
 5410 BL      check4x                 ;r2=1 if 'x', 0 if not
 5420 ADRVS   R0,err_syntaxload
 5430 LDMVSFD R13!,{R1-R2,PC}
 5440 MOV     R1,#0
 5450 BL      swi_qtmload
 5460 LDMVSFD R13!,{R1-R2,PC}
 5470 CMP     R2,#0
 5480 BLEQ    swi_qtmstart
 5490 LDMFD   R13!,{R1-R2,PC}
 5500 
 5510 
 5520 .check4x
 5530 STMFD   R13!,{R0,R14}
 5540 CMP     R1,#2                   ;number of params found
 5550 MOVNE   R2,#0                   ;less than 2, so put 0 in r2...
 5560 LDMNEFD R13!,{R0,PC}            ;...and exit
 5570 :
 5580 .findspace
 5590 LDRB    R2,[R0],#1
 5600 CMP     R2,#ASC" "
 5610 BNE     findspace
 5620 .findnonspace
 5630 LDRB    R2,[R0],#1
 5640 CMP     R2,#ASC" "
 5650 BEQ     findnonspace
 5660 :
 5670 CMP     R2,#ASC"x"
 5680 MOVEQ   R2,#1
 5690 LDMEQFD R13!,{R0,PC}
 5700 :
 5710 MOV     R2,#&80000000           ;if 2nd param was not 'x' then set up an error
 5720 SUBS    R2,R2,#1
 5730 LDMFD   R13!,{R0,PC}
 5740 
 5750 .err_syntaxload
 5760 EQUD    220
 5770 EQUS    "Syntax: *QTMLoad <filename> [x]"
 5780 EQUB    0
 5790 ALIGN
 5800 
 5810 .unknown     EQUS "<unknown>"+CHR$0
 5820 .in15        EQUS "Sound Tracker compatible, 4 channel, 15 inst"+CHR$0
 5830 ALIGN
 5840 
 5850 .cmd_qtminfo
 5860 LDR     R12,[R12]               ;v1.49 FNlong_adr("  ",12,song_data)
 5870 STMFD   R13!,{R0-R6,R14}
 5880 FNlong_adr("  ",0,help)
 5890 MOV     R1,#0
 5900 MOV     R2,R0
 5910 SWI     "XOS_Write0"
 5920 SWI     "XOS_NewLine"
 5930 :
 5940 BL      swi_qtminfo             ;r3=channels
 5950 STRVS   R0,[R13,#0]
 5960 LDMVSFD R13!,{R0-R6,PC}
 5970 :
 5980 SWI     "XOS_WriteS"
 5990 EQUS    "Song name     : "+CHR$0
 6000 SWI     "XOS_Write0"
 6010 SWI     "XOS_NewLine"
 6020 :
 6030 SWI     "XOS_WriteS"
 6040 EQUS    "Author        : "+CHR$0
 6050 MOVS    R0,R1
 6060 ADREQ   R0,unknown
 6070 SWI     "XOS_Write0"
 6080 SWI     "XOS_NewLine"
 6090 :
 6100 SWI     "XOS_WriteS"
 6110 EQUS    "Position      : "+CHR$0
 6120 BL      displaypos
 6130 SWI     "XOS_NewLine"
 6140 :
 6150 ADD     R3,R3,#ASC"0"
 6160 :
 6170 SWI     "XOS_WriteS"
 6180 EQUS    "Song type     : "+CHR$0
 6190 CMP     R2,#0
 6200 ADREQ   R0,in15
 6210 CMP     R2,#1
 6220 ADREQ   R0,in31
 6230 CMP     R2,#2
 6240 ADREQ   R0,pt31
 6250 CMP     R2,#3
 6260 ADREQ   R0,startrek
 6270 STREQB  R3,starchan_1  ;**THIS EDITS MODULE**
 6280 STREQB  R3,starchan_2
 6290 CMP     R2,#4
 6300 ADREQ   R0,fasttrack
 6310 STREQB  R3,fastchan_1  ;**THIS EDITS MODULE**
 6320 STREQB  R3,fastchan_2
 6330 CMP     R2,#5
 6340 ADREQ   R0,octalyser
 6350 STREQB  R3,octachan_1  ;**THIS EDITS MODULE**
 6360 STREQB  R3,octachan_2
 6370 SWI     "XOS_Write0"
 6380 SWI     "XOS_NewLine"
 6390 :
 6400 SWI     "XOS_WriteS"
 6410 EQUS    "Module length : "+CHR$0
 6420 MOV     R0,R4
 6430 ADD     R1,R12,#(numberbuf_new-song_data) ;v1.48
 6440 MOV     R2,#15
 6450 SWI     "XOS_ConvertSpacedCardinal4"
 6460 SWI     "XOS_Write0"
 6470 SWI     "XOS_WriteS"
 6480 EQUS    " bytes"+CHR$10+CHR$13+CHR$0
 6490 LDMFD   R13!,{R0-R6,PC}
 6500 
 6510 .in31        EQUS "Sound Tracker compatible, 4 channel, 31 inst"+CHR$0
 6520 .pt31        EQUS "ProTracker, 4 channel (M.K.)"+CHR$0
 6530 .startrek    EQUS "StarTrekker, "
 6540 .starchan_1  EQUS              "? channel (FLT"
 6550 .starchan_2  EQUS                            "?)"+CHR$0
 6560 .fasttrack   EQUS "FastTracker, "
 6570 .fastchan_1  EQUS              "? channel ("
 6580 .fastchan_2  EQUS                         "?CHN)"+CHR$0
 6590 .octalyser   EQUS "Octalyser, "
 6600 .octachan_1  EQUS            "? channel (CD"
 6610 .octachan_2  EQUS                          "?1)"+CHR$0
 6620 ALIGN
 6630 
 6640 
 6650 .displaypos                     ;**** only call if song loaded ****
 6660 STMFD   R13!,{R0-R3,R14}
 6670 BL      swi_qtmsonglength
 6680 MOV     R3,R0
 6690 MVN     R0,#0
 6700 MVN     R1,#0
 6710 BL      swi_qtmpos
 6720 :
 6730 ADD     R1,R12,#(numberbuf_new-song_data) ;v1.48
 6740 MOV     R2,#15
 6750 SWI     "XOS_ConvertCardinal2"
 6760 MOV     R0,#ASC"/"
 6770 STRB    R0,[R1],#1
 6780 :
 6790 MOV     R0,R3
 6800 MOV     R2,#15
 6810 SWI     "XOS_ConvertCardinal2"
 6820 ADD     R0,R12,#(numberbuf_new-song_data) ;v1.48
 6830 SWI     "XOS_Write0"
 6840 LDMFD   R13!,{R0-R3,PC}
 6850 
 6860 
 6870 .cmd_qtmpos
 6880 LDR     R12,[R12]               ;v1.49 FNlong_adr("  ",12,song_data)
 6890 STMFD   R13!,{R14}
 6900 BL      ensuresong
 6910 LDMVSFD R13!,{PC}
 6920 :
 6930 CMP     R1,#0
 6940 BNE     cmdsetpos
 6950 :
 6960 SWI     "XOS_WriteS"
 6970 EQUS    "Position : "+CHR$0
 6980 BL      displaypos
 6990 SWI     "XOS_NewLine"
 7000 LDMFD   R13!,{PC}
 7010 
 7020 .cmdsetpos
 7030 STMFD   R13!,{R0-R2}
 7040 BL      check4x
 7050 ADRVS   R0,err_setsyntax
 7060 BVS     err_cmdsetseq
 7070 :
 7080 CMP     R2,#1
 7090 MOV     R1,R0
 7100 MOV     R0,#10
 7110 SWI     "XOS_ReadUnsigned"
 7120 BVS     err_cmdsetseq
 7130 :
 7140 MOV     R0,R2
 7150 MOVNE   R1,#0
 7160 MVNEQ   R1,#0
 7170 BL      swi_qtmpos
 7180 .err_cmdsetseq
 7190 STRVS   R0,[R13,#0]
 7200 LDMFD   R13!,{R0-R2,PC}
 7210 
 7220 .err_setsyntax
 7230 EQUD    220
 7240 EQUS    "Syntax: *QTMPos [<position> [x]]"
 7250 EQUB    0
 7260 ALIGN
 7270 
 7280 
 7290 .cmd_qtmvolume
 7300 LDR     R12,[R12]               ;v1.49 FNlong_adr("  ",12,song_data)
 7310 STMFD   R13!,{R0-R2,R14}
 7320 CMP     R1,#1
 7330 BNE     displayvol
 7340 MOV     R1,R0
 7350 MOV     R0,#10
 7360 SWI     "XOS_ReadUnsigned"
 7370 :
 7380 MOVVC   R0,R2
 7390 BLVC    swi_qtmvolume
 7400 STRVS   R0,[R13,#0]
 7410 LDMFD   R13!,{R0-R2,PC}
 7420 
 7430 .displayvol
 7440 MVN     R0,#0
 7450 BL      swi_qtmvolume
 7460 ADD     R1,R12,#(numberbuf_new-song_data) ;v1.48
 7470 MOV     R2,#15
 7480 SWI     "XOS_ConvertCardinal1"
 7490 SWI     "XOS_WriteS"
 7500 EQUS    "Current volume level: "+CHR$0
 7510 SWI     "XOS_Write0"
 7520 SWI     "XOS_NewLine"
 7530 LDMFD   R13!,{R0-R2,PC}
 7540 
 7550 
 7560 .cmd_qtmdisable
 7570 LDR     R12,[R12]               ;v1.49 FNlong_adr("  ",12,song_data)
 7580 STMFD   R13!,{R0-R4,R14}
 7590 CMP     R1,#1
 7600 BNE     showdisabled
 7610 :
 7620 MOV     R1,R0
 7630 MOV     R0,#16
 7640 SWI     "XOS_ReadUnsigned"
 7650 BVS     err_cmddisable
 7660 :
 7670 MOV     R0,R2
 7680 MOV     R1,#0
 7690 BL      swi_qtmeffectctrl
 7700 BVS     err_cmddisable
 7710 :
 7720 SWI     "XOS_WriteS"
 7730 EQUS    "Effect disabled"+CHR$10+CHR$13+CHR$0
 7740 .err_cmddisable
 7750 STRVS   R0,[R13,#0]
 7760 LDMFD R13!,{R0-R4,PC}
 7770 
 7780 .showdisabled
 7790 MVN     R0,#0
 7800 BL      swi_qtmeffectctrl
 7810 :
 7820 SUB     R2,R0,#&FF00
 7830 SUBS    R2,R2,#&00FF
 7840 SUBEQ   R2,R1,#&FF00
 7850 SUBEQS  R2,R2,#&00FF
 7860 BEQ     nonedisabled
 7870 :
 7880 SWI     "XOS_WriteS"
 7890 EQUS    "Effect(s) disabled are: "+CHR$0
 7900 MOV     R3,R0
 7910 MOV     R4,R1
 7920 MOV     R5,#1
 7930 MOV     R6,#0
 7940 MOV     R7,#0                   ;flag; bit 0 on=E fx, bit 1 on=done first effect
 7950 ADD     R1,R12,#(numberbuf_new-song_data) ;v1.48
 7960 MOV     R2,#15
 7970 .anydisabled
 7980 TST     R3,R5,LSLR6
 7990 BNE     notthiseffect
 8000 TST     R7,#1<<1
 8010 SWINE   256+ASC","              ;',' if after first effect
 8020 ORREQ   R7,R7,#1<<1
 8030 TST     R7,#1<<0
 8040 ORRNE   R0,R6,#&E0              ;'E' effect
 8050 MOVEQ   R0,R6
 8060 MOV     R2,#15
 8070 SWI     "XOS_ConvertHex2"
 8080 MOV     R1,R0
 8090 SWI     "XOS_Write0"
 8100 .notthiseffect
 8110 ADD     R6,R6,#1
 8120 CMP     R6,#&F
 8130 BLE     anydisabled
 8140 TST     R7,#1<<0
 8150 MOVEQ   R3,R4
 8160 MOVEQ   R6,#0
 8170 ORREQ   R7,R7,#1<<0
 8180 BEQ     anydisabled
 8190 SWI     "XOS_NewLine"
 8200 LDMFD   R13!,{R0-R4,PC}
 8210 
 8220 .nonedisabled
 8230 SWI     "XOS_WriteS"
 8240 EQUS    "No effects disabled"+CHR$10+CHR$13+CHR$0
 8250 LDMFD   R13!,{R0-R4,PC}
 8260 
 8270 
 8280 .cmd_qtmenable
 8290 LDR     R12,[R12]               ;v1.49 FNlong_adr("  ",12,song_data)
 8300 STMFD   R13!,{R0-R2,R14}
 8310 MOV     R1,R0
 8320 MOV     R0,#16
 8330 SWI     "XOS_ReadUnsigned"
 8340 BVS     err_cmdenable
 8350 :
 8360 MOV     R0,R2
 8370 MOV     R1,#1
 8380 BL      swi_qtmeffectctrl
 8390 BVS     err_cmdenable
 8400 :
 8410 SWI     "XOS_WriteS"
 8420 EQUS    "Effect enabled"+CHR$10+CHR$13+CHR$0
 8430 .err_cmdenable
 8440 STRVS   R0,[R13,#0]
 8450 LDMFD   R13!,{R0-R2,PC}
 8460 
 8470 
 8480 .cmd_qtmsamples
 8490 LDR     R12,[R12]               ;v1.49 FNlong_adr("  ",12,song_data)
 8500 STMFD   R13!,{R14}
 8510 BL      ensuresong
 8520 LDMVSFD R13!,{PC}
 8530 :
 8540 STMFD   R13!,{R0-R9}
 8550 SWI     "XOS_WriteS"
 8560 EQUS    "No. Sample text            Vol Length RepOff RepLen FTune"+CHR$13+CHR$10+CHR$0
 8570 MOV     R0,#ASC"-"
 8580 MOV     R1,#57
 8590 BL      repeatchar              ;v1.48
 8600 SWI     "XOS_NewLine"
 8610 ;EQUS    "---------------------------------------------------------"+CHR$13+CHR$10
 8620 ;EQUB     00                     ;    00  00000  00000  00000    -0
 8630 :
 8640 ADD     R9,R12,#(numberbuf_new-song_data) ;v1.48
 8650 LDRB    R8,[R12,#songtype] ;was #insts
 8660 TEQ     R8,#0
 8670 MOVEQ   R8,#15
 8680 MOVNE   R8,#31
 8690 :
 8700 MOV     R7,#1
 8710 .printsamples
 8720 MOV     R0,R7
 8730 BL      swi_qtmreadsample
 8740 CMP     R1,#0
 8750 LDRB    R6,[R0]
 8760 CMPEQ   R6,#0
 8770 BEQ     skipthissample
 8780 :
 8790 STMFD   R13!,{R0-R2}
 8800 MOV     R0,R7
 8810 MOV     R1,R9
 8820 MOV     R2,#15
 8830 SWI     "XOS_ConvertHex2"
 8840 SWI     "XOS_Write0"
 8850 SWI     256+ASC" ":SWI 256+ASC" "
 8860 :
 8870 CMP     R6,#0
 8880 SWIEQ   256+ASC"-"
 8890 LDRNE   R0,[R13,#0]
 8900 MOVNE   R1,#22
 8910 BLNE    printnoctrl
 8920 :
 8930 SWI     256+13                  ;get back to start of line
 8940 MOV     R1,#2+2+22+2            ;v1.48 fix - just go to start of line and move cursor one by one
 8950 MOV     R0,#9                   ;VDU9 = cursor right one place
 8960 BL      repeatchar              ;should now work in task window...
 8970 ;BL      tab_n
 8980 MOV     R0,R4
 8990 CMP     R0,#10
 9000 MOV     R1,R9
 9010 MOV     R2,#15
 9020 SWI     "XOS_ConvertCardinal1"
 9030 SWILT   256+ASC" "
 9040 SWI     "XOS_Write0"
 9050 :
 9060 SWI     256+ASC" "
 9070 LDR     R0,[R13,#4]
 9080 MOV     R1,R9
 9090 MOV     R2,#6
 9100 SWI     "XOS_ConvertCardinal2"
 9110 MOVS    R1,R2
 9120 BLNE    spaces
 9130 SWI     "XOS_Write0"
 9140 LDMFD   R13!,{R0-R2}
 9150 :
 9160 SWI     256+ASC" "
 9170 MOV     R0,R2
 9180 MOV     R1,R9
 9190 MOV     R2,#6
 9200 SWI     "XOS_ConvertCardinal2"
 9210 MOVS    R1,R2
 9220 BLNE    spaces
 9230 SWI     "XOS_Write0"
 9240 :
 9250 SWI     256+ASC" "
 9260 MOV     R0,R3
 9270 MOV     R1,R9
 9280 MOV     R2,#6
 9290 SWI     "XOS_ConvertCardinal2"
 9300 MOVS    R1,R2
 9310 BLNE    spaces
 9320 SWI     "XOS_Write0"
 9330 :
 9340 MOV     R1,#4
 9350 BL      spaces
 9360 MOV     R0,R5                           ;signed -8 to 7 byte!
 9370 MOV     R1,R9
 9380 MOV     R2,#15
 9390 SWI     "XOS_ConvertInteger1"
 9400 CMP     R5,#0
 9410 SWIGE   256+ASC" "                      ;add space if not -ve
 9420 SWI     "XOS_Write0"
 9430 SWI     "XOS_NewLine"
 9440 .skipthissample
 9450 ADD     R7,R7,#1
 9460 CMP     R7,R8
 9470 BLE     printsamples
 9480 LDMFD   R13!,{R0-R9,PC}
 9490 
 9500 .printnoctrl                            ;prints R1 bytes from string at R0, no ctrl chars
 9510 STMFD   R13!,{R0-R2,R14}
 9520 MOV     R2,R0
 9530 .printloop
 9540 LDRB    R0,[R2],#1
 9550 CMP     R0,#32
 9560 SWIGE   "XOS_WriteC"
 9570 SUBS    R1,R1,#1
 9580 BNE     printloop
 9590 LDMFD   R13!,{R0-R2,PC}
 9600 
 9610 .spaces                                 ;prints R1 spaces
 9620 STMFD   R13!,{R0-R1,R14}
 9630 MOV     R0,#32
 9640 B       repeatcloop
 9650 
 9660 .repeatchar                             ;v1.48 R0=ascii code, R1=number to print
 9670 STMFD   R13!,{R0-R1,R14}
 9680 .repeatcloop
 9690 SWI     "OS_WriteC"
 9700 SUBS    R1,R1,#1
 9710 BGT     repeatcloop
 9720 LDMFD   R13!,{R0-R1,PC}
 9730 
 9740 ;.spaces                                 ;prints R1 spaces
 9750 ;STMFD   R13!,{R1,R14}
 9760 ;.spaceloop
 9770 ;SWI     256+ASC" "
 9780 ;SUBS    R1,R1,#1
 9790 ;BNE     spaceloop
 9800 ;LDMFD   R13!,{R1,PC}
 9810 
 9820 ;.tab_n                                  ;move x position to R0 (but doesn't work in task window)
 9830 ;STMFD   R13!,{R0-R3,R14}
 9840 ;MOV     R3,R0
 9850 ;MOV     R0,#165
 9860 ;SWI     "XOS_Byte"                      ;OS_Byte 165 always returns x=0,y=0 in task window
 9870 ;SWI     256+31
 9880 ;MOV     R0,R3
 9890 ;SWI     "XOS_WriteC"
 9900 ;MOV     R0,R2
 9910 ;SWI     "XOS_WriteC"
 9920 ;LDMFD   R13!,{R0-R3,PC}
 9930 
 9940 
 9950 .cmd_qtmtrans                   ;new for v1.44
 9960 LDR     R12,[R12]               ;v1.49 FNlong_adr("  ",12,song_data)
 9970 STMFD   R13!,{R0-R2,R14}
 9980 CMP     R1,#1
 9990 BNE     displaytrans
10000 :
10010 LDRB    R1,[R0],#1
10020 CMP     R1,#ASC"O"
10030 CMPNE   R1,#ASC"o"
10040 BNE     err_cmdtrans
10050 LDRB    R1,[R0],#1
10060 CMP     R1,#ASC"N"
10070 CMPNE   R1,#ASC"n"
10080 BEQ     cmd_transon
10090 CMP     R1,#ASC"F"
10100 CMPNE   R1,#ASC"f"
10110 BNE     err_cmdtrans
10120 LDRB    R1,[R0],#1
10130 CMP     R1,#ASC"F"
10140 CMPNE   R1,#ASC"f"
10150 BNE     err_cmdtrans
10160 .cmd_transoff
10170 LDRB    R1,[R0],#1
10180 CMP     R1,#32
10190 BGE     err_cmdtrans
10200 :
10210 MVN     R0,#0
10220 MVN     R1,#0
10230 MVN     R2,#0
10240 BL      swi_qtmsoundctrl
10250 TST     R1,#%1
10260 LDMEQFD R13!,{R0-R2,PC}       ;already off!
10270 :
10280 BIC     R1,R1,#%1
10290 BL      swi_qtmsoundctrl
10300 LDMFD   R13!,{R0-R2,PC}
10310 
10320 
10330 .cmd_transon
10340 LDRB    R1,[R0],#1
10350 CMP     R1,#32
10360 BGE     err_cmdtrans
10370 :
10380 MVN     R0,#0
10390 MVN     R1,#0
10400 MVN     R2,#0
10410 BL      swi_qtmsoundctrl
10420 TST     R1,#%1
10430 LDMNEFD R13!,{R0-R2,PC}       ;already on!
10440 :
10450 ORR     R1,R1,#%1
10460 BL      swi_qtmsoundctrl
10470 LDMFD   R13!,{R0-R2,PC}
10480 
10490 
10500 .displaytrans
10510 SWI     "XOS_WriteS"
10520 EQUS    "QTM Transparent Sound System is "+CHR$0
10530 LDRB    R0,[R12,#soundflags]
10540 TST     R0,#%10
10550 ADREQ   R0,text_off
10560 ADRNE   R0,text_on
10570 SWI     "XOS_Write0"
10580 SWI     "XOS_NewLine"
10590 LDMFD   R13!,{R0-R2,PC}
10600 
10610 
10620 .err_cmdtrans
10630 MOV     R0,#&80000000
10640 SUBS    R0,R0,#1
10650 LDMFD   R13!,{R0-R2,R14}
10660 ADR     R0,err_transsyntax
10670 MOV     PC,R14
10680 
10690 .err_transsyntax
10700 EQUD    220
10710 EQUS    "Syntax: *QTMTransparent [On|Off]"
10720 EQUB    0
10730 ALIGN
10740 
10750 
10760 .text_on
10770 EQUS    "on"+CHR$0
10780 .text_off
10790 EQUS    "off"+CHR$0
10800 ALIGN
10810 
10820 
10830 .swi_qtmload                    ;r0=filename/0/-1  r1=0/addr
10840 STMFD   R13!,{R0-R9,R14}
10850 CMP     R0,#0
10860 BEQ     memoryload
10870 CMN     R0,#1
10880 BEQ     transferload
10890 :
10900 MOV     R9,R1
10910 MOV     R1,R0
10920 MOV     R0,#5
10930 SWI     "XOS_File"              ;get module disc-length in r4
10940 CMP     R0,#1                   ;was it a file?
10950 MOVNE   R2,R0
10960 MOVNE   R0,#19
10970 SWINE   "XOS_File"              ;generate error if not found(0)/directory(2)/image file(3)
10980 BVS     err_qtmload
10990 :
11000 LDRB    R3,[R12,#songstatus]
11010 TST     R3,#%1<<0
11020 BLNE    swi_qtmclear
11030 BVS     err_qtmload
11040 BL      init
11050 :
11060 CMP     R9,#0
11070 MOVNE   R2,R9
11080 BNE     loadtomem
11090 MOV     R0,#6
11100 MOV     R3,R4
11110 SWI     "XOS_Module"            ;claim some RMA
11120 BVS     err_RMAclaim            ;special RMA error message
11130 :
11140 ;LDR     R0,[R12,#workspaceptr]  ;from here, call 'err_loadRMA' on QTM_Load error! ********
11150 ;STR     R2,[R0]
11160 :
11170 .loadtomem
11180 TEQ     R9,#0
11190 MOVNE   R6,#%01                 ;songstatus - clears bit 2 (playing) and bits 3-7
11200 MOVEQ   R6,#%11                 ;if load address was 0, it was an RMA load, else not
11210 :
11220 STR     R2,[R12,#songaddr]
11230 STR     R4,[R12,#songlength]
11240 MOV     R0,#&FF
11250 MOV     R3,#0
11260 SWI     "XOS_File"
11270 .continueload                   ;(V should be clear on all jumps to this point)
11280 STRB    R6,[R12,#songstatus]    ;store correct song flags!                      fix 1/1/96
11290 BVS     err_loadRMA             ;(from above...) load error, so release RMA...
11300 :
11310 FNlong_adr("  ",11,textdata)
11320 BL      init_type               ;v1.44 check format and init type (now sets songchans, songtype and insts)
11330 BLVC    initsong                ; \
11340 BLVC    init_title              ;  }- require r12=song data, r11=text data
11350 BLVC    init_author             ; /
11360 LDMVCFD R13!,{R0-R9,PC}         ;exit if no error... else continue...
11370 :
11380 .err_loadRMA                    ;handler if error occurs **AFTER** RMA possibly claimed!
11390 STR     R0,[R13,#0]             ;stack the error pointer (R0-R9, R14 stacked)
11400 :
11410 LDRB    R0,[R12,#songstatus]
11420 TST     R0,#%1<<1               ;test if we own the RMA or not...
11430 MOVNE   R0,#7                   ;and if we do, we'll have to release it
11440 LDRNE   R2,[R12,#songaddr]
11450 SWINE   "XOS_Module"
11460 :
11470 MOV     R3,#0                   ;** (nothing we can do if RMA wouldn't release...!) **
11480 ;LDR     R0,[R12,#workspaceptr]
11490 ;STR     R3,[R0]
11500 STRB    R3,[R12,#songstatus]    ;removed the song, so set correct status
11510 MOV     R0,#&80000000
11520 SUBS    R0,R0,#1                ;set V flag
11530 LDMFD   R13!,{R0-R9,PC}
11540 
11550 
11560 .err_qtmload                    ;handler if error occurs **BEFORE** RMA claimed
11570 STR   R0,[R13,#0]
11580 LDMFD R13!,{R0-R9,PC}
11590 
11600 
11610 .memoryload
11620 LDRB    R3,[R12,#songstatus]
11630 TST     R3,#%1<<0
11640 BLNE    swi_qtmclear
11650 BVS     err_qtmload
11660 BL      init                    ;song length blanked, 'initsong' will now re-calc length
11670 STR     R1,[R12,#songaddr]
11680 MOVS    R6,#%1<<0               ;set songstatus flags, and clear V on exit
11690 B       continueload
11700 
11710 
11720 .transferload                   ;R0=-1, R1=memory address
11730 LDRB    R3,[R12,#songstatus]
11740 TST     R3,#%1<<0
11750 BLNE    swi_qtmclear
11760 BVS     err_qtmload
11770 BL      init                    ;song length blanked, 'initsong' will now re-calc length
11780 :
11790 BL      checkRMAmemory          ;R0=0 if not RMA block, R0=1 if we get to keep this block
11800 CMP     R0,#1                   ;(if it was an RMA block, it also reads the size as len!)
11810 BEQ     exittransfer
11820 :
11830 STR     R1,[R12,#songaddr]      ;temporariliy put song address here, so we can check type
11840 BL      init_type               ;v1.44 check format, init type - must call BEFORE calc. length!
11850 BVS     err_loadRMA             ;not a ProTracker format song, so exit...
11860 :
11870 MOV     R11,R1                  ;R11=addr of song
11880 BL      workoutlength           ;work out actual song length (R0), entry R11=addr
11890 :
11900 MOV     R3,R0                   ;R3=length of song
11910 MOV     R0,#6
11920 SWI     "XOS_Module"            ;claim some RMA
11930 BVS     err_RMAclaim            ;special RMA error message
11940 MOV     R1,R2
11950 :
11960 .movesongwords                  ;r2=new start  r11=old start  r3=length
11970 SUBS    R3,R3,#4
11980 LDRGE   R0,[R11],#4
11990 STRGE   R0,[R2],#4
12000 BGT     movesongwords
12010 ADDLT   R3,R3,#4
12020 .movesongbytes
12030 SUBS    R3,R3,#1
12040 LDRGEB  R0,[R11],#1
12050 STRGEB  R0,[R2],#1
12060 BGT     movesongbytes
12070 :
12080 .exittransfer
12090 STR     R1,[R12,#songaddr]
12100 ;LDR     R0,[R12,#workspaceptr]
12110 ;STR     R1,[R0]
12120 MOVS    R6,#%11                 ;song loaded, and OUR RMA now (set songstatus) + clear V
12130 B       continueload            ;sets songstatus to R6
12140 
12150 
12160 .checkRMAmemory                 ;tests address in R1 is the start of an RMA-Heap block
12170 STMFD   R13!,{R1-R3,R14}        ;returns R0=0 if NOT start of RMA block, R0=1 if RMA block
12180 MOV     R2,R1
12190 MOV     R0,#1
12200 SWI     "XOS_ReadDynamicArea"   ;read RMA start
12210 MOV     R1,R0
12220 MOV     R0,#6
12230 SWI     "XOS_Heap"              ;attempt to read size of this RMA block (to R3)
12240 MOVVC   R0,#1                   ;block is RMA-Heap block start
12250 SUBVC   R3,R3,#16               ;*** (currently length returned is +16)       ************
12260 STRVC   R3,[R12,#songlength]    ;*** RMA block, so store the reserved length! ************
12270 MOVVS   R0,#0                   ;block is not the start of an RMA-Heap block
12280 LDMFD   R13!,{R1-R3,PC}         ;exit, NO errors returned
12290 
12300 
12310 .err_RMAclaim                   ;r0-r9,r14 stored on entry, r3=size of RMA needed
12320 MOV     R0,R3,LSR#10
12330 ADD     R0,R0,#1
12340 ADR     R1,RMAneeded
12350 MOV     R2,#8
12360 SWI     "XOS_BinaryToDecimal"           ;convert number, without terminator
12370 BVS     err_qtmload
12380 ADD     R1,R1,R2
12390 MOV     R0,#ASC"K":STRB R0,[R1],#1      ;**THIS EDITS MODULE**
12400 MOV     R0,#ASC" ":STRB R0,[R1],#1
12410 MOV     R0,#ASC"f":STRB R0,[R1],#1
12420 MOV     R0,#ASC"r":STRB R0,[R1],#1
12430 MOV     R0,#ASC"e":STRB R0,[R1],#1
12440 MOV     R0,#ASC"e":STRB R0,[R1],#1      ;add '...K free' to error message
12450 MOV     R0,#0:STRB R0,[R1],#1           ;ensure there is a message terminator (zero byte)
12460 ADR     R0,RMAerror
12470 STR     R0,[R13,#0]
12480 MOV     R0,#&80000000
12490 SUBS    R0,R0,#1 ; Set v flag
12500 LDMFD   R13!,{R0-R9,PC}
12510 
12520 .RMAerror ;**THIS EDITS MODULE** will need about 76 bytes to build this in RMA databank
12530 EQUD    qtm_error+&00
12540 EQUS    "Not enough memory in RMA to load song, requires at least "
12550 .RMAneeded
12560 EQUD    0:EQUD 0
12570 EQUS    "K free"
12580 EQUB    0
12590 ALIGN
12600 
12610 
12620 .swi_qtmclear
12630 STMFD   R13!,{R0-R3,R14}
12640 LDRB    R3,[R12,#songstatus]
12650 TST     R3,#%1<<0
12660 BNE     swi_qtmclear_noclear
12670 BL      clearinfos              ;always ensure channel DMA blocks are clear
12680 BL      waitchans               ;       & wait for chanels to clear
12690  ;LDRB    R14,[R12,#musicoptbyte]
12700  ;TST     R14,#%1<<3              ;v1.46, check MusicOptions bit3...
12710 LDRB    R14,[R12,#soundflags]   ;v1.49, check soundflags bit6...
12720 TST     R14,#%1<<6              ;
12730 BLEQ    resetsound              ;...if clear, ensure sound is returned to RO
12740 LDMFD   R13!,{R0-R3,PC}
12750 :
12760 .swi_qtmclear_noclear           ;get here if song loaded
12770 BL      swi_qtmstop
12780 BVS     err_qtmclear
12790 :
12800 CMN     R0,#1
12810 BLEQ    deinit_samples
12820 :
12830 TST     R3,#%1<<1
12840 MOVNE   R0,#7
12850 LDRNE   R2,[R12,#songaddr]
12860 SWINE   "XOS_Module"            ;release song RMA
12870 BVS     err_qtmclear
12880 :
12890 TST     R3,#%1<<1               ;*32Bit fix, NE (below) not preserved after SWI! v1.46 5/1/22*
12900 MOV     R3,#0
12910 ;LDR     R0,[R12,#workspaceptr]
12920 ;STR     R3,[R0]
12930 STRB    R3,[R12,#songstatus]    ;stoped and cleared the song, so set correct status
12940 MOVNE   R0,#1
12950 MOVNE   R1,#-16*1024*1024       ;move down RMA by 16Mb!!!
12960 SWINE   "XOS_ChangeDynamicArea" ;this call WILL ALWAYS set the V flag (maybe not on RPC..?)
12970 CMP     R0,R0                   ;...Clear V flag incase above is true
12980 LDMFD   R13!,{R0-R3,PC}
12990 .err_qtmclear
13000 STR     R0,[R13,#0]
13010 LDMFD   R13!,{R0-R3,PC}
13020 
13030 
13040 .swi_qtmpause                   ;may be called from play routine with IRQs off
13050 STMFD   R13!,{R0-R3,R14}        ; (F-00) if so, stop playing, but keep sound on
13060 LDRB    R3,[R12,#songstatus]
13070 TST     R3,#%1<<2               ;are we playing?
13080 BLNE    swi_qtmpause_noclear    ; yes, so skip the following...
13090 :
13100 BL      clearinfos              ;not playing - ensure channel DMA blocks clear
13110 BL      waitchans               ;            - wait for chanels to clear
13120  ;LDRB    R14,[R12,#musicoptbyte]
13130  ;TST     R14,#%1<<3              ;v1.46, check MusicOptions bit3...
13140 LDRB    R14,[R12,#soundflags]   ;v1.49, check soundflags bit6...
13150 TST     R14,#%1<<6              ;
13160 BLEQ    resetsound              ;...if clear, ensure sound is returned to RO
13170 LDMFD   R13!,{R0-R3,PC}
13180 :
13190 .swi_qtmpause_noclear           ;may still arrive here with IRQs off...
13200 ]:IF NOT qtmrast% THEN
13210 [OPT opt%
13220 MOV     R0,#&1C                 ;not required for QTM RasterMan edition
13230 FNlong_adr("  ",1,CIAhandler)
13240 MOV     R2,R12
13250 SWI     "XOS_Release"
13260 BVS     pause_err
13270 ]
13280 ENDIF
13290 [OPT opt%
13300 :
13310 BIC     R3,R3,#%1<<2
13320 STRB    R3,[R12,#songstatus]    ;stopped the song, so set correct status
13330 :
13340 SWI     "XOS_ReadMonotonicTime"
13350 STR     R0,[R12,#pause_time]
13360 LDR     R1,[R12,#start_time]
13370 SUB     R0,R0,R1
13380 LDR     R14,[R12,#total_time]
13390 ADD     R14,R14,R0              ;v1.45 fix - total time was not accumulated
13400 STR     R14,[R12,#total_time]   ;            on repeated QTM_Pause/Stop's
13410 :
13420 BL      backupinfos
13430 BL      clearinfos
13440 :
13450 ; LDRB    R0,[R12,#chans_use]     ;needed by 'waitchans' below (not at moment!)
13460 LDRB    R14,[R12,#oldchansused]
13470 STRB    R14,[R12,#chans_use]    ;if 4 chan default, but playing 8, go back to 4
13480 :
13490 :                               ;* v1.43 - if called with IRQs off we exit now
13500 TEQ     PC,PC                   ;* Test 32bit
13510 MOVNE   R2,PC                   ;* 26bit PSR into R2
13520 MOVNE   R2,R2,LSR#20            ;* shift so IRQ bit same position as 32bit PSR
13530 FNmrs("EQ","R2,CPSR")           ;* 32bit PSR into R2
13540 TST     R2,#%1<<7               ;* IRQs off?
13550 LDMNEFD R13!,{R0-R3,PC}         ;* if IRQs off, we can't release sound, so exit
13560 :
13570 BL      waitchans               ;wait for chanels to clear
13580  ;LDRB    R14,[R12,#musicoptbyte]
13590  ;TST     R14,#%1<<3              ;v1.46, check MusicOptions bit3...
13600 LDRB    R14,[R12,#soundflags]   ;v1.49, check soundflags bit6...
13610 TST     R14,#%1<<6              ;
13620 BLEQ    resetsound              ;...if clear, ensure sound is returned to RO
13630 :
13640 CMP     R0,R0                   ;<< v1.42 fix - was using LDM {...PC}^
13650 LDMFD   R13!,{R0-R3,PC}         ;<<
13660 .pause_err
13670 STRVS   R0,[R13,#0]
13680 LDMFD   R13!,{R0-R3,PC}
13690 
13700 
13710 .waitchans   ;(in future... R0=number of song channels in use? useful?)
13720 ;            ;previous versions just blanked the current DMA buffer...
13730 ;            ;* v1.43 ...this was ok on older systems, but not Pi
13740 ;
13750 ;STMFD   R13!,{R14}
13760 ;MOV     R14,#0
13770 ;STR     R14,[R12,#chanendflags] ;start channels clearing
13780 ;LDMFD   R13!,{PC}
13790 ;
13800 STMFD   R13!,{R0-R2,R14}
13810 MOV     R0,#&0                  ;we want chans to clear
13820 STR     R0,[R12,#chanendflags]  ;initialise channel clearing
13830 ;
13840 ]:IF NOT qtmrast% THEN
13850 [OPT opt%                       ;skip this if QTM RasterMan edition because...
13860 SWI     "XOS_ReadMonotonicTime" ;can't call this if IRQ off!
13870 ADD     R2,R0,#3                ;1/33rd of a sec delay
13880 .wchan_loop
13890 SWI     "XOS_ReadMonotonicTime"
13900 CMP     R0,R2
13910 BLT     wchan_loop
13920 ]
13930 ENDIF
13940 [OPT opt%
13950 LDMFD   R13!,{R0-R2,PC}
13960 
13970 
13980 .swi_qtmstop
13990 STMFD   R13!,{R1,R14}
14000 BL      swi_qtmpause
14010 BLVC    clearsongvars
14020 MOVVC   R1,#0
14030 STRVCB  R1,[R12,#oldinfoinuse]  ;qtmoldinfo backup DMA block no longer valid
14040 LDMFD R13!,{R1,PC}
14050 
14060 
14070 .swi_qtmstart
14080 STMFD   R13!,{R14}
14090 BL      ensuresong
14100 LDMVSFD R13!,{PC}
14110 :
14120 STMFD   R13!,{R0-R3}
14130 LDRB    R3,[R12,#songstatus]
14140 TST     R3,#%1<<2               ;are we playing?
14150 LDMNEFD R13!,{R0-R3,PC}
14160 :
14170 BL      restoreinfos
14180 :
14190 LDRB    R1,[R12,#chans_use]
14200 STRB    R1,[R12,#oldchansused]  ;old channels used
14210 LDRB    R1,[R12,#songchans]
14220 TEQ     R1,#6
14230 MOVEQ   R1,#8                   ;v1.45 if 6 channels, need to enable 8
14240 TEQ     R1,#8
14250 STREQB  R1,[R12,#chans_use]     ;if switching to 8 channel song, turn on extra channels!
14260 BL      initQTMsound
14270 BVS     err_qtmstart
14280 ]:IF NOT qtmrast% THEN
14290 [OPT opt%
14300 MOV     R0,#&1C                 ;not required for QTM RasterMan edition
14310 FNlong_adr("  ",1,CIAhandler)
14320 MOV     R2,R12
14330 SWI     "XOS_Claim"
14340 BVS     err_qtmstart
14350 ]
14360 ENDIF
14370 [OPT opt%
14380 :
14390 SWI     "XOS_ReadMonotonicTime"
14400 STR     R0,[R12,#start_time]
14410 ORR     R3,R3,#%1<<2
14420 STRB    R3,[R12,#songstatus]    ;playing the song, so set correct status
14430 LDMFD   R13!,{R0-R3,PC}
14440 .err_qtmstart
14450 STR     R0,[R13,#0]
14460 LDMFD   R13!,{R0-R3,PC}
14470 
14480 
14490 .backupinfos                    ;updated to v1.30a code 16/4/2001
14500 STMFD   R13!,{R0-R10,R14}       ;nb. used to not store if channel state flag off
14510 ;ADR     R0,qtmoldinfo+4         ;...now does store, but won't restore if channel state off
14520 ADD     R0,R12,#(qtmoldinfo_new-song_data)
14530 MOV     R1,#24*8                ;much improve/fix - now doesn't store if non-music samp playing!
14540 BL      blankmemory
14550 :
14560 STRB    R1,[R12,#oldinfoinuse]  ;R1<>0 (actually =196) flag that backup *is* valid
14570 LDRB    R8,[R12,#songchans]
14580 ADD     R1,R12,#(DMA_blocks-song_data)
14590 .backupachannel
14600 LDMIA   R1!,{R2,R3,R4,R5,R6,R7}
14610 TST     R5,#&FF00
14620 STMEQIA R0!,{R2,R3,R4,R5,R6,R7} ;ON LY music channels!
14630 ADDNE   R0,R0,#24
14640 SUBS    R8,R8,#1
14650 BNE     backupachannel
14660 LDMFD   R13!,{R0-R10,PC}
14670 
14680 
14690 .clearinfos             ;clear 8 channels DMA data
14700 STMFD   R13!,{R0-R5,R11,R14}
14710 ADD     R11,R12,#(DMA_blocks-song_data)
14720 MOV     R0,#0           ;4
14730 MOV     R1,#0           ;8
14740 MOV     R2,#0           ;12
14750 MOV     R3,#0           ;16
14760 MOV     R4,#0           ;20
14770 MOV     R5,#0           ;24 bytes
14780 STMIA   R11!,{R0-R5}
14790 STMIA   R11!,{R0-R5}
14800 STMIA   R11!,{R0-R5}
14810 STMIA   R11!,{R0-R5}
14820 STMIA   R11!,{R0-R5}
14830 STMIA   R11!,{R0-R5}
14840 STMIA   R11!,{R0-R5}
14850 STMIA   R11!,{R0-R5}
14860 LDMFD   R13!,{R0-R5,R11,PC}
14870 
14880 
14890 
14900 .restoreinfos
14910 STMFD   R13!,{R0-R10,R14}
14920 ;ADR     R0,qtmoldinfo+4
14930 ADD     R0,R12,#(qtmoldinfo_new-song_data)  ;v1.48 move qtmoldinfo to databanks
14940 :
14950 LDRB    R1,[R12,#oldinfoinuse]  ;v1.48...this will be <>0 (actually 196) if old info block valid
14960 TEQ     R1,#0
14970 LDMEQFD R13!,{R0-R10,PC}        ;backup not in use
14980 :
14990 MOV     R1,#0
15000 STRB    R1,[R12,#oldinfoinuse]  ;clear valid flag (v1.48)
15010 :
15020 LDR     R9,[R12,#channelstate]
15030 MOV     R9,R9,LSR#1
15040 LDRB    R8,[R12,#songchans]
15050 ADD     R1,R12,#(DMA_blocks-song_data)
15060 .restoreachannel
15070 MOVS    R9,R9,LSR#1
15080 LDMCSIA R0!,{R2,R3,R4,R5,R6,R7}
15090 STMCSIA R1!,{R2,R3,R4,R5,R6,R7} ;only music channels
15100 ADDCC   R0,R0,#24
15110 ADDCC   R1,R1,#24
15120 SUBS    R8,R8,#1
15130 BNE     restoreachannel
15140 LDMFD   R13!,{R0-R10,PC}
15150 
15160 
15170 ;.qtmoldinfo
15180 ;EQUD 0       ;in use flag
15190 ;EQUD 0;EQUD 0;EQUD 0;EQUD 0;EQUD 0;EQUD 0 ; \
15200 ;EQUD 0;EQUD 0;EQUD 0;EQUD 0;EQUD 0;EQUD 0 ;  }_ Backup space for DMA
15210 ;EQUD 0;EQUD 0;EQUD 0;EQUD 0;EQUD 0;EQUD 0 ;  }  block (chans 1-4)
15220 ;EQUD 0;EQUD 0;EQUD 0;EQUD 0;EQUD 0;EQUD 0 ; /
15230 ;EQUD 0;EQUD 0;EQUD 0;EQUD 0;EQUD 0;EQUD 0 ; \
15240 ;EQUD 0;EQUD 0;EQUD 0;EQUD 0;EQUD 0;EQUD 0 ;  }_ Backup space for DMA
15250 ;EQUD 0;EQUD 0;EQUD 0;EQUD 0;EQUD 0;EQUD 0 ;  }  block (chans 5-8)
15260 ;EQUD 0;EQUD 0;EQUD 0;EQUD 0;EQUD 0;EQUD 0 ; /
15270 
15280 
15290 .swi_qtmsongstatus
15300 LDRB    R0,[R12,#songstatus]
15310 MOV     PC,R14
15320 
15330 
15340 ]:IF alphatest% THEN
15350  [OPT opt%
15360  .swi_qtmdebug                  ;alpha test debug SWI
15370  STMFD R13!,{R3-R7,R14}
15380  FNlong_adr("",0,a2_jumptable)
15390  FNlong_adr("",1,unroll_a2_DMA)
15400  MOV   R2,R12
15410  LDMFD R13!,{R3-R7,PC}
15420  ]
15430  ENDIF
15440 [OPT opt%
15450 
15460                                 ;new in v1.49
15470 .swi_qtmdmahandler              ;returns R2 bit0=1 if RasterMan edition, bit1=1 if 4 chan only
15480 MOV      R2,#(qtmrast% AND %01) OR ((maxchans=4) AND %10)
15490 ;MVN R2,#0 ;for RMv0.29
15500 MOV      R1,R12                 ;        R0=DMA handler addr, R1=R12 ptr
15510 LDR      R0,[R12,#QTMblock]     ;RM uses SWI QTM_DMABuffer *twice* to get the two sound DMA addrs
15520 MOV      PC,R14                 ;...see DMA routine
15530 
15540 
15550 .swi_qtminfo
15560 STMFD   R13!,{R14}
15570 BL      ensuresong
15580 LDMVSFD R13!,{PC}
15590 :
15600 ;FNlong_adr("  ",11,textdata)
15610 ADD     R0,R12,#(songtitle_new-song_data)
15620 LDRB    R1,[R12,#(author_new-song_data)]
15630 CMP     R1,#0
15640 ADDNE   R1,R0,#(author_new-songtitle_new) ;v1.48 use offset from songtitle
15650 LDRB    R2,[R12,#songtype]
15660 LDRB    R3,[R12,#songchans]
15670 LDR     R4,[R12,#songlength]
15680 LDR     R5,[R12,#garbagedata]
15690 LDR     R6,[R12,#songaddr]
15700 LDMFD   R13!,{PC}
15710 
15720 
15730 .swi_qtmpos
15740 STMFD   R13!,{R2-R3,R14}
15750 BL      ensuresong
15760 LDMVSFD R13!,{R2-R3,PC}
15770 :
15780 LDRB    R2,[R12,#lastsequence]
15790 LDRB    R3,[R12,#lastevent]
15800 CMN     R0,#1
15810 BLNE    setsequence
15820 BVS     err_setpos
15830 CMN     R1,#1
15840 BLNE    setevent
15850 MOVVC   R0,R2
15860 MOVVC   R1,R3
15870 .err_setpos
15880 LDMFD   R13!,{R2-R3,PC}
15890 
15900 
15910 .setsequence
15920 STMFD   R13!,{R1,R14}
15930 LDRB    R1,[R12,#maxsequence]
15940 CMP     R0,R1
15950 BGE     err_setsequence
15960 :
15970 STRB    R0,[R12,#currentseq]
15980 STRB    R0,[R12,#lastsequence]
15990 MOV     R1,#0
16000 STRB    R1,[R12,#oldinfoinuse]  ;qtmoldinfo backup DMA block no longer valid
16010 MOV     R1,#&FF                 ;R1=&FF to only clear music DMA data, change 29/7/96
16020 BL      clearDMAchans
16030 MOV     R1,#&0                  ;we want *MUSIC* chans to clear
16040 STR     R1,[R12,#chanendflags]
16050 CMP     R0,R0 ; Clear V
16060 LDMFD   R13!,{R1,PC}
16070 .err_setsequence
16080 MOV     R0,#&80000000
16090 SUBS    R0,R0,#1 ; Set V
16100 ADR     R0,seq_range
16110 LDMFD   R13!,{R1,PC}
16120 
16130 
16140 .setevent
16150 STMFD   R13!,{R0,R14}
16160 CMP     R1,#63
16170 BGT     err_setevent
16180 CMP     R0,R0 ; Clear V
16190 STRB    R1,[R12,#currentevent]
16200 STRB    R1,[R12,#lastevent]
16210 LDMFD   R13!,{R0,PC}
16220 .err_setevent
16230 MOV     R0,#&80000000
16240 SUBS    R0,R0,#1 ; Set V
16250 LDMFD   R13!,{R0,R14}
16260 ADR     R0,evt_range ; I fixed a bug! woo!
16270 MOV     PC,R14
16280 
16290 .seq_range
16300 EQUD    qtm_error+&02
16310 EQUS    "Sequence number out of range"
16320 EQUB    0
16330 ALIGN
16340 .evt_range
16350 EQUD    qtm_error+&03
16360 EQUS    "Event number out of range"
16370 EQUB    0
16380 ALIGN
16390 
16400 
16410 .swi_qtmvolume                ;updated for v1.48 28/1/23
16420 STMFD   R13!,{R1-R6,R14}
16430 LDRB    R5,[R12,#musicvolume]
16440 CMN     R0,#1
16450 MOVEQ   R0,R5                 ;SWI QTM_Volume now returns music volume
16460 LDMEQFD R13!,{R1-R6,PC}
16470 :
16480 MOV     R6,#%11               ;r6 -> bit0=set music volume, bit1=set sample volume
16490 .multivolumes                 ;r0=volume to set, r5=volume to return, r6=tables to set
16500 BL      checkvolrange
16510 LDMVSFD R13!,{R1-R6,PC}
16520 :
16530 TST     R6,#%01
16540 STRNEB  R0,[R12,#musicvolume]
16550 TST     R6,#%10
16560 STRNEB  R0,[R12,#samplevolume]
16570 :
16580 MOV     R0,R0,LSL#16
16590 MOV     R1,#64
16600 BL      r0_div_r1                               ;exit r0=scaler r1=64
16610 :
16620 ADD     R2,R12,#(volumetable-song_data)
16630 ADD     R3,R2,#(musicvoltable-volumetable)
16640 ADD     R4,R2,#(samplevoltable-volumetable)
16650 .scalebothvols
16660 MUL     R14,R1,R0
16670 MOV     R14,R14,LSR#16
16680 LDRB    R14,[R2,R14]
16690 TST     R6,#%01
16700 STRNEB  R14,[R3,R1]
16710 TST     R6,#%10
16720 STRNEB  R14,[R4,R1]
16730 SUBS    R1,R1,#1
16740 BGE     scalebothvols
16750 :
16760 CMP     R0,R0 ; Clear V
16770 MOV     R0,R5
16780 LDMFD   R13!,{R1-R6,PC}
16790 
16800 
16810 .swi_qtmmusicvolume             ;updated v1.48
16820 STMFD   R13!,{R1-R6,R14}
16830 LDRB    R5,[R12,#musicvolume]
16840 CMN     R0,#1
16850 MOVEQ   R0,R5
16860 LDMEQFD R13!,{R1-R6,PC}
16870 :
16880 MOV     R6,#%01                 ;only setting music volume, bit0=music vol, bit1=sample vol
16890 B       multivolumes            ;jump to multi-function scaling routine
16900 
16910 
16920 .swi_qtmsamplevolume            ;updated v1.48
16930 STMFD   R13!,{R1-R6,R14}
16940 LDRB    R5,[R12,#samplevolume]
16950 CMN     R0,#1
16960 MOVEQ   R0,R5
16970 LDMEQFD R13!,{R1-R6,PC}
16980 :
16990 MOV     R6,#%10                 ;only setting music volume, bit0=music vol, bit1=sample vol
17000 B       multivolumes            ;jump to multi-function scaling routine
17010 
17020 
17030 .swi_qtmeffectctrl              ;r0=effect number (0-F,E0-EF,-1), r1=effect state (1/0)
17040 STMFD   R13!,{R2-R5,R14}        ;returns r0=old 0-F word, r1=old E0-EF word
17050 CMN     R0,#1
17060 LDREQ   R0,[R12,#FXflags]
17070 LDREQ   R1,[R12,#E_FXflags]
17080 LDMEQFD R13!,{R2-R5,PC}
17090 :
17100 BICS    R2,R0,#&0F
17110 CMPNE   R2,#&E0
17120 BNE     err_swi_qtmeffectctrl
17130 :
17140 LDR     R3,[R12,#FXflags]
17150 LDR     R4,[R12,#E_FXflags]
17160 CMP     R2,#&E0
17170 MOVEQ   R5,R4
17180 MOVNE   R5,R3
17190 :
17200 AND     R0,R0,#&0F
17210 CMP     R1,#0
17220 MOV     R1,#1
17230 MOV     R1,R1,LSLR0
17240 ORRNE   R5,R5,R1
17250 BICEQ   R5,R5,R1
17260 :
17270 CMP     R2,#&E0
17280 STREQ   R5,[R12,#E_FXflags]
17290 STRNE   R5,[R12,#FXflags]
17300 :
17310 MOV     R0,R3
17320 MOV     R1,R4
17330 CMP     R0,R0 ; Clear V
17340 LDMFD   R13!,{R2-R5,PC}
17350 .err_swi_qtmeffectctrl
17360 ADR     R0,effect_error
17370 MOV     R2,#&80000000
17380 SUBS    R2,R2,#1 ; Set V
17390 LDMFD   R13!,{R2-R5,PC}
17400 
17410 .effect_error
17420 EQUD    qtm_error+&04
17430 EQUS    "Effect number out of range"
17440 EQUB    0
17450 ALIGN
17460 
17470 
17480 .swi_qtmsonglength
17490 STMFD   R13!,{R14}
17500 BL      ensuresong
17510 :
17520 LDRVCB  R0,[R12,#maxsequence]
17530 LDRVCB  R1,[R12,#maxpattern]
17540 LDMFD   R13!,{PC}
17550 
17560 
17570 .swi_qtmreadsequence            ;recoded 19/2/95
17580 STMFD   R13!,{R14}
17590 BL      ensuresong
17600 LDMVSFD R13!,{PC}
17610 :
17620 CMP     R0,#0                   ;check if sequence is too low? (=LT)
17630 LDRGEB  R14,[R12,#maxsequence]  ; - no, so load max sequence
17640 SUBGES  R14,R14,R0              ;   and check it's not too high (=LE)
17650 BLE     err_swi_qtmreadsequence ; - if so, return with error
17660 :
17670 LDR     R14,[R12,#songaddr]
17680 ADD     R14,R14,#952
17690 LDRB    R0,[R14,R0]
17700 LDMFD   R13!,{PC}               ; - else read pattern
17710 .err_swi_qtmreadsequence
17720 FNlong_adr("  ",0,seq_range)
17730 MOV     R14,#&80000000
17740 SUBS    R14,R14,#1 ; Set V
17750 LDMFD   R13!,{PC}
17760 
17770 
17780 .swi_qtmreadspeed               ;updated 19/2/95 to return R0=0
17790 STMFD   R13!,{R14}
17800 BL      ensuresong
17810 LDMVSFD R13!,{PC}
17820 :
17830 LDRB    R0,[R12,#songstatus]
17840 TST     R0,#%1<<2               ;are we playing?
17850 LDRNEB  R0,[R12,#speed]         ; yes, so load current speed
17860 MOVEQ   R0,#0                   ; no, so return speed=0
17870 LDRB    R1,[R12,#CIAtempo]
17880 LDRB    R2,[R12,#counter]
17890 CMP     R0,R0 ; Clear V
17900 LDMFD   R13!,{PC}
17910 
17920 
17930 .swi_qtmreadsample                      ;re-coded 19/2/95
17940 STMFD   R13!,{R14}
17950 BL      ensuresong
17960 BLVC    checksample
17970 LDMVSFD R13!,{PC}
17980 :
17990 SUB     R0,R0,#1
18000 ADD     R14,R12,#(sampletable-song_data)
18010 ADD     R14,R14,R0,LSL#4
18020 ADD     R14,R14,R0,LSL#2                ;(sample-1)*20
18030 LDR     R1,[R14,#4]                     ;sample length
18040 LDR     R2,[R14,#8]                     ;repeat offset
18050 LDR     R3,[R14,#12]                    ;repeat length
18060 LDRB    R4,[R14,#19]                    ;volume byte
18070 LDRB    R5,[R14,#16]                    ;finetune byte (4 bits, signed)
18080 TST     R5,#1<<3                        ; \_ convert to 32bit
18090 SUBNE   R5,R5,#16                       ; /  signed number!
18100 LDR     R6,[R14,#0]                     ;address of sample
18110 LDR     R14,[R12,#songaddr]             ; \
18120 ADD     R14,R14,#20                     ;  \_ sample name ptr
18130 ADD     R14,R14,R0,LSL#5                ;  /
18140 SUB     R0,R14,R0,LSL#1                 ; /
18150 CMP     R0,R0 ; Clear V
18160 LDMFD   R13!,{PC}
18170 
18180 
18190 .swi_qtmstereo                  ;fixed 20/5/95 - stop OS being set if QTM off
18200 STMFD   R13!,{R0,R2-R3,R14}
18210 ADD     R2,R12,#QTMstereos
18220 CMP     R0,#0
18230 BEQ     doallstereo
18240 BL      checkchannel            ;make sure correct channel range
18250 STRVS   R0,[R13]                ;stack the error pointer
18260 LDMVSFD R13!,{R0,R2-R3,PC}
18270 :
18280 LDRB    R3,[R2,R0]
18290 CMP     R1,#127
18300 BGT     stereotoolarge          ;do this, 'cos the OS does, in SWI Sound_Stereo...
18310 CMN     R1,#128
18320 STRGTB  R1,[R2,R0]
18330 LDRGTB  R0,[R12,#soundflags]
18340 TSTGT   R0,#%1
18350 BLGT    setstereos              ;**ONLY** set stereos, if QTM is on!!!
18360 :
18370 .stereotoolarge
18380 MOV     R1,R3,LSL #24 ; Sign extend
18390 MOV     R1,R1,ASR #24
18400 CMP     R0,R0 ; Clear V
18410 LDMFD   R13!,{R0,R2-R3,PC}
18420 
18430 .doallstereo
18440 CMP     R1,#5                   ;v1.49 now 0-5 with new wide-stereo default and 5=medium stereo
18450 MOVHI   R1,#0                   ;if incorrect value, use default setting
18460 :
18470 ADR     R3,stereotable
18480 ADD     R3,R3,R1,LSL#3
18490 MOV     R0,#1
18500 .newstereoloop
18510 LDRB    R1,[R3],#1
18520 STRB    R1,[R2,R0]
18530 ADD     R0,R0,#1
18540 CMP     R0,#8
18550 BLE     newstereoloop
18560 :
18570 LDRB    R0,[R12,#soundflags]
18580 TST     R0,#%1
18590 BLNE    setstereos              ;**ON LY** set stereos, if QTM is on!!!
18600 MOV     R1,#0
18610 CMP     R0,R0 ; Clear V
18620 LDMFD   R13!,{R0,R2-R3,PC}
18630 
18640 .stereotable
18650 DCB -127:DCB  127:DCB   79:DCB  -79:DCB -127:DCB  127:DCB   79:DCB  -79 ;default (wide)
18660 DCB -127:DCB  127:DCB  127:DCB -127:DCB -127:DCB  127:DCB  127:DCB -127 ;amiga (full)
18670 DCB    0:DCB    0:DCB    0:DCB    0:DCB    0:DCB    0:DCB    0:DCB    0 ;centred
18680 DCB -127:DCB -127:DCB -127:DCB -127:DCB -127:DCB -127:DCB -127:DCB -127 ;full left
18690 DCB  127:DCB  127:DCB  127:DCB  127:DCB  127:DCB  127:DCB  127:DCB  127 ;full right
18691 DCB  -79:DCB   79:DCB   47:DCB  -47:DCB  -79:DCB   79:DCB   47:DCB  -47 ;medium stereo
18700 
18710 .swi_qtmremovechan              ;*** requires SVC mode
18720 STMFD   R13!,{R1-R9,R11,R14}
18730 BL      checkchannel
18740 LDMVSFD R13!,{R1-R9,R11,PC}
18750 :
18760 TEQ     PC,PC
18770 FNmrs("EQ","R9,CPSR")
18780 MOVNE   R9,PC
18790 ORREQ   R8,R9,#(%1<<7) ; Disable interrupts to stop DMA messing up
18800 ORRNE   R8,R9,#(%1<<27)
18810 FNmsr("EQ","CPSR_c,R8")
18820 TEQNEP  R8,#0
18830 MOV     R0,R0
18840 :
18850 LDR     R1,[R12,#chanendflags]
18860 MOV     R2,#3
18870 SUB     R3,R0,#1
18880 MOV     R3,R3,LSL#1
18890 BIC     R1,R1,R2,LSLR3          ;this channel needs clearing
18900 STR     R1,[R12,#chanendflags]
18910 :
18920 ADD     R10,R12,#(DMA_blocks-song_data)
18930 SUB     R1,R0,#1
18940 ADD     R10,R10,R1,LSL#4
18950 ADD     R10,R10,R1,LSL#3
18960 MOV     R1,#0
18970 MOV     R2,#0
18980 MOV     R3,#0
18990 MOV     R4,#0
19000 MOV     R5,#0
19010 MOV     R6,#0
19020 STMIA   R10!,{R1-R6}            ;24 bytes of DMA address cleared
19030 :
19040 LDR     R1,[R12,#channelstate]
19050 MOV     R2,#1
19060 TST     R1,R2,LSLR0
19070 BICNE   R1,R1,R2,LSLR0
19080 MOVNE   R0,#1
19090 MOVEQ   R0,#0
19100 STR     R1,[R12,#channelstate]
19110 :
19120 TEQ     PC,PC
19130 FNmsr("EQ","CPSR_c,R9")
19140 TEQNEP  R9,#0
19150 MOV     R0,R0
19160 CMP     R0,R0 ; Clear V
19170 LDMFD   R13!,{R1-R9,R11,PC}
19180 
19190 
19200 .swi_qtmrestorechan
19210 STMFD   R13!,{R1-R2,R14}
19220 BL      checkchannel
19230 LDMVSFD R13!,{R1-R2,PC}
19240 :
19250 LDR     R1,[R12,#channelstate]
19260 MOV     R2,#1
19270 TST     R1,R2,LSLR0
19280 ORREQ   R1,R1,R2,LSLR0
19290 MOVEQ   R0,#0
19300 MOVNE   R0,#1
19310 STR     R1,[R12,#channelstate]
19320 CMP     R0,R0 ; Clear V
19330 LDMFD   R13!,{R1-R2,PC}
19340 
19350 
19360 .swi_qtmsetsamplespeed
19370 CMN     R0,#1
19380 LDREQB  R0,[R12,#current_uS]
19390 MOVEQ   PC,R14
19400 :
19410 CMP     R0,#16
19420 BLT     err_swi_qtmsetsamplespeed
19430 CMP     R0,#100
19440 BGE     err_swi_qtmsetsamplespeed
19450 ]:IF qtmrast% THEN [OPT opt%:LDRB R0,[R12,#current_uS]:MOV PC,R14:]:REM v1.43 RasterMan edn don't
19460 [OPT opt%                                                          ;    change sample speed! 50Hz
19470 :
19480 STMFD   R13!,{R1-R4,R14}
19490 LDRB    R2,[R12,#soundflags]
19500 TST     R2,#1<<3                ;are we in the middle of recalcing the clock speed?
19510 MOVNE   R3,#0
19520 STRNE   R3,[R12,#ClockCalcEnd]  ;if so, clear the counters (else the routine would get very
19530 STRNE   R3,[R12,#DMAinterrupts] ; confused if the interrupt speed changed half way!)
19540 :
19550 TST     R0,#%11                 ;any bad bits set? added 17/4/2001
19560 BIC     R0,R0,#%11              ;clear bad bits
19570 ADDNE   R0,R0,#4                ;if any bad bits set, correct to an ok sample speed
19580 :
19590 LDRB    R4,[R12,#current_uS]
19600 STRB    R0,[R12,#current_uS]
19610 BL      setsoundconfig          ;wil fix sample speed for these channels! (R0-R3 corrupted)
19620 LDRB    R0,[R12,#soundflags]
19630 TST     R0,#1<<7
19640 ADR     R14,end_setsmpspd
19650 BEQ     recalc_uS_4clock        ;(** 'setsoundconfig' only affects sample speed if QTM on!)
19660 B       recalc_uS_4clock_16bit  ;(16bit version)
19670 :
19680 .end_setsmpspd
19690 MOV     R0,R4
19700 CMP     R0,R0 ; Clear V
19710 LDMFD   R13!,{R1-R4,PC}
19720 .err_swi_qtmsetsamplespeed
19730 MOV     R0,#&80000000
19740 SUBS    R0,R0,#1 ; Set V
19750 ADR     R0,err_samplespeed
19760 MOV     PC,R14
19770 
19780 
19790 .err_samplespeed
19800 EQUD    qtm_error+&08
19810 EQUS    "Sample speed out of range"
19820 EQUB    0
19830 ALIGN
19840 
19850 
19860 .ok2clearsmp
19870 BL      checkchannel
19880 STRVS   R0,[R13,#0]
19890 LDMFD   R13!,{R0,R14}
19900 MOVVS   PC,R14
19910 :
19920 STMFD   R13!,{R0-R7}
19930 SUB     R7,R0,#1                        ;channel-1
19940 ADD     R10,R12,#(DMA_blocks-song_data)
19950 ADD     R10,R10,R7,LSL#4
19960 ADD     R10,R10,R7,LSL#3
19970 MOV     R0,#0                   ;0
19980 MOV     R1,#0                   ;4
19990 MOV     R2,#0                   ;8
20000 MOV     R3,#0                   ;12
20010 MOV     R4,#0                   ;16
20020 MOV     R5,#0                   ;20
20030 STMIA   R10,{R0-R5}             ;blank DMA channel
20040 :
20050 LDMFD   R13!,{R0-R7}
20060 MOV     PC,R14
20070 
20080 
20090 .findachannel                   ;new FOR QTMv1.28!
20100 ;
20110 ; updated behaviour v1.44
20120 ; is any channel is currently playing an effect
20130 ; if so, the highest channel playing an effect is our backup channel, otherwise the highest channel is backup
20140 ; check if any available channels, including 0-volume channels
20150 ;
20160 STMFD   R13!,{R1-R8,R14}
20170 LDRB    R1,[R12,#songstatus] ; new v1.44
20180 TST     R1,#%1<<2     ; are we playing?
20190 BEQ     lookup_nosongplaying
20200 :
20210 LDR     R3,[R12,#chanendflags]
20220 MOV     R4,#%11
20230 LDRB    R6,[R12,#songchans]
20240 ADD     R8,R12,#(channeldata-song_data)-64      ;r8=addr of channel blocks
20250 ADD     R8,R8,R6,LSL#6                          ;pointer TO channel 3 or 7's block
20260 .findblanksongchannel
20270 LDRB    R1,[R8,#samplenumber]  ;sample number
20280 CMP     R1,#0
20290 BEQ     foundachannel          ;we are playing and we have a completely empty song channel, lets use this...
20300 SUB     R5,R6,#1
20310 MOV     R5,R5,LSL#1
20320 TST     R3,R4,LSLR5
20330 BNE     foundachannel          ;was playing but now over, lets use this...
20340 LDRB    R1,[R8,#currentvol]
20350 CMP     R1,#1
20360 BLT     foundachannel          ;no volume, lets use this...
20370 SUB     R8,R8,#64
20380 SUBS    R6,R6,#1
20390 BGT     findblanksongchannel
20400 :
20410 .lookup_nosongplaying ; ...or no spare song channels!
20420 LDRB    R6,[R12,#chans_use]
20430 SUB     R7,R6,#1
20440 ADD     R8,R12,#(DMA_blocks-song_data)
20450 ADD     R8,R8,R7,LSL#3
20460 ADD     R8,R8,R7,LSL#4          ;max chans*24 (last channel tested first - best for 8 chan)
20470 :
20480 MOV     R7,#0         ; new v1.44, backup channel (0 at mo)
20490 .lookchanloop
20500 LDMIA   R8,{R0-R5}              ;r0=end addr, r1=-ve offset, r2=pitch, r3=vol/flag, r4=rlen
20510 :
20520 AND     R14,R3,#&FF00 ; new v1.44
20530 CMP     R14,#&FF00    ; is this an effect?
20540 CMPEQ   R7,#0         ; have we chosen a backup channel?
20550 MOVEQ   R7,R6         ; no, so put highest effect playing channel in there
20560 :
20570 CMN     R1,#8<<12               ;v1.44 inc to 8 bytes, is offset >-(1<<12)? (ie. offset>>12 <1)?   (remember -ve!)
20580 MOVGT   R14,#3                  ; <put min loop len in r14>
20590 CMPGT   R14,R5                  ; <backwards!!! this does CMP 3,len so LE if valid!!!)
20600 BGT     foundachannel           ;if offset>-4096 and 3>repeat len, then exit
20610 :
20620 CMP     R2,#0
20630 BLE     foundachannel           ;no pitch
20640 :
20650 ANDS    R3,R3,#0
20660 BEQ     foundachannel           ;no volume, added v1.44
20670 :
20680 SUB     R8,R8,#24
20690 SUBS    R6,R6,#1
20700 BNE     lookchanloop            ;check next channel
20710 :
20720 CMP     R7,#0               ; is our backup channel 0 = not found one?
20730 LDREQB  R6,[R12,#chans_use] ; if so, use highest channel number
20740 :
20750 ;MVN     R6,#0 ; don't exit with -1 any more
20760 .foundachannel
20770 MOV     R0,R6
20780 LDMFD   R13!,{R1-R8,PC}
20790 
20800 
20810 .swi_qtmplaysample              ;r0=chan 1-8, r1=smp 1-64, r2=note (1-36,37-1999), r3=vol
20820 STMFD   R13!,{R14}              ;v1.44                          or (1-72+bit28 set)
20830 CMN     R0,#1
20840 BLEQ    findachannel
20850 CMN     R0,#1
20860 LDMEQFD R13!,{PC}
20870 :
20880 STMFD   R13!,{R0}
20890 CMP     R1,#0
20900 BEQ     ok2clearsmp             ;if sample=0 then clear the channel...
20910 :
20920 BL      checkchannel
20930 MOVVC   R0,R1
20940 BLVC    checksample
20950 MOVVC   R0,R3
20960 BLVC    checkvolrange
20970 STRVS   R0,[R13,#0]
20980 LDMFD   R13!,{R0,R14}
20990 MOVVS   PC,R14
21000 :
21010 STMFD   R13!,{R0-R9,R11,R14}
21020 LDRB    R11,[R12,#chans_use]
21030 CMP     R0,R11
21040 LDMGTFD R13!,{R0-R9,R11,PC}     ;exit with NO error, if channel 1-8 BUT only 4 chans on!!!
21050 :
21060 MOV     R0,R2
21070 BL      checknote               ;updated 1.44
21080 MOVVC   R2,R0                   ;returns R0=period 37-1999 or note 1-72 in bits 24-31
21090 STRVS   R0,[R13,#0]
21100 LDMVSFD R13!,{R0-R9,R11,PC}
21110 LDR     R0,[R13,#0]
21120 :
21130 BL      initQTMsound            ;will return if already on
21140 :
21150 SUB     R11,R0,#1                       ;channel-1
21160 ADD     R10,R12,#(DMA_blocks-song_data)
21170 ADD     R10,R10,R11,LSL#4
21180 ADD     R10,R10,R11,LSL#3
21190 :
21200 MOV     R11,R2                          ;pitch into r11
21210 ORR     R3,R3,#&FF00                    ;*** Set sample/sound effects flag in DMA block ***
21220 STR     R3,[R10,#DMA_volume]
21230 SUB     R9,R1,#1                        ;sample-1
21240 ADD     R7,R12,#(sampletable-song_data) ;get addr of sample data table in r7
21250 ADD     R7,R7,R9,LSL#4                  ;add (sample-1)*16 = correct info block for sample
21260 ADD     R7,R7,R9,LSL#2                  ;(+4) ******************* -(*20)
21270 :
21280 LDMIA   R7,{R0-R4}              ;r0=addr, r1=len, r2=rep off, r3=rep len, r4=ftune/volume
21290 CMP     R3,#2
21300 ADDGT   R1,R2,R3                ;if repeat, use rlen+roff as length, so it starts correctly
21310 ADD     R0,R0,R1                ;end address
21320 MOV     R1,R1,LSL#12            ;
21330 RSB     R1,R1,#0                ;start offset -ve
21340 STMIA   R10,{R0-R1}             ;set sample addr and offset
21350 ADD     R2,R10,#DMA_repaddr
21360 STMIA   R2,{R0,R3}              ;set repeat end address (as for sample) & repeat length
21370 :
21380 CMP     R11,#2000
21390 BLT     skipftuning             ;if note was<2000 then use it as REAL amiga note
21400 :
21410 MOV     R11,R11,LSR#24          ;shuffle note number back down again
21420 SUB     R11,R11,#1              ;move range to 0-71
21430 AND     R0,R4,#&FF              ;get fine tuning byte
21440 FNlong_adr("",7,amigaperiodz)   ;get addr of amiga period tables
21450 MOV     R1,R0,LSL#4             ;fine tune *16  }_
21460 ADD     R0,R1,R0,LSL#7          ;          *128 }  *144 = offset for correct tuning DCW table
21470 ADD     R7,R7,R0                ;get to address of table (r7)
21480 MOVS    R11,R11,LSR#1           ;CS if odd numbered note
21490 LDR     R11,[R7,R11,LSL#2]      ;fine tuned note (table+note number/2*4) b0-15=even, b16-31 odd
21500 MOVCC   R11,R11,LSL#16          ;
21510 MOV     R11,R11,LSR#16          ;v1.48 half size note tables
21520 :
21530 .skipftuning
21540 STR     R11,[R10,#DMA_pitch]     ;store pitch
21550 :
21560 MOV     R1,#1
21570 LDRB    R0,[R12,#vuflags]
21580 ORR     R0,R0,R1,LSLR9
21590 STRB    R0,[R12,#vuflags]       ;new note, so set VU flag
21600 CMP     R0,R0 ; Clear V
21610 LDMFD   R13!,{R0-R9,R11,PC}
21620 
21630 
21640 .swi_qtmreadchanneldata ; r0=channel, return r1=current period, r2=lin vol, r3=note, r4=sample, r5=effect, r6=data
21650 STMFD   R13!,{R14}
21660 BL      ensuresong
21670 BLVC    checkchannel            ;checks 1-8
21680 LDMVSFD R13!,{PC}
21690 :
21700 ADD     R14,R12,#(channeldata-song_data)-64     ;r11=addr of channel blocks
21710 ADD     R14,R14,R0,LSL#6                        ;...now at this channel's 64 byte channel data block
21720 LDRB    R4,[R14,#samplenumber]  ;sample number
21730 LDR     R1,[R14,#amigaperiod]   ;load amiga period
21740 TEQ     R1,#0                   ;is it 0?
21750 MOVEQ   R3,#0
21760 LDRNEB  R3,[R14,#notenumber]    ;if not, load note number (0-71)
21770 ADDNE   R3,R3,#1                ;...and adjust range to 1-72
21780 :
21790 LDR     R2,[R12,#chanendflags]
21800 SUB     R5,R0,#1                ;R5=channel 0-7
21810 :
21820 LDRB    R6,[R12,#songchans]     ;v1.44
21830 TEQ     R6,#4                   ;if 4 channel song
21840 LDREQB  R6,[R12,#soundflags]    ;are we using channels 0-3 on 4-7?
21850 TST     R6,#%1<<5               ;(this works as long as < 32 channels...)
21860 ADDNE   R5,R5,#4                ;if so get to 4-7
21870 CMP     R5,#7                   ;but if >7 then user is checking c4-7, so return value from c0-3
21880 SUBGT   R5,R5,#8                ;meaningless anyway, as 0-3 will be no note!
21890 :
21900 MOV     R6,#%11
21910 MOV     R5,R5,LSL#1
21920 TST     R2,R6,LSLR5
21930 MOVNE   R4,#0                   ;sample
21940 MOVNE   R1,#0                   ;period
21950 MOVNE   R3,#0                   ;return note, period and sample = 0 if channel ended playing
21960 :
21970 LDRB    R2,[R14,#currentvol]
21980 LDRB    R5,[R14,#currentFXnum]
21990 LDRB    R6,[R14,#currentFXdata]
22000 LDMFD   R13!,{PC}
22010 
22020 
22030 .swi_qtmplayraw         ;r0=chan 1-8, r1=addr, r2=len, r3=roff, r4=rlen, r5=note, r6=vol
22040 STMFD   R13!,{R14}      ;v1.44                                          or (1-72+bit28 set)
22050 CMN     R0,#1
22060 BLEQ    findachannel
22070 CMN     R0,#1
22080 LDMEQFD R13!,{PC}
22090 :
22100 STMFD   R13!,{R0}
22110 CMP     R1,#0
22120 BEQ     ok2clearsmp             ;if addr=0 then clear channel
22130 :
22140 STMFD   R13!,{R0,R1}
22150 MOV     R0,R1
22160 ADD     R1,R1,R2
22170 SWI     "XOS_ValidateAddress"
22180 LDMFD   R13!,{R0,R1}
22190 BCS     err_swi_qtmplayraw
22200 :
22210 BLVC    checkchannel
22220 MOVVC   R0,R6
22230 BLVC    checkvolrange
22240 .playrawerror
22250 STRVS   R0,[R13,#0]
22260 LDMFD   R13!,{R0,R14}
22270 MOVVS   PC,R14
22280 :
22290 STMFD   R13!,{R0-R9,R11,R14}
22300 LDRB    R11,[R12,#chans_use]
22310 CMP     R0,R11
22320 LDMGTFD R13!,{R0-R9,R11,PC}    ;exit with NO error, if channel 1-8 BUT only 4 chans on!!!
22330 :
22340 MOV     R0,R5
22350 BL      checknote               ;updated 1.44
22360 MOVVC   R5,R0                   ;returns R0=period 37-1999 or note 1-72 in bits 24-31
22370 STRVS   R0,[R13,#0]
22380 LDMVSFD R13!,{R0-R9,R11,PC}
22390 LDR     R0,[R13,#0]
22400 :
22410 BL      initQTMsound            ;will return if already on
22420 :
22430 SUB     R11,R0,#1                       ;channel-1
22440 ADD     R10,R12,#(DMA_blocks-song_data)
22450 ADD     R10,R10,R11,LSL#4
22460 ADD     R10,R10,R11,LSL#3
22470 :
22480 ORR     R6,R6,#&FF00                    ;*** Set sample/sound effects flag in DMA block ***
22490 STR     R6,[R10,#DMA_volume]
22500 :
22510 CMP     R4,#2
22520 ADDGT   R2,R3,R4                ;if repeat, use rlen+roff as length, so it starts correctly
22530 ADD     R1,R1,R2                ;now at end address
22540 MOV     R2,R2,LSL#12            ;
22550 RSB     R2,R2,#0                ;offset to start -ve
22560 STMIA   R10,{R1-R2}             ;set sample addr and offset
22570 ADD     R2,R10,#DMA_repaddr
22580 STMIA   R2,{R1,R4}              ;set repeat end address (as for sample) & repeat length
22590 :
22600 CMP     R5,#2000                ;if note was<2000 then use it as REAL amiga note
22610 BLE     playrawgotnote
22620 MOV     R5,R5,LSR#24            ;shuffle note number back down again
22630 SUB     R5,R5,#1
22640 FNlong_adr("",7,amigaperiodz)   ;get addr of amiga period tables
22650 MOVS    R5,R5,LSR#1
22660 LDR     R5,[R7,R5,LSL#2]        ;load note in r5 (from table+note number*4)
22670 MOVCC   R5,R5,LSL#16            ;
22680 MOV     R5,R5,LSR#16            ;v1.48 half size note tables
22690 .playrawgotnote
22700 STR     R5,[R10,#DMA_pitch]     ;store pitch
22710 :
22720 MOV     R1,#1
22730 LDRB    R0,[R12,#vuflags]
22740 ORR     R0,R0,R1,LSLR9
22750 STRB    R0,[R12,#vuflags]       ;new note, so set VU flag
22760 CMP     R0,R0 ; Clear V
22770 LDMFD   R13!,{R0-R9,R11,PC}
22780 .err_swi_qtmplayraw
22790 LDMFD   R13!,{R0,R14}
22800 MOV     R0,#&80000000
22810 SUBS    R0,R0,#1 ; Set V
22820 ADR     R0,err_badaddress
22830 MOV     PC,R14
22840 
22850 
22860 .err_badaddress
22870 EQUD    qtm_error+&0C
22880 EQUS    "Illegal address passed to QTM"
22890 EQUB    0
22900 ALIGN
22910 
22920 
22930 .swi_qtmsoundctrl  ;r0=chans, r1=flags (b0=TSS, b1=4c on 5-8, b2=on after pause), r2=TSS handler
22940 STMFD   R13!,{R3,R14}           ;on exit, old values of above
22950 CMN     R0,#1
22960 CMPNE   R0,#0
22970 CMPNE   R0,#4
22980 ]:IF maxchans>4 THEN [OPT opt%:CMPNE R0,#8:]:REM v1.46 RasterMan edition - remove 8 channel check
22990 [OPT opt%                                   ;    if limited to 4 channels (24 uS/832 byte DMA)
23000 BNE     err_swi_qtmsoundctrl
23010 :
23020 LDR     R3,[R12,#oldConfigure+12]       ;load old TRNS sound handler
23030 CMP     R2,#&8000                       ;are we setting a new one? (R2>=&8000)?  update 28/7/96
23040 STRGE   R2,[R12,#oldConfigure+12]       ;...yup
23050 MOV     R2,R3                           ;put previous in R2
23060 :
23070 LDRB    R3,[R12,#soundflags]    ;load current sound flags
23080 CMP     R1,#0
23090 BMI     donesetnewflags         ;skip next bit if reading current...
23100 :
23110 LDRB    R14,[R12,#songchans]    ;v1.44
23120 CMP     R14,#4
23130 BNE     soundctrl_not4c
23140 AND     R14,R1,#%10             ;get the new state of 'play 4 channel music on c5-8'
23150 EOR     R14,R3,R14,LSL#4        ;EOR with current setting (bug fix 1.49, was ...R1,LSL#4)
23160 TST     R14,#%1<<5              ;- so bit5<>0 if there is a change
23170 MOV     R3,R1
23180 MOVNE   R1,#&0                  ;we want *MUSIC* chans to clear
23190 STRNE   R1,[R12,#chanendflags]
23200 MOVNE   R1,#&FF                 ;R1=&FF to only clear music DMA data
23210 BLNE    clearDMAchans
23220 MOV     R1,R3
23230 :
23240 LDRB    R3,[R12,#soundflags]    ;load current sound flags
23250 .soundctrl_not4c
23260 BIC     R14,R3,#%1100010        ;clear the sound flags we are affecting (b1/5/6)
23270 TST     R1,#%1
23280 ORRNE   R14,R14,#%10            ;if bit 0 set in R1 (TSS on), set bit 1 in soundflags
23290 MOV     R1,R1,LSR#1             ;v1.44 loose bit 0 of R1 (and make bits 1&2 down to 0&1)
23300 ORR     R14,R14,R1,LSL#5        ; |    bits 1&2 (now 0&1) R1 affect bits 5&6 of soundflags
23310 STRB    R14,[R12,#soundflags]   ; |    bit 5 = play 4c on 5-8; bit 6 = keep on after Pause/Stop
23320 BL      setDMAblock             ;...and update QTM's channel handler block for DMA/TRNS
23330 .donesetnewflags
23340 MOV     R1,#0
23350 TST     R3,#%1<<1
23360 ORRNE   R1,R1,#%1
23370 MOV     R14,R3,LSR#5            ; |
23380 AND     R14,R14,#%11            ; keep bit 5&6 only (b5=use chan 5-8, v1.49 b6=on after Pause)
23390 ORR     R1,R1,R14,LSL#1         ;v1.44 do the above backwards TO GET correct previous flags
23400 :
23410 TST     R3,#1                   ;is the sound system currently on or off?
23420 LDRNEB  R3,[R12,#chans_use]     ;load current number of channels, if switched on
23430 MOVEQ   R3,#0                   ;specify 0 channels on return, if sound was off
23440 CMP     R0,#0                   ;are we altering the no. channels/switching off? (R0>=0)?
23450 BLT     soundctrl_chansok
23460 BGT     soundctrl_changechans
23470 .soundctrl_switchoff
23480 BL      clearinfos              ; -
23490 BL      resetsound              ; - if R0=0 then ensure sound system is off!
23500 B       soundctrl_chansok
23510 :
23520 .soundctrl_changechans
23530 STRB    R0,[R12,#chans_use]     ;if altering channels, then store new number of channels...
23540 STRB    R0,[R12,#oldchansused]  ;v1.44 fix - update oldchansused, in case 4 chan playing, and we select 8
23550 BL      initQTMsound            ;...and update the controller...
23560 :
23570 .soundctrl_chansok
23580 MOV     R0,R3                   ;old number of channels in R0
23590 LDMFD   R13!,{R3,PC}
23600 :
23610 .err_swi_qtmsoundctrl
23620 MOV     R0,#&80000000
23630 SUBS    R0,R0,#1 ; Set V
23640 ADR     R0,badnumchans
23650 LDMFD   R13!,{R3,PC}          ;if bad number of channels then error!
23660 
23670 
23680 .badnumchans
23690 EQUD    qtm_error+&0D
23700 EQUS    "Bad number of channels"
23710 EQUB    0
23720 ALIGN
23730 
23740 
23750 .swi_qtmswitableaddr
23760 FNlong_adr("  ",0,SWIcode)
23770 MOV     PC,R14
23780 
23790 
23800 .swi_qtmregistersmp             ;updated 19/2/95 - fixed crash on illegal address routine
23810 STMFD   R13!,{R14}              ;r0=no. r1=addr r2=len r3=roff r4=rlen r5=vol r6=ftune
23820 BL      checksample
23830 LDMVSFD R13!,{PC}
23840 :
23850 CMP     R1,#0
23860 BEQ     deregistersmp
23870 :
23880 STMFD   R13!,{R0,R1}
23890 MOV     R0,R1
23900 ADD     R1,R1,R2
23910 SWI     "XOS_ValidateAddress"
23920 LDMFD   R13!,{R0,R1}
23930 BCS     err_swi_qtmregistersamp
23940 :
23950 STMFD   R13!,{R0,R7}
23960 SUBS    R0,R0,#1
23970 ADD     R7,R12,#(sampletable-song_data)
23980 ADD     R7,R7,R0,LSL#4
23990 ADD     R7,R7,R0,LSL#2                  ;(sample-1)*20
24000 STR     R1,[R7,#0]                      ;address of sample
24010 STR     R2,[R7,#4]                      ;sample length
24020 STR     R3,[R7,#8]                      ;repeat offset
24030 STR     R4,[R7,#12]                     ;repeat length
24040 STRB    R5,[R7,#19]                     ;volume byte
24050 AND     R6,R6,#&F
24060 STRB    R6,[R7,#16]                     ;finetune byte (4 bits, signed)
24070 CMP     R0,R0 ; Clear V
24080 LDMFD   R13!,{R0,R7,PC}
24090 .err_swi_qtmregistersamp
24100 MOV     R0,#&80000000
24110 SUBS    R0,R0,#1 ; Set V
24120 ADR     R0,err_badaddress
24130 LDMFD   R13!,{PC}
24140 
24150 .deregistersmp
24160 STMFD   R13!,{R0,R7}
24170 SUBS    R0,R0,#1
24180 ADD     R7,R12,#(sampletable-song_data)
24190 ADD     R7,R7,R0,LSL#4
24200 ADD     R7,R7,R0,LSL#2                  ;(sample-1)*20
24210 :
24220 STR     R1,[R7,#0]
24230 STR     R1,[R7,#4]                      ;sample length   }
24240 STR     R1,[R7,#8]                      ;repeat offset    }
24250 STR     R1,[R7,#12]                     ;repeat length     } blank!
24260 STRB    R1,[R7,#19]                     ;volume byte      }
24270 STRB    R1,[R7,#16]                     ;finetune byte   }
24280 CMP     R0,R0 ; Clear V
24290 LDMFD   R13!,{R0,R7,PC}
24300 
24310 
24320 .swi_qtmsetspeed                        ;added 19/2/95
24330 STMFD   R13!,{R14}
24340 BL      ensuresong
24350 LDMVSFD R13!,{PC}
24360 :
24370 CMP     R0,#0
24380 LDMEQFD R13!,{PC}                       ;exit with no error if speed 0 requested
24390 :
24400 MOVS    R14,R0,LSR#8                    ;simple way of testing only lower bits used!
24410 STMEQFD R13!,{R0-R7}                    ;required to call speed 'F' effect handler
24420 MOVEQ   R1,R0
24430 BEQ     set_setspeed
24440 :
24450 MOV     R0,#&80000000
24460 SUBS    R0,R0,#1 ; Set V
24470 ADR     R0,badspeedset
24480 LDMFD   R13!,{PC}                       ;throw up error if illegal speed
24490 
24500 
24510 .badspeedset
24520 EQUD    qtm_error+&10
24530 EQUS    "Speed/tempo value out of range"
24540 EQUB    0
24550 ALIGN
24560 
24570 
24580 .swi_qtmmusicoptions                    ;added 24/6/96
24610 LDRB    R2,[R12,#musicoptbyte]
24620 AND     R1,R1,R0
24630 BIC     R3,R2,R0
24640 ORR     R3,R3,R1
24650 STRB    R3,[R12,#musicoptbyte]
24660 MOV     PC,R14
24670 
24680 
24690 .swi_qtmmusicinterrupt                  ;added 24/6/96
24700 STMFD   R13!,{R3-R4,R14}
24710 LDR     R3,[R12,#musicintaddr]
24720 LDR     R4,[R12,#musicintr12]
24730 CMP     R1,#0
24740 MOVEQ   R2,R1
24750 STRGE   R1,[R12,#musicintaddr]
24760 STRGE   R2,[R12,#musicintr12]
24770 MOV     R1,R3
24780 MOV     R2,R4
24790 CMP     R0,R0 ; Clear V
24800 LDMFD   R13!,{R3-R4,PC}
24810 
24820 
24830 .musicinterrupt
24840 STMFD   R13!,{R11,R12,R14}
24850 LDR     R11,[R12,#musicintaddr]
24860 LDR     R12,[R12,#musicintr12]
24870 CMP     R11,#&8000
24880 MOVGE   R14,PC
24890 MOVGE   PC,R11
24900 CMP     R0,R0        ; Clear V
24910 LDMFD   R13!,{R11,R12,PC}
24920 
24930 
24940 .swi_qtmreadnoteword ;R0=pattern (0-n), R1=event (0-63), R2=channel (1-8)
24950 STMFD   R13!,{R14}   ;Returns R0-R2 preserved, R3=note, R4=sample, R5=eff, R6=data
24960 BL      ensuresong
24970 LDMVSFD R13!,{PC}
24980 :
24990 LDRB    R14,[R12,#songchans]
25000 CMP     R2,R14
25010 LDMGTFD R13!,{R14}
25020 BGT     err_checkchannel
25030 :
25040 LDRB    R14,[R12,#maxpattern]
25050 CMP     R0,R14
25060 LDMGTFD R13!,{R14}
25070 BGT     err_patternnumber
25080 :
25090 STMFD   R13!,{R0}
25100 CMP     R1,#63
25110 BGT     err_setevent
25120 CMP     R1,#0
25130 BLT     err_setevent
25140 :
25150 LDR     R14,[R12,#patternlen]   ;v1.44 support for 8CHN and 6CHN
25160 MUL     R0,R14,R0               ;pattern * patternlen
25170 MOV     R14,R14,LSR#6           ;patternlen/64 = event length (16/24/32 for 4, 8 FLT/6/8)
25180 MLA     R0,R14,R1,R0            ;add on current event*event length (no longer just 16)
25190 :
25200 LDR     R14,[R12,#songaddr]     ;r14=addr of song address
25210 ADD     R14,R14,#1000
25220 ADD     R14,R14,#0084           ;r14=start of patterns
25230 ADD     R0,R0,R14               ;address of required event
25240 :
25250 SUB     R14,R2,#1               ;channel-1 in r14
25260 LDR     R0,[R0,R14,LSL#2]       ;add (channel-1) * 4
25270 :
25280 AND     R14,R0,#&00000010       ;upper 1 bit of sample number
25290 AND      R4,R0,#&00F00000       ;lower 4 bits of sample number
25300 ORR     R4,R14,R4,LSR#20        ;r4 = sample number
25310 :
25320 AND     R14,R0,#&00000007       ;**v1.44 test for 8CHN** upper 3 (was 2) bits of note period
25330 AND      R5,R0,#&0000FF00       ;lower 8 bits of note period
25340 MOV     R14,R14,LSL#8           ;
25350 ORR     R5,R14,R5,LSR#8         ;r5 = amiga note period (1-4095)
25360 :
25370 CMP     R5,#1920                ;v1.44 if >=1920, revert to notenumber=0 (lowest note)
25380 MOVGE   R14,#0                  ;
25390 ADDLT   R14,R12,#(div8notetable-song_data)
25400 ADDLT   R14,R14,R5,LSR#3        ;if <1920, use 'div8' table
25410 CMP     R5,#150                 ;
25420 ADDLT   R14,R12,#(div1notetable-song_data)
25430 ADDLT   R14,R14,R5              ;if <150, use 'div1' table
25440 TEQ     R5,#0 ;ignore IF amiga period=0
25450 MOVEQ   R3,#0 ;v1.45 fix = was returning prev. R3 value, ie. not 0 if no note!!!
25460 LDRNEB  R3,[R14]                ;load note number (-1)
25470 ADDNE   R3,R3,#1                ;get to range 1-72
25480 :
25490 AND     R5,R0,#&000F0000        ;mask off effect number into r5
25500 MOV     R5,R5,LSR#16
25510 :
25520 MOV     R6,R0,LSR#24            ;...if it is, then get data shifted into r0
25530 LDMFD   R13!,{R0,PC}
25540 
25550 
25560 .err_patternnumber
25570 MOV     R0,#&80000000
25580 SUBS    R0,R0,#1 ; Set V
25590 ADR     R0,illegalpatt
25600 MOV     PC,R14
25610 .illegalpatt
25620 EQUD    qtm_error+&11
25630 EQUS    "Pattern number out of range"
25640 EQUB    0
25650 ALIGN
25660 
25670 
25680 .checkchannel
25690 SUB     R0,R0,#1
25700 CMP     R0,#7
25710 BHI     err_checkchannel
25720 ADDS    R0,R0,#1 ; Clear V
25730 MOV     PC,R14
25740 .err_checkchannel
25750 MOV     R0,#&80000000
25760 SUBS    R0,R0,#1 ; Set V
25770 ADR     R0,illegalchan
25780 MOV     PC,R14
25790 
25800 .illegalchan
25810 EQUD    qtm_error+&09
25820 EQUS    "Channel number out of range"
25830 EQUB    0
25840 ALIGN
25850 
25860 .checksample
25870 SUB     R0,R0,#1
25880 CMP     R0,#63
25890 BHI     err_checksample
25900 ADDS    R0,R0,#1 ; Clear V
25910 MOV     PC,R14
25920 .err_checksample
25930 MOV     R0,#&80000000
25940 SUBS    R0,R0,#1 ; Set V
25950 ADR     R0,smprange_error
25960 MOV     PC,R14
25970 
25980 .smprange_error
25990 EQUD    qtm_error+&0A
26000 EQUS    "Sample number out of range"
26010 EQUB    0
26020 ALIGN
26030 
26040 
26050 .checkvolrange                  ;checks volume in r0
26060 CMP     R0,#64
26070 BHI     err_checkvolrange
26080 CMP     R0,R0 ; Clear V
26090 MOV     PC,R14
26100 .err_checkvolrange
26110 MOV     R0,#&80000000
26120 SUBS    R0,R0,#1 ; Set V
26130 ADR     R0,vol_error
26140 MOV     PC,R14
26150 
26160 .vol_error
26170 EQUD    qtm_error+&07
26180 EQUS    "Volume level out of range"
26190 EQUB    0
26200 ALIGN
26210 
26220 
26230 .checknote                   ;updated for 1.44
26240 CMP     R0,#0
26250 BLE     checknote_err
26260 CMP     R0,#36
26270 ADDLE   R0,R0,#12
26280 MOVLE   R0,R0,LSL#24         ;if range 1-36 note, and bit 28 clear, correct note to 72 note
26290 BLE     checknote_ok         ;and return in bits 24-31
26300 CMP     R0,#2000
26310 BLT     checknote_ok         ;if <2000 it's an Amiga period
26320 TST     R0,#%1110<<29
26330 BNE     checknote_err        ;if any flags 29-31 set, cause an error
26340 TST     R0,#%0001<<28
26350 BEQ     checknote_err        ;if bit 28 is not set and we get here, then return an error
26360 BIC     R0,R0,#%1<<28
26370 CMP     R0,#72
26380 MOVLE   R0,R0,LSL#24         ;if range 1-72 & bit 28 set, clear bit 28, return note in 24-31
26390 BGT     checknote_err
26400 .checknote_ok
26410 CMP     R0,R0 ; Clear V
26420 MOV     PC,R14
26430 .checknote_err
26440 MOV     R0,#&80000000
26450 SUBS    R0,R0,#1 ; Set V
26460 ADR     R0,noterange_error
26470 MOV     PC,R14
26480 
26490 
26500 .noterange_error
26510 EQUD    qtm_error+&0B
26520 EQUS    "Note number out of range"
26530 EQUB    0
26540 ALIGN
26550 
26560 
26570 .ensuresong
26580 STMFD   R13!,{R0}
26590 LDRB    R0,[R12,#songstatus]
26600 TST     R0,#1
26610 LDMFD   R13!,{R0}
26620 BEQ     err_ensuresong
26630 CMP     R0,R0 ; Clear V
26640 MOV     PC,R14
26650 .err_ensuresong
26660 MOV     R0,#&80000000
26670 SUBS    R0,R0,#1 ; Set V
26680 ADR     R0,no_song
26690 MOV     PC,R14
26700 
26710 .no_song
26720 EQUD    qtm_error+&05
26730 EQUS    "No song loaded"
26740 EQUB    0
26750 ALIGN
26760 
26770 
26780 .init_databanks
26790 STMFD   R13!,{R0-R6,R11-R12,R14}
26800 MOV     R0,#127              ;v1.48
26810 SWI     "Sound_Volume"       ; | set volume to max 127 for table creation...
26820 MOV     R6,R0                ; | r6=original log system volume
26830 FNlong_adr("  ",5,loglintab) ; |
26840 LDRB    R5,[R5,R6,LSL#1]     ; | get linear volume 0-127 from log system volume
26850 ADD     R5,R5,#2             ; | +2 correction 127 -> 129, so 129 DIV2 = 64 max lin vol
26860 MOV     R5,R5,LSR#1          ; | r5=scaled QTM_Volume setting
26870 :
26880 ;FNlong_adr("  ",11,linlogtab)
26890 ADD     R11,R12,#(linlognew-song_data)
26900 MOV     R1,#255
26910 .setlinlogtab
26920 MOV     R0,R1,LSL#24
26930 SWI     "XSound_SoundLog"
26940 STRB    R0,[R11,R1]
26950 SUBS    R1,R1,#1
26960 BGE     setlinlogtab
26970 :
26980 MOV     R1,#64               ;use 64 (max lin volume) to create unscaled base vol table
26990 ADD     R2,R12,#(volumetable-song_data)
27000 .setvoltabs
27010 MOV     R0,R1,LSL#(24+1)
27020 SWI     "XSound_SoundLog"
27030 RSB     R0,R0,#255
27040 AND     R0,R0,#%11111110     ;stops odd/even changes (ie. +/- sample changes)
27050 STRB    R0,[R2,R1]
27060 SUBS    R1,R1,#1
27070 BGE     setvoltabs
27080 :
27090 MOV     R0,R6                ;v1.48
27100 SWI     "Sound_Volume"       ; | restore system volume to previous
27110 MOV     R0,R5                ; |
27120 BL      swi_qtmvolume        ; | set QTM_Volume (music and sample) scaled to system volume
27130 :
27140 ; v1.44 note table size reduced to 160+240 = 400 bytes (from 1024)
27150 :
27160 FNlong_adr("",2,amigaperiodz);must be a 6-octave, 72 note, period table
27170 ADD     R3,R12,#(div8notetable-song_data)
27180 MOV     R0,#239              ;table offset count down
27190 MOV     R1,#0                ;note number count up
27200 .div8fillnextnote
27210 MOVS    R4,R1,LSR#1
27220 LDR     R4,[R2,R4,LSL#2]
27230 MOVCC   R4,R4,LSL#16
27240 MOV     R4,R4,LSR#16         ;v1.48 half size note tables
27250 .div8fillnoteloop
27260 STRB    R1,[R3,R0]
27270 SUB     R0,R0,#1
27280 CMP     R0,R4,LSR#3          ;divide period by 8
27290 BGE     div8fillnoteloop
27300 ADD     R1,R1,#1
27310 CMP     R1,#50
27320 BLE     div8fillnextnote
27330 :
27340 ADD     R3,R12,#(div1notetable-song_data)
27350 MOV     R0,#159              ;table offset count down
27360 MOV     R1,#43               ;note number count up
27370 .div1fillnextnote
27380 MOVS    R4,R1,LSR#1
27390 LDR     R4,[R2,R4,LSL#2]
27400 MOVCC   R4,R4,LSL#16
27410 MOV     R4,R4,LSR#16         ;v1.48 half size note tables
27420 .div1fillnoteloop
27430 STRB    R1,[R3,R0]
27440 SUB     R0,R0,#1
27450 CMP     R0,R4
27460 BGE     div1fillnoteloop
27470 ADD     R1,R1,#1
27480 CMP     R1,#71
27490 BLE     div1fillnextnote
27500 :
27510 MOV     R0,#&10000
27520 SUB     R0,R0,#1
27530 STR     R0,[R12,#FXflags]
27540 STR     R0,[R12,#E_FXflags]
27550 :
27560 MOV     R0,#512
27570 SUB     R0,R0,#2      ; =(%11111111)<<1 ;these take up more space like this, rather than
27580 STR     R0,[R12,#channelstate]          ;just pre-storing them, but this way they work if
27590 MOV     R0,#dma                         ;the module is saved from RMA, then re-run...
27600 MOV     R0,R0,LSR#4   ; v1.42 - div by 16 (208 -> 13, 416 -> 26)
27610 STRB    R0,[R12,#current_dma]  ;v1.45 this is QTM's desired DMA size
27620 STRB    R0,[R12,#actual_dma]   ;v1.45 this is actual DMA size, determined in 'setstereos'
27630 MOV     R0,#uS
27640 STRB    R0,[R12,#current_uS]   ;v1.45 overwritten for RO5 in machinedetect
27650 MOV     R0,#4
27660 STRB    R0,[R12,#chans_use]
27670 MOV     R0,#2
27680 STRB    R0,[R12,#vugravity]
27690 :
27700 MOV     R0,#0
27710 STRB    R0,[R12,#musicoptbyte]
27720 STR     R0,[R12,#musicintaddr]
27730 STR     R0,[R12,#musicintr12]
27740 STR     R0,[R12,#tempaddrptr]
27750 STR     R0,[R12,#fake8bitDMA]
27760 LDMFD   R13!,{R0-R6,R11-R12,PC}
27770 
27780 FNtimercode
27790 
27800 FNvucode
27810 
27820 .title
27830 EQUS    "QTMTracker"
27840 EQUB    0
27850 
27860 .help   ;do not edit between here and ehelp, as data is poked here later
27870 EQUS    "QTM Tracker"+CHR$9
27880 .helpver
27890 EQUS    ver$
27900 .helpdate
27910 EQUS    " ("+date$+") © Steve Harrison "
27920 .helpchar
27930 ]
27931 IF betatest% THEN [OPT opt%:EQUS" !BETA TEST VERSION!":]
27932 IF alphatest% THEN [OPT opt%:EQUS" !ALPHA TEST - NOT FOR RELEASE!":]
27940 [OPT opt%
27950 .ehelp
27960 EQUB    0
27970 
27980 .SWItable
27990 EQUS    "QTM"
28000 EQUB    0
28010 EQUS    "Load"
28020 EQUB    0
28030 EQUS    "Start"
28040 EQUB    0
28050 EQUS    "Stop"
28060 EQUB    0
28070 EQUS    "Pause"
28080 EQUB    0
28090 EQUS    "Clear"
28100 EQUB    0
28110 EQUS    "Info"
28120 EQUB    0
28130 EQUS    "Pos"
28140 EQUB    0
28150 EQUS    "EffectControl"
28160 EQUB    0
28170 EQUS    "Volume"
28180 EQUB    0
28190 EQUS    "SetSampleSpeed"
28200 EQUB    0
28210 EQUS    "DMABuffer"
28220 EQUB    0
28230 EQUS    "RemoveChannel"
28240 EQUB    0
28250 EQUS    "RestoreChannel"
28260 EQUB    0
28270 EQUS    "Stereo"
28280 EQUB    0
28290 EQUS    "ReadSongLength"
28300 EQUB    0
28310 EQUS    "ReadSequenceTable"
28320 EQUB    0
28330 EQUS    "VUBarControl"
28340 EQUB    0
28350 EQUS    "ReadVULevels"
28360 EQUB    0
28370 EQUS    "ReadSampleTable"
28380 EQUB    0
28390 EQUS    "ReadSpeed"
28400 EQUB    0
28410 EQUS    "PlaySample"
28420 EQUB    0
28430 EQUS    "SongStatus"
28440 EQUB    0
28450 EQUS    "ReadPlayingTime"
28460 EQUB    0
28470 EQUS    "PlayRawSample"
28480 EQUB    0
28490 EQUS    "SoundControl"
28500 EQUB    0
28510 EQUS    "SWITableAddress"
28520 EQUB    0
28530 EQUS    "RegisterSample"
28540 EQUB    0
28550 EQUS    "SetSpeed"
28560 EQUB    0
28570 EQUS    "MusicVolume"
28580 EQUB    0
28590 EQUS    "SampleVolume"
28600 EQUB    0
28610 EQUS    "MusicOptions"
28620 EQUB    0
28630 EQUS    "MusicInterrupt"
28640 EQUB    0
28650 EQUS    "ReadChannelData"
28660 EQUB    0
28670 EQUS    "ReadNoteWord"
28680 EQUB    0
28690 EQUS    "DMAHandler"
28700 EQUB    0
28710 ]:IF alphatest% THEN [OPT opt%:EQUS "Debug":EQUB 0:]
28720 [OPT opt%
28730 EQUB    0
28740 
28750 .commands
28760 EQUS    "QTMTracker"
28770 EQUB    0
28780 ALIGN
28790 EQUD    0
28800 EQUB    0
28810 EQUB    0
28820 EQUB    0
28830 EQUB    0
28840 EQUD    0
28850 EQUD    hlp_qtm
28860 
28870 EQUS    "QTMLoad"
28880 EQUB    0
28890 ALIGN
28900 EQUD    cmd_qtmload
28910 EQUB    1
28920 EQUB    %00000001
28930 EQUB    2
28940 EQUB    0
28950 EQUD    syn_qtmload
28960 EQUD    hlp_qtmload
28970 :
28980 EQUS    "QTMStart"
28990 EQUB    0
29000 ALIGN
29010 EQUD    cmd_qtmstart
29020 EQUB    0
29030 EQUB    %00000000
29040 EQUB    0
29050 EQUB    0
29060 EQUD    syn_qtmstart
29070 EQUD    hlp_qtmstart
29080 :
29090 EQUS    "QTMStop"
29100 EQUB    0
29110 ALIGN
29120 EQUD    cmd_qtmstop
29130 EQUB    0
29140 EQUB    %00000000
29150 EQUB    0
29160 EQUB    0
29170 EQUD    syn_qtmstop
29180 EQUD    hlp_qtmstop
29190 :
29200 EQUS    "QTMPause"
29210 EQUB    0
29220 ALIGN
29230 EQUD    cmd_qtmpause
29240 EQUB    0
29250 EQUB    %00000000
29260 EQUB    0
29270 EQUB    0
29280 EQUD    syn_qtmpause
29290 EQUD    hlp_qtmpause
29300 :
29310 EQUS    "QTMClear"
29320 EQUB    0
29330 ALIGN
29340 EQUD    cmd_qtmclear
29350 EQUB    0
29360 EQUB    %00000000
29370 EQUB    0
29380 EQUB    0
29390 EQUD    syn_qtmclear
29400 EQUD    hlp_qtmclear
29410 :
29420 EQUS    "QTMInfo"
29430 EQUB    0
29440 ALIGN
29450 EQUD    cmd_qtminfo
29460 EQUB    0
29470 EQUB    %00000000
29480 EQUB    0
29490 EQUB    0
29500 EQUD    syn_qtminfo
29510 EQUD    hlp_qtminfo
29520 :
29530 EQUS    "QTMSamples"
29540 EQUB    0
29550 ALIGN
29560 EQUD    cmd_qtmsamples
29570 EQUB    0
29580 EQUB    %00000000
29590 EQUB    0
29600 EQUB    0
29610 EQUD    syn_qtmsamples
29620 EQUD    hlp_qtmsamples
29630 :
29640 EQUS    "QTMVolume"
29650 EQUB    0
29660 ALIGN
29670 EQUD    cmd_qtmvolume
29680 EQUB    0
29690 EQUB    %00000000
29700 EQUB    1
29710 EQUB    0
29720 EQUD    syn_qtmvolume
29730 EQUD    hlp_qtmvolume
29740 :
29750 EQUS    "QTMPos"
29760 EQUB    0
29770 ALIGN
29780 EQUD    cmd_qtmpos
29790 EQUB    0
29800 EQUB    %00000000
29810 EQUB    2
29820 EQUB    0
29830 EQUD    syn_qtmpos
29840 EQUD    hlp_qtmpos
29850 :
29860 EQUS    "QTMDisable"
29870 EQUB    0
29880 ALIGN
29890 EQUD    cmd_qtmdisable
29900 EQUB    0
29910 EQUB    %00000000
29920 EQUB    1
29930 EQUB    0
29940 EQUD    syn_qtmdisable
29950 EQUD    hlp_qtmdisable
29960 :
29970 EQUS    "QTMEnable"
29980 EQUB    0
29990 ALIGN
30000 EQUD    cmd_qtmenable
30010 EQUB    1
30020 EQUB    %00000000
30030 EQUB    1
30040 EQUB    0
30050 EQUD    syn_qtmenable
30060 EQUD    hlp_qtmenable
30070 :
30080 EQUS    "QTMTransparent"
30090 EQUB    0
30100 ALIGN
30110 EQUD    cmd_qtmtrans
30120 EQUB    0
30130 EQUB    %00000000
30140 EQUB    1
30150 EQUB    0
30160 EQUD    syn_qtmtrans
30170 EQUD    hlp_qtmtrans
30180 
30190 EQUB    0
30200 
30210 .hlp_qtm
30220 EQUS    "+"+STRING$(74,"-")+"+"+CHR$13
30230 EQUS    "|"+STRING$(9,CHR$9)+STRING$(3,CHR$31)+"|"+CHR$13
30240 EQUS    "|"+STRING$(3,CHR$9)+STRING$(0,CHR$31)+"»»» QTM  -  Q The Music «««"+STRING$(3,CHR$9)+STRING$(3,CHR$31)+"|"+CHR$13
30250 ]:IF alphatest% OR betatest% THEN
30260  [OPT opt%
30270  EQUS "|"+STRING$(9,CHR$9)+STRING$(3,CHR$31)+"|"+CHR$13
30280 EQUS    "|"+CHR$9+STRING$(4,CHR$31)+"TEST VERSION TEST VERSION TEST VERSION TEST VERSION"+CHR$9+CHR$9+STRING$(3,CHR$31)+"|"+CHR$13:]
30290  ENDIF
30300 [OPT opt%
30310 EQUS    "|"+STRING$(9,CHR$9)+STRING$(3,CHR$31)+"|"+CHR$13
30320 EQUS    "|"+STRING$(4,CHR$31)+"The 4/6/8-channel RISC OS ProTracker/FastTracker/StarTrekker player"+STRING$(3,CHR$31)+"|"+CHR$13
30330 EQUS    "|"+STRING$(9,CHR$9)+CHR$31+CHR$31+CHR$31+"|"+CHR$13
30340 EQUS    "|"+CHR$9+STRING$(3,CHR$31)+"---> http://www.pi-star.co.uk/qtm"+CHR$9+CHR$9+STRING$(6,CHR$31)+"<---"+CHR$9+STRING$(3,CHR$31)+"|"+CHR$13
30350 EQUS    "|"+CHR$9+STRING$(3,CHR$31)+"---> http://www.phlamethrower.co.uk/riscos/qtm.php <---"+CHR$9+STRING$(3,CHR$31)+"|"+CHR$13
30360 EQUS    "|"+STRING$(9,CHR$9)+CHR$31+CHR$31+CHR$31+"|"+CHR$13
30370 .helptextversion
30380 EQUS    "|"+STRING$(2,CHR$9)+STRING$(6,CHR$31)+"v"+ver$+" © 1993-2023 Steve Harrison"+STRING$(3,CHR$9)+STRING$(3,CHR$31)+"|"+CHR$13
30390 ]:IF qtmrast% THEN [OPT opt%:EQUS "|"+CHR$9+"Special "+STR$maxchans+"-channel, ":.qtmrmtext:EQUS STR$dmachoice+"uS version, for use only with RasterMan"+CHR$9+STRING$(3,CHR$31)+"|"+CHR$13:]
30400 [OPT opt%
30410 EQUS    "|"+STRING$(9,CHR$9)+CHR$31+CHR$31+CHR$31+"|"+CHR$13
30420 EQUS    "+"+STRING$(74,"-")+"+"+CHR$13
30430 EQUB    0
30440 
30450 .hlp_qtmload
30460 EQUS    FNcompress("*QTMLoad loads (and plays) the specified 15/31 inst sound tracker module. If an 'x' is placed after the filename, then the sound tracker","QTMLoad")
30470 EQUS    FNcompress(" module will be loaded but the play routine will not be started, use *QTMStart to start the module playing.","QTMLoad")
30480 EQUB    13
30490 .syn_qtmload
30500 EQUS    FNcompress("Syntax: *QTMLoad <filename> [x]","QTMLoad")
30510 EQUB    0
30520 
30530 .hlp_qtmclear
30540 EQUS    FNcompress("*QTMClear stops the current song playing and removes it from memory, releasing the RMA used to store it.","QTMClear")
30550 EQUB    13
30560 .syn_qtmclear
30570 EQUS    FNcompress("Syntax: *QTMClear","QTMClear")
30580 EQUB    0
30590 
30600 .hlp_qtmstart
30610 EQUS    FNcompress("*QTMStart starts the current song playing, if it has been stopped or paused.","QTMStart")
30620 EQUB    13
30630 .syn_qtmstart
30640 EQUS    FNcompress("Syntax: *QTMStart","QTMStart")
30650 EQUB    0
30660 
30670 .hlp_qtmpause
30680 EQUS    FNcompress("*QTMPause stops the current song playing and resets the sound channels to their previous owner (use *QTMStart to restart the player).","QTMPause")
30690 EQUB    13
30700 .syn_qtmpause
30710 EQUS    FNcompress("Syntax: *QTMPause","QTMPause")
30720 EQUB    0
30730 
30740 .hlp_qtmstop
30750 EQUS    FNcompress("*QTMStop acts as *QTMPause, but also sets the song sequence position to 0 and defaults the channel/effect flags (this is equivalent to reloading the song).","QTMStop")
30760 EQUB    13
30770 .syn_qtmstop
30780 EQUS    FNcompress("Syntax: *QTMStop","QTMStop")
30790 EQUB    0
30800 
30810 .hlp_qtminfo
30820 EQUS    FNcompress("*QTMInfo displays a variety of information about the currently loaded song.","QTMInfo")
30830 EQUB    13
30840 .syn_qtminfo
30850 EQUS    FNcompress("Syntax: *QTMInfo","QTMInfo")
30860 EQUB    0
30870 
30880 .hlp_qtmpos
30890 EQUS    FNcompress("*QTMPos with no parameters displays the current position in the song's sequence table. If a number is specified, this will cause the player","QTMPos")
30900 EQUS    FNcompress(" to jump to that sequence position. If an 'x' is present after the number, the player will not reset the event count when jumping to that position.","QTMPos")
30910 EQUB    13
30920 .syn_qtmpos
30930 EQUS    FNcompress("Syntax: *QTMPos [<position> [x]]","QTMPos")
30940 EQUB    0
30950 
30960 .hlp_qtmsamples
30970 EQUS    FNcompress("*QTMSamples lists the names, lengths, repeats, etc. of all the samples used in the current song.","QTMSamples")
30980 EQUB    13
30990 .syn_qtmsamples
31000 EQUS    FNcompress("Syntax: *QTMSamples","QTMSamples")
31010 EQUB    0
31020 
31030 .hlp_qtmdisable
31040 EQUS    FNcompress("*QTMDisable with no parameters will list the numbers of the currently disabled effects. If an effect is specified, it will be disabled from the song effect handlers. (enter 'E'-effects as '*QTMDisable E6' etc.)","QTMDisable")
31050 EQUB    13
31060 .syn_qtmdisable
31070 EQUS    FNcompress("Syntax: *QTMDisable [<effect number>]","QTMDisable")
31080 EQUB    0
31090 
31100 .hlp_qtmenable
31110 EQUS    FNcompress("*QTMEnable reverses the operation of *QTMDisable.","QTMEnable")
31120 EQUB    13
31130 .syn_qtmenable
31140 EQUS    FNcompress("Syntax: *QTMEnable <effect number>","QTMEnable")
31150 
31160 .hlp_qtmtrans
31170 EQUS    FNcompress("*QTMTransparent enables or disables QTM's Transparent Sound System (TSS). When switched on, RISC OS system sounds continue to be played while QTM is playing music.","QTMTransparent")
31180 EQUB    13
31190 .syn_qtmtrans
31200 EQUS    FNcompress("Syntax: *QTMTransparent [On|Off]","QTMTransparent")
31210 EQUB    0
31220 
31230 .hlp_qtmvolume
31240 EQUS    FNcompress("*QTMVolume will set the overall output volume from the QTM play routine to the specified linear volume (0-64). If the command is issued without a parameter, the current overall volume will be displayed.","QTMVolume")
31250 EQUB    13
31260 .syn_qtmvolume
31270 EQUS    FNcompress("Syntax: *QTMVolume [<volume 0-64>]","QTMVolume")
31280 EQUB    0
31290 ALIGN
31300 ]
31310 =opt%
31320 
31330 DEF PROCmodvars
31340 ENDPROC
31350 
31360 DATA  42
31370 DATA  0, 0,""
31380 DATA  9, 1,"Syntax: *"
31390 DATA -1, 2," the "
31400 DATA -1, 3,"director"
31410 DATA -1, 4,"filing system"
31420 DATA -1, 5,"current"
31430 DATA -1, 6," to a variable. Other types of value can be assigned with *"
31440 DATA -1, 7,"file"
31450 DATA -1, 8,"default "
31460 DATA -1, 9,"tion"
31470 DATA -1,10,"*Configure "
31480 DATA -1,11,"name"
31490 DATA -1,12," server"
31500 DATA -1,13,"number"
31510 DATA  9,14,"Syntax: * <"
31520 DATA -1,15," one or more files that match the given wildcard"
31530 DATA -1,16," and "
31540 DATA -1,17,"relocatable module"
31550 DATA -1,18,"C(onfirm)	Prompt for confirmation of each "
31560 DATA -1,19,"sets the "
31570 DATA  9,20,"Syntax: * [<disc spec.>]"
31580 DATA -1,21,"} V(erbose)	Print information on each file "
31590 DATA -1,23,"spriteLandscape [<XScale> [<YScale> [<Margin> [<Threshold>]]]]]"
31600 DATA -1,24," is used to print a hard copy of the screen on EPSON-"
31610 DATA -1,25,". Options: (use ~ to force off, eg. ~"
31620 DATA -1,26,"printe"
31630 DATA  9,27,"Syntax: * <filename>"
31640 DATA -1,28,"select"
31650 DATA -1,29,"xpression"
31660 DATA  9,30,"Syntax: * ["
31670 DATA -1,31,"sprite"
31680 DATA -1,32," displays"
31690 DATA -1,33,"free space"
31700 DATA -1,34," {off}"
31710 DATA -1,35,"library"
31720 DATA -1,36,"parameter"
31730 DATA -1,37,"object"
31740 DATA -1,38," all "
31750 DATA -1,39,"disc"
31760 DATA -1,40," to "
31770 DATA -1,41," is "
31780 DATA &FF
31790 
