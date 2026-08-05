   10 REM Text compressor for OS_PrettyPrint LEN 1994 Phoenix
   20 REM
   30 ON ERROR REPORT:PRINT" at line ";ERL:END
   40 MODE78
   50 PROCdefinecodes
   60 text$="Syntax: *QTMLoad <filename> [x]"
   70 comp$=FNcompress(text$,"QTMLoad")
   80 PRINT LEN text$,LEN comp$
   90 PRINT text$
  100 SYS"OS_PrettyPrint",comp$,0,"QTMLoad"
  110 END
  120 
  130 DEF FNcompress(text$,r2$)
  140 PROCsetspecial(r2$)
  150 PROCsortorder
  160 pos%=0
  170 word%=1
  180 REPEAT
  190 currentword%=order(word%)
  200 pos%=INSTR(text$,full$(currentword%),pos%+1)
  210 REM PRINTpos%,full$(currentword%)
  220 IF pos%>0 text$=LEFT$(text$,pos%-1)+CHR$27+CHR$ code(currentword%)+RIGHT$(text$,LEN text$-(pos%+LEN full$(currentword%)-1))
  230 IF pos%=0 THEN word%+=1
  240 UNTIL word%=42
  250 REM PRINTLENtext$
  260 =text$
  270 
  280 DEF PROCsetspecial(r2$)
  290 word%=1
  300 REPEAT
  310  IF r2pos(word%)<>-1 THEN
  320   full$(word%)=LEFT$(word$(word%),r2pos(word%))+r2$+RIGHT$(word$(word%),LEN word$(word%)-r2pos(word%))
  330  ENDIF
  340  word%+=1
  350 UNTIL r2pos(word%)=&FF
  360 ENDPROC
  370 
  380 DEF PROCdefinecodes
  390 RESTORE
  400 READ maxwords%
  410 DIM word$(maxwords%)
  420 DIM full$(maxwords%)
  430 DIM code(maxwords%)
  440 DIM r2pos(maxwords%)
  450 DIM len(maxwords%)
  460 DIM order(maxwords%)
  470 word%=1
  480 REPEAT
  490 READ r2pos(word%)
  500 IF r2pos(word%)<>&FF THEN
  510  READ code(word%)
  520  READ word$(word%)
  530  full$(word%)=word$(word%)
  540  len(word%)=LEN word$(word%)
  550  word%+=1
  560 ENDIF
  570 UNTIL r2pos(word%)=&FF
  580 ENDPROC
  590 
  600 DEF PROCsortorder
  610 word%=1
  620 REPEAT
  630  len(word%)=LEN full$(word%)
  640  word%+=1
  650 UNTIL r2pos(word%)=&FF
  660 PROCorderarray(len(),order(),word%-1)
  670 REM FOR I=1 TO word%-1
  680 REM PRINTorder(I),code(order(I)),full$(order(I))
  690 REM NEXT
  700 ENDPROC
  710 
  720 DEF PROCorderarray(nums(),RETURN order(),length)
  730 FOR fill=1 TO length:order(fill)=fill:NEXT
  740 number=2
  750 REPEAT
  760  IF nums(number)>nums(number-1) THEN
  770   current=number
  780   REPEAT
  790    SWAP nums(number),nums(number-1)
  800    SWAP order(number),order(number-1)
  810    number-=1
  820   UNTIL number=1 OR nums(number)<nums(number-1)
  830   number=current
  840  ENDIF
  850  number+=1
  860 UNTIL number>length
  870 ENDPROC
  880 
  890 REM sorted order     sorted value
  900 REM            \    /
  910 REM     1-54    5-98
  920 REM     2-34    4-87
  930 REM     3-76    3-76
  940 REM     4-87    1-54
  950 REM     5-98    7-43
  960 REM     6-23    2-34
  970 REM     7-43    6-23
  980 REM     8-1     9-3
  990 REM     9-3     8-1
 1000 
 1010 DATA  42
 1020 DATA  0, 0,""
 1030 DATA  9, 1,"Syntax: *"
 1040 DATA -1, 2," the "
 1050 DATA -1, 3,"director"
 1060 DATA -1, 4,"filing system"
 1070 DATA -1, 5,"current"
 1080 DATA -1, 6," to a variable. Other types of value can be assigned with *"
 1090 DATA -1, 7,"file"
 1100 DATA -1, 8,"default "
 1110 DATA -1, 9,"tion"
 1120 DATA -1,10,"*Configure "
 1130 DATA -1,11,"name"
 1140 DATA -1,12," server"
 1150 DATA -1,13,"number"
 1160 DATA  9,14,"Syntax: * <"
 1170 DATA -1,15," one or more files that match the given wildcard"
 1180 DATA -1,16," and "
 1190 DATA -1,17,"relocatable module"
 1200 DATA -1,18,"C(onfirm)	Prompt for confirmation of each "
 1210 DATA -1,19,"sets the "
 1220 DATA  9,20,"Syntax: * [<disc spec.>]"
 1230 DATA -1,21,"} V(erbose)	Print information on each file "
 1240 DATA -1,23,"spriteLandscape [<XScale> [<YScale> [<Margin> [<Threshold>]]]]]"
 1250 DATA -1,24," is used to print a hard copy of the screen on EPSON-"
 1260 DATA -1,25,". Options: (use ~ to force off, eg. ~"
 1270 DATA -1,26,"printe"
 1280 DATA  9,27,"Syntax: * <filename>"
 1290 DATA -1,28,"select"
 1300 DATA -1,29,"xpression"
 1310 DATA  9,30,"Syntax: * ["
 1320 DATA -1,31,"sprite"
 1330 DATA -1,32," displays"
 1340 DATA -1,33,"free space"
 1350 DATA -1,34," {off}"
 1360 DATA -1,35,"library"
 1370 DATA -1,36,"parameter"
 1380 DATA -1,37,"object"
 1390 DATA -1,38," all "
 1400 DATA -1,39,"disc"
 1410 DATA -1,40," to "
 1420 DATA -1,41," is "
 1430 DATA &FF
 1440 
