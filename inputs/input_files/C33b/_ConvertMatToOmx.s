;script used to convert MTX or MAT files to OMX format
;no module needed because it runs in PILOT
;more info here: https://communities.bentley.com/products/mobility-simulation/w/cube-legion-wiki/59307/how-to-convert-omx-matrices-from-to-cube-matrices

convertmat from = "1Skm_TotTransitTime_Ok.MTX" to = "1Skm_TotTransitTime_Ok.omx" compression = 1 format = omx
convertmat from = "1Skm_TotTransitTime_Pk.MTX" to = "1Skm_TotTransitTime_Pk.omx" compression = 1 format = omx
convertmat from = "Best_Walk_Skims.MTX" to = "Best_Walk_Skims.omx" compression = 1 format = omx
convertmat from = "HBW_logsums_Pk.MTX" to = "HBW_logsums_Pk.omx" compression = 1 format = omx
convertmat from = "skm_auto_Pk.MTX" to = "skm_auto_Pk.omx" compression = 1 format = omx