
;System
    ;file to halt the model run if model crashes
    *(ECHO 'model crashed' > 07_HBW_dest_choice.txt)



;get start time
ScriptStartTime = currenttime()




;calculate and print HBW productions by market segment (vehicles, income) for each zone
RUN PGM=MATRIX   MSG='Mode Choice 7: calculate productions by market segment - HBW'
 zones=@UsedZones@
 zonemsg=@ZoneMsgRate@          ;reduces print messages in TPP DOS. (i.e. runs faster).

    ;read in % of HBW trip productions by household size, autos, workers and income
    ZDATI[1] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\HH1_PercTrips_segment_hbw.dbf'
    ZDATI[2] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\HH2_PercTrips_segment_hbw.dbf'
    ZDATI[3] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\HH3_PercTrips_segment_hbw.dbf'
    ZDATI[4] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\HH4_PercTrips_segment_hbw.dbf'
    ZDATI[5] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\HH5_PercTrips_segment_hbw.dbf'
    ZDATI[6] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\HH6_PercTrips_segment_hbw.dbf'

    ZDATI[7]='@ParentDir@@ScenarioDir@2_TripGen\pa_initial.dbf'           ;productions/attractions by TAZ

    
    ;Cluster: distribute intrastep processing
    DistributeINTRASTEP PROCESSID=ClusterNodeID, PROCESSLIST=2-@CoresAvailable@
    
    

; NOTE: in MATRIX there is a built-in loop through all production zones


  IF (Z=@dummyzones@ | Z=@externalzones@)
    trips_0veh_lo = 0
    trips_1veh_lo = 0
    trips_2veh_lo = 0
    trips_0veh_hi = 0
    trips_1veh_hi = 0
    trips_2veh_hi = 0
  ELSE
    ;for each production zone calculate HBW productions by households stratified by autos (0,1,2+) and income (low, not low)
    trips_0veh_lo =     (ZI.1.P_ILW0V0[Z] + ZI.1.P_ILW1V0[Z] + ZI.1.P_ILW2V0[Z] + ZI.1.P_ILW3V0[Z] +
                         ZI.2.P_ILW0V0[Z] + ZI.2.P_ILW1V0[Z] + ZI.2.P_ILW2V0[Z] + ZI.2.P_ILW3V0[Z] +
                         ZI.3.P_ILW0V0[Z] + ZI.3.P_ILW1V0[Z] + ZI.3.P_ILW2V0[Z] + ZI.3.P_ILW3V0[Z] +
                         ZI.4.P_ILW0V0[Z] + ZI.4.P_ILW1V0[Z] + ZI.4.P_ILW2V0[Z] + ZI.4.P_ILW3V0[Z] +
                         ZI.5.P_ILW0V0[Z] + ZI.5.P_ILW1V0[Z] + ZI.5.P_ILW2V0[Z] + ZI.5.P_ILW3V0[Z] +
                         ZI.6.P_ILW0V0[Z] + ZI.6.P_ILW1V0[Z] + ZI.6.P_ILW2V0[Z] + ZI.6.P_ILW3V0[Z]) * ZI.7.HBW_P[Z]

    trips_1veh_lo =     (ZI.1.P_ILW0V1[Z] + ZI.1.P_ILW1V1[Z] + ZI.1.P_ILW2V1[Z] + ZI.1.P_ILW3V1[Z] +
                         ZI.2.P_ILW0V1[Z] + ZI.2.P_ILW1V1[Z] + ZI.2.P_ILW2V1[Z] + ZI.2.P_ILW3V1[Z] +
                         ZI.3.P_ILW0V1[Z] + ZI.3.P_ILW1V1[Z] + ZI.3.P_ILW2V1[Z] + ZI.3.P_ILW3V1[Z] +
                         ZI.4.P_ILW0V1[Z] + ZI.4.P_ILW1V1[Z] + ZI.4.P_ILW2V1[Z] + ZI.4.P_ILW3V1[Z] +
                         ZI.5.P_ILW0V1[Z] + ZI.5.P_ILW1V1[Z] + ZI.5.P_ILW2V1[Z] + ZI.5.P_ILW3V1[Z] +
                         ZI.6.P_ILW0V1[Z] + ZI.6.P_ILW1V1[Z] + ZI.6.P_ILW2V1[Z] + ZI.6.P_ILW3V1[Z]) * ZI.7.HBW_P[Z]

    trips_2veh_lo =     (ZI.1.P_ILW0V2[Z] + ZI.1.P_ILW1V2[Z] + ZI.1.P_ILW2V2[Z] + ZI.1.P_ILW3V2[Z] +
                         ZI.2.P_ILW0V2[Z] + ZI.2.P_ILW1V2[Z] + ZI.2.P_ILW2V2[Z] + ZI.2.P_ILW3V2[Z] +
                         ZI.3.P_ILW0V2[Z] + ZI.3.P_ILW1V2[Z] + ZI.3.P_ILW2V2[Z] + ZI.3.P_ILW3V2[Z] +
                         ZI.4.P_ILW0V2[Z] + ZI.4.P_ILW1V2[Z] + ZI.4.P_ILW2V2[Z] + ZI.4.P_ILW3V2[Z] +
                         ZI.5.P_ILW0V2[Z] + ZI.5.P_ILW1V2[Z] + ZI.5.P_ILW2V2[Z] + ZI.5.P_ILW3V2[Z] +
                         ZI.6.P_ILW0V2[Z] + ZI.6.P_ILW1V2[Z] + ZI.6.P_ILW2V2[Z] + ZI.6.P_ILW3V2[Z] +
                         ZI.1.P_ILW0V3[Z] + ZI.1.P_ILW1V3[Z] + ZI.1.P_ILW2V3[Z] + ZI.1.P_ILW3V3[Z] +
                         ZI.2.P_ILW0V3[Z] + ZI.2.P_ILW1V3[Z] + ZI.2.P_ILW2V3[Z] + ZI.2.P_ILW3V3[Z] +
                         ZI.3.P_ILW0V3[Z] + ZI.3.P_ILW1V3[Z] + ZI.3.P_ILW2V3[Z] + ZI.3.P_ILW3V3[Z] +
                         ZI.4.P_ILW0V3[Z] + ZI.4.P_ILW1V3[Z] + ZI.4.P_ILW2V3[Z] + ZI.4.P_ILW3V3[Z] +
                         ZI.5.P_ILW0V3[Z] + ZI.5.P_ILW1V3[Z] + ZI.5.P_ILW2V3[Z] + ZI.5.P_ILW3V3[Z] +
                         ZI.6.P_ILW0V3[Z] + ZI.6.P_ILW1V3[Z] + ZI.6.P_ILW2V3[Z] + ZI.6.P_ILW3V3[Z]) * ZI.7.HBW_P[Z]

    trips_0veh_hi =      (ZI.1.P_IHW0V0[Z] + ZI.1.P_IHW1V0[Z] + ZI.1.P_IHW2V0[Z] + ZI.1.P_IHW3V0[Z] +
                          ZI.2.P_IHW0V0[Z] + ZI.2.P_IHW1V0[Z] + ZI.2.P_IHW2V0[Z] + ZI.2.P_IHW3V0[Z] +
                          ZI.3.P_IHW0V0[Z] + ZI.3.P_IHW1V0[Z] + ZI.3.P_IHW2V0[Z] + ZI.3.P_IHW3V0[Z] +
                          ZI.4.P_IHW0V0[Z] + ZI.4.P_IHW1V0[Z] + ZI.4.P_IHW2V0[Z] + ZI.4.P_IHW3V0[Z] +
                          ZI.5.P_IHW0V0[Z] + ZI.5.P_IHW1V0[Z] + ZI.5.P_IHW2V0[Z] + ZI.5.P_IHW3V0[Z] +
                          ZI.6.P_IHW0V0[Z] + ZI.6.P_IHW1V0[Z] + ZI.6.P_IHW2V0[Z] + ZI.6.P_IHW3V0[Z]) * ZI.7.HBW_P[Z]

    trips_1veh_hi =      (ZI.1.P_IHW0V1[Z] + ZI.1.P_IHW1V1[Z] + ZI.1.P_IHW2V1[Z] + ZI.1.P_IHW3V1[Z] +
                          ZI.2.P_IHW0V1[Z] + ZI.2.P_IHW1V1[Z] + ZI.2.P_IHW2V1[Z] + ZI.2.P_IHW3V1[Z] +
                          ZI.3.P_IHW0V1[Z] + ZI.3.P_IHW1V1[Z] + ZI.3.P_IHW2V1[Z] + ZI.3.P_IHW3V1[Z] +
                          ZI.4.P_IHW0V1[Z] + ZI.4.P_IHW1V1[Z] + ZI.4.P_IHW2V1[Z] + ZI.4.P_IHW3V1[Z] +
                          ZI.5.P_IHW0V1[Z] + ZI.5.P_IHW1V1[Z] + ZI.5.P_IHW2V1[Z] + ZI.5.P_IHW3V1[Z] +
                          ZI.6.P_IHW0V1[Z] + ZI.6.P_IHW1V1[Z] + ZI.6.P_IHW2V1[Z] + ZI.6.P_IHW3V1[Z]) * ZI.7.HBW_P[Z]

    trips_2veh_hi =      (ZI.1.P_IHW0V2[Z] + ZI.1.P_IHW1V2[Z] + ZI.1.P_IHW2V2[Z] + ZI.1.P_IHW3V2[Z] +
                          ZI.2.P_IHW0V2[Z] + ZI.2.P_IHW1V2[Z] + ZI.2.P_IHW2V2[Z] + ZI.2.P_IHW3V2[Z] +
                          ZI.3.P_IHW0V2[Z] + ZI.3.P_IHW1V2[Z] + ZI.3.P_IHW2V2[Z] + ZI.3.P_IHW3V2[Z] +
                          ZI.4.P_IHW0V2[Z] + ZI.4.P_IHW1V2[Z] + ZI.4.P_IHW2V2[Z] + ZI.4.P_IHW3V2[Z] +
                          ZI.5.P_IHW0V2[Z] + ZI.5.P_IHW1V2[Z] + ZI.5.P_IHW2V2[Z] + ZI.5.P_IHW3V2[Z] +
                          ZI.6.P_IHW0V2[Z] + ZI.6.P_IHW1V2[Z] + ZI.6.P_IHW2V2[Z] + ZI.6.P_IHW3V2[Z] +
                          ZI.1.P_IHW0V3[Z] + ZI.1.P_IHW1V3[Z] + ZI.1.P_IHW2V3[Z] + ZI.1.P_IHW3V3[Z] +
                          ZI.2.P_IHW0V3[Z] + ZI.2.P_IHW1V3[Z] + ZI.2.P_IHW2V3[Z] + ZI.2.P_IHW3V3[Z] +
                          ZI.3.P_IHW0V3[Z] + ZI.3.P_IHW1V3[Z] + ZI.3.P_IHW2V3[Z] + ZI.3.P_IHW3V3[Z] +
                          ZI.4.P_IHW0V3[Z] + ZI.4.P_IHW1V3[Z] + ZI.4.P_IHW2V3[Z] + ZI.4.P_IHW3V3[Z] +
                          ZI.5.P_IHW0V3[Z] + ZI.5.P_IHW1V3[Z] + ZI.5.P_IHW2V3[Z] + ZI.5.P_IHW3V3[Z] +
                          ZI.6.P_IHW0V3[Z] + ZI.6.P_IHW1V3[Z] + ZI.6.P_IHW2V3[Z] + ZI.6.P_IHW3V3[Z]) * ZI.7.HBW_P[Z]

  ENDIF

    ;print HBW productions by households stratified by autos (0,1,2+) and income (low, not low) for each zone
    print file = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\HBW_prods_by_autos_income.txt', form=8.0 list=  Z(6), trips_0veh_lo, trips_0veh_hi,
                                                                                 trips_1veh_lo, trips_1veh_hi,
                                                                                 trips_2veh_lo, trips_2veh_hi

