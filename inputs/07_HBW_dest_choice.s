
;System
    ;file to halt the model run if model crashes
    *(ECHO 'model crashed' > 07_HBW_dest_choice.txt)



;get start time
ScriptStartTime = currenttime()



;====================================================================================================================================================================;
; Preprocessing Steps
;====================================================================================================================================================================;

; Reorganize Walk Skims prior to running python destination choice model
RUN PGM=MATRIX   MSG='Mode Choice 7: process dest choice walk skims'
  FILEI mati[1] ='@ParentDir@@ScenarioDir@0_InputProcessing\c_TransitWalkSkim_FF.mtx'
  FILEO mato    ='@ParentDir@@ScenarioDir@Temp\4_ModeChoice\Best_Walk_Skims.mtx'  MO=1-7, NAME=WALKTIME, INITWAIT, XFERWAIT, T45678, DRIVETIME, TRANSFERS, GENCOST
  
  
    
    ;Cluster: distribute intrastep processing
    DistributeINTRASTEP PROCESSID=ClusterNodeID, PROCESSLIST=2-@CoresAvailable@
    
    
  ZONEMSG = @ZoneMsgRate@
  
  MW[1] = mi.1.WALKTIME
  MW[2] = mi.1.INITWAIT
  MW[3] = mi.1.XFERWAIT
  MW[4] = mi.1.IVTTime 
  MW[5] = 0                  ;drive time to transit is 0 for walk skim
  MW[6] = mi.1.XFERS  
  MW[7] = MW[4] + 2*MW[2] + 3*MW[3] + 4*MW[1] + 2.5*MW[5] 
  
  jloop
   IF(MW[4][j]==0)
      MW[1][j] = 0
      MW[2][j] = 0
      MW[3][j] = 0
      MW[5][j] = 0
      MW[6][j] = 0
      MW[7][j] = 0
   ENDIF
  endjloop    
ENDRUN


;====================================================================================================================================================================;
;Python HBW Destination Choice Model
;====================================================================================================================================================================;

; convert .mtx files used in destination choice model to .omx files for use in python model
RUN PGM=MATRIX MSG='0: Run HBW Destination Choice Model Python Script'

    ZONES = 1
    
    ;create control input file for this Python script
    PRINT FILE = '@ParentDir@@ScenarioDir@_Log\py_Variables - mc_HBW_dest_choice.txt',
        LIST='#Python input file variables and paths',
             '\n',
             '\nParentDir = @ParentDir@',       ;note: \ added to prevent python from crashing
             '\nScenarioDir = @ScenarioDir@',   ;note: \ added to prevent python from crashing
             '\nUsedZones = @UsedZones@',
             '\ndummyzones = "@dummyzones@"',
             '\nexternalzones = "@externalzones@"',
             '\n'
ENDRUN


;Python script: create json for transit routes
;  note using single asterix minimizes the command window when executed, double asterix executes the command window non-minimized
;  note: the 1>&2 echos the python window output to the one started by Cube
**"@ParentDir@2_ModelScripts\_Python\py-tdm-env\python.exe" "@ParentDir@2_ModelScripts\_Python\mc_HBW_dest_choice.py" 1>&2


;handle python script errors
if (ReturnCode<>0)
    
    PROMPT QUESTION='Python failed to run correctly',
        ANSWER="Please check the py log file in '@ParentDir@@ScenarioDir@_Log' for error messages."
    
    GOTO :ONERROR
    
    ABORT
    
endif  ;ReturnCode<>0


;DOS command to delete '__pycache__' folder
;  note: '/s' removes folder & contents of folder includling any subfolders
;  note: '/q' denotes quite mode, meaning doesn't ask for confirmation to delete
*(rmdir /s /q "_Log\__pycache__")
*(rmdir /s /q "@ParentDir@2_ModelScripts\_Python\py-vizTool\__pycache__")




