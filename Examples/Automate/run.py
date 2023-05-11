from string import Template
import argparse
import subprocess
import os
from map_watermanagement import output_nc


temp=Template(
"""! ****************************************************************************************************************************
! ***** DEFINITION OF MODEL CONTROL INFORMATION ******************************************************************************
! ****************************************************************************************************************************
! ****************************************************************************************************************************
! Note: lines starting with "!" are treated as comment lines -- there is no limit on the number of comment lines.
!    lines starting with <xxx> are read till "!" 
!
! ****************************************************************************************************************************
! DEFINE DIRECTORIES 
! --------------------------
<ancil_dir>         ./topo/                       ! directory containing ancillary data (river network, remapping netCDF) 
<input_dir>         ./forcing/future_forcings/$model/                       ! directory containing input data (runoff netCDF)
<output_dir>        ./output/$model/                                    ! directory containing output data
! ****************************************************************************************************************************
! DEFINE TIME PERIOD OF THE SIMULATION
! --------------------------------------------
<case_name>         GRFR_simu.WW.$scenario                            ! simulation case name
<sim_start>         2010-1-1 00:00:00                         ! time of simulation start (yyyy-mm-dd hh:mm:ss)
<sim_end>           2050-12-31 00:00:00                       ! time of simulation end (yyyy-mm-dd hh:mm:ss)
<route_opt>         0                                         ! option for routing schemes 0-> both, 1->IRF, 2->KWT otherwise error 
<restart_write>     last                                      ! restart write option. never, last, specified (need to specify date with <restart_date> 
<newFileFrequency>  single                                     !frequency write output
!<fname_state_in>    ! input netCDF for channel states 
! ****************************************************************************************************************************
! DEFINE RIVER NETWORK FILE 
! ---------------------------------------
<fname_ntopOld>     redriver_topo_modified.nc                 ! name of netCDF containing river segment data 
<dname_sseg>        seg                                       ! dimension name of the stream segments
<dname_nhru>        hru                                       ! dimension name of the RN_HRUs 
! ****************************************************************************************************************************
! DEFINE DESIRED VARIABLES FOR THE NETWORK TOPOLOGY
! -------------------ShangGao--------------------------------------
<seg_outlet>        -9999                                    ! reach ID of outlet streamflow segment. -9999 for all segments 
<doesSubSurfRoute>  0                                         ! whether do subsurface routing: 0 -deactivate; 1- activate
<is_lake_sim>       T                                         ! whether do lake simulation
<is_flux_wm>        T                                         ! whether use water fluxes
<is_vol_wm>         F                                         ! whether to use desired lake volume time series
<debug>             F                                         !debug
! ****************************************************************************************************************************
! DEFINE RUNOFF FILE
! ----------------------------------
<fname_qsim>        nc_files.txt                           ! name of netCDF containing the HRU runoff
<vname_qsim>        runoff                                    ! variable name of HRU runoff 
<vname_subqsim>     subrunoff                                 ! variable name of subsurface runoff
<vname_evapo>       runoff                                      ! name of HRU runoff variable
<vname_precip>      runoff                                      ! name of HRU runoff variable
<vname_time>        time                                      ! variable name of time in the runoff file 
<vname_hruid>       hru                                       ! variable name of runoff HRU ID 
<dname_time>        time                                      ! dimension name of time 
<dname_hruid>       HR_HRU                                       ! dimension name of HM_HRU 
<units_qsim>        mm/d                                      ! units of runoff
<dt_qsim>           86400                                     ! time interval of the runoff
! ****************************************************************************************************************************
! DEFINE RUNOFF MAPPING FILE 
! ----------------------------------
<is_remap>          F                                         ! logical to indicate runnoff needs to be mapped to river network HRU 
! ****************************************************************************************************************************
! Namelist file name 
! ---------------------------
<param_nml>         param.nml.default                         ! spatially constant model parameters 
! ****************************************************************************************************************************
! Dictionary to map variable names
! ---------------------------
<varname_area>      area                                  ! name of variable holding hru area
<varname_man_n>     man_n                                  ! name of hard-code manning coefficient
<varname_length>    length                                    ! name of variable holding segment length
<varname_slope>     slope                                        ! name of variable holding segment slope
<varname_HRUid>     HRUid                                 ! name of variable holding HRU id
<varname_hruSegId>  hruSegId                                   ! name of variable holding the stream segment below each HRU  
<varname_segId>     segId                                      ! name of variable holding the ID of each stream segment  
<varname_downSegId> downSegId                                        ! name of variable holding the ID of the next downstream segment
!<varname_pfafCode>  pfaf_code                                     ! name of variable holding the pfafstetter code 
!<varname_timeDelayHist> timeDelayHist                             ! time delay for histogram
! ****************************************************************************************************************************
! Define lake variables
! ----------------------------------------------------
<lake_model_D03>                T                                     !activate lake model d3
<varname_lakeModelType>     lakeModelType                             !lake type 1-Doll 2-H
<varname_islake>            islake                                    !whether reach is lake effected
<varname_D03_MaxStorage>    D03_MaxStorage                            !maximum lake storage
<varname_D03_Coefficient>   D03_Coefficient                           !lake coefficient
<varname_D03_Power>         D03_Power                                 !power
<varname_LakeTargVol>       lakeTargetVolume                          !no volume provided
! ****************************************************************************************************************************
! Define Water management file
! ----------------------------------------------------
<fname_wm>                  water_management.txt                        !file name
<vname_flux_wm>             flux_wm                                    !variable name to hold water injection/withdraw time series
!<vname_vol_wm>             vol_wm                                     !varible name to hold lake volume time series
<vname_time_wm>             time                                       !time variable name
<vname_segid_wm>            segId                                      !segment ID
<dname_time_wm>             time                                       !dimension name of time
<dname_segid_wm>            seg                                        !dimension name of segment
! ****************************************************************************************************************************
! Define options to include/skip calculations
! ----------------------------------------------------
!<hydGeometryOption>     1                          ! option for hydraulic geometry calculations (0=read from file, 1=compute)
!<topoNetworkOption>     1                          ! option for network topology calculations (0=read from file, 1=compute)
!<computeReachList>      1                          ! option to compute list of upstream reaches (0=do not compute, 1=compute)
! ****************************************************************************************************************************
! ****************************************************************************************************************************
! ****************************************************************************************************************************
! ****************************************************************************************************************************
! Output variables
! -------------------------------
<basRunoff>             F                                  ! bool set to output basin runoff
<instRunoff>            F                                  ! bool set to output instantaneous runoff
<dlayRunoff>            F                                  ! bool set to output delayed runoff
<sumUpstreamRunoff>     F                                  ! bool set to output accumulated runoff
<KWTroutedRunoff>       T                                  ! bool set to output KW routed runoff
<IRFroutedRunoff>       T                                  ! bool set to output terrain routed runoff"""
)