ENDRUN




;use NETWORK to convert text file to dbf
RUN PGM=NETWORK

 FILEI NODEI = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\HBW_prods_by_autos_income.txt', VAR=N, p_0veh_lo, p_0veh_hi,
                                                                   p_1veh_lo, p_1veh_hi,
                                                                   p_2veh_lo, p_2veh_hi

 FILEO NODEO = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\HBW_prods_by_autos_income.dbf', FORMAT=DBF
 ZONES=@UsedZones@
ENDRUN




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




;* ************************ Begin HBW Destination Choice Model ***************** *

n=0  ;iteration counter (iterate until P/A balance)

;initialize trip attraction adjustment factors to 0 and percent differences to 100%
;	adjustment factors are used to doubly-constrain gravity model
;	percent differences measure the extent to which trip distribution matches trip generation
RUN PGM=MATRIX   MSG='Mode Choice 7: initialzie trip adjustment factors'
zones=@UsedZones@

 PRINT file = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\adjust_attractions_@n@.txt', form=12.0, list = Z(6.0),' 1 ', ' 1 ', ' 0 ', ' 1 '
											;variable 1 - zone
											;variable 2 - trip gen attractions (place-holder)
											;variable 3 - dest choice attractions (place-holder)
											;variable 4 - attraction adjustment factor (place-holder)
											;variable 5 - percent difference (place-holder)
ENDRUN




;use NETWORK to convert text file to dbf
RUN PGM=NETWORK   MSG='Mode Choice 7: convert trip adjustment factors to dbf'
 FILEI NODEI = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\adjust_attractions_@n@.txt', VAR=N, tripgen, destchoice, factor, percdiff
 FILEO NODEO = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\adjust_attractions_@n@.dbf', FORMAT=DBF
 ZONES=@UsedZones@
ENDRUN




;iterate through up to 10 iterations to achieve reasonable attraction balancing
;balancing is acheived when 95% of zones are within 5% of trip generation results
LOOP iterate=1,10,1

    ;loop through vehicle ownership and income segments
    LOOP numveh=1,3,1
      LOOP income=1,2,1

       ;define tags to be used below for code efficiency
       if (numveh==1)
         if (income=1)
           veh = '0veh'
           inc = 'lo'
         elseif (income=2)
           veh = '0veh'
           inc = 'hi'
         endif
       elseif (numveh==2)
         if (income=1)
           veh = '1veh'
           inc = 'lo'
         elseif (income=2)
           veh = '1veh'
           inc = 'hi'
         endif
       elseif (numveh==3)
         if (income=1)
           veh = '2veh'
           inc = 'lo'
         elseif (income=2)
           veh = '2veh'
           inc = 'hi'
         endif
       endif

