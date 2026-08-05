; Generated from QTM_Mod.bas by tools/bas2vasm.py -- do not hand-edit.
; Mechanical translation; verify against ref/listing.txt.


uservariablespace:
userprivateword:
	.long	0                                             ;start code             00
userR14store:
	.long	initqtm                                       ;init code              04
userPSRstore:
	.long	exitqtm                                       ;exit code              08
	.long	services                                      ;service code           12
	.long	title                                         ;title                  16
	.long	help                                          ;help                   20
	.long	commands                                      ;commands               24
	.long	0x47E40                                       ;SWI number             28
	.long	SWIcode                                       ;SWI code               32
	.long	SWItable                                      ;SWI table              36
	.long	0                                             ;SWI decoding code      40
	.long	0                                             ;MessageTrans file      44
	.long	flagsword                                     ;Flags word ptr         48

	.p2align 2
	B	user_initqtm                                      ;                       52
	B	user_swicode                                      ;                       56
	B	user_services                                     ;                       60
	B	user_exitqtm                                      ;                       64


user_initqtm:                                        ;should be called only in SVC or User
	STR	R14,userR14store
	.long	0xE10FE000                                    ; FNmrs("AL","R14,CPSR")
	STR	R14,userPSRstore
	TST	R14,#3
	SWIEQ	OS_EnterOS
	LDR	R14,userR14store
	STMFD	R13!,{R0-R6,R10-R12,R14}
	ADR	R12,userprivateword                             ;this is first word of module header - OK to edit as we're not
	MOV	R11,#0                                          ;   loaded as a module or from ROM, we're in user code...
	ADR	R10,nullenviroment                              ;this is a ptr to a null string, as R10 would be on loading
	BL	initqtm
	STRVS	R0,[R13]
	LDMFD	R13!,{R0-R6,R10-R12,R14}
	TEQ	PC,PC
	BEQ	user_exit32
	BICVCS	PC,R14,#1 << 0x1C
	ORRVSS	PC,R14,#1 << 0x1C                            ;back to original mode & exit


user_swicode:                                        ;R11=swi offset
	STR	R14,userR14store
	.long	0xE10FE000                                    ; FNmrs("AL","R14,CPSR")
	STR	R14,userPSRstore
	TST	R14,#3
	SWIEQ	OS_EnterOS
	LDR	R14,userR14store
	STMFD	R13!,{R10-R12,R14}
	ADR	R12,userprivateword
	BL	SWIcode
	LDMFD	R13!,{R10-R12,R14}
	TEQ	PC,PC
	BEQ	user_exit32
	BICVCS	PC,R14,#1 << 0x1C
	ORRVSS	PC,R14,#1 << 0x1C                            ;back to original mode & exit


user_services:                                       ;R1=service number
	STR	R14,userR14store
	.long	0xE10FE000                                    ; FNmrs("AL","R14,CPSR")
	STR	R14,userPSRstore
	TST	R14,#3
	SWIEQ	OS_EnterOS
	LDR	R14,userR14store
	STMFD	R13!,{R12,R14}
	ADR	R12,userprivateword
	BL	services
	LDMFD	R13!,{R12,R14}
	TEQ	PC,PC
	BEQ	user_exit32
	BICVCS	PC,R14,#1 << 0x1C
	ORRVSS	PC,R14,#1 << 0x1C                            ;back to original mode & exit


user_exitqtm:
	STR	R14,userR14store
	.long	0xE10FE000                                    ; FNmrs("AL","R14,CPSR")
	STR	R14,userPSRstore
	TST	R14,#3
	SWIEQ	OS_EnterOS
	LDR	R14,userR14store
	STMFD	R13!,{R0-R6,R10-R12,R14}
	ADR	R12,userprivateword
	MOV	R11,#0
	MOV	R10,#1                                          ;fatal finalisation!
	BL	exitqtm                                          ;(could also attempt to release RMA in private word, but NR)
	LDMFD	R13!,{R0-R6,R10-R12,R14}
	TEQ	PC,PC
	BEQ	user_exit32
	BICS	PC,R14,#1 << 0x1C                              ;never return error on exit, no point in user control!


user_exit32:                                         ;common exit code for 32bit machines
	LDR	R14,userPSRstore
	ORRVS	R14,R14,#1 << 0x1C
	BICVC	R14,R14,#1 << 0x1C
	.long	0xE129F00E                                    ; FNmsr("AL","CPSR_cf,R14")
	LDR	PC,userR14store


flagsword:
	.long	1                                             ;32bit!

textdata:
by:
	.byte	"by"
nullenviroment:
	.byte	0
of:
	.byte	"of"
	.byte	0
copyright:
	.byte	"copyright"
	.byte	0
cpy:
	.byte	"(c)"
	.byte	0
hash:
	.byte	"#"
	.byte	0
back:
	.byte	"/"
	.byte	0
	.p2align 2
mk:
	.byte	"M.K."
flt4:
	.byte	"FLT4"
flt8:
	.byte	"FLT8"                                        ;8 channels!
chn8:
	.byte	"8CHN"                                        ;FastTracker 8 channels!
chn6:
	.byte	"6CHN"                                        ;FastTracker 6 channels!
cd81:
	.byte	"CD81"                                        ;Octalyser 8 channels
cd61:
	.byte	"CD61"                                        ;Octalyser 6 channels (not seen one of these...)
chn4:
	.byte	"4CHN"                                        ;4 channel FastTracker
flt2:
	.byte	"FLT2"                                        ;2 channel StarTrekker ** not supported (not seen one of these)
ch16:
	.byte	"16CH"                                        ;16 channel FastTracker ** not supported
ch24:
	.byte	"24CH"                                        ;24 channel FastTracker ** not supported
ch32:
	.byte	"32CH"                                        ;32 channel FastTracker ** not supported


	.p2align 2
initqtm:
	STMFD	R13!,{R7-R12,R14}
	.if qtmrast | alphatest | betatest
	SWI	XOS_WriteS
	.byte	"QTM v1.49"
	.endif
	.if qtmrast
	.byte	0x72
	.endif
	.if alphatest
	.byte	" alpha-test "
	.endif
	.if betatest
	.byte	" beta-test "
	.endif
	.if qtmrast
	.include "stamp_l171.asm"
	.p2align 2