i=0

# for model in ['RCP26-CCSM4-BCQM','RCP26-CCSM4-CDFt', 'RCP26-CCSM4-EDQM','RCP26-MIROC5-BCQM','RCP26-MIROC5-CDFt','RCP26-MIROC5-EDQM','RCP26-MPI_ESM_LR-BCQM','RCP26-MPI_ESM_LR-CDFt','RCP26-MPI_ESM_LR-EDQM','RCP45-CCSM4-BCQM',
# 'RCP45-CCSM4-CDFt','RCP45-CCSM4-EDQM','RCP45-MIROC5-BCQM','RCP45-MIROC5-CDFt','RCP45-MIROC5-EDQM','RCP45-MPI_ESM_LR-BCQM','RCP45-MPI_ESM_LR-CDFt','RCP45-MPI_ESM_LR-EDQM',
# 'RCP85-CCSM4-BCQM','RCP85-CCSM4-CDFt','RCP85-CCSM4-EDQM','RCP85-MIROC5-BCQM','RCP85-MIROC5-CDFt','RCP85-MIROC5-EDQM','RCP85-MPI_ESM_LR-BCQM','RCP85-MPI_ESM_LR-CDFt',
# 'RCP85-MPI_ESM_LR-EDQM']:
for model in ['RCP85-MPI_ESM_LR-CDFt','RCP85-MPI_ESM_LR-EDQM']:
	for scenario in [0, 10, 25, 50, 75, 100]:
		print('---------------%d/%d-----------------'%(i, 27*6))
		print('Simulating %s --- %s'%(model, scenario))
		#map waste water management file
		output_nc(scenario)
		with open('forcing/future_forcings/%s/water_management.txt'%model, 'w+') as f:
			f.write('water_management_%d.nc'%scenario)
		os.system('cp forcing/water_management_%d.nc forcing/future_forcings/%s/water_management_%d.nc'%(scenario, model,scenario))
		if not os.path.exists('output/%s'%model):
			os.system('mkdir output/%s'%model)


		with open('temp.control', 'w') as f:
			f.write(temp.substitute(model=model, scenario=scenario))

		cmd= '/mnt/s/Models/mizuRoute-cesm-coupling/route/bin/mizuroute_lake temp.control'
		p = subprocess.run([cmd], shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
		i+=1