;calculate utilities by market segment
RUN PGM=MATRIX   MSG='Mode Choice 7: calculate utilities - @veh@ - @inc@ - iteration @iterate@'
 zones=@UsedZones@
 maxmw=500                      ;resets the maximimum number of working matrices from 200 to 500
 zonemsg=@ZoneMsgRate@          ;reduces print messages in TPP DOS. (i.e. runs faster).

  ZDATI[1] = '@ParentDir@@ScenarioDir@2_TripGen\pa_initial.dbf'     	;productions/attractions by TAZ
  ZDATI[2] = '@ParentDir@@ScenarioDir@0_InputProcessing\SE_File.dbf'		;employment by TAZ
  ZDATI[3] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\adjust_attractions_@n@.dbf', Z=N   ;adjustment factors
  ZDATI[4] = '@ParentDir@@ScenarioDir@0_InputProcessing\Urbanization.dbf' 
  ZDATI[5] = '@ParentDir@1_Inputs\1_TAZ\@TAZ_DBF@' Z=TAZID

  MATI[1] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\HBW_logsums_Pk.mtx'    ;HBW peak logsums
  MATI[2] = '@ParentDir@@ScenarioDir@4_ModeChoice\1a_Skims\skm_auto_Pk.mtx'       ;peak highway skims
  MATI[3] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\Best_Walk_Skims.mtx'   ;best peak walk-to-transit skims

  MATO[1] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\HBW_@veh@_@inc@_utilities_temp_@n@.mtx', MO=10,11, NAME=utility, exp_util

    
    ;Cluster: distribute intrastep processing
    DistributeINTRASTEP PROCESSID=ClusterNodeID, PROCESSLIST=2-@CoresAvailable@
    
    

; NOTE: in MATRIX there is a built-in loop through all production zones

    ;read in destination choice model coefficients
    read file='@ParentDir@2_ModelScripts\4_ModeChoice\block\@dc_coefficients@'

       MW[1]=mi.1.@veh@_@inc@

       ;loop through attractions
       jloop

         ;calculate and exponentiate utilities
         if (Z=@dummyzones@ | Z=@externalzones@ | j=@dummyzones@ | j=@externalzones@)
           utility = -99
           exp_utility = 0
  
         elseif (ZI.2.TOTEMP[J]>0 & ZI.1.HBW_P[I]>0)  ;if employment in attraction zone & productions in prod zone

           ;the coefficients are located in the coefficients text file

           ; intra-zonal calibration constant
           izcon = 0
           if (i == j)
                izcon = intra_@veh@_@inc@
           endif

           distcon = 0
           if (zi.5.DISTLRG[i] == zi.5.DISTLRG[j])
                distcon = intradist_@veh@_@inc@
           endif

           ; calibrated distance
           distcal = hwy_dist_@veh@_@inc@ - distcal_@veh@_@inc@


           ; adjust total employment if there are coefficients on retail,
           ; industrial, or other employment
           total_emp = ZI.2.TOTEMP[j]
           if (retail_emp_@veh@_@inc@ != 1)
                tot_emp = tot_emp - ZI.2.RETEMP[j]
           endif
           if (industrial_emp_@veh@_@inc@ != 1)
                tot_emp = tot_emp - ZI.2.INDEMP[j]
           endif
           if (other_emp_@veh@_@inc@ != 1)
                tot_emp = tot_emp - ZI.2.OTHEMP[j]
           endif


           ; create employment ratios (% employment by type)
                retail_ratio = ZI.2.RETEMP[j] /
                        (ZI.2.RETEMP[j] + ZI.2.INDEMP[j] + ZI.2.OTHEMP[j])

                industrial_ratio = ZI.2.INDEMP[j] /
                        (ZI.2.RETEMP[j] + ZI.2.INDEMP[j] + ZI.2.OTHEMP[j])

                other_ratio = ZI.2.OTHEMP[j] /
                        (ZI.2.RETEMP[j] + ZI.2.INDEMP[j] + ZI.2.OTHEMP[j])


           exp_retail = 0
           if (retail_emp_@veh@_@inc@ != 1)
                exp_retail = retail_emp_@veh@_@inc@ * RETEMP[j]
           endif

           exp_industrial = 0
           if (industrial_emp_@veh@_@inc@ != 1)
                exp_industrial = industrial_emp_@veh@_@inc@ * INDEMP[j]
           endif

           exp_other = 0
           if (other_emp_@veh@_@inc@ != 1)
                exp_other = other_emp_@veh@_@inc@ * OTHEMP[j]
           endif

		;short trip calibration constant
           	short_trip = 1/MAX(1,mi.2.dist_GP[j])


           ;utility equation
           utility = (logsum_@veh@_@inc@*mw[1][j] +
                     short_trip + 
                     distcal*mi.2.dist_GP[j] + .00075*mi.2.dist_GP[j]*mi.2.dist_GP[j] +
		     -0.000002*mi.2.dist_GP[j]*mi.2.dist_GP[j]*mi.2.dist_GP[j] +
                     hwy_time_@veh@_@inc@*(mi.2.ivt_GP[j] + mi.2.ovt[j]) +
                     transit_cost_@veh@_@inc@*mi.3.gencost[j] +
                     retail_ratio_@veh@_@inc@*retail_ratio +
                     industrial_ratio_@veh@_@inc@*industrial_ratio +
                     other_ratio_@veh@_@inc@*other_ratio +
                     izcon + distcon +
                     LN(total_emp +
                        exp_retail +
                        exp_industrial +
                        exp_other +
                        0))+ZI.3.FACTOR[j]


           exp_utility = EXP(utility)

         else   ;if 0 productions or 0 attractions

           utility = -99
           exp_utility = 0

         endif

        MW[10][j] = utility
        MW[11][j] = exp_utility


       ;print debugging info for 1 interchange if debug flag is set to 1
       if (@debug@=1 && Z=@debug_p@ && J=@debug_a@)
          print file='@ParentDir@@ScenarioDir@Temp\4_ModeChoice\debug_@veh@_@inc@_hbw_@n@.txt', form=8.0, list = 'prod zone', Z, '\n',
                                                 'attr zone', J, '\n',
                                                 'vehicles ', '@veh@', '\n',
                                                 'income   ', '@inc@', '\n',
                                                 'HBW prod ', ZI.1.HBW_P[I], '\n',
                                                 'attr total emp ', ZI.2.TOTEMP[J], '\n',
                                                 'attr retail emp ', ZI.2.RETEMP[J], '\n',
                                                 'attr indust emp ', ZI.2.INDEMP[J], '\n',
                                                 'attr other emp ', ZI.2.OTHEMP[J], '\n',
                                                 'logsum coef ', logsum_@veh@_@inc@(8.3), '\n',
                                                 'logsum      ', mw[1][j](8.3), '\n',
                                                 'hwy dist coef ', hwy_dist_@veh@_@inc@(8.3), '\n',
                                                 'hwy distance ', mi.2.dist_GP[j](8.1), '\n',
                                                 'hwy time coef ', hwy_time_@veh@_@inc@(8.3), '\n',
                                                 'hwy time ', mi.2.ivt_GP[j]+mi.2.ovt[j], '\n',
                                                 'transit cost coef ', transit_cost_@veh@_@inc@(8.3), '\n',
                                                 'transit cost ', mi.3.gencost[j]

          print file='@ParentDir@@ScenarioDir@Temp\4_ModeChoice\debug_@veh@_@inc@_hbw_@n@.txt', form=8.0, list = 'total emp ', ZI.2.TOTEMP[j], '\n',
                                                 'retail emp coef ', retail_emp_@veh@_@inc@(8.3), '\n',
                                                 'retail emp ', ZI.2.RETEMP[j], '\n',
                                                 'ind emp coef ',  industrial_emp_@veh@_@inc@(8.3), '\n',
                                                 'ind emp ', ZI.2.INDEMP[j], '\n',
                                                 'other emp coef ', other_emp_@veh@_@inc@(8.3), '\n',
                                                 'other emp ', ZI.2.OTHEMP[j], '\n',
                                                 'calc utility ', utility(8.3), '\n',
                                                 'calc exp utility ', exp_utility(8.2)
       endif

       endjloop