qtm_mod_adr172:                                      ; FNlong_adr("",0,qtmrmtext)
	.long	0xE28F0000-(((qtmrmtext-qtm_mod_adr172)>>31)&0x00400000)+((((qtmrmtext-qtm_mod_adr172-8)^((qtmrmtext-qtm_mod_adr172-8)>>31))-((qtmrmtext-qtm_mod_adr172-8)>>31))&0xFF)
	.long	0xE2800C00-(((qtmrmtext-qtm_mod_adr172)>>31)&0x00400000)+(((((qtmrmtext-qtm_mod_adr172-8)^((qtmrmtext-qtm_mod_adr172-8)>>31))-((qtmrmtext-qtm_mod_adr172-8)>>31))>>8)&0xFF)
	MOV	R1,#0x29
	SWI	XOS_WriteN
	SWI	XOS_NewLine
	.else
	.if alphatest | betatest
	.byte	"version loaded.",0x0D,0x0A,0x00
	.endif
	.endif
	.p2align 2
	MOV	R1,#0+(song_data_end - song_data) & 0xFF        ;v1.49 RMA datablock
	ORR	R1,R1,#0+(song_data_end - song_data) & 0xFF00
	MOV	R0,R1
	BL	claimRMA                                         ;claim RMA for datablock
	BL	blankmemory                                      ;R0=RMA datablock!
	MOV	R11,R12                                         ;R11=module workspace ptr
	MOV	R12,R0                                          ;FNlong_adr("  ",12,song_data)
	BL	init                                             ;R12 needs to be set up by here
	STR	R11,[R12,#modworkspace]
	STR	R12,[R11]                                       ;v1.49 finally we can try storing datablock addr in workspace ptr!
	BL	init_databanks                                   ;sets up tables, volumes and vars incl. current_uS to 'uS' (32 default)
	BL	machinedetect                                    ;sets osversion, turns TSS to 'On' for RO5 (no longer uS=48 for RPCEmu)
	MOV	R0,#0
	MOV	R1,#0
	BL	swi_qtmstereo                                    ;v1.48 this avoids needing to preset default stereo in databanks
	LDRB	R0,[R12,#armchip]                              ;v1.48
	CMP	R0,#3                                           ;
	BLLE	unroll_a2_DMA                                  ;if Arm2 or Arm3, unroll the DMA code for Arm2/cache-off Arm3
	LDMVSFD	R13!,{R7-R12,PC}
	LDRB	R1,[R12,#osversion]
	CMP	R1,#0xA6 - 0xA0                                 ;check for OS 3.6 or above (16bit sound possible)
	MOVLT	R0,#0                                         ; ..this should really move to 'machinedetect' and only
	STRLT	R0,[R12,#fake8bitDMA]                         ; ..allocate fakeDMA if 16bit sound actually in use...?
	BLT	finishinit                                      ; ..
	; ..
	MOV	R1,#0xD0 * 8                                    ; v1.45 reverted to fixed 'fakeDMA' as 208x8 -no need for larger!
	MOV	R0,R1                                           ; ..
	BL	claimRMA                                         ; ..
	BL	blankmemory                                      ; ..should only need if actually using 16bit sound..
	STR	R0,[R12,#fake8bitDMA]                           ;if we're on a RISC OS 3.6+ machine, use fake DMA buffer
finishinit:
	BL	initVIDCandpitch                                 ;sets Arc pitch tables based on uS etc.
	LDMFD	R13!,{R7-R12,PC}


initVIDCandpitch:                                    ;call AFTER 'machinedetect'
	STMFD	R13!,{R0-R1,R12,R14}
	.if qtmrast
	MOV	R0,#1 << 0x10
	STR	R0,[R12,#rm_CIAdec]
	.endif
	;                    music on DMA IRQ, not altered again if 16bt)
	LDRB	R14,[R12,#soundflags]
	TST	R14,#1 << 7
	BNE	initVIDCandpitch16bit
	TST	R14,#1 << 2                                     ;test for new VIDC clock
	BNE	newmachinemode                                  ;new-clock flag set, so use its routine
	MOV	R0,#0x5DC0 & 0xFF00
	ADD	R0,R0,#0x5DC0 & 0xFF
	STR	R0,[R12,#clockspeed]
	MOV	R0,#0+(0x5DC0 / 0x3E8) * 0x1000
	STR	R0,[R12,#shiftclock]                            ;not a new clock machine, so assume 24MHz at start
	BL	recalc_uS_4clock
	B	oldmachinemode
initVIDCandpitch16bit:
	BL	recalc_uS_4clock_16bit
	LDMFD	R13!,{R0-R1,R12,PC}                           ;v1.48 fix, was ...R14} meaning machinedetect was called twice!


machinedetect:
	STMFD	R13!,{R0-R6,R14}
	MOV	R6,#0                                           ;default for soundflags = 0
	BL	armcheck                                         ;R0=Arm number (2, 3 or 6)
	STRB	R0,[R12,#armchip]
	MOV	R0,#0x81
	MOV	R1,#0
	MOV	R2,#0xFF
	SWI	XOS_Byte
	SUB	R1,R1,#0xA0
	STRB	R1,[R12,#osversion]                            ;set OS version-&A0
	CMP	R1,#0xA2 - 0xA0                                 ;check for OS 2.01 or above
	ORREQ	R6,R6,#1 << 2                                 ;EQ = RO2.01, so A540 with new VIDC
	BLE	setmachinetype                                  ;...if OS <=2.01, old so exit!
	CMP	R1,#0xAA - 0xA0                                 ;RISC OS 5? (handles 'Tuning' of OS sounds correctly)
	ORRGE	R6,R6,#2                                      ; ...if so, enable TSS by default
	LDRGEB	R0,[R12,#musicvolume]                        ; ...scale vol to 3/4 for RO5 to make TSS sounds louder
	ADDGE	R0,R0,R0,LSL #1                               ; ...musicvolume already scaled to sys volume, in initdatabanks
	MOVGE	R0,R0,LSR #2                                  ; ...now scale music volume to 3/4 by r1=(music vol * 3) / 4
	BLGE	swi_qtmvolume                                  ; ...BUG'd before v1.48, as coded didn't call swi_qtmvol!!!
	CMP	R1,#0xA5 - 0xA0                                 ;v1.44 test for RPCEmu
	BLT	testRO3oldnewVIDC                               ;if <RO3.5, then not RPCEmu
	;ADR     R1,rpcemuhostfs         ;removed in v1.48 becuase latest RPCEmu0.9.4 seems ok with
	;MOV     R0,#18                  ;sample speed <>48...
	;SWI     "XOS_Module"            ;test for RPCEmuHostFS (wipes R5!)
	;MOVVC   R0,#48                  ;
	;STRVCB  R0,[R12,#current_uS]    ;if VC (module present) then set uS to 48
test16bitsound:
	MOVS	R0,#0                                          ;test for 16bit sound
	SWI	XSound_4                                        ;v1.42 fix, was XSound_Mode - so compiles on RO3.6+ only
	CMP	R0,#1                                           ;returns VS and R0<>1 if error unknown SWI
	ORREQ	R6,R6,#1 << 7                                 ;16bit sound available!
	BEQ	setmachinetype                                  ;don't care about VIDC type if 16bit
testRO3oldnewVIDC:
	MOV	R0,#2                                           ;OS 3+ (only) old/new detection coming up!
	SWI	XOS_ReadSysInfo                                 ;*this detects RO3 A540 as 'old' which is ok, but should be 'new'
	CMP	R0,#0
	CMPEQ	R1,#0
	CMPEQ	R2,#0
	CMPEQ	R3,#0
	CMPEQ	R4,#0
	ORRNE	R6,R6,#1 << 2                                 ;above call returned non-zero, so set as a new machine VIDC
setmachinetype:
	STRB	R6,[R12,#soundflags]
	LDMFD	R13!,{R0-R6,PC}


	;.rpcemuhostfs
	;EQUS    "RPCEmuHostFS"
	;EQUB    0
	;ALIGN


SWIcode:                                             ;wrapper to allow flag preservation on 26bit systems
	STMFD	R13!,{R14}
	BL	origSWIcode
	LDMFD	R13!,{R14}
	TEQ	PC,PC
	MOVEQ	PC,R14                                        ;SWIs don't preserve flags under 32bit RO
	BICVCS	PC,R14,#1 << 0x1C
	ORRS	PC,R14,#1 << 0x1C

origSWIcode:
	LDR	R12,[R12]                                       ;v1.49 FNlong_adr("  ",12,song_data)
	CMP	R11,#0+(endSWItable - startSWItable) / 4
	ADDLO	PC,PC,R11,LSL #2
	B	UnknownSWIerror
startSWItable:
	B	swi_qtmload                                       ;0
	B	swi_qtmstart                                      ;1
	B	swi_qtmstop                                       ;2
	B	swi_qtmpause                                      ;3
	B	swi_qtmclear                                      ;4
	B	swi_qtminfo                                       ;5
	B	swi_qtmpos                                        ;6
	B	swi_qtmeffectctrl                                 ;7
	B	swi_qtmvolume                                     ;8
	B	swi_qtmsetsamplespeed                             ;9
	B	swi_qtmdmabuffer                                  ;10
	B	swi_qtmremovechan                                 ;11
	B	swi_qtmrestorechan                                ;12
	B	swi_qtmstereo                                     ;13
	B	swi_qtmsonglength                                 ;14
	B	swi_qtmreadsequence                               ;15
	B	swi_qtmvubarctrl                                  ;16
	B	swi_qtmreadvulevels                               ;17
	B	swi_qtmreadsample                                 ;18
	B	swi_qtmreadspeed                                  ;19
	B	swi_qtmplaysample                                 ;20
	B	swi_qtmsongstatus                                 ;21
	B	swi_qtmplayingtime                                ;22
	B	swi_qtmplayraw                                    ;23
	B	swi_qtmsoundctrl                                  ;24
	B	swi_qtmswitableaddr                               ;25
	B	swi_qtmregistersmp                                ;26
	B	swi_qtmsetspeed                                   ;27
	B	swi_qtmmusicvolume                                ;28
	B	swi_qtmsamplevolume                               ;29
	B	swi_qtmmusicoptions                               ;30
	B	swi_qtmmusicinterrupt                             ;31
	B	swi_qtmreadchanneldata                            ;32
	B	swi_qtmreadnoteword                               ;33
	B	swi_qtmdmahandler                                 ;34
	.if alphatest
	B	swi_qtmdebug
	.endif
endSWItable:
UnknownSWIerror:
	MOV	R0,#0x80000000
	SUBS	R0,R0,#1
	ADR	R0,swierror
	MOV	PC,R14
swierror:
	.long	0x1E6                                         ;<-- ???? wot a c**p error number
	.byte	"Unknown QTMTracker operation"
	.byte	0
	.p2align 2


exitqtm:
	STMFD	R13!,{R12,R14}
	LDR	R12,[R12]                                       ;v1.49 FNlong_adr("  ",12,song_data)
	MOV	R0,#0
	MVN	R1,#0
	BL	swi_qtmvubarctrl
	BL	swi_qtmclear
	LDRB	R0,[R12,#armchip]                              ;v1.48
	CMP	R0,#3                                           ;
	BLLE	release_a2_DMA                                 ;
	LDMVSFD	R13!,{R12,PC}                               ;if Arm2 or Arm3, release RMA for all the unrolled DMA code
	LDR	R0,[R12,#fake8bitDMA]
	TEQ	R0,#0
	BLNE	releaseRMA
	MOV	R0,R12                                          ;v1.49 last thing we do is...
	BL	releaseRMA                                       ;...release RMA for datablock ;-)
	LDMFD	R13!,{R12,PC}


claimRMA:                                            ;r0=size
	STMFD	R13!,{R1-R3,R14}
	MOV	R3,R0
	MOV	R0,#6
	SWI	XOS_Module                                      ;address in R2
	MOVVC	R0,R2
	LDMFD	R13!,{R1-R3,PC}                               ;returns r0=addr or VS


releaseRMA:
	STMFD	R13!,{R1-R3,R14}
	MOV	R2,R0
	MOV	R0,#7
	SWI	XOS_Module
	MOVVC	R0,#0
	LDMFD	R13!,{R1-R3,PC}


blankmemory:
	STMFD	R13!,{R0-R12,R14}                             ;address in R0, length in R1
	MOV	R2,#0
	MOV	R3,R2
	MOV	R4,R2
	MOV	R5,R2
	MOV	R6,R2
	MOV	R7,R2
	MOV	R8,R2
	MOV	R9,R2
	MOV	R10,R2
	MOV	R11,R2
	MOV	R12,R2
	MOV	R14,R2
blank256:
	SUBS	R1,R1,#0x100
	BMI	blankwords
	STMIA	R0!,{R2-R12,R14}                              ;48
	STMIA	R0!,{R2-R12,R14}                              ;96
	STMIA	R0!,{R2-R12,R14}                              ;144
	STMIA	R0!,{R2-R12,R14}                              ;192
	STMIA	R0!,{R2-R12,R14}                              ;240
	STMIA	R0!,{R2-R5}                                   ;256
	BGT	blank256
	LDMFD	R13!,{R0-R12,PC}
blankwords:
	ADD	R1,R1,#0x100
blank8:
	SUBS	R1,R1,#4
	STRGE	R2,[R0],#4
	SUBS	R1,R1,#4
	STRGE	R2,[R0],#4
	BGT	blank8
	LDMFD	R13!,{R0-R12,PC}


	; RISC OS 4 service call table
servicetable:
	.long	0                                             ;Flag word
	.long	servicedispatch                               ;Dispatch code
	.long	0x27                                          ;Services, listed in increasing order
	;EQUD    &46                     ;v1.49 fix, ModeChange service n/r on RO3.5+
	.long	0                                             ;Terminator
	.long	servicetable                                  ;Pointer to table in word before .services
	.p2align 2
services:
	MOV	R0,R0                                           ;Magic marker for OS 4 service call table to work
servicedispatch:
	CMP	R1,#0x46
	BEQ	domodechange                                    ;R2,R3 = mode and monitor type on OS 3.1+, but not user call!
	CMP	R1,#0x27
	BEQ	handlereset
	MOV	PC,R14


handlereset:                                         ;&27
	STMFD	R13!,{R0,R12,R14}
	LDR	R12,[R12]                                       ;v1.49 FNlong_adr("  ",12,song_data)
	LDRB	R0,[R12,#songstatus]
	TST	R0,#1 << 2                                      ;are we playing?
	BICNE	R0,R0,#1 << 2
	STRNEB	R0,[R12,#songstatus]                         ;if playing, clear 'playing' flag - so qtm_start will work!
	BLNE	swi_qtmstart
	CMP	R0,R0                                           ;don't return errors (clear V)
	LDMFD	R13!,{R0,R12,PC}


domodechange:                                        ;&46 n/r on RO3.5+
	STMFD	R13!,{R0-R1,R12,R14}
	LDR	R12,[R12]                                       ;v1.49 FNlong_adr("  ",12,song_data)
	LDRB	R1,[R12,#osversion]
	CMP	R1,#0xA5 - 0xA0                                 ;RO3.5+? v1.49 fix - previously checked for 16bit sound...
	LDMGEFD	R13!,{R0-R1,R12,PC}                         ;...but RO3.5+ won't affect pitch on mode change (even if 8bit!)
	BL	twangsoundsystem                                 ;force RISC OS 2/3 to update sound system after mode change!
	LDRB	R1,[R12,#soundflags]
	TST	R1,#1 << 2
	BEQ	oldmachinemode                                  ;if new VIDC clock flag clear, use pre-A5000 timed calc routine
newmachinemode:                                      ;*** also jumped here from 'initVIDCandpitch' ***
qtm_mod_adr487:                                      ;for A5000 and later, we simply read the new mode's clock speed
	.long	0xE28F0000-(((readclock-qtm_mod_adr487)>>31)&0x00400000)+((((readclock-qtm_mod_adr487-8)^((readclock-qtm_mod_adr487-8)>>31))-((readclock-qtm_mod_adr487-8)>>31))&0xFF)
	.long	0xE2800C00-(((readclock-qtm_mod_adr487)>>31)&0x00400000)+(((((readclock-qtm_mod_adr487-8)^((readclock-qtm_mod_adr487-8)>>31))-((readclock-qtm_mod_adr487-8)>>31))>>8)&0xFF)
	ADD	R1,R12,#numberbuf_new - song_data               ;then go and see if pitches need recalcing!
	SWI	XOS_ReadVduVariables                            ;RiscPC and later should always return 24MHz (no impact to sound)
	LDR	R0,[R1]
	LDR	R1,[R12,#clockspeed]
	CMP	R0,R1
	LDMEQFD	R13!,{R0-R1,R12,PC}                         ;if same clock speed, just exit!
	STR	R0,[R12,#clockspeed]
	.if qtmrast
	AND	R1,R0,#0xFF00                                   ;v1.43se for RasterMan... adjust CIA dec value for VGA or other
	CMP	R1,#0x6200                                      ;are we currently 25175MHz? (well anywhere between 25088-25343)
	MOVNE	R1,#1 << 0x10                                 ;if not, use CIA decrement value for 24/36/48MHz
	MOVEQ	R1,#0xF400                                    ;if 25175MHz then..
	ORREQ	R1,R1,#0xD                                    ;..use CIA dec value for 25175MHz [CIAdec is n/r for normal QTM]
	STR	R1,[R12,#rm_CIAdec]                             ;store
	.endif
	MOV	R0,R0,LSL #0xC                                  ;if not RasterMan, we don't use CIAdec, since running off 100Hz
	MOV	R1,#0x3E8
	BL	r0_div_r1
	STR	R0,[R12,#shiftclock]                            ;else, recalc 'shiftclock' and go to recalc pitches!
	BL	recalc_uS_4clock
	LDMFD	R13!,{R0-R1,R12,PC}


oldmachinemode:                                      ;for pre-A5000 "old" machines, we manually calc the clock speed
	MOV	R0,#0                                           ;using timed # of DMA IRQs, before calcing the pitches... this
	STR	R0,[R12,#DMAinterrupts]                         ;allows QTM to determine correct pitch even if VIDC enhancer used
	STR	R0,[R12,#ClockCalcEnd]
	LDRB	R0,[R12,#soundflags]
	ORR	R0,R0,#1 << 3                                   ;flag for manual VIDC clock calc (pre-A5000 only!)
	STRB	R0,[R12,#soundflags]
	LDMFD	R13!,{R0-R1,R12,PC}


cmd_qtmstart:
	LDR	R12,[R12]                                       ;v1.49 FNlong_adr("  ",12,song_data)
	B	swi_qtmstart
cmd_qtmstop:
	LDR	R12,[R12]                                       ;v1.49 FNlong_adr("  ",12,song_data)
	B	swi_qtmstop
cmd_qtmpause:
	LDR	R12,[R12]                                       ;v1.49 FNlong_adr("  ",12,song_data)
	B	swi_qtmpause
cmd_qtmclear:
	LDR	R12,[R12]                                       ;v1.49 FNlong_adr("  ",12,song_data)
	B	swi_qtmclear
cmd_qtmload:
	LDR	R12,[R12]                                       ;v1.49 FNlong_adr("  ",12,song_data)
	STMFD	R13!,{R1-R2,R14}
	BL	check4x                                          ;r2=1 if 'x', 0 if not
	ADRVS	R0,err_syntaxload
	LDMVSFD	R13!,{R1-R2,PC}
	MOV	R1,#0
	BL	swi_qtmload
	LDMVSFD	R13!,{R1-R2,PC}
	CMP	R2,#0
	BLEQ	swi_qtmstart
	LDMFD	R13!,{R1-R2,PC}


check4x:
	STMFD	R13!,{R0,R14}
	CMP	R1,#2                                           ;number of params found
	MOVNE	R2,#0                                         ;less than 2, so put 0 in r2...
	LDMNEFD	R13!,{R0,PC}                                ;...and exit
findspace:
	LDRB	R2,[R0],#1
	CMP	R2,#0x20
	BNE	findspace
findnonspace:
	LDRB	R2,[R0],#1
	CMP	R2,#0x20
	BEQ	findnonspace
	CMP	R2,#0x78
	MOVEQ	R2,#1
	LDMEQFD	R13!,{R0,PC}
	MOV	R2,#0x80000000                                  ;if 2nd param was not 'x' then set up an error
	SUBS	R2,R2,#1
	LDMFD	R13!,{R0,PC}

err_syntaxload:
	.long	0xDC
	.byte	"Syntax: *QTMLoad <filename> [x]"
	.byte	0
	.p2align 2

unknown:
	.byte	"<unknown>",0x00
in15:
	.byte	"Sound Tracker compatible, 4 channel, 15 inst",0x00
	.p2align 2

cmd_qtminfo:
	LDR	R12,[R12]                                       ;v1.49 FNlong_adr("  ",12,song_data)
	STMFD	R13!,{R0-R6,R14}
qtm_mod_adr588:                                      ; FNlong_adr("  ",0,help)
	.long	0xE28F0000-(((help-qtm_mod_adr588)>>31)&0x00400000)+((((help-qtm_mod_adr588-8)^((help-qtm_mod_adr588-8)>>31))-((help-qtm_mod_adr588-8)>>31))&0xFF)
	.long	0xE2800C00-(((help-qtm_mod_adr588)>>31)&0x00400000)+(((((help-qtm_mod_adr588-8)^((help-qtm_mod_adr588-8)>>31))-((help-qtm_mod_adr588-8)>>31))>>8)&0xFF)
	MOV	R1,#0
	MOV	R2,R0
	SWI	XOS_Write0
	SWI	XOS_NewLine
	BL	swi_qtminfo                                      ;r3=channels
	STRVS	R0,[R13,#0]
	LDMVSFD	R13!,{R0-R6,PC}
	SWI	XOS_WriteS
	.byte	"Song name     : ",0x00
	.p2align 2
	SWI	XOS_Write0
	SWI	XOS_NewLine
	SWI	XOS_WriteS
	.byte	"Author        : ",0x00
	.p2align 2
	MOVS	R0,R1
	ADREQ	R0,unknown
	SWI	XOS_Write0
	SWI	XOS_NewLine
	SWI	XOS_WriteS
	.byte	"Position      : ",0x00
	.p2align 2
	BL	displaypos
	SWI	XOS_NewLine
	ADD	R3,R3,#0x30
	SWI	XOS_WriteS
	.byte	"Song type     : ",0x00
	.p2align 2
	CMP	R2,#0
	ADREQ	R0,in15
	CMP	R2,#1
	ADREQ	R0,in31
	CMP	R2,#2
	ADREQ	R0,pt31
	CMP	R2,#3
	ADREQ	R0,startrek
	STREQB	R3,starchan_1                                ;**THIS EDITS MODULE**
	STREQB	R3,starchan_2
	CMP	R2,#4
	ADREQ	R0,fasttrack
	STREQB	R3,fastchan_1                                ;**THIS EDITS MODULE**
	STREQB	R3,fastchan_2
	CMP	R2,#5
	ADREQ	R0,octalyser
	STREQB	R3,octachan_1                                ;**THIS EDITS MODULE**
	STREQB	R3,octachan_2
	SWI	XOS_Write0
	SWI	XOS_NewLine
	SWI	XOS_WriteS
	.byte	"Module length : ",0x00
	.p2align 2
	MOV	R0,R4
	ADD	R1,R12,#numberbuf_new - song_data               ;v1.48
	MOV	R2,#0xF
	SWI	XOS_ConvertSpacedCardinal4
	SWI	XOS_Write0
	SWI	XOS_WriteS
	.byte	" bytes",0x0A,0x0D,0x00
	.p2align 2
	LDMFD	R13!,{R0-R6,PC}

in31:
	.byte	"Sound Tracker compatible, 4 channel, 31 inst",0x00
pt31:
	.byte	"ProTracker, 4 channel (M.K.)",0x00
startrek:
	.byte	"StarTrekker, "
starchan_1:
	.byte	"? channel (FLT"
starchan_2:
	.byte	"?)",0x00
fasttrack:
	.byte	"FastTracker, "
fastchan_1:
	.byte	"? channel ("
fastchan_2:
	.byte	"?CHN)",0x00
octalyser:
	.byte	"Octalyser, "
octachan_1:
	.byte	"? channel (CD"
octachan_2:
	.byte	"?1)",0x00
	.p2align 2


displaypos:                                          ;**** only call if song loaded ****
	STMFD	R13!,{R0-R3,R14}
	BL	swi_qtmsonglength
	MOV	R3,R0
	MVN	R0,#0
	MVN	R1,#0
	BL	swi_qtmpos
	ADD	R1,R12,#numberbuf_new - song_data               ;v1.48
	MOV	R2,#0xF
	SWI	XOS_ConvertCardinal2
	MOV	R0,#0x2F
	STRB	R0,[R1],#1
	MOV	R0,R3
	MOV	R2,#0xF
	SWI	XOS_ConvertCardinal2
	ADD	R0,R12,#numberbuf_new - song_data               ;v1.48
	SWI	XOS_Write0
	LDMFD	R13!,{R0-R3,PC}


cmd_qtmpos:
	LDR	R12,[R12]                                       ;v1.49 FNlong_adr("  ",12,song_data)
	STMFD	R13!,{R14}
	BL	ensuresong
	LDMVSFD	R13!,{PC}
	CMP	R1,#0
	BNE	cmdsetpos
	SWI	XOS_WriteS
	.byte	"Position : ",0x00
	.p2align 2
	BL	displaypos
	SWI	XOS_NewLine
	LDMFD	R13!,{PC}

cmdsetpos:
	STMFD	R13!,{R0-R2}
	BL	check4x
	ADRVS	R0,err_setsyntax
	BVS	err_cmdsetseq
	CMP	R2,#1
	MOV	R1,R0
	MOV	R0,#0xA
	SWI	XOS_ReadUnsigned
	BVS	err_cmdsetseq
	MOV	R0,R2
	MOVNE	R1,#0
	MVNEQ	R1,#0
	BL	swi_qtmpos
err_cmdsetseq:
	STRVS	R0,[R13,#0]
	LDMFD	R13!,{R0-R2,PC}

err_setsyntax:
	.long	0xDC
	.byte	"Syntax: *QTMPos [<position> [x]]"
	.byte	0
	.p2align 2


cmd_qtmvolume:
	LDR	R12,[R12]                                       ;v1.49 FNlong_adr("  ",12,song_data)
	STMFD	R13!,{R0-R2,R14}
	CMP	R1,#1
	BNE	displayvol
	MOV	R1,R0
	MOV	R0,#0xA
	SWI	XOS_ReadUnsigned
	MOVVC	R0,R2
	BLVC	swi_qtmvolume
	STRVS	R0,[R13,#0]
	LDMFD	R13!,{R0-R2,PC}

displayvol:
	MVN	R0,#0
	BL	swi_qtmvolume
	ADD	R1,R12,#numberbuf_new - song_data               ;v1.48
	MOV	R2,#0xF
	SWI	XOS_ConvertCardinal1
	SWI	XOS_WriteS
	.byte	"Current volume level: ",0x00
	.p2align 2
	SWI	XOS_Write0
	SWI	XOS_NewLine
	LDMFD	R13!,{R0-R2,PC}


cmd_qtmdisable:
	LDR	R12,[R12]                                       ;v1.49 FNlong_adr("  ",12,song_data)
	STMFD	R13!,{R0-R4,R14}
	CMP	R1,#1
	BNE	showdisabled
	MOV	R1,R0
	MOV	R0,#0x10
	SWI	XOS_ReadUnsigned
	BVS	err_cmddisable
	MOV	R0,R2
	MOV	R1,#0
	BL	swi_qtmeffectctrl
	BVS	err_cmddisable
	SWI	XOS_WriteS
	.byte	"Effect disabled",0x0A,0x0D,0x00
	.p2align 2
err_cmddisable:
	STRVS	R0,[R13,#0]
	LDMFD	R13!,{R0-R4,PC}

showdisabled:
	MVN	R0,#0
	BL	swi_qtmeffectctrl
	SUB	R2,R0,#0xFF00
	SUBS	R2,R2,#0xFF
	SUBEQ	R2,R1,#0xFF00
	SUBEQS	R2,R2,#0xFF
	BEQ	nonedisabled
	SWI	XOS_WriteS
	.byte	"Effect(s) disabled are: ",0x00
	.p2align 2
	MOV	R3,R0
	MOV	R4,R1
	MOV	R5,#1
	MOV	R6,#0
	MOV	R7,#0                                           ;flag; bit 0 on=E fx, bit 1 on=done first effect
	ADD	R1,R12,#numberbuf_new - song_data               ;v1.48
	MOV	R2,#0xF
anydisabled:
	TST	R3,R5,LSL R6
	BNE	notthiseffect
	TST	R7,#1 << 1
	SWINE	0x100 + 0x2C                                  ;',' if after first effect
	ORREQ	R7,R7,#1 << 1
	TST	R7,#1 << 0
	ORRNE	R0,R6,#0xE0                                   ;'E' effect
	MOVEQ	R0,R6
	MOV	R2,#0xF
	SWI	XOS_ConvertHex2
	MOV	R1,R0
	SWI	XOS_Write0
notthiseffect:
	ADD	R6,R6,#1
	CMP	R6,#0xF
	BLE	anydisabled
	TST	R7,#1 << 0
	MOVEQ	R3,R4
	MOVEQ	R6,#0
	ORREQ	R7,R7,#1 << 0
	BEQ	anydisabled
	SWI	XOS_NewLine
	LDMFD	R13!,{R0-R4,PC}

nonedisabled:
	SWI	XOS_WriteS
	.byte	"No effects disabled",0x0A,0x0D,0x00
	.p2align 2
	LDMFD	R13!,{R0-R4,PC}


cmd_qtmenable:
	LDR	R12,[R12]                                       ;v1.49 FNlong_adr("  ",12,song_data)
	STMFD	R13!,{R0-R2,R14}
	MOV	R1,R0
	MOV	R0,#0x10
	SWI	XOS_ReadUnsigned
	BVS	err_cmdenable
	MOV	R0,R2
	MOV	R1,#1
	BL	swi_qtmeffectctrl
	BVS	err_cmdenable
	SWI	XOS_WriteS
	.byte	"Effect enabled",0x0A,0x0D,0x00
	.p2align 2
err_cmdenable:
	STRVS	R0,[R13,#0]
	LDMFD	R13!,{R0-R2,PC}


cmd_qtmsamples:
	LDR	R12,[R12]                                       ;v1.49 FNlong_adr("  ",12,song_data)
	STMFD	R13!,{R14}
	BL	ensuresong
	LDMVSFD	R13!,{PC}
	STMFD	R13!,{R0-R9}
	SWI	XOS_WriteS
	.byte	"No. Sample text            Vol Length RepOff RepLen FTune",0x0D,0x0A,0x00
	.p2align 2
	MOV	R0,#0x2D
	MOV	R1,#0x39
	BL	repeatchar                                       ;v1.48
	SWI	XOS_NewLine
	;EQUS    "---------------------------------------------------------"+CHR$13+CHR$10
	;EQUB     00                     ;    00  00000  00000  00000    -0
	ADD	R9,R12,#numberbuf_new - song_data               ;v1.48
	LDRB	R8,[R12,#songtype]                             ;was #insts
	TEQ	R8,#0
	MOVEQ	R8,#0xF
	MOVNE	R8,#0x1F
	MOV	R7,#1
printsamples:
	MOV	R0,R7
	BL	swi_qtmreadsample
	CMP	R1,#0
	LDRB	R6,[R0]
	CMPEQ	R6,#0
	BEQ	skipthissample
	STMFD	R13!,{R0-R2}
	MOV	R0,R7
	MOV	R1,R9
	MOV	R2,#0xF
	SWI	XOS_ConvertHex2
	SWI	XOS_Write0
	SWI	0x100 + 0x20
	SWI	0x100 + 0x20
	CMP	R6,#0
	SWIEQ	0x100 + 0x2D
	LDRNE	R0,[R13,#0]
	MOVNE	R1,#0x16
	BLNE	printnoctrl
	SWI	0x100 + 0xD                                     ;get back to start of line
	MOV	R1,#0+((2 + 2) + 0x16) + 2                      ;v1.48 fix - just go to start of line and move cursor one by one
	MOV	R0,#9                                           ;VDU9 = cursor right one place
	BL	repeatchar                                       ;should now work in task window...
	;BL      tab_n
	MOV	R0,R4
	CMP	R0,#0xA
	MOV	R1,R9
	MOV	R2,#0xF
	SWI	XOS_ConvertCardinal1
	SWILT	0x100 + 0x20
	SWI	XOS_Write0
	SWI	0x100 + 0x20
	LDR	R0,[R13,#4]
	MOV	R1,R9
	MOV	R2,#6
	SWI	XOS_ConvertCardinal2
	MOVS	R1,R2
	BLNE	spaces
	SWI	XOS_Write0
	LDMFD	R13!,{R0-R2}
	SWI	0x100 + 0x20
	MOV	R0,R2
	MOV	R1,R9
	MOV	R2,#6
	SWI	XOS_ConvertCardinal2
	MOVS	R1,R2
	BLNE	spaces
	SWI	XOS_Write0
	SWI	0x100 + 0x20
	MOV	R0,R3
	MOV	R1,R9
	MOV	R2,#6
	SWI	XOS_ConvertCardinal2
	MOVS	R1,R2
	BLNE	spaces
	SWI	XOS_Write0
	MOV	R1,#4
	BL	spaces
	MOV	R0,R5                                           ;signed -8 to 7 byte!
	MOV	R1,R9
	MOV	R2,#0xF
	SWI	XOS_ConvertInteger1
	CMP	R5,#0
	SWIGE	0x100 + 0x20                                  ;add space if not -ve
	SWI	XOS_Write0
	SWI	XOS_NewLine
skipthissample:
	ADD	R7,R7,#1
	CMP	R7,R8
	BLE	printsamples
	LDMFD	R13!,{R0-R9,PC}

printnoctrl:                                         ;prints R1 bytes from string at R0, no ctrl chars
	STMFD	R13!,{R0-R2,R14}
	MOV	R2,R0
printloop:
	LDRB	R0,[R2],#1
	CMP	R0,#0x20
	SWIGE	XOS_WriteC
	SUBS	R1,R1,#1
	BNE	printloop
	LDMFD	R13!,{R0-R2,PC}

spaces:                                              ;prints R1 spaces
	STMFD	R13!,{R0-R1,R14}
	MOV	R0,#0x20
	B	repeatcloop

repeatchar:                                          ;v1.48 R0=ascii code, R1=number to print
	STMFD	R13!,{R0-R1,R14}
repeatcloop:
	SWI	OS_WriteC
	SUBS	R1,R1,#1
	BGT	repeatcloop
	LDMFD	R13!,{R0-R1,PC}

	;.spaces                                 ;prints R1 spaces
	;STMFD   R13!,{R1,R14}
	;.spaceloop
	;SWI     256+ASC" "
	;SUBS    R1,R1,#1
	;BNE     spaceloop
	;LDMFD   R13!,{R1,PC}

	;.tab_n                                  ;move x position to R0 (but doesn't work in task window)
	;STMFD   R13!,{R0-R3,R14}
	;MOV     R3,R0
	;MOV     R0,#165
	;SWI     "XOS_Byte"                      ;OS_Byte 165 always returns x=0,y=0 in task window
	;SWI     256+31
	;MOV     R0,R3
	;SWI     "XOS_WriteC"
	;MOV     R0,R2
	;SWI     "XOS_WriteC"
	;LDMFD   R13!,{R0-R3,PC}


cmd_qtmtrans:                                        ;new for v1.44
	LDR	R12,[R12]                                       ;v1.49 FNlong_adr("  ",12,song_data)
	STMFD	R13!,{R0-R2,R14}
	CMP	R1,#1
	BNE	displaytrans
	LDRB	R1,[R0],#1
	CMP	R1,#0x4F
	CMPNE	R1,#0x6F
	BNE	err_cmdtrans
	LDRB	R1,[R0],#1
	CMP	R1,#0x4E
	CMPNE	R1,#0x6E
	BEQ	cmd_transon
	CMP	R1,#0x46
	CMPNE	R1,#0x66
	BNE	err_cmdtrans
	LDRB	R1,[R0],#1
	CMP	R1,#0x46
	CMPNE	R1,#0x66
	BNE	err_cmdtrans
cmd_transoff:
	LDRB	R1,[R0],#1
	CMP	R1,#0x20
	BGE	err_cmdtrans
	MVN	R0,#0
	MVN	R1,#0
	MVN	R2,#0
	BL	swi_qtmsoundctrl
	TST	R1,#1
	LDMEQFD	R13!,{R0-R2,PC}                             ;already off!
	BIC	R1,R1,#1
	BL	swi_qtmsoundctrl
	LDMFD	R13!,{R0-R2,PC}


cmd_transon:
	LDRB	R1,[R0],#1
	CMP	R1,#0x20
	BGE	err_cmdtrans
	MVN	R0,#0
	MVN	R1,#0
	MVN	R2,#0
	BL	swi_qtmsoundctrl
	TST	R1,#1
	LDMNEFD	R13!,{R0-R2,PC}                             ;already on!
	ORR	R1,R1,#1
	BL	swi_qtmsoundctrl
	LDMFD	R13!,{R0-R2,PC}


displaytrans:
	SWI	XOS_WriteS
	.byte	"QTM Transparent Sound System is ",0x00
	.p2align 2
	LDRB	R0,[R12,#soundflags]
	TST	R0,#2
	ADREQ	R0,text_off
	ADRNE	R0,text_on
	SWI	XOS_Write0
	SWI	XOS_NewLine
	LDMFD	R13!,{R0-R2,PC}


err_cmdtrans:
	MOV	R0,#0x80000000
	SUBS	R0,R0,#1
	LDMFD	R13!,{R0-R2,R14}
	ADR	R0,err_transsyntax
	MOV	PC,R14

err_transsyntax:
	.long	0xDC
	.byte	"Syntax: *QTMTransparent [On|Off]"
	.byte	0
	.p2align 2


text_on:
	.byte	"on",0x00
text_off:
	.byte	"off",0x00
	.p2align 2


swi_qtmload:                                         ;r0=filename/0/-1  r1=0/addr
	STMFD	R13!,{R0-R9,R14}
	CMP	R0,#0
	BEQ	memoryload
	CMN	R0,#1
	BEQ	transferload
	MOV	R9,R1
	MOV	R1,R0
	MOV	R0,#5
	SWI	XOS_File                                        ;get module disc-length in r4
	CMP	R0,#1                                           ;was it a file?
	MOVNE	R2,R0
	MOVNE	R0,#0x13
	SWINE	XOS_File                                      ;generate error if not found(0)/directory(2)/image file(3)
	BVS	err_qtmload
	LDRB	R3,[R12,#songstatus]
	TST	R3,#1 << 0
	BLNE	swi_qtmclear
	BVS	err_qtmload
	BL	init
	CMP	R9,#0
	MOVNE	R2,R9
	BNE	loadtomem
	MOV	R0,#6
	MOV	R3,R4
	SWI	XOS_Module                                      ;claim some RMA
	BVS	err_RMAclaim                                    ;special RMA error message
	;LDR     R0,[R12,#workspaceptr]  ;from here, call 'err_loadRMA' on QTM_Load error! ********
	;STR     R2,[R0]
loadtomem:
	TEQ	R9,#0
	MOVNE	R6,#1                                         ;songstatus - clears bit 2 (playing) and bits 3-7
	MOVEQ	R6,#3                                         ;if load address was 0, it was an RMA load, else not
	STR	R2,[R12,#songaddr]
	STR	R4,[R12,#songlength]
	MOV	R0,#0xFF
	MOV	R3,#0
	SWI	XOS_File
continueload:                                        ;(V should be clear on all jumps to this point)
	STRB	R6,[R12,#songstatus]                           ;store correct song flags!                      fix 1/1/96
	BVS	err_loadRMA                                     ;(from above...) load error, so release RMA...
qtm_mod_adr1131:                                     ; FNlong_adr("  ",11,textdata)
	.long	0xE28FB000-(((textdata-qtm_mod_adr1131)>>31)&0x00400000)+((((textdata-qtm_mod_adr1131-8)^((textdata-qtm_mod_adr1131-8)>>31))-((textdata-qtm_mod_adr1131-8)>>31))&0xFF)
	.long	0xE28BBC00-(((textdata-qtm_mod_adr1131)>>31)&0x00400000)+(((((textdata-qtm_mod_adr1131-8)^((textdata-qtm_mod_adr1131-8)>>31))-((textdata-qtm_mod_adr1131-8)>>31))>>8)&0xFF)
	BL	init_type                                        ;v1.44 check format and init type (now sets songchans, songtype and insts)
	BLVC	initsong                                       ; \
	BLVC	init_title                                     ;  }- require r12=song data, r11=text data
	BLVC	init_author                                    ; /
	LDMVCFD	R13!,{R0-R9,PC}                             ;exit if no error... else continue...
err_loadRMA:                                         ;handler if error occurs **AFTER** RMA possibly claimed!
	STR	R0,[R13,#0]                                     ;stack the error pointer (R0-R9, R14 stacked)
	LDRB	R0,[R12,#songstatus]
	TST	R0,#1 << 1                                      ;test if we own the RMA or not...
	MOVNE	R0,#7                                         ;and if we do, we'll have to release it
	LDRNE	R2,[R12,#songaddr]
	SWINE	XOS_Module
	MOV	R3,#0                                           ;** (nothing we can do if RMA wouldn't release...!) **
	;LDR     R0,[R12,#workspaceptr]
	;STR     R3,[R0]
	STRB	R3,[R12,#songstatus]                           ;removed the song, so set correct status
	MOV	R0,#0x80000000
	SUBS	R0,R0,#1                                       ;set V flag
	LDMFD	R13!,{R0-R9,PC}


err_qtmload:                                         ;handler if error occurs **BEFORE** RMA claimed
	STR	R0,[R13,#0]
	LDMFD	R13!,{R0-R9,PC}


memoryload:
	LDRB	R3,[R12,#songstatus]
	TST	R3,#1 << 0
	BLNE	swi_qtmclear
	BVS	err_qtmload
	BL	init                                             ;song length blanked, 'initsong' will now re-calc length
	STR	R1,[R12,#songaddr]
	MOVS	R6,#1 << 0                                     ;set songstatus flags, and clear V on exit
	B	continueload


transferload:                                        ;R0=-1, R1=memory address
	LDRB	R3,[R12,#songstatus]
	TST	R3,#1 << 0
	BLNE	swi_qtmclear
	BVS	err_qtmload
	BL	init                                             ;song length blanked, 'initsong' will now re-calc length
	BL	checkRMAmemory                                   ;R0=0 if not RMA block, R0=1 if we get to keep this block
	CMP	R0,#1                                           ;(if it was an RMA block, it also reads the size as len!)
	BEQ	exittransfer
	STR	R1,[R12,#songaddr]                              ;temporariliy put song address here, so we can check type
	BL	init_type                                        ;v1.44 check format, init type - must call BEFORE calc. length!
	BVS	err_loadRMA                                     ;not a ProTracker format song, so exit...
	MOV	R11,R1                                          ;R11=addr of song
	BL	workoutlength                                    ;work out actual song length (R0), entry R11=addr
	MOV	R3,R0                                           ;R3=length of song
	MOV	R0,#6
	SWI	XOS_Module                                      ;claim some RMA
	BVS	err_RMAclaim                                    ;special RMA error message
	MOV	R1,R2
movesongwords:                                       ;r2=new start  r11=old start  r3=length
	SUBS	R3,R3,#4
	LDRGE	R0,[R11],#4
	STRGE	R0,[R2],#4
	BGT	movesongwords
	ADDLT	R3,R3,#4
movesongbytes:
	SUBS	R3,R3,#1
	LDRGEB	R0,[R11],#1
	STRGEB	R0,[R2],#1
	BGT	movesongbytes
exittransfer:
	STR	R1,[R12,#songaddr]
	;LDR     R0,[R12,#workspaceptr]
	;STR     R1,[R0]
	MOVS	R6,#3                                          ;song loaded, and OUR RMA now (set songstatus) + clear V
	B	continueload                                      ;sets songstatus to R6


checkRMAmemory:                                      ;tests address in R1 is the start of an RMA-Heap block
	STMFD	R13!,{R1-R3,R14}                              ;returns R0=0 if NOT start of RMA block, R0=1 if RMA block
	MOV	R2,R1
	MOV	R0,#1
	SWI	XOS_ReadDynamicArea                             ;read RMA start
	MOV	R1,R0
	MOV	R0,#6
	SWI	XOS_Heap                                        ;attempt to read size of this RMA block (to R3)
	MOVVC	R0,#1                                         ;block is RMA-Heap block start
	SUBVC	R3,R3,#0x10                                   ;*** (currently length returned is +16)       ************
	STRVC	R3,[R12,#songlength]                          ;*** RMA block, so store the reserved length! ************
	MOVVS	R0,#0                                         ;block is not the start of an RMA-Heap block
	LDMFD	R13!,{R1-R3,PC}                               ;exit, NO errors returned


err_RMAclaim:                                        ;r0-r9,r14 stored on entry, r3=size of RMA needed
	MOV	R0,R3,LSR #0xA
	ADD	R0,R0,#1
	ADR	R1,RMAneeded
	MOV	R2,#8
	SWI	XOS_BinaryToDecimal                             ;convert number, without terminator
	BVS	err_qtmload
	ADD	R1,R1,R2
	MOV	R0,#0x4B
	STRB	R0,[R1],#1                                     ;**THIS EDITS MODULE**
	MOV	R0,#0x20
	STRB	R0,[R1],#1
	MOV	R0,#0x66
	STRB	R0,[R1],#1
	MOV	R0,#0x72
	STRB	R0,[R1],#1
	MOV	R0,#0x65
	STRB	R0,[R1],#1
	MOV	R0,#0x65
	STRB	R0,[R1],#1                                     ;add '...K free' to error message
	MOV	R0,#0
	STRB	R0,[R1],#1                                     ;ensure there is a message terminator (zero byte)
	ADR	R0,RMAerror
	STR	R0,[R13,#0]
	MOV	R0,#0x80000000
	SUBS	R0,R0,#1                                       ; Set v flag
	LDMFD	R13!,{R0-R9,PC}

RMAerror:                                            ;**THIS EDITS MODULE** will need about 76 bytes to build this in RMA databank
	.long	(qtm_error + 0)
	.byte	"Not enough memory in RMA to load song, requires at least "
RMAneeded:
	.long	0
	.long	0
	.byte	"K free"
	.byte	0
	.p2align 2


swi_qtmclear:
	STMFD	R13!,{R0-R3,R14}
	LDRB	R3,[R12,#songstatus]
	TST	R3,#1 << 0
	BNE	swi_qtmclear_noclear
	BL	clearinfos                                       ;always ensure channel DMA blocks are clear
	BL	waitchans                                        ;       & wait for chanels to clear
	;LDRB    R14,[R12,#musicoptbyte]
	;TST     R14,#%1<<3              ;v1.46, check MusicOptions bit3...
	LDRB	R14,[R12,#soundflags]                          ;v1.49, check soundflags bit6...
	TST	R14,#1 << 6                                     ;
	BLEQ	resetsound                                     ;...if clear, ensure sound is returned to RO
	LDMFD	R13!,{R0-R3,PC}
swi_qtmclear_noclear:                                ;get here if song loaded
	BL	swi_qtmstop
	BVS	err_qtmclear
	CMN	R0,#1
	BLEQ	deinit_samples
	TST	R3,#1 << 1
	MOVNE	R0,#7
	LDRNE	R2,[R12,#songaddr]
	SWINE	XOS_Module                                    ;release song RMA
	BVS	err_qtmclear
	TST	R3,#1 << 1                                      ;*32Bit fix, NE (below) not preserved after SWI! v1.46 5/1/22*
	MOV	R3,#0
	;LDR     R0,[R12,#workspaceptr]
	;STR     R3,[R0]
	STRB	R3,[R12,#songstatus]                           ;stoped and cleared the song, so set correct status
	MOVNE	R0,#1
	MOVNE	R1,#0+((-0x10) * 0x400) * 0x400               ;move down RMA by 16Mb!!!
	SWINE	XOS_ChangeDynamicArea                         ;this call WILL ALWAYS set the V flag (maybe not on RPC..?)
	CMP	R0,R0                                           ;...Clear V flag incase above is true
	LDMFD	R13!,{R0-R3,PC}
err_qtmclear:
	STR	R0,[R13,#0]
	LDMFD	R13!,{R0-R3,PC}


swi_qtmpause:                                        ;may be called from play routine with IRQs off
	STMFD	R13!,{R0-R3,R14}                              ; (F-00) if so, stop playing, but keep sound on
	LDRB	R3,[R12,#songstatus]
	TST	R3,#1 << 2                                      ;are we playing?
	BLNE	swi_qtmpause_noclear                           ; yes, so skip the following...
	BL	clearinfos                                       ;not playing - ensure channel DMA blocks clear
	BL	waitchans                                        ;            - wait for chanels to clear
	;LDRB    R14,[R12,#musicoptbyte]
	;TST     R14,#%1<<3              ;v1.46, check MusicOptions bit3...
	LDRB	R14,[R12,#soundflags]                          ;v1.49, check soundflags bit6...
	TST	R14,#1 << 6                                     ;
	BLEQ	resetsound                                     ;...if clear, ensure sound is returned to RO
	LDMFD	R13!,{R0-R3,PC}
swi_qtmpause_noclear:                                ;may still arrive here with IRQs off...
	.if (qtmrast) == 0
	MOV	R0,#0x1C                                        ;not required for QTM RasterMan edition
qtm_mod_adr1323:                                     ; FNlong_adr("  ",1,CIAhandler)
	.long	0xE28F1000-(((CIAhandler-qtm_mod_adr1323)>>31)&0x00400000)+((((CIAhandler-qtm_mod_adr1323-8)^((CIAhandler-qtm_mod_adr1323-8)>>31))-((CIAhandler-qtm_mod_adr1323-8)>>31))&0xFF)
	.long	0xE2811C00-(((CIAhandler-qtm_mod_adr1323)>>31)&0x00400000)+(((((CIAhandler-qtm_mod_adr1323-8)^((CIAhandler-qtm_mod_adr1323-8)>>31))-((CIAhandler-qtm_mod_adr1323-8)>>31))>>8)&0xFF)
	MOV	R2,R12
	SWI	XOS_Release
	BVS	pause_err
	.endif
	BIC	R3,R3,#1 << 2
	STRB	R3,[R12,#songstatus]                           ;stopped the song, so set correct status
	SWI	XOS_ReadMonotonicTime
	STR	R0,[R12,#pause_time]
	LDR	R1,[R12,#start_time]
	SUB	R0,R0,R1
	LDR	R14,[R12,#total_time]
	ADD	R14,R14,R0                                      ;v1.45 fix - total time was not accumulated
	STR	R14,[R12,#total_time]                           ;            on repeated QTM_Pause/Stop's
	BL	backupinfos
	BL	clearinfos
	; LDRB    R0,[R12,#chans_use]     ;needed by 'waitchans' below (not at moment!)
	LDRB	R14,[R12,#oldchansused]
	STRB	R14,[R12,#chans_use]                           ;if 4 chan default, but playing 8, go back to 4
	;* v1.43 - if called with IRQs off we exit now
	TEQ	PC,PC                                           ;* Test 32bit
	MOVNE	R2,PC                                         ;* 26bit PSR into R2
	MOVNE	R2,R2,LSR #0x14                               ;* shift so IRQ bit same position as 32bit PSR
	.long	0x010F2000                                    ;* 32bit PSR into R2
	TST	R2,#1 << 7                                      ;* IRQs off?
	LDMNEFD	R13!,{R0-R3,PC}                             ;* if IRQs off, we can't release sound, so exit
	BL	waitchans                                        ;wait for chanels to clear
	;LDRB    R14,[R12,#musicoptbyte]
	;TST     R14,#%1<<3              ;v1.46, check MusicOptions bit3...
	LDRB	R14,[R12,#soundflags]                          ;v1.49, check soundflags bit6...
	TST	R14,#1 << 6                                     ;
	BLEQ	resetsound                                     ;...if clear, ensure sound is returned to RO
	CMP	R0,R0                                           ;<< v1.42 fix - was using LDM {...PC}^
	LDMFD	R13!,{R0-R3,PC}                               ;<<
pause_err:
	STRVS	R0,[R13,#0]
	LDMFD	R13!,{R0-R3,PC}


waitchans:                                           ;(in future... R0=number of song channels in use? useful?)
	;            ;previous versions just blanked the current DMA buffer...
	;            ;* v1.43 ...this was ok on older systems, but not Pi
	;
	;STMFD   R13!,{R14}
	;MOV     R14,#0
	;STR     R14,[R12,#chanendflags] ;start channels clearing
	;LDMFD   R13!,{PC}
	;
	STMFD	R13!,{R0-R2,R14}
	MOV	R0,#0                                           ;we want chans to clear
	STR	R0,[R12,#chanendflags]                          ;initialise channel clearing
	;
	.if (qtmrast) == 0
	SWI	XOS_ReadMonotonicTime                           ;can't call this if IRQ off!
	ADD	R2,R0,#3                                        ;1/33rd of a sec delay
wchan_loop:
	SWI	XOS_ReadMonotonicTime
	CMP	R0,R2
	BLT	wchan_loop
	.endif
	LDMFD	R13!,{R0-R2,PC}


swi_qtmstop:
	STMFD	R13!,{R1,R14}
	BL	swi_qtmpause
	BLVC	clearsongvars
	MOVVC	R1,#0
	STRVCB	R1,[R12,#oldinfoinuse]                       ;qtmoldinfo backup DMA block no longer valid
	LDMFD	R13!,{R1,PC}


swi_qtmstart:
	STMFD	R13!,{R14}
	BL	ensuresong
	LDMVSFD	R13!,{PC}
	STMFD	R13!,{R0-R3}
	LDRB	R3,[R12,#songstatus]
	TST	R3,#1 << 2                                      ;are we playing?
	LDMNEFD	R13!,{R0-R3,PC}
	BL	restoreinfos
	LDRB	R1,[R12,#chans_use]
	STRB	R1,[R12,#oldchansused]                         ;old channels used
	LDRB	R1,[R12,#songchans]
	TEQ	R1,#6
	MOVEQ	R1,#8                                         ;v1.45 if 6 channels, need to enable 8
	TEQ	R1,#8
	STREQB	R1,[R12,#chans_use]                          ;if switching to 8 channel song, turn on extra channels!
	BL	initQTMsound
	BVS	err_qtmstart
	.if (qtmrast) == 0
	MOV	R0,#0x1C                                        ;not required for QTM RasterMan edition
qtm_mod_adr1431:                                     ; FNlong_adr("  ",1,CIAhandler)
	.long	0xE28F1000-(((CIAhandler-qtm_mod_adr1431)>>31)&0x00400000)+((((CIAhandler-qtm_mod_adr1431-8)^((CIAhandler-qtm_mod_adr1431-8)>>31))-((CIAhandler-qtm_mod_adr1431-8)>>31))&0xFF)
	.long	0xE2811C00-(((CIAhandler-qtm_mod_adr1431)>>31)&0x00400000)+(((((CIAhandler-qtm_mod_adr1431-8)^((CIAhandler-qtm_mod_adr1431-8)>>31))-((CIAhandler-qtm_mod_adr1431-8)>>31))>>8)&0xFF)
	MOV	R2,R12
	SWI	XOS_Claim
	BVS	err_qtmstart
	.endif
	SWI	XOS_ReadMonotonicTime
	STR	R0,[R12,#start_time]
	ORR	R3,R3,#1 << 2
	STRB	R3,[R12,#songstatus]                           ;playing the song, so set correct status
	LDMFD	R13!,{R0-R3,PC}
err_qtmstart:
	STR	R0,[R13,#0]
	LDMFD	R13!,{R0-R3,PC}


backupinfos:                                         ;updated to v1.30a code 16/4/2001
	STMFD	R13!,{R0-R10,R14}                             ;nb. used to not store if channel state flag off
	;ADR     R0,qtmoldinfo+4         ;...now does store, but won't restore if channel state off
	ADD	R0,R12,#qtmoldinfo_new - song_data
	MOV	R1,#0x18 * 8                                    ;much improve/fix - now doesn't store if non-music samp playing!
	BL	blankmemory
	STRB	R1,[R12,#oldinfoinuse]                         ;R1<>0 (actually =196) flag that backup *is* valid
	LDRB	R8,[R12,#songchans]
	ADD	R1,R12,#DMA_blocks - song_data
backupachannel:
	LDMIA	R1!,{R2,R3,R4,R5,R6,R7}
	TST	R5,#0xFF00
	STMEQIA	R0!,{R2,R3,R4,R5,R6,R7}                     ;ON LY music channels!
	ADDNE	R0,R0,#0x18
	SUBS	R8,R8,#1
	BNE	backupachannel
	LDMFD	R13!,{R0-R10,PC}


clearinfos:                                          ;clear 8 channels DMA data
	STMFD	R13!,{R0-R5,R11,R14}
	ADD	R11,R12,#DMA_blocks - song_data
	MOV	R0,#0                                           ;4
	MOV	R1,#0                                           ;8
	MOV	R2,#0                                           ;12
	MOV	R3,#0                                           ;16
	MOV	R4,#0                                           ;20
	MOV	R5,#0                                           ;24 bytes
	STMIA	R11!,{R0-R5}
	STMIA	R11!,{R0-R5}
	STMIA	R11!,{R0-R5}
	STMIA	R11!,{R0-R5}
	STMIA	R11!,{R0-R5}
	STMIA	R11!,{R0-R5}
	STMIA	R11!,{R0-R5}
	STMIA	R11!,{R0-R5}
	LDMFD	R13!,{R0-R5,R11,PC}



restoreinfos:
	STMFD	R13!,{R0-R10,R14}
	;ADR     R0,qtmoldinfo+4
	ADD	R0,R12,#qtmoldinfo_new - song_data              ;v1.48 move qtmoldinfo to databanks
	LDRB	R1,[R12,#oldinfoinuse]                         ;v1.48...this will be <>0 (actually 196) if old info block valid
	TEQ	R1,#0
	LDMEQFD	R13!,{R0-R10,PC}                            ;backup not in use
	MOV	R1,#0
	STRB	R1,[R12,#oldinfoinuse]                         ;clear valid flag (v1.48)
	LDR	R9,[R12,#channelstate]
	MOV	R9,R9,LSR #1
	LDRB	R8,[R12,#songchans]
	ADD	R1,R12,#DMA_blocks - song_data
restoreachannel:
	MOVS	R9,R9,LSR #1
	LDMCSIA	R0!,{R2,R3,R4,R5,R6,R7}
	STMCSIA	R1!,{R2,R3,R4,R5,R6,R7}                     ;only music channels
	ADDCC	R0,R0,#0x18
	ADDCC	R1,R1,#0x18
	SUBS	R8,R8,#1
	BNE	restoreachannel
	LDMFD	R13!,{R0-R10,PC}


	;.qtmoldinfo
	;EQUD 0       ;in use flag
	;EQUD 0;EQUD 0;EQUD 0;EQUD 0;EQUD 0;EQUD 0 ; \
	;EQUD 0;EQUD 0;EQUD 0;EQUD 0;EQUD 0;EQUD 0 ;  }_ Backup space for DMA
	;EQUD 0;EQUD 0;EQUD 0;EQUD 0;EQUD 0;EQUD 0 ;  }  block (chans 1-4)
	;EQUD 0;EQUD 0;EQUD 0;EQUD 0;EQUD 0;EQUD 0 ; /
	;EQUD 0;EQUD 0;EQUD 0;EQUD 0;EQUD 0;EQUD 0 ; \
	;EQUD 0;EQUD 0;EQUD 0;EQUD 0;EQUD 0;EQUD 0 ;  }_ Backup space for DMA
	;EQUD 0;EQUD 0;EQUD 0;EQUD 0;EQUD 0;EQUD 0 ;  }  block (chans 5-8)
	;EQUD 0;EQUD 0;EQUD 0;EQUD 0;EQUD 0;EQUD 0 ; /


swi_qtmsongstatus:
	LDRB	R0,[R12,#songstatus]
	MOV	PC,R14


	.if alphatest
swi_qtmdebug:                                        ;alpha test debug SWI
	STMFD	R13!,{R3-R7,R14}
qtm_mod_adr1538:                                     ; FNlong_adr("",0,a2_jumptable)
	.long	0xE28F0000-(((a2_jumptable-qtm_mod_adr1538)>>31)&0x00400000)+((((a2_jumptable-qtm_mod_adr1538-8)^((a2_jumptable-qtm_mod_adr1538-8)>>31))-((a2_jumptable-qtm_mod_adr1538-8)>>31))&0xFF)
	.long	0xE2800C00-(((a2_jumptable-qtm_mod_adr1538)>>31)&0x00400000)+(((((a2_jumptable-qtm_mod_adr1538-8)^((a2_jumptable-qtm_mod_adr1538-8)>>31))-((a2_jumptable-qtm_mod_adr1538-8)>>31))>>8)&0xFF)
qtm_mod_adr1539:                                     ; FNlong_adr("",1,unroll_a2_DMA)
	.long	0xE28F1000-(((unroll_a2_DMA-qtm_mod_adr1539)>>31)&0x00400000)+((((unroll_a2_DMA-qtm_mod_adr1539-8)^((unroll_a2_DMA-qtm_mod_adr1539-8)>>31))-((unroll_a2_DMA-qtm_mod_adr1539-8)>>31))&0xFF)
	.long	0xE2811C00-(((unroll_a2_DMA-qtm_mod_adr1539)>>31)&0x00400000)+(((((unroll_a2_DMA-qtm_mod_adr1539-8)^((unroll_a2_DMA-qtm_mod_adr1539-8)>>31))-((unroll_a2_DMA-qtm_mod_adr1539-8)>>31))>>8)&0xFF)
	MOV	R2,R12
	LDMFD	R13!,{R3-R7,PC}
	.endif

	;new in v1.49
swi_qtmdmahandler:                                   ;returns R2 bit0=1 if RasterMan edition, bit1=1 if 4 chan only
	MOV	R2,#0+(qtmrast & 1) | ((maxchans == 4) & 2)
	;MVN R2,#0 ;for RMv0.29
	MOV	R1,R12                                          ;        R0=DMA handler addr, R1=R12 ptr
	LDR	R0,[R12,#QTMblock]                              ;RM uses SWI QTM_DMABuffer *twice* to get the two sound DMA addrs
	MOV	PC,R14                                          ;...see DMA routine


swi_qtminfo:
	STMFD	R13!,{R14}
	BL	ensuresong
	LDMVSFD	R13!,{PC}
	;FNlong_adr("  ",11,textdata)
	ADD	R0,R12,#songtitle_new - song_data
	LDRB	R1,[R12,#author_new - song_data]
	CMP	R1,#0
	ADDNE	R1,R0,#author_new - songtitle_new             ;v1.48 use offset from songtitle
	LDRB	R2,[R12,#songtype]
	LDRB	R3,[R12,#songchans]
	LDR	R4,[R12,#songlength]
	LDR	R5,[R12,#garbagedata]
	LDR	R6,[R12,#songaddr]
	LDMFD	R13!,{PC}


swi_qtmpos:
	STMFD	R13!,{R2-R3,R14}
	BL	ensuresong
	LDMVSFD	R13!,{R2-R3,PC}
	LDRB	R2,[R12,#lastsequence]
	LDRB	R3,[R12,#lastevent]
	CMN	R0,#1
	BLNE	setsequence
	BVS	err_setpos
	CMN	R1,#1
	BLNE	setevent
	MOVVC	R0,R2
	MOVVC	R1,R3
err_setpos:
	LDMFD	R13!,{R2-R3,PC}


setsequence:
	STMFD	R13!,{R1,R14}
	LDRB	R1,[R12,#maxsequence]
	CMP	R0,R1
	BGE	err_setsequence
	STRB	R0,[R12,#currentseq]
	STRB	R0,[R12,#lastsequence]
	MOV	R1,#0
	STRB	R1,[R12,#oldinfoinuse]                         ;qtmoldinfo backup DMA block no longer valid
	MOV	R1,#0xFF                                        ;R1=&FF to only clear music DMA data, change 29/7/96
	BL	clearDMAchans
	MOV	R1,#0                                           ;we want *MUSIC* chans to clear
	STR	R1,[R12,#chanendflags]
	CMP	R0,R0                                           ; Clear V
	LDMFD	R13!,{R1,PC}
err_setsequence:
	MOV	R0,#0x80000000
	SUBS	R0,R0,#1                                       ; Set V
	ADR	R0,seq_range
	LDMFD	R13!,{R1,PC}


setevent:
	STMFD	R13!,{R0,R14}
	CMP	R1,#0x3F
	BGT	err_setevent
	CMP	R0,R0                                           ; Clear V
	STRB	R1,[R12,#currentevent]
	STRB	R1,[R12,#lastevent]
	LDMFD	R13!,{R0,PC}
err_setevent:
	MOV	R0,#0x80000000
	SUBS	R0,R0,#1                                       ; Set V
	LDMFD	R13!,{R0,R14}
	ADR	R0,evt_range                                    ; I fixed a bug! woo!
	MOV	PC,R14

seq_range:
	.long	(qtm_error + 2)
	.byte	"Sequence number out of range"
	.byte	0
	.p2align 2
evt_range:
	.long	(qtm_error + 3)
	.byte	"Event number out of range"
	.byte	0
	.p2align 2


swi_qtmvolume:                                       ;updated for v1.48 28/1/23
	STMFD	R13!,{R1-R6,R14}
	LDRB	R5,[R12,#musicvolume]
	CMN	R0,#1
	MOVEQ	R0,R5                                         ;SWI QTM_Volume now returns music volume
	LDMEQFD	R13!,{R1-R6,PC}
	MOV	R6,#3                                           ;r6 -> bit0=set music volume, bit1=set sample volume
multivolumes:                                        ;r0=volume to set, r5=volume to return, r6=tables to set
	BL	checkvolrange
	LDMVSFD	R13!,{R1-R6,PC}
	TST	R6,#1
	STRNEB	R0,[R12,#musicvolume]
	TST	R6,#2
	STRNEB	R0,[R12,#samplevolume]
	MOV	R0,R0,LSL #0x10
	MOV	R1,#0x40
	BL	r0_div_r1                                        ;exit r0=scaler r1=64
	ADD	R2,R12,#volumetable - song_data
	ADD	R3,R2,#musicvoltable - volumetable
	ADD	R4,R2,#samplevoltable - volumetable
scalebothvols:
	MUL	R14,R1,R0
	MOV	R14,R14,LSR #0x10
	LDRB	R14,[R2,R14]
	TST	R6,#1
	STRNEB	R14,[R3,R1]
	TST	R6,#2
	STRNEB	R14,[R4,R1]
	SUBS	R1,R1,#1
	BGE	scalebothvols
	CMP	R0,R0                                           ; Clear V
	MOV	R0,R5
	LDMFD	R13!,{R1-R6,PC}


swi_qtmmusicvolume:                                  ;updated v1.48
	STMFD	R13!,{R1-R6,R14}
	LDRB	R5,[R12,#musicvolume]
	CMN	R0,#1
	MOVEQ	R0,R5
	LDMEQFD	R13!,{R1-R6,PC}
	MOV	R6,#1                                           ;only setting music volume, bit0=music vol, bit1=sample vol
	B	multivolumes                                      ;jump to multi-function scaling routine


swi_qtmsamplevolume:                                 ;updated v1.48
	STMFD	R13!,{R1-R6,R14}
	LDRB	R5,[R12,#samplevolume]
	CMN	R0,#1
	MOVEQ	R0,R5
	LDMEQFD	R13!,{R1-R6,PC}
	MOV	R6,#2                                           ;only setting music volume, bit0=music vol, bit1=sample vol
	B	multivolumes                                      ;jump to multi-function scaling routine


swi_qtmeffectctrl:                                   ;r0=effect number (0-F,E0-EF,-1), r1=effect state (1/0)
	STMFD	R13!,{R2-R5,R14}                              ;returns r0=old 0-F word, r1=old E0-EF word
	CMN	R0,#1
	LDREQ	R0,[R12,#FXflags]
	LDREQ	R1,[R12,#E_FXflags]
	LDMEQFD	R13!,{R2-R5,PC}
	BICS	R2,R0,#0xF
	CMPNE	R2,#0xE0
	BNE	err_swi_qtmeffectctrl
	LDR	R3,[R12,#FXflags]
	LDR	R4,[R12,#E_FXflags]
	CMP	R2,#0xE0
	MOVEQ	R5,R4
	MOVNE	R5,R3
	AND	R0,R0,#0xF
	CMP	R1,#0
	MOV	R1,#1
	MOV	R1,R1,LSL R0
	ORRNE	R5,R5,R1
	BICEQ	R5,R5,R1
	CMP	R2,#0xE0
	STREQ	R5,[R12,#E_FXflags]
	STRNE	R5,[R12,#FXflags]
	MOV	R0,R3
	MOV	R1,R4
	CMP	R0,R0                                           ; Clear V
	LDMFD	R13!,{R2-R5,PC}
err_swi_qtmeffectctrl:
	ADR	R0,effect_error
	MOV	R2,#0x80000000
	SUBS	R2,R2,#1                                       ; Set V
	LDMFD	R13!,{R2-R5,PC}

effect_error:
	.long	(qtm_error + 4)
	.byte	"Effect number out of range"
	.byte	0
	.p2align 2


swi_qtmsonglength:
	STMFD	R13!,{R14}
	BL	ensuresong
	LDRVCB	R0,[R12,#maxsequence]
	LDRVCB	R1,[R12,#maxpattern]
	LDMFD	R13!,{PC}


swi_qtmreadsequence:                                 ;recoded 19/2/95
	STMFD	R13!,{R14}
	BL	ensuresong
	LDMVSFD	R13!,{PC}
	CMP	R0,#0                                           ;check if sequence is too low? (=LT)
	LDRGEB	R14,[R12,#maxsequence]                       ; - no, so load max sequence
	SUBGES	R14,R14,R0                                   ;   and check it's not too high (=LE)
	BLE	err_swi_qtmreadsequence                         ; - if so, return with error
	LDR	R14,[R12,#songaddr]
	ADD	R14,R14,#0x3B8
	LDRB	R0,[R14,R0]
	LDMFD	R13!,{PC}                                     ; - else read pattern
err_swi_qtmreadsequence:
qtm_mod_adr1772:                                     ; FNlong_adr("  ",0,seq_range)
	.long	0xE28F0000-(((seq_range-qtm_mod_adr1772)>>31)&0x00400000)+((((seq_range-qtm_mod_adr1772-8)^((seq_range-qtm_mod_adr1772-8)>>31))-((seq_range-qtm_mod_adr1772-8)>>31))&0xFF)
	.long	0xE2800C00-(((seq_range-qtm_mod_adr1772)>>31)&0x00400000)+(((((seq_range-qtm_mod_adr1772-8)^((seq_range-qtm_mod_adr1772-8)>>31))-((seq_range-qtm_mod_adr1772-8)>>31))>>8)&0xFF)
	MOV	R14,#0x80000000
	SUBS	R14,R14,#1                                     ; Set V
	LDMFD	R13!,{PC}


swi_qtmreadspeed:                                    ;updated 19/2/95 to return R0=0
	STMFD	R13!,{R14}
	BL	ensuresong
	LDMVSFD	R13!,{PC}
	LDRB	R0,[R12,#songstatus]
	TST	R0,#1 << 2                                      ;are we playing?
	LDRNEB	R0,[R12,#speed]                              ; yes, so load current speed
	MOVEQ	R0,#0                                         ; no, so return speed=0
	LDRB	R1,[R12,#CIAtempo]
	LDRB	R2,[R12,#counter]
	CMP	R0,R0                                           ; Clear V
	LDMFD	R13!,{PC}


swi_qtmreadsample:                                   ;re-coded 19/2/95
	STMFD	R13!,{R14}
	BL	ensuresong
	BLVC	checksample
	LDMVSFD	R13!,{PC}
	SUB	R0,R0,#1
	ADD	R14,R12,#sampletable - song_data
	ADD	R14,R14,R0,LSL #4
	ADD	R14,R14,R0,LSL #2                               ;(sample-1)*20
	LDR	R1,[R14,#4]                                     ;sample length
	LDR	R2,[R14,#8]                                     ;repeat offset
	LDR	R3,[R14,#0xC]                                   ;repeat length
	LDRB	R4,[R14,#0x13]                                 ;volume byte
	LDRB	R5,[R14,#0x10]                                 ;finetune byte (4 bits, signed)
	TST	R5,#1 << 3                                      ; \_ convert to 32bit
	SUBNE	R5,R5,#0x10                                   ; /  signed number!
	LDR	R6,[R14,#0]                                     ;address of sample
	LDR	R14,[R12,#songaddr]                             ; \
	ADD	R14,R14,#0x14                                   ;  \_ sample name ptr
	ADD	R14,R14,R0,LSL #5                               ;  /
	SUB	R0,R14,R0,LSL #1                                ; /
	CMP	R0,R0                                           ; Clear V
	LDMFD	R13!,{PC}


swi_qtmstereo:                                       ;fixed 20/5/95 - stop OS being set if QTM off
	STMFD	R13!,{R0,R2-R3,R14}
	ADD	R2,R12,#QTMstereos
	CMP	R0,#0
	BEQ	doallstereo
	BL	checkchannel                                     ;make sure correct channel range
	STRVS	R0,[R13]                                      ;stack the error pointer
	LDMVSFD	R13!,{R0,R2-R3,PC}
	LDRB	R3,[R2,R0]
	CMP	R1,#0x7F
	BGT	stereotoolarge                                  ;do this, 'cos the OS does, in SWI Sound_Stereo...
	CMN	R1,#0x80
	STRGTB	R1,[R2,R0]
	LDRGTB	R0,[R12,#soundflags]
	TSTGT	R0,#1
	BLGT	setstereos                                     ;**ONLY** set stereos, if QTM is on!!!
stereotoolarge:
	MOV	R1,R3,LSL #0x18                                 ; Sign extend
	MOV	R1,R1,ASR #0x18
	CMP	R0,R0                                           ; Clear V
	LDMFD	R13!,{R0,R2-R3,PC}

doallstereo:
	CMP	R1,#5                                           ;v1.49 now 0-5 with new wide-stereo default and 5=medium stereo
	MOVHI	R1,#0                                         ;if incorrect value, use default setting
	ADR	R3,stereotable
	ADD	R3,R3,R1,LSL #3
	MOV	R0,#1
newstereoloop:
	LDRB	R1,[R3],#1
	STRB	R1,[R2,R0]
	ADD	R0,R0,#1
	CMP	R0,#8
	BLE	newstereoloop
	LDRB	R0,[R12,#soundflags]
	TST	R0,#1
	BLNE	setstereos                                     ;**ON LY** set stereos, if QTM is on!!!
	MOV	R1,#0
	CMP	R0,R0                                           ; Clear V
	LDMFD	R13!,{R0,R2-R3,PC}

stereotable:
	.byte	(-0x7F)
	.byte	0x7F
	.byte	0x4F
	.byte	(-0x4F)
	.byte	(-0x7F)
	.byte	0x7F
	.byte	0x4F
	.byte	(-0x4F)                                       ;default (wide)
	.byte	(-0x7F)
	.byte	0x7F
	.byte	0x7F
	.byte	(-0x7F)
	.byte	(-0x7F)
	.byte	0x7F
	.byte	0x7F
	.byte	(-0x7F)                                       ;amiga (full)
	.byte	0
	.byte	0
	.byte	0
	.byte	0
	.byte	0
	.byte	0
	.byte	0
	.byte	0                                             ;centred
	.byte	(-0x7F)
	.byte	(-0x7F)
	.byte	(-0x7F)
	.byte	(-0x7F)
	.byte	(-0x7F)
	.byte	(-0x7F)
	.byte	(-0x7F)
	.byte	(-0x7F)                                       ;full left
	.byte	0x7F
	.byte	0x7F
	.byte	0x7F
	.byte	0x7F
	.byte	0x7F
	.byte	0x7F
	.byte	0x7F
	.byte	0x7F                                          ;full right
	.byte	(-0x4F)
	.byte	0x4F
	.byte	0x2F
	.byte	(-0x2F)
	.byte	(-0x4F)
	.byte	0x4F
	.byte	0x2F
	.byte	(-0x2F)                                       ;medium stereo

	.p2align 2
swi_qtmremovechan:                                   ;*** requires SVC mode
	STMFD	R13!,{R1-R9,R11,R14}
	BL	checkchannel
	LDMVSFD	R13!,{R1-R9,R11,PC}
	TEQ	PC,PC
	.long	0x010F9000                                    ; FNmrs("EQ","R9,CPSR")
	MOVNE	R9,PC
	ORREQ	R8,R9,#1 << 7                                 ; Disable interrupts to stop DMA messing up
	ORRNE	R8,R9,#1 << 0x1B
	.long	0x0121F008                                    ; FNmsr("EQ","CPSR_c,R8")
	TEQNEP	R8,#0
	MOV	R0,R0
	LDR	R1,[R12,#chanendflags]
	MOV	R2,#3
	SUB	R3,R0,#1
	MOV	R3,R3,LSL #1
	BIC	R1,R1,R2,LSL R3                                 ;this channel needs clearing
	STR	R1,[R12,#chanendflags]
	ADD	R10,R12,#DMA_blocks - song_data
	SUB	R1,R0,#1
	ADD	R10,R10,R1,LSL #4
	ADD	R10,R10,R1,LSL #3
	MOV	R1,#0
	MOV	R2,#0
	MOV	R3,#0
	MOV	R4,#0
	MOV	R5,#0
	MOV	R6,#0
	STMIA	R10!,{R1-R6}                                  ;24 bytes of DMA address cleared
	LDR	R1,[R12,#channelstate]
	MOV	R2,#1
	TST	R1,R2,LSL R0
	BICNE	R1,R1,R2,LSL R0
	MOVNE	R0,#1
	MOVEQ	R0,#0
	STR	R1,[R12,#channelstate]
	TEQ	PC,PC
	.long	0x0121F009                                    ; FNmsr("EQ","CPSR_c,R9")
	TEQNEP	R9,#0
	MOV	R0,R0
	CMP	R0,R0                                           ; Clear V
	LDMFD	R13!,{R1-R9,R11,PC}


swi_qtmrestorechan:
	STMFD	R13!,{R1-R2,R14}
	BL	checkchannel
	LDMVSFD	R13!,{R1-R2,PC}
	LDR	R1,[R12,#channelstate]
	MOV	R2,#1
	TST	R1,R2,LSL R0
	ORREQ	R1,R1,R2,LSL R0
	MOVEQ	R0,#0
	MOVNE	R0,#1
	STR	R1,[R12,#channelstate]
	CMP	R0,R0                                           ; Clear V
	LDMFD	R13!,{R1-R2,PC}


swi_qtmsetsamplespeed:
	CMN	R0,#1
	LDREQB	R0,[R12,#current_uS]
	MOVEQ	PC,R14
	CMP	R0,#0x10
	BLT	err_swi_qtmsetsamplespeed
	CMP	R0,#0x64
	BGE	err_swi_qtmsetsamplespeed
	.if qtmrast
	LDRB	R0,[R12,#current_uS]
	MOV	PC,R14
	.endif
	STMFD	R13!,{R1-R4,R14}
	LDRB	R2,[R12,#soundflags]
	TST	R2,#1 << 3                                      ;are we in the middle of recalcing the clock speed?
	MOVNE	R3,#0
	STRNE	R3,[R12,#ClockCalcEnd]                        ;if so, clear the counters (else the routine would get very
	STRNE	R3,[R12,#DMAinterrupts]                       ; confused if the interrupt speed changed half way!)
	TST	R0,#3                                           ;any bad bits set? added 17/4/2001
	BIC	R0,R0,#3                                        ;clear bad bits
	ADDNE	R0,R0,#4                                      ;if any bad bits set, correct to an ok sample speed
	LDRB	R4,[R12,#current_uS]
	STRB	R0,[R12,#current_uS]
	BL	setsoundconfig                                   ;wil fix sample speed for these channels! (R0-R3 corrupted)
	LDRB	R0,[R12,#soundflags]
	TST	R0,#1 << 7
	ADR	R14,end_setsmpspd
	BEQ	recalc_uS_4clock                                ;(** 'setsoundconfig' only affects sample speed if QTM on!)
	B	recalc_uS_4clock_16bit                            ;(16bit version)
end_setsmpspd:
	MOV	R0,R4
	CMP	R0,R0                                           ; Clear V
	LDMFD	R13!,{R1-R4,PC}
err_swi_qtmsetsamplespeed:
	MOV	R0,#0x80000000
	SUBS	R0,R0,#1                                       ; Set V
	ADR	R0,err_samplespeed
	MOV	PC,R14


err_samplespeed:
	.long	(qtm_error + 8)
	.byte	"Sample speed out of range"
	.byte	0
	.p2align 2


ok2clearsmp:
	BL	checkchannel
	STRVS	R0,[R13,#0]
	LDMFD	R13!,{R0,R14}
	MOVVS	PC,R14
	STMFD	R13!,{R0-R7}
	SUB	R7,R0,#1                                        ;channel-1
	ADD	R10,R12,#DMA_blocks - song_data
	ADD	R10,R10,R7,LSL #4
	ADD	R10,R10,R7,LSL #3
	MOV	R0,#0                                           ;0
	MOV	R1,#0                                           ;4
	MOV	R2,#0                                           ;8
	MOV	R3,#0                                           ;12
	MOV	R4,#0                                           ;16
	MOV	R5,#0                                           ;20
	STMIA	R10,{R0-R5}                                   ;blank DMA channel
	LDMFD	R13!,{R0-R7}
	MOV	PC,R14


findachannel:                                        ;new FOR QTMv1.28!
	;
	; updated behaviour v1.44
	; is any channel is currently playing an effect
	; if so, the highest channel playing an effect is our backup channel, otherwise the highest channel is backup
	; check if any available channels, including 0-volume channels
	;
	STMFD	R13!,{R1-R8,R14}
	LDRB	R1,[R12,#songstatus]                           ; new v1.44
	TST	R1,#1 << 2                                      ; are we playing?
	BEQ	lookup_nosongplaying
	LDR	R3,[R12,#chanendflags]
	MOV	R4,#3
	LDRB	R6,[R12,#songchans]
	ADD	R8,R12,#0+(channeldata - song_data) - 0x40      ;r8=addr of channel blocks
	ADD	R8,R8,R6,LSL #6                                 ;pointer TO channel 3 or 7's block
findblanksongchannel:
	LDRB	R1,[R8,#samplenumber]                          ;sample number
	CMP	R1,#0
	BEQ	foundachannel                                   ;we are playing and we have a completely empty song channel, lets use this...
	SUB	R5,R6,#1
	MOV	R5,R5,LSL #1
	TST	R3,R4,LSL R5
	BNE	foundachannel                                   ;was playing but now over, lets use this...
	LDRB	R1,[R8,#currentvol]
	CMP	R1,#1
	BLT	foundachannel                                   ;no volume, lets use this...
	SUB	R8,R8,#0x40
	SUBS	R6,R6,#1
	BGT	findblanksongchannel
lookup_nosongplaying:                                ; ...or no spare song channels!
	LDRB	R6,[R12,#chans_use]
	SUB	R7,R6,#1
	ADD	R8,R12,#DMA_blocks - song_data
	ADD	R8,R8,R7,LSL #3
	ADD	R8,R8,R7,LSL #4                                 ;max chans*24 (last channel tested first - best for 8 chan)
	MOV	R7,#0                                           ; new v1.44, backup channel (0 at mo)
lookchanloop:
	LDMIA	R8,{R0-R5}                                    ;r0=end addr, r1=-ve offset, r2=pitch, r3=vol/flag, r4=rlen
	AND	R14,R3,#0xFF00                                  ; new v1.44
	CMP	R14,#0xFF00                                     ; is this an effect?
	CMPEQ	R7,#0                                         ; have we chosen a backup channel?
	MOVEQ	R7,R6                                         ; no, so put highest effect playing channel in there
	CMN	R1,#8 << 0xC                                    ;v1.44 inc to 8 bytes, is offset >-(1<<12)? (ie. offset>>12 <1)?   (remember -ve!)
	MOVGT	R14,#3                                        ; <put min loop len in r14>
	CMPGT	R14,R5                                        ; <backwards!!! this does CMP 3,len so LE if valid!!!)
	BGT	foundachannel                                   ;if offset>-4096 and 3>repeat len, then exit
	CMP	R2,#0
	BLE	foundachannel                                   ;no pitch
	ANDS	R3,R3,#0
	BEQ	foundachannel                                   ;no volume, added v1.44
	SUB	R8,R8,#0x18
	SUBS	R6,R6,#1
	BNE	lookchanloop                                    ;check next channel
	CMP	R7,#0                                           ; is our backup channel 0 = not found one?
	LDREQB	R6,[R12,#chans_use]                          ; if so, use highest channel number
	;MVN     R6,#0 ; don't exit with -1 any more
foundachannel:
	MOV	R0,R6
	LDMFD	R13!,{R1-R8,PC}


swi_qtmplaysample:                                   ;r0=chan 1-8, r1=smp 1-64, r2=note (1-36,37-1999), r3=vol
	STMFD	R13!,{R14}                                    ;v1.44                          or (1-72+bit28 set)
	CMN	R0,#1
	BLEQ	findachannel
	CMN	R0,#1
	LDMEQFD	R13!,{PC}
	STMFD	R13!,{R0}
	CMP	R1,#0
	BEQ	ok2clearsmp                                     ;if sample=0 then clear the channel...
	BL	checkchannel
	MOVVC	R0,R1
	BLVC	checksample
	MOVVC	R0,R3
	BLVC	checkvolrange
	STRVS	R0,[R13,#0]
	LDMFD	R13!,{R0,R14}
	MOVVS	PC,R14
	STMFD	R13!,{R0-R9,R11,R14}
	LDRB	R11,[R12,#chans_use]
	CMP	R0,R11
	LDMGTFD	R13!,{R0-R9,R11,PC}                         ;exit with NO error, if channel 1-8 BUT only 4 chans on!!!
	MOV	R0,R2
	BL	checknote                                        ;updated 1.44
	MOVVC	R2,R0                                         ;returns R0=period 37-1999 or note 1-72 in bits 24-31
	STRVS	R0,[R13,#0]
	LDMVSFD	R13!,{R0-R9,R11,PC}
	LDR	R0,[R13,#0]
	BL	initQTMsound                                     ;will return if already on
	SUB	R11,R0,#1                                       ;channel-1
	ADD	R10,R12,#DMA_blocks - song_data
	ADD	R10,R10,R11,LSL #4
	ADD	R10,R10,R11,LSL #3
	MOV	R11,R2                                          ;pitch into r11
	ORR	R3,R3,#0xFF00                                   ;*** Set sample/sound effects flag in DMA block ***
	STR	R3,[R10,#DMA_volume]
	SUB	R9,R1,#1                                        ;sample-1
	ADD	R7,R12,#sampletable - song_data                 ;get addr of sample data table in r7
	ADD	R7,R7,R9,LSL #4                                 ;add (sample-1)*16 = correct info block for sample
	ADD	R7,R7,R9,LSL #2                                 ;(+4) ******************* -(*20)
	LDMIA	R7,{R0-R4}                                    ;r0=addr, r1=len, r2=rep off, r3=rep len, r4=ftune/volume
	CMP	R3,#2
	ADDGT	R1,R2,R3                                      ;if repeat, use rlen+roff as length, so it starts correctly
	ADD	R0,R0,R1                                        ;end address
	MOV	R1,R1,LSL #0xC                                  ;
	RSB	R1,R1,#0                                        ;start offset -ve
	STMIA	R10,{R0-R1}                                   ;set sample addr and offset
	ADD	R2,R10,#DMA_repaddr
	STMIA	R2,{R0,R3}                                    ;set repeat end address (as for sample) & repeat length
	CMP	R11,#0x7D0
	BLT	skipftuning                                     ;if note was<2000 then use it as REAL amiga note
	MOV	R11,R11,LSR #0x18                               ;shuffle note number back down again
	SUB	R11,R11,#1                                      ;move range to 0-71
	AND	R0,R4,#0xFF                                     ;get fine tuning byte
qtm_mod_adr2145:                                     ;get addr of amiga period tables
	.long	0xE28F7000-(((amigaperiodz-qtm_mod_adr2145)>>31)&0x00400000)+((((amigaperiodz-qtm_mod_adr2145-8)^((amigaperiodz-qtm_mod_adr2145-8)>>31))-((amigaperiodz-qtm_mod_adr2145-8)>>31))&0xFF)
	.long	0xE2877C00-(((amigaperiodz-qtm_mod_adr2145)>>31)&0x00400000)+(((((amigaperiodz-qtm_mod_adr2145-8)^((amigaperiodz-qtm_mod_adr2145-8)>>31))-((amigaperiodz-qtm_mod_adr2145-8)>>31))>>8)&0xFF)
	MOV	R1,R0,LSL #4                                    ;fine tune *16  }_
	ADD	R0,R1,R0,LSL #7                                 ;          *128 }  *144 = offset for correct tuning DCW table
	ADD	R7,R7,R0                                        ;get to address of table (r7)
	MOVS	R11,R11,LSR #1                                 ;CS if odd numbered note
	LDR	R11,[R7,R11,LSL #2]                             ;fine tuned note (table+note number/2*4) b0-15=even, b16-31 odd
	MOVCC	R11,R11,LSL #0x10                             ;
	MOV	R11,R11,LSR #0x10                               ;v1.48 half size note tables
skipftuning:
	STR	R11,[R10,#DMA_pitch]                            ;store pitch
	MOV	R1,#1
	LDRB	R0,[R12,#vuflags]
	ORR	R0,R0,R1,LSL R9
	STRB	R0,[R12,#vuflags]                              ;new note, so set VU flag
	CMP	R0,R0                                           ; Clear V
	LDMFD	R13!,{R0-R9,R11,PC}


swi_qtmreadchanneldata:                              ; r0=channel, return r1=current period, r2=lin vol, r3=note, r4=sample, r5=effect, r6=data
	STMFD	R13!,{R14}
	BL	ensuresong
	BLVC	checkchannel                                   ;checks 1-8
	LDMVSFD	R13!,{PC}
	ADD	R14,R12,#0+(channeldata - song_data) - 0x40     ;r11=addr of channel blocks
	ADD	R14,R14,R0,LSL #6                               ;...now at this channel's 64 byte channel data block
	LDRB	R4,[R14,#samplenumber]                         ;sample number
	LDR	R1,[R14,#amigaperiod]                           ;load amiga period
	TEQ	R1,#0                                           ;is it 0?
	MOVEQ	R3,#0
	LDRNEB	R3,[R14,#notenumber]                         ;if not, load note number (0-71)
	ADDNE	R3,R3,#1                                      ;...and adjust range to 1-72
	LDR	R2,[R12,#chanendflags]
	SUB	R5,R0,#1                                        ;R5=channel 0-7
	LDRB	R6,[R12,#songchans]                            ;v1.44
	TEQ	R6,#4                                           ;if 4 channel song
	LDREQB	R6,[R12,#soundflags]                         ;are we using channels 0-3 on 4-7?
	TST	R6,#1 << 5                                      ;(this works as long as < 32 channels...)
	ADDNE	R5,R5,#4                                      ;if so get to 4-7
	CMP	R5,#7                                           ;but if >7 then user is checking c4-7, so return value from c0-3
	SUBGT	R5,R5,#8                                      ;meaningless anyway, as 0-3 will be no note!
	MOV	R6,#3
	MOV	R5,R5,LSL #1
	TST	R2,R6,LSL R5
	MOVNE	R4,#0                                         ;sample
	MOVNE	R1,#0                                         ;period
	MOVNE	R3,#0                                         ;return note, period and sample = 0 if channel ended playing
	LDRB	R2,[R14,#currentvol]
	LDRB	R5,[R14,#currentFXnum]
	LDRB	R6,[R14,#currentFXdata]
	LDMFD	R13!,{PC}


swi_qtmplayraw:                                      ;r0=chan 1-8, r1=addr, r2=len, r3=roff, r4=rlen, r5=note, r6=vol
	STMFD	R13!,{R14}                                    ;v1.44                                          or (1-72+bit28 set)
	CMN	R0,#1
	BLEQ	findachannel
	CMN	R0,#1
	LDMEQFD	R13!,{PC}
	STMFD	R13!,{R0}
	CMP	R1,#0
	BEQ	ok2clearsmp                                     ;if addr=0 then clear channel
	STMFD	R13!,{R0,R1}
	MOV	R0,R1
	ADD	R1,R1,R2
	SWI	XOS_ValidateAddress
	LDMFD	R13!,{R0,R1}
	BCS	err_swi_qtmplayraw
	BLVC	checkchannel
	MOVVC	R0,R6
	BLVC	checkvolrange
playrawerror:
	STRVS	R0,[R13,#0]
	LDMFD	R13!,{R0,R14}
	MOVVS	PC,R14
	STMFD	R13!,{R0-R9,R11,R14}
	LDRB	R11,[R12,#chans_use]
	CMP	R0,R11
	LDMGTFD	R13!,{R0-R9,R11,PC}                         ;exit with NO error, if channel 1-8 BUT only 4 chans on!!!
	MOV	R0,R5
	BL	checknote                                        ;updated 1.44
	MOVVC	R5,R0                                         ;returns R0=period 37-1999 or note 1-72 in bits 24-31
	STRVS	R0,[R13,#0]
	LDMVSFD	R13!,{R0-R9,R11,PC}
	LDR	R0,[R13,#0]
	BL	initQTMsound                                     ;will return if already on
	SUB	R11,R0,#1                                       ;channel-1
	ADD	R10,R12,#DMA_blocks - song_data
	ADD	R10,R10,R11,LSL #4
	ADD	R10,R10,R11,LSL #3
	ORR	R6,R6,#0xFF00                                   ;*** Set sample/sound effects flag in DMA block ***
	STR	R6,[R10,#DMA_volume]
	CMP	R4,#2
	ADDGT	R2,R3,R4                                      ;if repeat, use rlen+roff as length, so it starts correctly
	ADD	R1,R1,R2                                        ;now at end address
	MOV	R2,R2,LSL #0xC                                  ;
	RSB	R2,R2,#0                                        ;offset to start -ve
	STMIA	R10,{R1-R2}                                   ;set sample addr and offset
	ADD	R2,R10,#DMA_repaddr
	STMIA	R2,{R1,R4}                                    ;set repeat end address (as for sample) & repeat length
	CMP	R5,#0x7D0                                       ;if note was<2000 then use it as REAL amiga note
	BLE	playrawgotnote
	MOV	R5,R5,LSR #0x18                                 ;shuffle note number back down again
	SUB	R5,R5,#1
qtm_mod_adr2265:                                     ;get addr of amiga period tables
	.long	0xE28F7000-(((amigaperiodz-qtm_mod_adr2265)>>31)&0x00400000)+((((amigaperiodz-qtm_mod_adr2265-8)^((amigaperiodz-qtm_mod_adr2265-8)>>31))-((amigaperiodz-qtm_mod_adr2265-8)>>31))&0xFF)
	.long	0xE2877C00-(((amigaperiodz-qtm_mod_adr2265)>>31)&0x00400000)+(((((amigaperiodz-qtm_mod_adr2265-8)^((amigaperiodz-qtm_mod_adr2265-8)>>31))-((amigaperiodz-qtm_mod_adr2265-8)>>31))>>8)&0xFF)
	MOVS	R5,R5,LSR #1
	LDR	R5,[R7,R5,LSL #2]                               ;load note in r5 (from table+note number*4)
	MOVCC	R5,R5,LSL #0x10                               ;
	MOV	R5,R5,LSR #0x10                                 ;v1.48 half size note tables
playrawgotnote:
	STR	R5,[R10,#DMA_pitch]                             ;store pitch
	MOV	R1,#1
	LDRB	R0,[R12,#vuflags]
	ORR	R0,R0,R1,LSL R9
	STRB	R0,[R12,#vuflags]                              ;new note, so set VU flag
	CMP	R0,R0                                           ; Clear V
	LDMFD	R13!,{R0-R9,R11,PC}
err_swi_qtmplayraw:
	LDMFD	R13!,{R0,R14}
	MOV	R0,#0x80000000
	SUBS	R0,R0,#1                                       ; Set V
	ADR	R0,err_badaddress
	MOV	PC,R14


err_badaddress:
	.long	(qtm_error + 0xC)
	.byte	"Illegal address passed to QTM"
	.byte	0
	.p2align 2


swi_qtmsoundctrl:                                    ;r0=chans, r1=flags (b0=TSS, b1=4c on 5-8, b2=on after pause), r2=TSS handler
	STMFD	R13!,{R3,R14}                                 ;on exit, old values of above
	CMN	R0,#1
	CMPNE	R0,#0
	CMPNE	R0,#4
	.if maxchans>4
	CMPNE	R0,#8
	.endif
	BNE	err_swi_qtmsoundctrl
	LDR	R3,[R12,#oldConfigure + 0xC]                    ;load old TRNS sound handler
	CMP	R2,#0x8000                                      ;are we setting a new one? (R2>=&8000)?  update 28/7/96
	STRGE	R2,[R12,#oldConfigure + 0xC]                  ;...yup
	MOV	R2,R3                                           ;put previous in R2
	LDRB	R3,[R12,#soundflags]                           ;load current sound flags
	CMP	R1,#0
	BMI	donesetnewflags                                 ;skip next bit if reading current...
	LDRB	R14,[R12,#songchans]                           ;v1.44
	CMP	R14,#4
	BNE	soundctrl_not4c
	AND	R14,R1,#2                                       ;get the new state of 'play 4 channel music on c5-8'
	EOR	R14,R3,R14,LSL #4                               ;EOR with current setting (bug fix 1.49, was ...R1,LSL#4)
	TST	R14,#1 << 5                                     ;- so bit5<>0 if there is a change
	MOV	R3,R1
	MOVNE	R1,#0                                         ;we want *MUSIC* chans to clear
	STRNE	R1,[R12,#chanendflags]
	MOVNE	R1,#0xFF                                      ;R1=&FF to only clear music DMA data
	BLNE	clearDMAchans
	MOV	R1,R3
	LDRB	R3,[R12,#soundflags]                           ;load current sound flags
soundctrl_not4c:
	BIC	R14,R3,#0x62                                    ;clear the sound flags we are affecting (b1/5/6)
	TST	R1,#1
	ORRNE	R14,R14,#2                                    ;if bit 0 set in R1 (TSS on), set bit 1 in soundflags
	MOV	R1,R1,LSR #1                                    ;v1.44 loose bit 0 of R1 (and make bits 1&2 down to 0&1)
	ORR	R14,R14,R1,LSL #5                               ; |    bits 1&2 (now 0&1) R1 affect bits 5&6 of soundflags
	STRB	R14,[R12,#soundflags]                          ; |    bit 5 = play 4c on 5-8; bit 6 = keep on after Pause/Stop
	BL	setDMAblock                                      ;...and update QTM's channel handler block for DMA/TRNS
donesetnewflags:
	MOV	R1,#0
	TST	R3,#1 << 1
	ORRNE	R1,R1,#1
	MOV	R14,R3,LSR #5                                   ; |
	AND	R14,R14,#3                                      ; keep bit 5&6 only (b5=use chan 5-8, v1.49 b6=on after Pause)
	ORR	R1,R1,R14,LSL #1                                ;v1.44 do the above backwards TO GET correct previous flags
	TST	R3,#1                                           ;is the sound system currently on or off?
	LDRNEB	R3,[R12,#chans_use]                          ;load current number of channels, if switched on
	MOVEQ	R3,#0                                         ;specify 0 channels on return, if sound was off
	CMP	R0,#0                                           ;are we altering the no. channels/switching off? (R0>=0)?
	BLT	soundctrl_chansok
	BGT	soundctrl_changechans
soundctrl_switchoff:
	BL	clearinfos                                       ; -
	BL	resetsound                                       ; - if R0=0 then ensure sound system is off!
	B	soundctrl_chansok
soundctrl_changechans:
	STRB	R0,[R12,#chans_use]                            ;if altering channels, then store new number of channels...
	STRB	R0,[R12,#oldchansused]                         ;v1.44 fix - update oldchansused, in case 4 chan playing, and we select 8
	BL	initQTMsound                                     ;...and update the controller...
soundctrl_chansok:
	MOV	R0,R3                                           ;old number of channels in R0
	LDMFD	R13!,{R3,PC}
err_swi_qtmsoundctrl:
	MOV	R0,#0x80000000
	SUBS	R0,R0,#1                                       ; Set V
	ADR	R0,badnumchans
	LDMFD	R13!,{R3,PC}                                  ;if bad number of channels then error!


badnumchans:
	.long	(qtm_error + 0xD)
	.byte	"Bad number of channels"
	.byte	0
	.p2align 2


swi_qtmswitableaddr:
qtm_mod_adr2377:                                     ; FNlong_adr("  ",0,SWIcode)
	.long	0xE28F0000-(((SWIcode-qtm_mod_adr2377)>>31)&0x00400000)+((((SWIcode-qtm_mod_adr2377-8)^((SWIcode-qtm_mod_adr2377-8)>>31))-((SWIcode-qtm_mod_adr2377-8)>>31))&0xFF)
	.long	0xE2800C00-(((SWIcode-qtm_mod_adr2377)>>31)&0x00400000)+(((((SWIcode-qtm_mod_adr2377-8)^((SWIcode-qtm_mod_adr2377-8)>>31))-((SWIcode-qtm_mod_adr2377-8)>>31))>>8)&0xFF)
	MOV	PC,R14


swi_qtmregistersmp:                                  ;updated 19/2/95 - fixed crash on illegal address routine
	STMFD	R13!,{R14}                                    ;r0=no. r1=addr r2=len r3=roff r4=rlen r5=vol r6=ftune
	BL	checksample
	LDMVSFD	R13!,{PC}
	CMP	R1,#0
	BEQ	deregistersmp
	STMFD	R13!,{R0,R1}
	MOV	R0,R1
	ADD	R1,R1,R2
	SWI	XOS_ValidateAddress
	LDMFD	R13!,{R0,R1}
	BCS	err_swi_qtmregistersamp
	STMFD	R13!,{R0,R7}
	SUBS	R0,R0,#1
	ADD	R7,R12,#sampletable - song_data
	ADD	R7,R7,R0,LSL #4
	ADD	R7,R7,R0,LSL #2                                 ;(sample-1)*20
	STR	R1,[R7,#0]                                      ;address of sample
	STR	R2,[R7,#4]                                      ;sample length
	STR	R3,[R7,#8]                                      ;repeat offset
	STR	R4,[R7,#0xC]                                    ;repeat length
	STRB	R5,[R7,#0x13]                                  ;volume byte
	AND	R6,R6,#0xF
	STRB	R6,[R7,#0x10]                                  ;finetune byte (4 bits, signed)
	CMP	R0,R0                                           ; Clear V
	LDMFD	R13!,{R0,R7,PC}
err_swi_qtmregistersamp:
	MOV	R0,#0x80000000
	SUBS	R0,R0,#1                                       ; Set V
	ADR	R0,err_badaddress
	LDMFD	R13!,{PC}

deregistersmp:
	STMFD	R13!,{R0,R7}
	SUBS	R0,R0,#1
	ADD	R7,R12,#sampletable - song_data
	ADD	R7,R7,R0,LSL #4
	ADD	R7,R7,R0,LSL #2                                 ;(sample-1)*20
	STR	R1,[R7,#0]
	STR	R1,[R7,#4]                                      ;sample length   }
	STR	R1,[R7,#8]                                      ;repeat offset    }
	STR	R1,[R7,#0xC]                                    ;repeat length     } blank!
	STRB	R1,[R7,#0x13]                                  ;volume byte      }
	STRB	R1,[R7,#0x10]                                  ;finetune byte   }
	CMP	R0,R0                                           ; Clear V
	LDMFD	R13!,{R0,R7,PC}


swi_qtmsetspeed:                                     ;added 19/2/95
	STMFD	R13!,{R14}
	BL	ensuresong
	LDMVSFD	R13!,{PC}
	CMP	R0,#0
	LDMEQFD	R13!,{PC}                                   ;exit with no error if speed 0 requested
	MOVS	R14,R0,LSR #8                                  ;simple way of testing only lower bits used!
	STMEQFD	R13!,{R0-R7}                                ;required to call speed 'F' effect handler
	MOVEQ	R1,R0
	BEQ	set_setspeed
	MOV	R0,#0x80000000
	SUBS	R0,R0,#1                                       ; Set V
	ADR	R0,badspeedset
	LDMFD	R13!,{PC}                                     ;throw up error if illegal speed


badspeedset:
	.long	(qtm_error + 0x10)
	.byte	"Speed/tempo value out of range"
	.byte	0
	.p2align 2


swi_qtmmusicoptions:                                 ;added 24/6/96
	LDRB	R2,[R12,#musicoptbyte]
	AND	R1,R1,R0
	BIC	R3,R2,R0
	ORR	R3,R3,R1
	STRB	R3,[R12,#musicoptbyte]
	MOV	PC,R14


swi_qtmmusicinterrupt:                               ;added 24/6/96
	STMFD	R13!,{R3-R4,R14}
	LDR	R3,[R12,#musicintaddr]
	LDR	R4,[R12,#musicintr12]
	CMP	R1,#0
	MOVEQ	R2,R1
	STRGE	R1,[R12,#musicintaddr]
	STRGE	R2,[R12,#musicintr12]
	MOV	R1,R3
	MOV	R2,R4
	CMP	R0,R0                                           ; Clear V
	LDMFD	R13!,{R3-R4,PC}


musicinterrupt:
	STMFD	R13!,{R11,R12,R14}
	LDR	R11,[R12,#musicintaddr]
	LDR	R12,[R12,#musicintr12]
	CMP	R11,#0x8000
	MOVGE	R14,PC
	MOVGE	PC,R11
	CMP	R0,R0                                           ; Clear V
	LDMFD	R13!,{R11,R12,PC}


swi_qtmreadnoteword:                                 ;R0=pattern (0-n), R1=event (0-63), R2=channel (1-8)
	STMFD	R13!,{R14}                                    ;Returns R0-R2 preserved, R3=note, R4=sample, R5=eff, R6=data
	BL	ensuresong
	LDMVSFD	R13!,{PC}
	LDRB	R14,[R12,#songchans]
	CMP	R2,R14
	LDMGTFD	R13!,{R14}
	BGT	err_checkchannel
	LDRB	R14,[R12,#maxpattern]
	CMP	R0,R14
	LDMGTFD	R13!,{R14}
	BGT	err_patternnumber
	STMFD	R13!,{R0}
	CMP	R1,#0x3F
	BGT	err_setevent
	CMP	R1,#0
	BLT	err_setevent
	LDR	R14,[R12,#patternlen]                           ;v1.44 support for 8CHN and 6CHN
	MUL	R0,R14,R0                                       ;pattern * patternlen
	MOV	R14,R14,LSR #6                                  ;patternlen/64 = event length (16/24/32 for 4, 8 FLT/6/8)
	MLA	R0,R14,R1,R0                                    ;add on current event*event length (no longer just 16)
	LDR	R14,[R12,#songaddr]                             ;r14=addr of song address
	ADD	R14,R14,#0x3E8
	ADD	R14,R14,#0x54                                   ;r14=start of patterns
	ADD	R0,R0,R14                                       ;address of required event
	SUB	R14,R2,#1                                       ;channel-1 in r14
	LDR	R0,[R0,R14,LSL #2]                              ;add (channel-1) * 4
	AND	R14,R0,#0x10                                    ;upper 1 bit of sample number
	AND	R4,R0,#0xF00000                                 ;lower 4 bits of sample number
	ORR	R4,R14,R4,LSR #0x14                             ;r4 = sample number
	AND	R14,R0,#7                                       ;**v1.44 test for 8CHN** upper 3 (was 2) bits of note period
	AND	R5,R0,#0xFF00                                   ;lower 8 bits of note period
	MOV	R14,R14,LSL #8                                  ;
	ORR	R5,R14,R5,LSR #8                                ;r5 = amiga note period (1-4095)
	CMP	R5,#0x780                                       ;v1.44 if >=1920, revert to notenumber=0 (lowest note)
	MOVGE	R14,#0                                        ;
	ADDLT	R14,R12,#div8notetable - song_data
	ADDLT	R14,R14,R5,LSR #3                             ;if <1920, use 'div8' table
	CMP	R5,#0x96                                        ;
	ADDLT	R14,R12,#div1notetable - song_data
	ADDLT	R14,R14,R5                                    ;if <150, use 'div1' table
	TEQ	R5,#0                                           ;ignore IF amiga period=0
	MOVEQ	R3,#0                                         ;v1.45 fix = was returning prev. R3 value, ie. not 0 if no note!!!
	LDRNEB	R3,[R14]                                     ;load note number (-1)
	ADDNE	R3,R3,#1                                      ;get to range 1-72
	AND	R5,R0,#0xF0000                                  ;mask off effect number into r5
	MOV	R5,R5,LSR #0x10
	MOV	R6,R0,LSR #0x18                                 ;...if it is, then get data shifted into r0
	LDMFD	R13!,{R0,PC}


err_patternnumber:
	MOV	R0,#0x80000000
	SUBS	R0,R0,#1                                       ; Set V
	ADR	R0,illegalpatt
	MOV	PC,R14
illegalpatt:
	.long	(qtm_error + 0x11)
	.byte	"Pattern number out of range"
	.byte	0
	.p2align 2


checkchannel:
	SUB	R0,R0,#1
	CMP	R0,#7
	BHI	err_checkchannel
	ADDS	R0,R0,#1                                       ; Clear V
	MOV	PC,R14
err_checkchannel:
	MOV	R0,#0x80000000
	SUBS	R0,R0,#1                                       ; Set V
	ADR	R0,illegalchan
	MOV	PC,R14

illegalchan:
	.long	(qtm_error + 9)
	.byte	"Channel number out of range"
	.byte	0
	.p2align 2

checksample:
	SUB	R0,R0,#1
	CMP	R0,#0x3F
	BHI	err_checksample
	ADDS	R0,R0,#1                                       ; Clear V
	MOV	PC,R14
err_checksample:
	MOV	R0,#0x80000000
	SUBS	R0,R0,#1                                       ; Set V
	ADR	R0,smprange_error
	MOV	PC,R14

smprange_error:
	.long	(qtm_error + 0xA)
	.byte	"Sample number out of range"
	.byte	0
	.p2align 2


checkvolrange:                                       ;checks volume in r0
	CMP	R0,#0x40
	BHI	err_checkvolrange
	CMP	R0,R0                                           ; Clear V
	MOV	PC,R14
err_checkvolrange:
	MOV	R0,#0x80000000
	SUBS	R0,R0,#1                                       ; Set V
	ADR	R0,vol_error
	MOV	PC,R14

vol_error:
	.long	(qtm_error + 7)
	.byte	"Volume level out of range"
	.byte	0
	.p2align 2


checknote:                                           ;updated for 1.44
	CMP	R0,#0
	BLE	checknote_err
	CMP	R0,#0x24
	ADDLE	R0,R0,#0xC
	MOVLE	R0,R0,LSL #0x18                               ;if range 1-36 note, and bit 28 clear, correct note to 72 note
	BLE	checknote_ok                                    ;and return in bits 24-31
	CMP	R0,#0x7D0
	BLT	checknote_ok                                    ;if <2000 it's an Amiga period
	TST	R0,#0xE << 0x1D
	BNE	checknote_err                                   ;if any flags 29-31 set, cause an error
	TST	R0,#1 << 0x1C
	BEQ	checknote_err                                   ;if bit 28 is not set and we get here, then return an error
	BIC	R0,R0,#1 << 0x1C
	CMP	R0,#0x48
	MOVLE	R0,R0,LSL #0x18                               ;if range 1-72 & bit 28 set, clear bit 28, return note in 24-31
	BGT	checknote_err
checknote_ok:
	CMP	R0,R0                                           ; Clear V
	MOV	PC,R14
checknote_err:
	MOV	R0,#0x80000000
	SUBS	R0,R0,#1                                       ; Set V
	ADR	R0,noterange_error
	MOV	PC,R14


noterange_error:
	.long	(qtm_error + 0xB)
	.byte	"Note number out of range"
	.byte	0
	.p2align 2


ensuresong:
	STMFD	R13!,{R0}
	LDRB	R0,[R12,#songstatus]
	TST	R0,#1
	LDMFD	R13!,{R0}
	BEQ	err_ensuresong
	CMP	R0,R0                                           ; Clear V
	MOV	PC,R14
err_ensuresong:
	MOV	R0,#0x80000000
	SUBS	R0,R0,#1                                       ; Set V
	ADR	R0,no_song
	MOV	PC,R14

no_song:
	.long	(qtm_error + 5)
	.byte	"No song loaded"
	.byte	0
	.p2align 2


init_databanks:
	STMFD	R13!,{R0-R6,R11-R12,R14}
	MOV	R0,#0x7F                                        ;v1.48
	SWI	Sound_Volume                                    ; | set volume to max 127 for table creation...
	MOV	R6,R0                                           ; | r6=original log system volume
qtm_mod_adr2682:                                     ; |
	.long	0xE28F5000-(((loglintab-qtm_mod_adr2682)>>31)&0x00400000)+((((loglintab-qtm_mod_adr2682-8)^((loglintab-qtm_mod_adr2682-8)>>31))-((loglintab-qtm_mod_adr2682-8)>>31))&0xFF)
	.long	0xE2855C00-(((loglintab-qtm_mod_adr2682)>>31)&0x00400000)+(((((loglintab-qtm_mod_adr2682-8)^((loglintab-qtm_mod_adr2682-8)>>31))-((loglintab-qtm_mod_adr2682-8)>>31))>>8)&0xFF)
	LDRB	R5,[R5,R6,LSL #1]                              ; | get linear volume 0-127 from log system volume
	ADD	R5,R5,#2                                        ; | +2 correction 127 -> 129, so 129 DIV2 = 64 max lin vol
	MOV	R5,R5,LSR #1                                    ; | r5=scaled QTM_Volume setting
	;FNlong_adr("  ",11,linlogtab)
	ADD	R11,R12,#linlognew - song_data
	MOV	R1,#0xFF
setlinlogtab:
	MOV	R0,R1,LSL #0x18
	SWI	XSound_SoundLog
	STRB	R0,[R11,R1]
	SUBS	R1,R1,#1
	BGE	setlinlogtab
	MOV	R1,#0x40                                        ;use 64 (max lin volume) to create unscaled base vol table
	ADD	R2,R12,#volumetable - song_data
setvoltabs:
	MOV	R0,R1,LSL #(0x18 + 1)
	SWI	XSound_SoundLog
	RSB	R0,R0,#0xFF
	AND	R0,R0,#0xFE                                     ;stops odd/even changes (ie. +/- sample changes)
	STRB	R0,[R2,R1]
	SUBS	R1,R1,#1
	BGE	setvoltabs
	MOV	R0,R6                                           ;v1.48
	SWI	Sound_Volume                                    ; | restore system volume to previous
	MOV	R0,R5                                           ; |
	BL	swi_qtmvolume                                    ; | set QTM_Volume (music and sample) scaled to system volume
	; v1.44 note table size reduced to 160+240 = 400 bytes (from 1024)
qtm_mod_adr2715:                                     ;must be a 6-octave, 72 note, period table
	.long	0xE28F2000-(((amigaperiodz-qtm_mod_adr2715)>>31)&0x00400000)+((((amigaperiodz-qtm_mod_adr2715-8)^((amigaperiodz-qtm_mod_adr2715-8)>>31))-((amigaperiodz-qtm_mod_adr2715-8)>>31))&0xFF)
	.long	0xE2822C00-(((amigaperiodz-qtm_mod_adr2715)>>31)&0x00400000)+(((((amigaperiodz-qtm_mod_adr2715-8)^((amigaperiodz-qtm_mod_adr2715-8)>>31))-((amigaperiodz-qtm_mod_adr2715-8)>>31))>>8)&0xFF)
	ADD	R3,R12,#div8notetable - song_data
	MOV	R0,#0xEF                                        ;table offset count down
	MOV	R1,#0                                           ;note number count up
div8fillnextnote:
	MOVS	R4,R1,LSR #1
	LDR	R4,[R2,R4,LSL #2]
	MOVCC	R4,R4,LSL #0x10
	MOV	R4,R4,LSR #0x10                                 ;v1.48 half size note tables
div8fillnoteloop:
	STRB	R1,[R3,R0]
	SUB	R0,R0,#1
	CMP	R0,R4,LSR #3                                    ;divide period by 8
	BGE	div8fillnoteloop
	ADD	R1,R1,#1
	CMP	R1,#0x32
	BLE	div8fillnextnote
	ADD	R3,R12,#div1notetable - song_data
	MOV	R0,#0x9F                                        ;table offset count down
	MOV	R1,#0x2B                                        ;note number count up
div1fillnextnote:
	MOVS	R4,R1,LSR #1
	LDR	R4,[R2,R4,LSL #2]
	MOVCC	R4,R4,LSL #0x10
	MOV	R4,R4,LSR #0x10                                 ;v1.48 half size note tables
div1fillnoteloop:
	STRB	R1,[R3,R0]
	SUB	R0,R0,#1
	CMP	R0,R4
	BGE	div1fillnoteloop
	ADD	R1,R1,#1
	CMP	R1,#0x47
	BLE	div1fillnextnote
	MOV	R0,#0x10000
	SUB	R0,R0,#1
	STR	R0,[R12,#FXflags]
	STR	R0,[R12,#E_FXflags]
	MOV	R0,#0x200
	SUB	R0,R0,#2                                        ; =(%11111111)<<1 ;these take up more space like this, rather than
	STR	R0,[R12,#channelstate]                          ;just pre-storing them, but this way they work if
	MOV	R0,#dma                                         ;the module is saved from RMA, then re-run...
	MOV	R0,R0,LSR #4                                    ; v1.42 - div by 16 (208 -> 13, 416 -> 26)
	STRB	R0,[R12,#current_dma]                          ;v1.45 this is QTM's desired DMA size
	STRB	R0,[R12,#actual_dma]                           ;v1.45 this is actual DMA size, determined in 'setstereos'
	MOV	R0,#uS
	STRB	R0,[R12,#current_uS]                           ;v1.45 overwritten for RO5 in machinedetect
	MOV	R0,#4
	STRB	R0,[R12,#chans_use]
	MOV	R0,#2
	STRB	R0,[R12,#vugravity]
	MOV	R0,#0
	STRB	R0,[R12,#musicoptbyte]
	STR	R0,[R12,#musicintaddr]
	STR	R0,[R12,#musicintr12]
	STR	R0,[R12,#tempaddrptr]
	STR	R0,[R12,#fake8bitDMA]
	LDMFD	R13!,{R0-R6,R11-R12,PC}

	.include "qtm_timer.asm"

	.include "qtm_vucode.asm"

title:
	.byte	"QTMTracker"
	.byte	0

help:                                                ;do not edit between here and ehelp, as data is poked here later
	.byte	"QTM Tracker",0x09
helpver:
	.byte	"1.49"
helpdate:
	.include "stamp_helpdate.asm"                       ; frozen post-assembly patch, per variant
helpchar:
	.if betatest
	.byte	" !BETA TEST VERSION!"
	.endif
	.if alphatest
	.byte	" !ALPHA TEST - NOT FOR RELEASE!"
	.endif
ehelp:
	.byte	0

SWItable:
	.byte	"QTM"
	.byte	0
	.byte	"Load"
	.byte	0
	.byte	"Start"
	.byte	0
	.byte	"Stop"
	.byte	0
	.byte	"Pause"
	.byte	0
	.byte	"Clear"
	.byte	0
	.byte	"Info"
	.byte	0
	.byte	"Pos"
	.byte	0
	.byte	"EffectControl"
	.byte	0
	.byte	"Volume"
	.byte	0
	.byte	"SetSampleSpeed"
	.byte	0
	.byte	"DMABuffer"
	.byte	0
	.byte	"RemoveChannel"
	.byte	0
	.byte	"RestoreChannel"
	.byte	0
	.byte	"Stereo"
	.byte	0
	.byte	"ReadSongLength"
	.byte	0
	.byte	"ReadSequenceTable"
	.byte	0
	.byte	"VUBarControl"
	.byte	0
	.byte	"ReadVULevels"
	.byte	0
	.byte	"ReadSampleTable"
	.byte	0
	.byte	"ReadSpeed"
	.byte	0
	.byte	"PlaySample"
	.byte	0
	.byte	"SongStatus"
	.byte	0
	.byte	"ReadPlayingTime"
	.byte	0
	.byte	"PlayRawSample"
	.byte	0
	.byte	"SoundControl"
	.byte	0
	.byte	"SWITableAddress"
	.byte	0
	.byte	"RegisterSample"
	.byte	0
	.byte	"SetSpeed"
	.byte	0
	.byte	"MusicVolume"
	.byte	0
	.byte	"SampleVolume"
	.byte	0
	.byte	"MusicOptions"
	.byte	0
	.byte	"MusicInterrupt"
	.byte	0
	.byte	"ReadChannelData"
	.byte	0
	.byte	"ReadNoteWord"
	.byte	0
	.byte	"DMAHandler"
	.byte	0
	.if alphatest
	.byte	"Debug"
	.byte	0
	.endif
	.byte	0

commands:
	.byte	"QTMTracker"
	.byte	0
	.p2align 2
	.long	0
	.byte	0
	.byte	0
	.byte	0
	.byte	0
	.long	0
	.long	hlp_qtm

	.byte	"QTMLoad"
	.byte	0
	.p2align 2
	.long	cmd_qtmload
	.byte	1
	.byte	1
	.byte	2
	.byte	0
	.long	syn_qtmload
	.long	hlp_qtmload
	.byte	"QTMStart"
	.byte	0
	.p2align 2
	.long	cmd_qtmstart
	.byte	0
	.byte	0
	.byte	0
	.byte	0
	.long	syn_qtmstart
	.long	hlp_qtmstart
	.byte	"QTMStop"
	.byte	0
	.p2align 2
	.long	cmd_qtmstop
	.byte	0
	.byte	0
	.byte	0
	.byte	0
	.long	syn_qtmstop
	.long	hlp_qtmstop
	.byte	"QTMPause"
	.byte	0
	.p2align 2
	.long	cmd_qtmpause
	.byte	0
	.byte	0
	.byte	0
	.byte	0
	.long	syn_qtmpause
	.long	hlp_qtmpause
	.byte	"QTMClear"
	.byte	0
	.p2align 2
	.long	cmd_qtmclear
	.byte	0
	.byte	0
	.byte	0
	.byte	0
	.long	syn_qtmclear
	.long	hlp_qtmclear
	.byte	"QTMInfo"
	.byte	0
	.p2align 2
	.long	cmd_qtminfo
	.byte	0
	.byte	0
	.byte	0
	.byte	0
	.long	syn_qtminfo
	.long	hlp_qtminfo
	.byte	"QTMSamples"
	.byte	0
	.p2align 2
	.long	cmd_qtmsamples
	.byte	0
	.byte	0
	.byte	0
	.byte	0
	.long	syn_qtmsamples
	.long	hlp_qtmsamples
	.byte	"QTMVolume"
	.byte	0
	.p2align 2
	.long	cmd_qtmvolume
	.byte	0
	.byte	0
	.byte	1
	.byte	0
	.long	syn_qtmvolume
	.long	hlp_qtmvolume
	.byte	"QTMPos"
	.byte	0
	.p2align 2
	.long	cmd_qtmpos
	.byte	0
	.byte	0
	.byte	2
	.byte	0
	.long	syn_qtmpos
	.long	hlp_qtmpos
	.byte	"QTMDisable"
	.byte	0
	.p2align 2
	.long	cmd_qtmdisable
	.byte	0
	.byte	0
	.byte	1
	.byte	0
	.long	syn_qtmdisable
	.long	hlp_qtmdisable
	.byte	"QTMEnable"
	.byte	0
	.p2align 2
	.long	cmd_qtmenable
	.byte	1
	.byte	0
	.byte	1
	.byte	0
	.long	syn_qtmenable
	.long	hlp_qtmenable
	.byte	"QTMTransparent"
	.byte	0
	.p2align 2
	.long	cmd_qtmtrans
	.byte	0
	.byte	0
	.byte	1
	.byte	0
	.long	syn_qtmtrans
	.long	hlp_qtmtrans

	.byte	0

hlp_qtm:
	.byte	"+--------------------------------------------------------------------------+",0x0D
	.byte	"|",0x09,0x09,0x09,0x09,0x09,0x09,0x09,0x09,0x09,0x1F,0x1F,0x1F,"|",0x0D
	.byte	"|",0x09,0x09,0x09,0xBB,0xBB,0xBB,0xA0,"QTM",0xA0,0xA0,"-",0xA0,0xA0,"Q",0xA0,"The",0xA0,"Music",0xA0,0xAB,0xAB,0xAB,0x09,0x09,0x09,0x1F,0x1F,0x1F,"|",0x0D
	.if alphatest | betatest
	.byte	"|",0x09,0x09,0x09,0x09,0x09,0x09,0x09,0x09,0x09,0x1F,0x1F,0x1F,"|",0x0D
	.byte	"|",0x09,0x1F,0x1F,0x1F,0x1F,"TEST VERSION TEST VERSION TEST VERSION TEST VERSION",0x09,0x09,0x1F,0x1F,0x1F,"|",0x0D
	.endif
	.byte	"|",0x09,0x09,0x09,0x09,0x09,0x09,0x09,0x09,0x09,0x1F,0x1F,0x1F,"|",0x0D
	.byte	"|",0x1F,0x1F,0x1F,0x1F,"The 4/6/8-channel RISC OS ProTracker/FastTracker/StarTrekker player",0x1F,0x1F,0x1F,"|",0x0D
	.byte	"|",0x09,0x09,0x09,0x09,0x09,0x09,0x09,0x09,0x09,0x1F,0x1F,0x1F,"|",0x0D
	.byte	"|",0x09,0x1F,0x1F,0x1F,"---> http://www.pi-star.co.uk/qtm",0x09,0x09,0x1F,0x1F,0x1F,0x1F,0x1F,0x1F,"<---",0x09,0x1F,0x1F,0x1F,"|",0x0D
	.byte	"|",0x09,0x1F,0x1F,0x1F,"---> http://www.phlamethrower.co.uk/riscos/qtm.php <---",0x09,0x1F,0x1F,0x1F,"|",0x0D
	.byte	"|",0x09,0x09,0x09,0x09,0x09,0x09,0x09,0x09,0x09,0x1F,0x1F,0x1F,"|",0x0D
helptextversion:
	.include "stamp_helptextversion.asm"                ; frozen post-assembly patch, per variant
	.if qtmrast
	.include "stamp_l3040.asm"
qtmrmtext:
	.include "stamp_l3040_2.asm"
	.endif
	.byte	"|",0x09,0x09,0x09,0x09,0x09,0x09,0x09,0x09,0x09,0x1F,0x1F,0x1F,"|",0x0D
	.byte	"+--------------------------------------------------------------------------+",0x0D
	.byte	0

hlp_qtmload:
	; *QTMLoad loads (and plays) the specified 15/31 inst sound tracker module. If an 'x' is placed af
	.byte	0x2A,0x1B,0x00,0x20,0x6C,0x6F,0x61,0x64,0x73,0x20,0x28,0x61,0x6E,0x64,0x20,0x70,0x6C,0x61,0x79,0x73,0x29,0x1B,0x02,0x73,0x70,0x65,0x63,0x69,0x66,0x69,0x65,0x64,0x20,0x31,0x35,0x2F,0x33,0x31,0x20,0x69,0x6E,0x73,0x74,0x20,0x73,0x6F,0x75,0x6E,0x64,0x20,0x74,0x72,0x61,0x63,0x6B,0x65,0x72,0x20,0x6D,0x6F,0x64,0x75,0x6C,0x65,0x2E,0x20,0x49,0x66,0x20,0x61,0x6E,0x20,0x27,0x78,0x27,0x1B,0x29,0x70,0x6C,0x61,0x63,0x65,0x64,0x20,0x61,0x66,0x74,0x65,0x72,0x1B,0x02,0x1B,0x07,0x1B,0x0B,0x2C,0x20,0x74,0x68,0x65,0x6E,0x1B,0x02,0x73,0x6F,0x75,0x6E,0x64,0x20,0x74,0x72,0x61,0x63,0x6B,0x65,0x72 ; frozen FNcompress output
	;  module will be loaded but the play routine will not be started, use *QTMStart to start the modu
	.byte	0x20,0x6D,0x6F,0x64,0x75,0x6C,0x65,0x20,0x77,0x69,0x6C,0x6C,0x20,0x62,0x65,0x20,0x6C,0x6F,0x61,0x64,0x65,0x64,0x20,0x62,0x75,0x74,0x1B,0x02,0x70,0x6C,0x61,0x79,0x20,0x72,0x6F,0x75,0x74,0x69,0x6E,0x65,0x20,0x77,0x69,0x6C,0x6C,0x20,0x6E,0x6F,0x74,0x20,0x62,0x65,0x20,0x73,0x74,0x61,0x72,0x74,0x65,0x64,0x2C,0x20,0x75,0x73,0x65,0x20,0x2A,0x51,0x54,0x4D,0x53,0x74,0x61,0x72,0x74,0x1B,0x28,0x73,0x74,0x61,0x72,0x74,0x1B,0x02,0x6D,0x6F,0x64,0x75,0x6C,0x65,0x20,0x70,0x6C,0x61,0x79,0x69,0x6E,0x67,0x2E ; frozen FNcompress output
	.byte	0xD
syn_qtmload:
	; Syntax: *QTMLoad <filename> [x]
	.byte	0x1B,0x1B,0x20,0x5B,0x78,0x5D                 ; frozen FNcompress output
	.byte	0

hlp_qtmclear:
	; *QTMClear stops the current song playing and removes it from memory, releasing the RMA used to s
	.byte	0x2A,0x1B,0x00,0x20,0x73,0x74,0x6F,0x70,0x73,0x1B,0x02,0x1B,0x05,0x20,0x73,0x6F,0x6E,0x67,0x20,0x70,0x6C,0x61,0x79,0x69,0x6E,0x67,0x1B,0x10,0x72,0x65,0x6D,0x6F,0x76,0x65,0x73,0x20,0x69,0x74,0x20,0x66,0x72,0x6F,0x6D,0x20,0x6D,0x65,0x6D,0x6F,0x72,0x79,0x2C,0x20,0x72,0x65,0x6C,0x65,0x61,0x73,0x69,0x6E,0x67,0x1B,0x02,0x52,0x4D,0x41,0x20,0x75,0x73,0x65,0x64,0x1B,0x28,0x73,0x74,0x6F,0x72,0x65,0x20,0x69,0x74,0x2E ; frozen FNcompress output
	.byte	0xD
syn_qtmclear:
	; Syntax: *QTMClear
	.byte	0x1B,0x01                                     ; frozen FNcompress output
	.byte	0

hlp_qtmstart:
	; *QTMStart starts the current song playing, if it has been stopped or paused.
	.byte	0x2A,0x1B,0x00,0x20,0x73,0x74,0x61,0x72,0x74,0x73,0x1B,0x02,0x1B,0x05,0x20,0x73,0x6F,0x6E,0x67,0x20,0x70,0x6C,0x61,0x79,0x69,0x6E,0x67,0x2C,0x20,0x69,0x66,0x20,0x69,0x74,0x20,0x68,0x61,0x73,0x20,0x62,0x65,0x65,0x6E,0x20,0x73,0x74,0x6F,0x70,0x70,0x65,0x64,0x20,0x6F,0x72,0x20,0x70,0x61,0x75,0x73,0x65,0x64,0x2E ; frozen FNcompress output
	.byte	0xD
syn_qtmstart:
	; Syntax: *QTMStart
	.byte	0x1B,0x01                                     ; frozen FNcompress output
	.byte	0

hlp_qtmpause:
	; *QTMPause stops the current song playing and resets the sound channels to their previous owner (
	.byte	0x2A,0x1B,0x00,0x20,0x73,0x74,0x6F,0x70,0x73,0x1B,0x02,0x1B,0x05,0x20,0x73,0x6F,0x6E,0x67,0x20,0x70,0x6C,0x61,0x79,0x69,0x6E,0x67,0x1B,0x10,0x72,0x65,0x1B,0x13,0x73,0x6F,0x75,0x6E,0x64,0x20,0x63,0x68,0x61,0x6E,0x6E,0x65,0x6C,0x73,0x1B,0x28,0x74,0x68,0x65,0x69,0x72,0x20,0x70,0x72,0x65,0x76,0x69,0x6F,0x75,0x73,0x20,0x6F,0x77,0x6E,0x65,0x72,0x20,0x28,0x75,0x73,0x65,0x20,0x2A,0x51,0x54,0x4D,0x53,0x74,0x61,0x72,0x74,0x1B,0x28,0x72,0x65,0x73,0x74,0x61,0x72,0x74,0x1B,0x02,0x70,0x6C,0x61,0x79,0x65,0x72,0x29,0x2E ; frozen FNcompress output
	.byte	0xD
syn_qtmpause:
	; Syntax: *QTMPause
	.byte	0x1B,0x01                                     ; frozen FNcompress output
	.byte	0

hlp_qtmstop:
	; *QTMStop acts as *QTMPause, but also sets the song sequence position to 0 and defaults the chann
	.byte	0x2A,0x1B,0x00,0x20,0x61,0x63,0x74,0x73,0x20,0x61,0x73,0x20,0x2A,0x51,0x54,0x4D,0x50,0x61,0x75,0x73,0x65,0x2C,0x20,0x62,0x75,0x74,0x20,0x61,0x6C,0x73,0x6F,0x20,0x1B,0x13,0x73,0x6F,0x6E,0x67,0x20,0x73,0x65,0x71,0x75,0x65,0x6E,0x63,0x65,0x20,0x70,0x6F,0x73,0x69,0x1B,0x09,0x1B,0x28,0x30,0x1B,0x10,0x64,0x65,0x66,0x61,0x75,0x6C,0x74,0x73,0x1B,0x02,0x63,0x68,0x61,0x6E,0x6E,0x65,0x6C,0x2F,0x65,0x66,0x66,0x65,0x63,0x74,0x20,0x66,0x6C,0x61,0x67,0x73,0x20,0x28,0x74,0x68,0x69,0x73,0x1B,0x29,0x65,0x71,0x75,0x69,0x76,0x61,0x6C,0x65,0x6E,0x74,0x1B,0x28,0x72,0x65,0x6C,0x6F,0x61,0x64,0x69,0x6E,0x67,0x1B,0x02,0x73,0x6F,0x6E,0x67,0x29,0x2E ; frozen FNcompress output
	.byte	0xD
syn_qtmstop:
	; Syntax: *QTMStop
	.byte	0x1B,0x01                                     ; frozen FNcompress output
	.byte	0

hlp_qtminfo:
	; *QTMInfo displays a variety of information about the currently loaded song.
	.byte	0x2A,0x1B,0x00,0x1B,0x20,0x20,0x61,0x20,0x76,0x61,0x72,0x69,0x65,0x74,0x79,0x20,0x6F,0x66,0x20,0x69,0x6E,0x66,0x6F,0x72,0x6D,0x61,0x1B,0x09,0x20,0x61,0x62,0x6F,0x75,0x74,0x1B,0x02,0x1B,0x05,0x6C,0x79,0x20,0x6C,0x6F,0x61,0x64,0x65,0x64,0x20,0x73,0x6F,0x6E,0x67,0x2E ; frozen FNcompress output
	.byte	0xD
syn_qtminfo:
	; Syntax: *QTMInfo
	.byte	0x1B,0x01                                     ; frozen FNcompress output
	.byte	0

hlp_qtmpos:
	; *QTMPos with no parameters displays the current position in the song's sequence table. If a numb
	.byte	0x2A,0x1B,0x00,0x20,0x77,0x69,0x74,0x68,0x20,0x6E,0x6F,0x20,0x1B,0x24,0x73,0x1B,0x20,0x1B,0x02,0x1B,0x05,0x20,0x70,0x6F,0x73,0x69,0x1B,0x09,0x20,0x69,0x6E,0x1B,0x02,0x73,0x6F,0x6E,0x67,0x27,0x73,0x20,0x73,0x65,0x71,0x75,0x65,0x6E,0x63,0x65,0x20,0x74,0x61,0x62,0x6C,0x65,0x2E,0x20,0x49,0x66,0x20,0x61,0x20,0x1B,0x0D,0x1B,0x29,0x73,0x70,0x65,0x63,0x69,0x66,0x69,0x65,0x64,0x2C,0x20,0x74,0x68,0x69,0x73,0x20,0x77,0x69,0x6C,0x6C,0x20,0x63,0x61,0x75,0x73,0x65,0x1B,0x02,0x70,0x6C,0x61,0x79,0x65,0x72 ; frozen FNcompress output
	;  to jump to that sequence position. If an 'x' is present after the number, the player will not r
	.byte	0x1B,0x28,0x6A,0x75,0x6D,0x70,0x1B,0x28,0x74,0x68,0x61,0x74,0x20,0x73,0x65,0x71,0x75,0x65,0x6E,0x63,0x65,0x20,0x70,0x6F,0x73,0x69,0x1B,0x09,0x2E,0x20,0x49,0x66,0x20,0x61,0x6E,0x20,0x27,0x78,0x27,0x1B,0x29,0x70,0x72,0x65,0x73,0x65,0x6E,0x74,0x20,0x61,0x66,0x74,0x65,0x72,0x1B,0x02,0x1B,0x0D,0x2C,0x1B,0x02,0x70,0x6C,0x61,0x79,0x65,0x72,0x20,0x77,0x69,0x6C,0x6C,0x20,0x6E,0x6F,0x74,0x20,0x72,0x65,0x73,0x65,0x74,0x1B,0x02,0x65,0x76,0x65,0x6E,0x74,0x20,0x63,0x6F,0x75,0x6E,0x74,0x20,0x77,0x68,0x65,0x6E,0x20,0x6A,0x75,0x6D,0x70,0x69,0x6E,0x67,0x1B,0x28,0x74,0x68,0x61,0x74,0x20,0x70,0x6F,0x73,0x69,0x1B,0x09,0x2E ; frozen FNcompress output
	.byte	0xD
syn_qtmpos:
	; Syntax: *QTMPos [<position> [x]]
	.byte	0x1B,0x1E,0x3C,0x70,0x6F,0x73,0x69,0x1B,0x09,0x3E,0x20,0x5B,0x78,0x5D,0x5D ; frozen FNcompress output
	.byte	0

hlp_qtmsamples:
	; *QTMSamples lists the names, lengths, repeats, etc. of all the samples used in the current song.
	.byte	0x2A,0x1B,0x00,0x20,0x6C,0x69,0x73,0x74,0x73,0x1B,0x02,0x1B,0x0B,0x73,0x2C,0x20,0x6C,0x65,0x6E,0x67,0x74,0x68,0x73,0x2C,0x20,0x72,0x65,0x70,0x65,0x61,0x74,0x73,0x2C,0x20,0x65,0x74,0x63,0x2E,0x20,0x6F,0x66,0x1B,0x26,0x74,0x68,0x65,0x20,0x73,0x61,0x6D,0x70,0x6C,0x65,0x73,0x20,0x75,0x73,0x65,0x64,0x20,0x69,0x6E,0x1B,0x02,0x1B,0x05,0x20,0x73,0x6F,0x6E,0x67,0x2E ; frozen FNcompress output
	.byte	0xD
syn_qtmsamples:
	; Syntax: *QTMSamples
	.byte	0x1B,0x01                                     ; frozen FNcompress output
	.byte	0

hlp_qtmdisable:
	; *QTMDisable with no parameters will list the numbers of the currently disabled effects. If an ef
	.byte	0x2A,0x1B,0x00,0x20,0x77,0x69,0x74,0x68,0x20,0x6E,0x6F,0x20,0x1B,0x24,0x73,0x20,0x77,0x69,0x6C,0x6C,0x20,0x6C,0x69,0x73,0x74,0x1B,0x02,0x1B,0x0D,0x73,0x20,0x6F,0x66,0x1B,0x02,0x1B,0x05,0x6C,0x79,0x20,0x64,0x69,0x73,0x61,0x62,0x6C,0x65,0x64,0x20,0x65,0x66,0x66,0x65,0x63,0x74,0x73,0x2E,0x20,0x49,0x66,0x20,0x61,0x6E,0x20,0x65,0x66,0x66,0x65,0x63,0x74,0x1B,0x29,0x73,0x70,0x65,0x63,0x69,0x66,0x69,0x65,0x64,0x2C,0x20,0x69,0x74,0x20,0x77,0x69,0x6C,0x6C,0x20,0x62,0x65,0x20,0x64,0x69,0x73,0x61,0x62,0x6C,0x65,0x64,0x20,0x66,0x72,0x6F,0x6D,0x1B,0x02,0x73,0x6F,0x6E,0x67,0x20,0x65,0x66,0x66,0x65,0x63,0x74,0x20,0x68,0x61,0x6E,0x64,0x6C,0x65,0x72,0x73,0x2E,0x20,0x28,0x65,0x6E,0x74,0x65,0x72,0x20,0x27,0x45,0x27,0x2D,0x65,0x66,0x66,0x65,0x63,0x74,0x73,0x20,0x61,0x73,0x20,0x27,0x2A,0x1B,0x00,0x20,0x45,0x36,0x27,0x20,0x65,0x74,0x63,0x2E,0x29 ; frozen FNcompress output
	.byte	0xD
syn_qtmdisable:
	; Syntax: *QTMDisable [<effect number>]
	.byte	0x1B,0x1E,0x3C,0x65,0x66,0x66,0x65,0x63,0x74,0x20,0x1B,0x0D,0x3E,0x5D ; frozen FNcompress output
	.byte	0

hlp_qtmenable:
	; *QTMEnable reverses the operation of *QTMDisable.
	.byte	0x2A,0x1B,0x00,0x20,0x72,0x65,0x76,0x65,0x72,0x73,0x65,0x73,0x1B,0x02,0x6F,0x70,0x65,0x72,0x61,0x1B,0x09,0x20,0x6F,0x66,0x20,0x2A,0x51,0x54,0x4D,0x44,0x69,0x73,0x61,0x62,0x6C,0x65,0x2E ; frozen FNcompress output
	.byte	0xD
syn_qtmenable:
	; Syntax: *QTMEnable <effect number>
	.byte	0x1B,0x0E,0x65,0x66,0x66,0x65,0x63,0x74,0x20,0x1B,0x0D,0x3E ; frozen FNcompress output

hlp_qtmtrans:
	; *QTMTransparent enables or disables QTM's Transparent Sound System (TSS). When switched on, RISC
	.byte	0x2A,0x1B,0x00,0x20,0x65,0x6E,0x61,0x62,0x6C,0x65,0x73,0x20,0x6F,0x72,0x20,0x64,0x69,0x73,0x61,0x62,0x6C,0x65,0x73,0x20,0x51,0x54,0x4D,0x27,0x73,0x20,0x54,0x72,0x61,0x6E,0x73,0x70,0x61,0x72,0x65,0x6E,0x74,0x20,0x53,0x6F,0x75,0x6E,0x64,0x20,0x53,0x79,0x73,0x74,0x65,0x6D,0x20,0x28,0x54,0x53,0x53,0x29,0x2E,0x20,0x57,0x68,0x65,0x6E,0x20,0x73,0x77,0x69,0x74,0x63,0x68,0x65,0x64,0x20,0x6F,0x6E,0x2C,0x20,0x52,0x49,0x53,0x43,0x20,0x4F,0x53,0x20,0x73,0x79,0x73,0x74,0x65,0x6D,0x20,0x73,0x6F,0x75,0x6E,0x64,0x73,0x20,0x63,0x6F,0x6E,0x74,0x69,0x6E,0x75,0x65,0x1B,0x28,0x62,0x65,0x20,0x70,0x6C,0x61,0x79,0x65,0x64,0x20,0x77,0x68,0x69,0x6C,0x65,0x20,0x51,0x54,0x4D,0x1B,0x29,0x70,0x6C,0x61,0x79,0x69,0x6E,0x67,0x20,0x6D,0x75,0x73,0x69,0x63,0x2E ; frozen FNcompress output
	.byte	0xD
syn_qtmtrans:
	; Syntax: *QTMTransparent [On|Off]
	.byte	0x1B,0x1E,0x4F,0x6E,0x7C,0x4F,0x66,0x66,0x5D  ; frozen FNcompress output
	.byte	0

hlp_qtmvolume:
	; *QTMVolume will set the overall output volume from the QTM play routine to the specified linear 
	.byte	0x2A,0x1B,0x00,0x20,0x77,0x69,0x6C,0x6C,0x20,0x73,0x65,0x74,0x1B,0x02,0x6F,0x76,0x65,0x72,0x61,0x6C,0x6C,0x20,0x6F,0x75,0x74,0x70,0x75,0x74,0x20,0x76,0x6F,0x6C,0x75,0x6D,0x65,0x20,0x66,0x72,0x6F,0x6D,0x1B,0x02,0x51,0x54,0x4D,0x20,0x70,0x6C,0x61,0x79,0x20,0x72,0x6F,0x75,0x74,0x69,0x6E,0x65,0x20,0x74,0x6F,0x1B,0x02,0x73,0x70,0x65,0x63,0x69,0x66,0x69,0x65,0x64,0x20,0x6C,0x69,0x6E,0x65,0x61,0x72,0x20,0x76,0x6F,0x6C,0x75,0x6D,0x65,0x20,0x28,0x30,0x2D,0x36,0x34,0x29,0x2E,0x20,0x49,0x66,0x1B,0x02,0x63,0x6F,0x6D,0x6D,0x61,0x6E,0x64,0x1B,0x29,0x69,0x73,0x73,0x75,0x65,0x64,0x20,0x77,0x69,0x74,0x68,0x6F,0x75,0x74,0x20,0x61,0x20,0x1B,0x24,0x2C,0x1B,0x02,0x1B,0x05,0x20,0x6F,0x76,0x65,0x72,0x61,0x6C,0x6C,0x20,0x76,0x6F,0x6C,0x75,0x6D,0x65,0x20,0x77,0x69,0x6C,0x6C,0x20,0x62,0x65,0x20,0x64,0x69,0x73,0x70,0x6C,0x61,0x79,0x65,0x64,0x2E ; frozen FNcompress output
	.byte	0xD
syn_qtmvolume:
	; Syntax: *QTMVolume [<volume 0-64>]
	.byte	0x1B,0x1E,0x3C,0x76,0x6F,0x6C,0x75,0x6D,0x65,0x20,0x30,0x2D,0x36,0x34,0x3E,0x5D ; frozen FNcompress output
	.byte	0
	.p2align 2