;====================================================================================================================================================================;
;Postprocessing Steps
;====================================================================================================================================================================;
;copy and reorganize output files from python script
RUN PGM=MATRIX   MSG='Mode Choice 7: copy and rename HBW-Veh-Inc matrices from final iteration'
 zones=@UsedZones@
 maxmw=999                      ;resets the maximimum number of working matrices from 200 to 900
 zonemsg=@ZoneMsgRate@          ;reduces print messages in TPP DOS. (i.e. runs faster).

    MATI[1] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\pa_HBW_0veh_lo_tmp.mtx'    ;trips for each market segment
    MATI[2] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\pa_HBW_0veh_hi_tmp.mtx'
    MATI[3] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\pa_HBW_1veh_lo_tmp.mtx'
    MATI[4] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\pa_HBW_1veh_hi_tmp.mtx'
    MATI[5] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\pa_HBW_2veh_lo_noXI_tmp.mtx'
    MATI[6] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\pa_HBW_2veh_hi_noXI_tmp.mtx'
    MATI[7] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\pa_HBW_total_noXI_tmp.mtx'
    MATI[8] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\pa_HBW_NumVeh_noXI_tmp.mtx'

    MATO[1] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\pa_HBW_0veh_lo.mtx', 
        mo=101-109,
        name=ini_trips100,
             ini_trips   ,
             trips100    ,
             trips       ,
             Tel_trips100,
             Tel_trips   ,
             Tot_trips100,
             Tot_trips   ,
             share       
    
    MATO[2] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\pa_HBW_0veh_hi.mtx', 
        mo=201-209,
        name=ini_trips100,
             ini_trips   ,
             trips100    ,
             trips       ,
             Tel_trips100,
             Tel_trips   ,
             Tot_trips100,
             Tot_trips   ,
             share       
    
    MATO[3] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\pa_HBW_1veh_lo.mtx', 
        mo=301-309,
        name=ini_trips100,
             ini_trips   ,
             trips100    ,
             trips       ,
             Tel_trips100,
             Tel_trips   ,
             Tot_trips100,
             Tot_trips   ,
             share       
    
    MATO[4] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\pa_HBW_1veh_hi.mtx', 
        mo=401-409,
        name=ini_trips100,
             ini_trips   ,
             trips100    ,
             trips       ,
             Tel_trips100,
             Tel_trips   ,
             Tot_trips100,
             Tot_trips   ,
             share       
    
    MATO[5] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\pa_HBW_2veh_lo_noXI.mtx', 
        mo=501-509,
        name=ini_trips100,
             ini_trips   ,
             trips100    ,
             trips       ,
             Tel_trips100,
             Tel_trips   ,
             Tot_trips100,
             Tot_trips   ,
             share       
    
    MATO[6] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\pa_HBW_2veh_hi_noXI.mtx', 
        mo=601-609,
        name=ini_trips100,
             ini_trips   ,
             trips100    ,
             trips       ,
             Tel_trips100,
             Tel_trips   ,
             Tot_trips100,
             Tot_trips   ,
             share       
    
    MATO[7] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\pa_HBW_total_noXI.mtx',
        mo=701-708,
        name=ini_trips100,
             ini_trips   ,
             trips100    ,
             trips       ,
             Tel_trips100,
             Tel_trips   ,
             Tot_trips100,
             Tot_trips   
    
    MATO[8] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\pa_HBW_NumVeh_noXI.mtx',
        mo=801-812,
        name=HBWTOT    ,
             HBW0      ,
             HBW1      ,
             HBW2      ,
             Tel_HBWTOT,
             Tel_HBW0  ,
             Tel_HBW1  ,
             Tel_HBW2  ,
             Tot_HBWTOT,
             Tot_HBW0  ,
             Tot_HBW1  ,
             Tot_HBW2  
    
    
    ;Cluster: distribute intrastep processing
    DistributeINTRASTEP PROCESSID=ClusterNodeID, PROCESSLIST=2-@CoresAvailable@
    
    mw[101] = mi.1.ini_trips100
    mw[102] = mi.1.ini_trips
    mw[103] = mi.1.trips100
    mw[104] = mi.1.trips
    mw[105] = mi.1.Tel_trips100
    mw[106] = mi.1.Tel_trips
    mw[107] = mi.1.Tot_trips100
    mw[108] = mi.1.Tot_trips
    mw[109] = mi.1.share
    
    mw[201] = mi.2.ini_trips100
    mw[202] = mi.2.ini_trips
    mw[203] = mi.2.trips100
    mw[204] = mi.2.trips
    mw[205] = mi.2.Tel_trips100
    mw[206] = mi.2.Tel_trips
    mw[207] = mi.2.Tot_trips100
    mw[208] = mi.2.Tot_trips
    mw[209] = mi.2.share
    
    mw[301] = mi.3.ini_trips100
    mw[302] = mi.3.ini_trips
    mw[303] = mi.3.trips100
    mw[304] = mi.3.trips
    mw[305] = mi.3.Tel_trips100
    mw[306] = mi.3.Tel_trips
    mw[307] = mi.3.Tot_trips100
    mw[308] = mi.3.Tot_trips
    mw[309] = mi.3.share
    
    mw[401] = mi.4.ini_trips100
    mw[402] = mi.4.ini_trips
    mw[403] = mi.4.trips100
    mw[404] = mi.4.trips
    mw[405] = mi.4.Tel_trips100
    mw[406] = mi.4.Tel_trips
    mw[407] = mi.4.Tot_trips100
    mw[408] = mi.4.Tot_trips
    mw[409] = mi.4.share
    
    mw[501] = mi.5.ini_trips100
    mw[502] = mi.5.ini_trips
    mw[503] = mi.5.trips100
    mw[504] = mi.5.trips
    mw[505] = mi.5.Tel_trips100
    mw[506] = mi.5.Tel_trips
    mw[507] = mi.5.Tot_trips100
    mw[508] = mi.5.Tot_trips
    mw[509] = mi.5.share
    
    mw[601] = mi.6.ini_trips100
    mw[602] = mi.6.ini_trips
    mw[603] = mi.6.trips100
    mw[604] = mi.6.trips
    mw[605] = mi.6.Tel_trips100
    mw[606] = mi.6.Tel_trips
    mw[607] = mi.6.Tot_trips100
    mw[608] = mi.6.Tot_trips
    mw[609] = mi.6.share
    
    mw[701] = mi.7.ini_trips100
    mw[702] = mi.7.ini_trips
    mw[703] = mi.7.trips100
    mw[704] = mi.7.trips
    mw[705] = mi.7.Tel_trips100
    mw[706] = mi.7.Tel_trips
    mw[707] = mi.7.Tot_trips100
    mw[708] = mi.7.Tot_trips
    
    mw[801] = mi.8.HBWTOT
    mw[802] = mi.8.HBW0
    mw[803] = mi.8.HBW1
    mw[804] = mi.8.HBW2
    mw[805] = mi.8.Tel_HBWTOT
    mw[806] = mi.8.Tel_HBW0
    mw[807] = mi.8.Tel_HBW1
    mw[808] = mi.8.Tel_HBW2
    mw[809] = mi.8.Tot_HBWTOT
    mw[810] = mi.8.Tot_HBW0
    mw[811] = mi.8.Tot_HBW1
    mw[812] = mi.8.Tot_HBW2
    