ENDRUN





;calculate trips for each interchange
RUN PGM=MATRIX   MSG='Mode Choice 7: calculate trips - @veh@ - @inc@ - iteration @iterate@'
 zones=@UsedZones@
 maxmw=500                      ;resets the maximimum number of working matrices from 200 to 500
 zonemsg=@ZoneMsgRate@          ;reduces print messages in TPP DOS. (i.e. runs faster).
    ZDATI[1] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\HBW_prods_by_autos_income.dbf', Z=N
    MATI[1] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\HBW_@veh@_@inc@_utilities_temp_@n@.mtx'


    MATO[1] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\pa_HBW_@veh@_@inc@_temp_@n@.mtx', MO=2-4, NAME=share,trips100,trips

    
    ;Cluster: distribute intrastep processing
    DistributeINTRASTEP PROCESSID=ClusterNodeID, PROCESSLIST=2-@CoresAvailable@
    
    
    MW[1] = mi.1.exp_util

    jloop
      ;calculate share of trips to each attraction
      share = (MW[1][j]/(ROWSUM(1) + .0000000001))*100

      MW[2][j] = share

      ;calculate number of trips to each attraction
      MW[3][j] = MW[2][j]*ZI.1.p_@veh@_@inc@[i]

      MW[4][j] = MW[3][j]/100

      if (@debug@=1 && Z=@debug_p@ && J=@debug_a@)
          print file = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\debug_@veh@_@inc@_hbw_@n@.txt', APPEND=T, form=8.0, list =
                                                                                       'share ',  MW[2][j](8.6), '\n',
                                                                                       'trips ',  MW[4][j](8.2), '\n\n\n'
      endif
    endjloop
ENDRUN

        ENDLOOP ;income segment
    ENDLOOP ;numveh segments





  n=n+1   ;add 1 for next iteration
  n_1 = n-1     ;keep track of current iteration

;calculate trip attraction adjustment factors (to assure consistency between trip gen and dest choice)
RUN PGM=MATRIX   MSG='Mode Choice 7: calculate attraction adjust factors - iteration @iterate@'
 zones=@UsedZones@
 maxmw=500                      ;resets the maximimum number of working matrices from 200 to 500
 zonemsg=@ZoneMsgRate@          ;reduces print messages in TPP DOS. (i.e. runs faster).
    ZDATI[1] = '@ParentDir@@ScenarioDir@2_TripGen\pa_initial.dbf'         ;productions/attractions by TAZ
    ZDATI[2] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\adjust_attractions_@n_1@.dbf', Z=N
    MATI[1] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\pa_HBW_0veh_lo_temp_@n_1@.mtx'    ;trips for each market segment
    MATI[2] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\pa_HBW_0veh_hi_temp_@n_1@.mtx'
    MATI[3] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\pa_HBW_1veh_lo_temp_@n_1@.mtx'
    MATI[4] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\pa_HBW_1veh_hi_temp_@n_1@.mtx'
    MATI[5] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\pa_HBW_2veh_lo_temp_@n_1@.mtx'
    MATI[6] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\pa_HBW_2veh_hi_temp_@n_1@.mtx'



    MATO[1] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\pa_HBW_total_temp_@n_1@.mtx', MO=3,4, NAME=trips100, trips

    ARRAY distrib_attrs=@UsedZones@, tripgen_attrs=@UsedZones@, factor_attrs=@UsedZones@
    ARRAY perc_diff=@UsedZones@, abs_diff=@UsedZones@

    MW[1] = Mi.1.trips100.T + Mi.2.trips100.T + Mi.3.trips100.T + Mi.4.trips100.T + Mi.5.trips100.T + Mi.6.trips100.T
    MW[2] = Mi.1.trips.T + Mi.2.trips.T + Mi.3.trips.T + Mi.4.trips.T + Mi.5.trips.T + Mi.6.trips.T

    MW[3] = Mi.1.trips100 + Mi.2.trips100 + Mi.3.trips100 + Mi.4.trips100 + Mi.5.trips100 + Mi.6.trips100
    MW[4] = Mi.1.trips + Mi.2.trips + Mi.3.trips + Mi.4.trips + Mi.5.trips + Mi.6.trips

    distrib_attrs[i] = ROWSUM(1)/100

    IF (Z=@dummyzones@ | Z=@externalzones@)
      tripgen_attrs[i] = 0
    ELSE
      tripgen_attrs[i] = ZI.1.HBW_A[i]
    ENDIF

    ;calculate adjustment factors to balance attractions to trip gen output
    factor_attrs[i] = ln((tripgen_attrs[i] + .00001)/(distrib_attrs[i] + .00001)) + ZI.2.FACTOR[i]

    ;calculate percent differences by TAZ for use in assessing convergence
    abs_diff[i]  = ABS(distrib_attrs[i] - tripgen_attrs[i])
    perc_diff[i] = (distrib_attrs[i] - tripgen_attrs[i])/(tripgen_attrs[i] + .00001)

    ;print adjustment factors and percent differences
    PRINT file = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\adjust_attractions_@n@.txt', form=12.0, list = Z(6.0), tripgen_attrs[i],
                                                         distrib_attrs[i], factor_attrs[i](12.3), perc_diff[i](12.3), abs_diff[i]

    IF (((ABS(perc_diff[i]) < .02) | abs_diff[i]<=10) && tripgen_attrs[i]>0) _converged_count = _converged_count + 1

    IF (tripgen_attrs[i]>0) _total_count = _total_count + 1

    IF (Z=@UsedZones@) _percent_converged = _converged_count/_total_count

    LOG var=_percent_converged
ENDRUN




;use NETWORK to convert text file to dbf
RUN PGM=NETWORK   MSG='Mode Choice 7: convert attraction factors to dbf - iteration @iterate@'
 FILEI NODEI = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\adjust_attractions_@n@.txt', VAR=N, tripgen, destchoice, factor, percdiff, absdiff

 FILEO NODEO = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\adjust_attractions_@n@.dbf', FORMAT=DBF
 ZONES=@UsedZones@
ENDRUN

 IF (MATRIX._percent_converged > .99) BREAK

ENDLOOP ;iterate




