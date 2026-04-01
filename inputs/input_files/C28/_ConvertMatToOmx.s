;script used to convert MTX or MAT files to OMX format
;no module needed because it runs in PILOT
;more info here: https://communities.bentley.com/products/mobility-simulation/w/cube-legion-wiki/59307/how-to-convert-omx-matrices-from-to-cube-matrices

convertmat from = "1Skm_TotTransitTime_Ok.MTX" to = "1Skm_TotTransitTime_Ok.omx" compression = 1 format = omx
convertmat from = "1Skm_TotTransitTime_Pk.MTX" to = "1Skm_TotTransitTime_Pk.omx" compression = 1 format = omx
