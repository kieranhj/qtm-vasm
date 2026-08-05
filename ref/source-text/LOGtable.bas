   10 REM log to lin accurate conversion table creator
   20 REM by Phoenix
   30 :
   40 MODE 0
   50 PRINT"Wait a mo, while I create my log table... (";
   60 OFF
   70 :
   80 DIM loglin 256
   90 :
  100 FOR lin=0 TO 256<<5
  110 SYS"Sound_SoundLog",lin<<(24-5) TO log
  120 loglin?log=lin>>5
  130 PRINT TAB(43,0);log;") "
  140 NEXT
  150 :
  160 PRINT''"Finished!"''
  170 *.
  180 ON
  190 INPUT'"Filename for LOG table: "fn$
  200 OSCLI"Save "+fn$+" "+STR$~loglin+"+100"
  210 OSCLI"Settype "+fn$+" Data"