;copy and rename files from last iteration to output directory
RUN PGM=MATRIX   MSG='Mode Choice 7: copy and rename HBW-Veh-Inc matrices from final iteration'
 zones=@UsedZones@
 maxmw=999                      ;resets the maximimum number of working matrices from 200 to 500
 zonemsg=@ZoneMsgRate@          ;reduces print messages in TPP DOS. (i.e. runs faster).
    
    FILEI ZDATI[1] = '@ParentDir@@ScenarioDir@2_TripGen\pa_initial.dbf'
    FILEI ZDATI[2] = '@ParentDir@@ScenarioDir@2_TripGen\telecommute.dbf'

    MATI[1] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\pa_HBW_0veh_lo_temp_@n_1@.mtx'    ;trips for each market segment
    MATI[2] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\pa_HBW_0veh_hi_temp_@n_1@.mtx'
    MATI[3] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\pa_HBW_1veh_lo_temp_@n_1@.mtx'
    MATI[4] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\pa_HBW_1veh_hi_temp_@n_1@.mtx'
    MATI[5] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\pa_HBW_2veh_lo_temp_@n_1@.mtx'
    MATI[6] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\pa_HBW_2veh_hi_temp_@n_1@.mtx'
    MATI[7] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\pa_HBW_total_temp_@n_1@.mtx'

    MATO[1] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\pa_HBW_0veh_lo.mtx', 
        mo=112-113, 212-213, 312-313, 412-413, 510,
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
        mo=122-123, 222-223, 322-323, 422-423, 520,
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
        mo=132-133, 232-233, 332-333, 432-433, 530,
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
        mo=142-143, 242-243, 342-343, 442-443, 540,
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
        mo=152-153, 252-253, 352-353, 452-453, 550,
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
        mo=162-163, 262-263, 362-363, 462-463, 560,
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
        mo=172-173, 272-273, 372-373, 472-473, ;570,
        name=ini_trips100,
             ini_trips   ,
             trips100    ,
             trips       ,
             Tel_trips100,
             Tel_trips   ,
             Tot_trips100,
             Tot_trips   ;,
             ;share       
    
    MATO[8] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\pa_HBW_NumVeh_noXI.mtx',
        mo=200-203, 300-303, 400-403,
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
    
    ;sum low 0 auto and high 0 auto to the general 0 auto market segment
    ;  previously, this was a separate, but unnecessary, matrix call
    MATO[9] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\pa_HBW_0veh.mtx', 
        mo=201, 
        name=trips
    
    
    ;Cluster: distribute intrastep processing
    DistributeINTRASTEP PROCESSID=ClusterNodeID, PROCESSLIST=2-@CoresAvailable@
    
    mw[510] = mi.1.share     ;Total HBW_0veh_lo
    mw[520] = mi.2.share     ;Total HBW_0veh_hi
    mw[530] = mi.3.share     ;Total HBW_1veh_lo
    mw[540] = mi.4.share     ;Total HBW_1veh_hi
    mw[550] = mi.5.share     ;Total HBW_2veh_lo
    mw[560] = mi.6.share     ;Total HBW_2veh_hi
    
    mw[112] = mi.1.trips100  ;Initial HBW_0veh_lo
    mw[122] = mi.2.trips100  ;Initial HBW_0veh_hi
    mw[132] = mi.3.trips100  ;Initial HBW_1veh_lo
    mw[142] = mi.4.trips100  ;Initial HBW_1veh_hi
    mw[152] = mi.5.trips100  ;Initial HBW_2veh_lo
    mw[162] = mi.6.trips100  ;Initial HBW_2veh_hi

    mw[113] = mi.1.trips     ;Initial HBW_0veh_lo
    mw[123] = mi.2.trips     ;Initial HBW_0veh_hi
    mw[133] = mi.3.trips     ;Initial HBW_1veh_lo
    mw[143] = mi.4.trips     ;Initial HBW_1veh_hi
    mw[153] = mi.5.trips     ;Initial HBW_2veh_lo
    mw[163] = mi.6.trips     ;Initial HBW_2veh_hi

    ;Total Initial HBW_total
    mw[172] = mi.7.trips100
    mw[173] = mi.7.trips   

    ;calculate telecommute trips
    JLOOP
        
        ;trips 100
        mw[312] = mw[112] * zi.2.PctTelHBW[j]    ;HBW_0veh_lo
        mw[322] = mw[122] * zi.2.PctTelHBW[j]    ;HBW_0veh_hi
        mw[332] = mw[132] * zi.2.PctTelHBW[j]    ;HBW_1veh_lo
        mw[342] = mw[142] * zi.2.PctTelHBW[j]    ;HBW_1veh_hi
        mw[352] = mw[152] * zi.2.PctTelHBW[j]    ;HBW_2veh_lo
        mw[362] = mw[162] * zi.2.PctTelHBW[j]    ;HBW_2veh_hi
        mw[372] = mw[172] * zi.2.PctTelHBW[j]    ;HBW total
        
        ;trips
        mw[313] = mw[113] * zi.2.PctTelHBW[j]    ;HBW_0veh_lo
        mw[323] = mw[123] * zi.2.PctTelHBW[j]    ;HBW_0veh_hi
        mw[333] = mw[133] * zi.2.PctTelHBW[j]    ;HBW_1veh_lo
        mw[343] = mw[143] * zi.2.PctTelHBW[j]    ;HBW_1veh_hi
        mw[353] = mw[153] * zi.2.PctTelHBW[j]    ;HBW_2veh_lo
        mw[363] = mw[163] * zi.2.PctTelHBW[j]    ;HBW_2veh_hi
        mw[373] = mw[173] * zi.2.PctTelHBW[j]    ;HBW total  
        
    ENDJLOOP
    
    ;calulate trip adjustment to accurately account for telecommute trips (see TripGen for more explanation)
    JLOOP
        
        ;trips 100
        mw[912] = mw[112] * zi.2.FacTelHBW[j]    ;HBW_0veh_lo
        mw[922] = mw[122] * zi.2.FacTelHBW[j]    ;HBW_0veh_hi
        mw[932] = mw[132] * zi.2.FacTelHBW[j]    ;HBW_1veh_lo
        mw[942] = mw[142] * zi.2.FacTelHBW[j]    ;HBW_1veh_hi
        mw[952] = mw[152] * zi.2.FacTelHBW[j]    ;HBW_2veh_lo
        mw[962] = mw[162] * zi.2.FacTelHBW[j]    ;HBW_2veh_hi
        mw[972] = mw[172] * zi.2.FacTelHBW[j]    ;HBW total
        
        ;trips
        mw[913] = mw[113] * zi.2.FacTelHBW[j]    ;HBW_0veh_lo
        mw[923] = mw[123] * zi.2.FacTelHBW[j]    ;HBW_0veh_hi
        mw[933] = mw[133] * zi.2.FacTelHBW[j]    ;HBW_1veh_lo
        mw[943] = mw[143] * zi.2.FacTelHBW[j]    ;HBW_1veh_hi
        mw[953] = mw[153] * zi.2.FacTelHBW[j]    ;HBW_2veh_lo
        mw[963] = mw[163] * zi.2.FacTelHBW[j]    ;HBW_2veh_hi
        mw[973] = mw[173] * zi.2.FacTelHBW[j]    ;HBW total  
        
    ENDJLOOP
    
    ;calcualte final hbw trips by applying trip adjustment factor
    ;trips 100
    mw[212] = mw[112] - mw[912]    ;HBW_0veh_lo
    mw[222] = mw[122] - mw[922]    ;HBW_0veh_hi
    mw[232] = mw[132] - mw[932]    ;HBW_1veh_lo
    mw[242] = mw[142] - mw[942]    ;HBW_1veh_hi
    mw[252] = mw[152] - mw[952]    ;HBW_2veh_lo
    mw[262] = mw[162] - mw[962]    ;HBW_2veh_hi
    mw[272] = mw[172] - mw[972]    ;HBW total
    
    ;trips
    mw[213] = mw[113] - mw[913]    ;HBW_0veh_lo
    mw[223] = mw[123] - mw[923]    ;HBW_0veh_hi
    mw[233] = mw[133] - mw[933]    ;HBW_1veh_lo
    mw[243] = mw[143] - mw[943]    ;HBW_1veh_hi
    mw[253] = mw[153] - mw[953]    ;HBW_2veh_lo
    mw[263] = mw[163] - mw[963]    ;HBW_2veh_hi
    mw[273] = mw[173] - mw[973]    ;HBW total  
    
    ;calculate total as Total = Final trips + Tel Trips
    ;trips 100
    mw[412] = mw[212] + mw[312]
    mw[422] = mw[222] + mw[322]
    mw[432] = mw[232] + mw[332]
    mw[442] = mw[242] + mw[342]
    mw[452] = mw[252] + mw[352]
    mw[462] = mw[262] + mw[362]
    mw[472] = mw[272] + mw[372]
    
    ;trips
    mw[413] = mw[213] + mw[313]
    mw[423] = mw[223] + mw[323]
    mw[433] = mw[233] + mw[333]
    mw[443] = mw[243] + mw[343]
    mw[453] = mw[253] + mw[353]
    mw[463] = mw[263] + mw[363]
    mw[473] = mw[273] + mw[373]

    
    ;total by vehicles
    mw[401] = mw[413] + mw[423]     ;HBW0
    mw[402] = mw[433] + mw[443]     ;HBW1
    mw[403] = mw[453] + mw[463]     ;HBW2
    
    mw[400] = mw[401] +
              mw[402] +
              mw[403] 
    
    ;sum telecommuting by vehicle segment
    mw[301] = mw[313] + mw[323]     ;HBW0
    mw[302] = mw[333] + mw[343]     ;HBW1
    mw[303] = mw[353] + mw[363]     ;HBW2
    
    mw[300] = mw[301] +
              mw[302] +
              mw[303] 
    
    ;sum HBW minus telecommuting by vehicle segment
    mw[201] = mw[213] + mw[223]     ;HBW0
    mw[202] = mw[233] + mw[243]     ;HBW1
    mw[203] = mw[253] + mw[263]     ;HBW2
    
    mw[200] = mw[201] +
              mw[202] +
              mw[203] 
    
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