ENDRUN



;output new P/A matrix file for all purporses (replace distribution HBW with destination choice HBW)
RUN PGM=MATRIX   MSG='Mode Choice 7: replace HBW trips in distribution trip table'
FILEI MATI[1] = '@ParentDir@@ScenarioDir@3_Distribute\PA_AllPurp_GRAVITY.mtx'
FILEI MATI[2] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\pa_HBW_NumVeh_noXI.mtx'

FILEO MATO[1] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\pa_AllPurp.2.DestChoice.mtx', 
    mo=100-116, 120-124, 130-133, 141-146, 200-203, 300-303,
    name=TOT         ,
         HBW         ,
         HBShp       ,
         HBOth       ,
         HBSch_Pr    ,
         HBSch_Sc    ,
         HBC         ,
         NHBW        ,
         NHBNW       ,
         IX          ,
         XI          ,
         XX          ,
         SH_LT       ,
         SH_MD       ,
         SH_HV       ,
         Ext_MD      ,
         Ext_HV      ,
                     
         HBSch       ,
         HBO         ,
         NHB         ,
         TTUNIQUE    ,
         HBOthnTT    ,
         
         Tot_HBW     ,
         Tel_HBW     ,
         Tot_NHBW    ,
         Tel_NHBW    ,
                 
         IX_MD       ,
         XI_MD       ,
         XX_MD       ,
         IX_HV       ,
         XI_HV       ,
         XX_HV       ,
         
         D_TOT       ,         ;original values from distribution
         D_HBW       ,
         D_Tot_HBW   ,
         D_Tel_HBW   ,
         dif_TOT     ,
         dif_HBW     ,
         dif_Tot_HBW ,
         dif_Tel_HBW 
    
    
    ;Cluster: distribute intrastep processing
    DistributeINTRASTEP PROCESSID=ClusterNodeID, PROCESSLIST=2-@CoresAvailable@
    
    
    ZONES   = @Usedzones@
    ZONEMSG = 10
    
    
    
    ;assign trips from distribution
    mw[102] = mi.1.HBShp
    mw[103] = mi.1.HBOth
    mw[104] = mi.1.HBSch_Pr
    mw[105] = mi.1.HBSch_Sc
    mw[106] = mi.1.HBC
    mw[107] = mi.1.NHBW
    mw[108] = mi.1.NHBNW
    mw[109] = mi.1.IX
    mw[110] = mi.1.XI
    mw[111] = mi.1.XX
    mw[112] = mi.1.SH_LT
    mw[113] = mi.1.SH_MD
    mw[114] = mi.1.SH_HV
    mw[115] = mi.1.Ext_MD
    mw[116] = mi.1.Ext_HV
    
    mw[120] = mi.1.HBSch
    mw[121] = mi.1.HBO
    mw[122] = mi.1.NHB
    mw[123] = mi.1.TTUNIQUE
    mw[124] = mi.1.HBOthnTT
    
    mw[132] = mi.1.Tot_NHBW
    mw[133] = mi.1.Tel_NHBW
    
    
    ;save distribtution total, HBW & HBW telecommute trips
    mw[200] = mi.1.TOT
    mw[201] = mi.1.HBW
    mw[202] = mi.1.Tot_HBW
    mw[203] = mi.1.Tel_HBW
    
    
    ;replace HBW & HBW-Telecommute from distribution with results from destination choice
    mw[101] = mi.2.HBWTOT
    mw[130] = mi.2.Tot_HBWTOT
    mw[131] = mi.2.Tel_HBWTOT

    ;IX, XI & XX Truck
    mw[141] = mi.1.IX_MD
    mw[142] = mi.1.XI_MD
    mw[143] = mi.1.XX_MD
    mw[144] = mi.1.IX_HV
    mw[145] = mi.1.XI_HV
    mw[146] = mi.1.XX_HV
    
    
    ;calculate trip totals with HBW from destination choice
    mw[100] = mw[101] +                 ;HBW          
              mw[102] +                 ;HBShp   
              mw[103] +                 ;HBOth   
              mw[104] +                 ;HBSch_Pr
              mw[105] +                 ;HBSch_Sc
              mw[106] +                 ;HBC     
              mw[107] +                 ;NHBW    
              mw[108] +                 ;NHBNW   
              mw[109] +                 ;IX      
              mw[110] +                 ;XI      
              mw[111] +                 ;XX      
              mw[112] +                 ;SH_LT   
              mw[113] +                 ;SH_MD   
              mw[114] +                 ;SH_HV   
              mw[115] +                 ;Ext_MD  
              mw[116]                   ;Ext_HV  
    
    
    ;calculate difference
    mw[300] = mw[100] - mw[200]         ;TOT
    mw[301] = mw[101] - mw[201]         ;HBW
    mw[302] = mw[130] - mw[202]         ;Tot_HBW 
    mw[303] = mw[131] - mw[203]         ;Tel_HBW 
    
ENDRUN



;print timestamp
RUN PGM=MATRIX
    
    ZONES = 1
    
    ScriptEndTime = currenttime()
    ScriptRunTime = ScriptEndTime - @ScriptStartTime@
    
    PRINT FILE='@ParentDir@@ScenarioDir@_Log\_RunTime.txt',
        APPEND=T,
        LIST='\n    Destination Choice                 ', formatdatetime(@ScriptStartTime@, 40, 0, 'yyyy-mm-dd,  hh:nn:ss'), 
                 ',  ', formatdatetime(ScriptRunTime, 40, 0, 'hhh:nn:ss')
    
ENDRUN




*(del 07_HBW_dest_choice.txt)
