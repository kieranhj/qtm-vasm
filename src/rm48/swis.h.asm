; SWI numbers used by QTM v1.49b.
; Extracted by tools/listing.py from the assembled words in the
; golden listing, so these are the numbers the original build used.

    .equ OS_EnterOS                  ,0x000016
    .equ OS_WriteC                   ,0x000000
    .equ Sound_Volume                ,0x040180
    .equ XOS_BinaryToDecimal         ,0x020028
    .equ XOS_Byte                    ,0x020006
    .equ XOS_ChangeDynamicArea       ,0x02002A
    .equ XOS_ConvertCardinal1        ,0x0200D5
    .equ XOS_ConvertCardinal2        ,0x0200D6
    .equ XOS_ConvertHex2             ,0x0200D1
    .equ XOS_ConvertInteger1         ,0x0200D9
    .equ XOS_ConvertSpacedCardinal4  ,0x0200E4
    .equ XOS_File                    ,0x020008
    .equ XOS_Heap                    ,0x02001D
    .equ XOS_Module                  ,0x02001E
    .equ XOS_NewLine                 ,0x020003
    .equ XOS_ReadDynamicArea         ,0x02005C
    .equ XOS_ReadMonotonicTime       ,0x020042
    .equ XOS_ReadSysInfo             ,0x020058
    .equ XOS_ReadUnsigned            ,0x020021
    .equ XOS_ReadVduVariables        ,0x020031
    .equ XOS_ValidateAddress         ,0x02003A
    .equ XOS_Write0                  ,0x020002
    .equ XOS_WriteC                  ,0x020000
    .equ XOS_WriteN                  ,0x020046
    .equ XOS_WriteS                  ,0x020001
    .equ XSound_4                    ,0x060144
    .equ XSound_6                    ,0x060146
    .equ XSound_Configure            ,0x060140
    .equ XSound_ReadControlBlock     ,0x06018B
    .equ XSound_SoundLog             ,0x060181
    .equ XSound_Stereo               ,0x060142
    .equ XSound_WriteControlBlock    ,0x06018C