/*   ; uncomment if you want some base year calibration summaries



; sum intrazonals
LOOP iter=1,5
if (iter=1)
  MktSeg = '0veh'
endif
if (iter=2)
  MktSeg = '1veh_lo'
endif
if (iter=3)
  MktSeg = '2veh_lo_noXI'
endif
if (iter=4)
  MktSeg = '1veh_hi'
endif
if (iter=5)
  MktSeg = '2veh_hi_noXI'
endif

 RUN PGM=MATRIX

 zones=@UsedZones@
 maxmw=500                      ;resets the maximimum number of working matrices from 200 to 500
 zonemsg=@ZoneMsgRate@          ;reduces print messages in TPP DOS. (i.e. runs faster).

  MATI[1] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\pa_HBW_@MktSeg@.mtx'

  MW[1]=mi.1.1

  jloop

    if(j==i)
      iztrips = iztrips + mw[1][j]
    endif

    if(j==zones && i==zones)
      print
       list="@MktSeg@ intrazonal trip sum: ",iztrips,
       file='@ParentDir@@ScenarioDir@3_Distribute\intrazonal\@MktSeg@intrazonal.txt'
    endif

  endjloop

 ENDRUN
ENDLOOP

;output district-level trip tables
RUN PGM=MATRIX
 zones=@UsedZones@
 maxmw=500                      ;resets the maximimum number of working matrices from 200 to 500
 zonemsg=@ZoneMsgRate@          ;reduces print messages in TPP DOS. (i.e. runs faster).

    MATI[1] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\pa_HBW_0veh_lo.mtx'
    MATI[2] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\pa_HBW_0veh_hi.mtx'
    MATI[3] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\pa_HBW_1veh_lo.mtx'
    MATI[4] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\pa_HBW_1veh_hi.mtx'
    MATI[5] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\pa_HBW_2veh_lo_noXI.mtx'
    MATI[6] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\pa_HBW_2veh_hi_noXI.mtx'
    MATI[7] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\pa_HBW_total_noXI.mtx'

    MATO[1] = '@ParentDir@@ScenarioDir@3_Distribute\district\pa_HBW_0veh_lo_district.mtx', MO=2-3,   NAME=trips100,trips
    MATO[2] = '@ParentDir@@ScenarioDir@3_Distribute\district\pa_HBW_0veh_hi_district.mtx', MO=12-13, NAME=trips100,trips
    MATO[3] = '@ParentDir@@ScenarioDir@3_Distribute\district\pa_HBW_1veh_lo_district.mtx', MO=22-23, NAME=trips100,trips
    MATO[4] = '@ParentDir@@ScenarioDir@3_Distribute\district\pa_HBW_1veh_hi_district.mtx', MO=32-33, NAME=trips100,trips
    MATO[5] = '@ParentDir@@ScenarioDir@3_Distribute\district\pa_HBW_2veh_lo_district_noXI.mtx', MO=42-43, NAME=trips100,trips
    MATO[6] = '@ParentDir@@ScenarioDir@3_Distribute\district\pa_HBW_2veh_hi_district_noXI.mtx', MO=52-53, NAME=trips100,trips
    MATO[7] = '@ParentDir@@ScenarioDir@3_Distribute\district\pa_HBW_total_district_noXI.mtx',   MO=61-62, NAME=trips100,trips

    MW[2] = mi.1.2
    MW[3] = mi.1.3
    MW[12] = mi.2.2
    MW[13] = mi.2.3
    MW[22] = mi.3.2
    MW[23] = mi.3.3
    MW[32] = mi.4.2
    MW[33] = mi.4.3
    MW[42] = mi.5.2
    MW[43] = mi.5.3
    MW[52] = mi.6.2
    MW[53] = mi.6.3
    MW[61] = mi.7.1
    MW[62] = mi.7.2

 RENUMBER file='..\..\9AnalysisDistrict\DistrictSets\@dc_district_file@', missingzi=m, missingzo=w
ENDRUN


;******************* Create trip length frequencies and average trip lengths for each county and the region.
LOOP iter=1,5
if (iter=1)
  _Z = RegionRange
  Ccode = '1RE'
endif
if (iter=2)
  _Z    = WeberRange
  Ccode = '2WE'
endif
if (iter=3)
  _Z = DavisRange
  Ccode = '3DA'
endif
if (iter=4)
  _Z = SLRange
  Ccode = '4SL'
endif
if (iter=5)
  _Z = UtahRange
  Ccode = '6UT'
endif

RUN PGM=MATRIX

FILEI   MATI[1] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\pa_HBW_total_noXI.mtx'
        MATI[2] = '@ParentDir@@ScenarioDir@4_ModeChoice\1a_Skims\skm_auto_Pk.mtx'  ;peak highway skims

ZONEMSG = @ZoneMsgRate@  ;reduces print messages in TPP DOS. (i.e. runs faster).

mw[11] = mi.1.trips

mw[21] = mi.2.ivt_GP + mi.2.ovt      ; peak auto travel times
mw[22] = mi.2.dist_GP          ; peak travel distances

; initialize trip length freq arrays (for time and distance)
ARRAY hbw_tlf_time=100,  hbw_tlf_dist=100

hbw_tlf_time  = 0
hbw_tlf_dist  = 0

if (i==@_Z@)
; loop through all O-D pairs, assigning trips to travel time/distance bins (increments)
jloop
  temp1 = MW[21][j]  ; travel time for HBW trips
  temp2 = MW[22][j]  ; travel distance for HBW trips

; assign travel times/distances to "bins" (intervals of time or distance).
; truncate travel times and distances for each O-D pair, and assign the appropriate bin number:
; e.g. if your bin width is 2 mins, and a particular travel time is 5.7 mins, then the following calc
;  will evaluate to integer(5.7/2) + 1 = integer(2.85) + 1 = 2+1 = 3. The trips between
;  this zone will be put into bin number 3, which is in this case 4-6 minutes of travel time.
  index1 = Int(temp1/@dc_bin_time@) + 1  ; add 1 because there is no position "0" in a TP+ array
  index2 = Int(temp2/@dc_bin_dist@) + 1

; assign all trips with travel times/distances greater than we care about (say, 90 minutes) to
;   one bin, which has a number one greater than the bin corresponding to the MAX time or dist.
  if(index1 > @dc_MAX_time@) index1 = @dc_MAX_time@/@dc_bin_time@ + 1
  if(index2 > @dc_MAX_dist@) index2 = @dc_MAX_dist@/@dc_bin_dist@ + 1

; sum up trips in each time bin
  hbw_tlf_time[index1] = hbw_tlf_time[index1] + MW[11][j]  ;HBW trips

; sum up trips in each dist bin
  hbw_tlf_dist[index2] = hbw_tlf_dist[index2] + MW[11][j]  ;HBW trips

; sum up total trips by purpose
  total_HBW_trips = total_HBW_trips + MW[11][j]

; sum up total time by purpose
  total_HBW_ptt = total_HBW_ptt + (MW[11][j] * MW[21][j]) ;"person-trip time" = Total ij trips * Total ij time

; sum up total distance by purpose
  total_HBW_ptm = total_HBW_ptm + (MW[11][j] * MW[22][j]) ;"person-trip miles" = Total ij trips * Total ij miles

endjloop
endif ;i=county set
; output number of trips in each bin

if (i==@Usedzones@)

  loop k=1, @dc_MAX_time@/@dc_bin_time@, 1
    if (k==1)
      print file = '@ParentDir@@ScenarioDir@3_Distribute\tlf\TLF_TotalTrips_time_@Ccode@.txt', CFORM=11, LIST= 'Actual_Time', '    ', 'HBW_tlf'(11)

      print file = '@ParentDir@@ScenarioDir@3_Distribute\tlf\TLF_scaled_time_@Ccode@.txt', CFORM=11, LIST= 'Scaled_Time', '    ', 'HBW_tlf'(11)
    endif

    print file = '@ParentDir@@ScenarioDir@3_Distribute\tlf\TLF_TotalTrips_time_@Ccode@.txt', FORM=11.2, LIST= k(11), hbw_tlf_time[k]

    print file = '@ParentDir@@ScenarioDir@3_Distribute\tlf\TLF_scaled_time_@Ccode@.txt', FORM=11.6, LIST= k(11), hbw_tlf_time[k]/total_HBW_trips
  endloop


  loop k=1, @dc_MAX_dist@/@dc_bin_dist@, 1
    if (k==1)
      print file = '@ParentDir@@ScenarioDir@3_Distribute\tlf\TLF_TotalTrips_dist_@Ccode@.txt', CFORM=11, LIST= 'Actual_Dist', '    ', 'HBW_tlf'(11)

      print file = '@ParentDir@@ScenarioDir@3_Distribute\tlf\TLF_scaled_dist_@Ccode@.txt', CFORM=11, LIST= 'Scaled_Dist', '    ', 'HBW_tlf'(11)
    endif

    print file = '@ParentDir@@ScenarioDir@3_Distribute\tlf\TLF_TotalTrips_dist_@Ccode@.txt', FORM=11.2, LIST= k(11), hbw_tlf_dist[k]

    print file = '@ParentDir@@ScenarioDir@3_Distribute\tlf\TLF_scaled_dist_@Ccode@.txt', FORM=11.6, LIST= k(11), hbw_tlf_dist[k]/total_HBW_trips
  endloop

  TotalMiles =  total_HBW_ptm
  TotalHours = (total_HBW_ptt)/60
  total_ALL_trips = total_HBW_trips

  print file = '@ParentDir@@ScenarioDir@3_Distribute\tlf\TLF_AverageTripLengthsByPurp_@Ccode@.txt', FORM=11.0C, LIST=
    'Total trips and average trip lengths by purpose for area @Ccode@:\n',
    '\nTotal HBW trips                  ', total_HBW_trips,
    '\n',
    '\nAverage HBW trip dist (miles)    ', total_HBW_ptm/total_HBW_trips,
    '\n',
    '\nAverage HBW trip time (minutes)  ', total_HBW_ptt/total_HBW_trips,
    '\n',
    '\nAverage HBW trip speed (mph)     ', 60*(total_HBW_ptm/total_HBW_trips)/(total_HBW_ptt/total_HBW_trips)

endif
endrun
ENDLOOP

;******************* Create trip length frequencies and average trip lengths by market segment.
LOOP iter=1,6
if (iter=1)
  MktSeg = '0veh_lo'
  MktSeg2 = '0veh_lo'
endif
if (iter=2)
  MktSeg = '0veh_hi'
  MktSeg2 = '0veh_hi'
endif
if (iter=3)
  MktSeg = '1veh_lo'
  MktSeg2 = '1veh_lo'
endif
if (iter=4)
  MktSeg = '2veh_lo'
  MktSeg2 = '2veh_lo_noXI'
endif
if (iter=5)
  MktSeg = '1veh_hi'
  MktSeg2 = '1veh_hi'
endif
if (iter=6)
  MktSeg = '2veh_hi'
  MktSeg2 = '2veh_hi_noXI'
endif

RUN PGM=MATRIX

FILEI   MATI[1] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\pa_HBW_@MktSeg2@.mtx'
        MATI[2] = '@ParentDir@@ScenarioDir@4_ModeChoice\1a_Skims\skm_auto_Pk.mtx'  ;peak highway skims
        MATI[3] = '@ParentDir@@ScenarioDir@Temp\4_ModeChoice\HBW_logsums_PK.mtx'       ;peak mode choice logsums

ZONEMSG = @ZoneMsgRate@  ;reduces print messages in TPP DOS. (i.e. runs faster).

mw[11] =  mi.1.trips

mw[21] = mi.2.ivt_GP + mi.2.ovt      ; peak auto travel times
mw[22] = mi.2.dist_GP          ; peak travel distances
mw[31] = mi.3.@MktSeg@          ; peak, market segment specific mode choice logsums


; initialize trip length freq arrays (for time, distance and logsum)
ARRAY hbw_tlf_time=100,  hbw_tlf_dist=100, hbw_tlf_lgsm=100

; loop through all O-D pairs, assigning trips to travel time/distance bins (increments)
jloop
  temp1 = MW[21][j]  ; travel time for HBW trips
  temp2 = MW[22][j]  ; travel distance for HBW trips
  temp3 = MW[31][j] + @dc_SHIFT_lgsm@  ; travel logsums for HBW trips

; assign travel times/distances/logsusm to "bins" (intervals of time or distance or logsum).
; truncate travel times and distances for each O-D pair, and assign the appropriate bin number:
; e.g. if your bin width is 2 mins, and a particular travel time is 5.7 mins, then the following calc
;  will evaluate to integer(5.7/2) + 1 = integer(2.85) + 1 = 2+1 = 3. The trips between
;  this zone will be put into bin number 3, which is in this case 4-6 minutes of travel time.
  index1 = Int(temp1/@dc_bin_time@) + 1  ; add 1 because there is no position "0" in a TP+ array
  index2 = Int(temp2/@dc_bin_dist@) + 1
  index3 = Int(temp3/@dc_bin_lgsm@) + 1

; assign all trips with travel times/distances greater than we care about (say, 90 minutes) to
;   one bin, which has a number one greater than the bin corresponding to the MAX time or dist.
  if(index1 > @dc_MAX_time@) index1 = @dc_MAX_time@/@dc_bin_time@ + 1
  if(index2 > @dc_MAX_dist@) index2 = @dc_MAX_dist@/@dc_bin_dist@ + 1
  if(index3 > (@dc_MAX_lgsm@ + @dc_SHIFT_lgsm@)/@dc_bin_lgsm@)
        index3 = (@dc_MAX_lgsm@ + @dc_SHIFT_lgsm@)/@dc_bin_lgsm@ + 1
  endif

; sum up trips in each time bin
  hbw_tlf_time[index1] = hbw_tlf_time[index1] + MW[11][j]  ;HBW trips

; sum up trips in each dist bin
  hbw_tlf_dist[index2] = hbw_tlf_dist[index2] + MW[11][j]  ;HBW trips

; sum up trips in each logsum bin
  hbw_tlf_lgsm[index3] = hbw_tlf_lgsm[index3] + MW[11][j]  ;HBW trips

; sum up total trips by purpose
  total_HBW_trips = total_HBW_trips + MW[11][j]

; sum up total time by purpose
  total_HBW_ptt = total_HBW_ptt + (MW[11][j] * MW[21][j]) ;"person-trip time" = Total ij trips * Total ij time

; sum up total distance by purpose
  total_HBW_ptm = total_HBW_ptm + (MW[11][j] * MW[22][j]) ;"person-trip miles" = Total ij trips * Total ij miles

; sum up total logsum by purpose
  total_HBW_plg = total_HBW_ptm + (MW[11][j] * (MW[23][j] + @dc_SHIFT_lgsm@)) ;"person-trip logsum" = Total ij trips * Total ij logsums

endjloop
; output number of trips in each bin

if (i==@Usedzones@)

  loop k=1, @dc_MAX_time@/@dc_bin_time@, 1
    if (k==1)
      print file = '@ParentDir@@ScenarioDir@3_Distribute\tlf\@MktSeg@TLF_TotalTrips_time.txt', CFORM=11, LIST= 'Actual_Time', '    ', 'HBW_tlf'(11)

      print file = '@ParentDir@@ScenarioDir@3_Distribute\tlf\@MktSeg@TLF_scaled_time.txt', CFORM=11, LIST= 'Scaled_Time', '    ', 'HBW_tlf'(11)
    endif

    print file = '@ParentDir@@ScenarioDir@3_Distribute\tlf\@MktSeg@TLF_TotalTrips_time.txt', FORM=11.2, LIST= k(11), hbw_tlf_time[k]

    print file = '@ParentDir@@ScenarioDir@3_Distribute\tlf\@MktSeg@TLF_scaled_time.txt', FORM=11.6, LIST= k(11), hbw_tlf_time[k]/total_HBW_trips
  endloop

  loop k=1, @dc_MAX_dist@/@dc_bin_dist@, 1
    if (k==1)
      print file = '@ParentDir@@ScenarioDir@3_Distribute\tlf\@MktSeg@TLF_TotalTrips_dist.txt', CFORM=11, LIST= 'Actual_Dist', '    ', 'HBW_tlf'(11)

      print file = '@ParentDir@@ScenarioDir@3_Distribute\tlf\@MktSeg@TLF_scaled_dist.txt', CFORM=11, LIST= 'Scaled_Dist', '    ', 'HBW_tlf'(11)
    endif

    print file = '@ParentDir@@ScenarioDir@3_Distribute\tlf\@MktSeg@TLF_TotalTrips_dist.txt', FORM=11.2, LIST= k(11), hbw_tlf_dist[k]

    print file = '@ParentDir@@ScenarioDir@3_Distribute\tlf\@MktSeg@TLF_scaled_dist.txt', FORM=11.6, LIST= k(11), hbw_tlf_dist[k]/total_HBW_trips
  endloop

  loop k=1, (@dc_MAX_lgsm@ + @dc_SHIFT_lgsm@)/@dc_bin_lgsm@, 1
    if (k==1)
      print file = '@ParentDir@@ScenarioDir@3_Distribute\tlf\@MktSeg@TLF_TotalTrips_lgsm.txt', CFORM=11, LIST= 'Shifted_Logsum', '    ', 'HBW_tlf'(11)

      print file = '@ParentDir@@ScenarioDir@3_Distribute\tlf\@MktSeg@TLF_scaled_lgsm.txt', CFORM=11, LIST= 'Scaled_Logsum', '    ', 'HBW_tlf'(11)
    endif

    print file = '@ParentDir@@ScenarioDir@3_Distribute\tlf\@MktSeg@TLF_TotalTrips_lgsm.txt', FORM=11.2, LIST= k(11), hbw_tlf_lgsm[k]

    print file = '@ParentDir@@ScenarioDir@3_Distribute\tlf\@MktSeg@TLF_scaled_lgsm.txt', FORM=11.6, LIST= k(11), hbw_tlf_lgsm[k]/total_HBW_trips
  endloop

  TotalMiles =  total_HBW_ptm
  TotalHours = (total_HBW_ptt)/60
  TotalLgsm = total_HBW_plg
  total_ALL_trips = total_HBW_trips

  print file = '@ParentDir@@ScenarioDir@3_Distribute\tlf\@MktSeg@TLF_AverageTripLengthsByPurp.txt', FORM=11.0C, LIST=
    'Total trips and average trip lengths by purpose for area :\n',
    '\nTotal HBW trips                  ', total_HBW_trips,
    '\n',
    '\nAverage HBW trip dist (miles)    ', total_HBW_ptm/total_HBW_trips,
    '\n',
    '\nAverage HBW trip time (minutes)  ', total_HBW_ptt/total_HBW_trips,
    '\n',
    '\nAverage HBW trip speed (mph)     ', 60*(total_HBW_ptm/total_HBW_trips)/(total_HBW_ptt/total_HBW_trips),
    '\n',
    '\nAverage HBW trip logsum  ', total_HBW_plg/total_HBW_trips

endif
endrun
ENDLOOP

*/  ; uncomment if you want some base year calibration summaries




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
