MODULE basinUH_module

USE nrtype
USE public_var
USE dataTypes, ONLY: STRFLX         ! fluxes in each reach
USE dataTypes, ONLY: RCHTOPO        ! network tiver topology

implicit none

private

public::IRF_route_basin, IRF_route_basin_subsurf

CONTAINS

 ! ---------------------------------------------------------------------------------------
 ! Public subroutine main driver for basin routing
 ! ---------------------------------------------------------------------------------------
 SUBROUTINE IRF_route_basin(iens,          & ! input: ensemble index
                            NETOPO_in,     & ! input: reach topology
                            RCHFLX_out,    & ! inout: reach flux data structure
                            ierr, message, & ! output: error control
                            ixSubRch)        ! optional input: subset of reach indices to be processed
 implicit none
 ! input
 integer(i4b), intent(in)                 :: iens            ! ith ensemble
 type(RCHTOPO),intent(in),   allocatable  :: NETOPO_in(:)    ! River Network topology
 ! inout
 type(STRFLX), intent(inout), allocatable :: RCHFLX_out(:,:) ! Reach fluxes (ensembles, space [reaches]) for decomposed domains
 ! output
 integer(I4B), intent(out)                :: ierr            ! error code
 character(*), intent(out)                :: message         ! error message
 ! input (optional)
 integer(i4b), intent(in),   optional     :: ixSubRch(:)     ! subset of reach indices to be processed
 ! local variables
 integer(i4b)                             :: nSeg            ! number of reaches to be processed
 integer(i4b)                             :: iSeg            ! reach loop indix
 logical(lgt),               allocatable  :: doRoute(:)      ! logical to indicate which reaches are processed
 character(len=strLen)                    :: cmessage        ! error message from subroutines

 ierr=0; message='IRF_route_basin/'

 nSeg = size(RCHFLX_out(iens,:))

 allocate(doRoute(nSeg), stat=ierr)
 if(ierr/=0)then; message=trim(message)//'unable to allocate space for [doRoute]'; return; endif

 ! if a subset of reaches is processed
 if (present(ixSubRch))then
  doRoute(:) = .false.
  doRoute(ixSubRch) = .true. ! only subset of reaches are on
 else
  doRoute(:) = .true.
 endif

!$OMP PARALLEL DO schedule(dynamic,1)   &
!$OMP          private(iSeg)            & ! loop index
!$OMP          private(ierr, cmessage)  & ! private for a given thread
!$OMP          shared(doRoute)          & ! data array shared
!$OMP          shared(RCHFLX_out)       & ! data structure shared
!$OMP          shared(NETOPO_in)        & ! data structure shared
!$OMP          shared(iEns)             & ! indices shared
!$OMP          firstprivate(nSeg)
 do iSeg=1,nSeg

  if (.not. doRoute(iSeg)) cycle

  call hru_irf(iEns, iSeg, NETOPO_in, .false., RCHFLX_out, ierr, cmessage)
!  f(ierr/=0)then; ixmessage(iSeg)=trim(message)//trim(cmessage); exit; endif

 end do
!$OMP END PARALLEL DO

 END SUBROUTINE IRF_route_basin

 SUBROUTINE IRF_route_basin_subsurf(iens,          & ! input: ensemble index
                            NETOPO_in,             & ! input: reach topology
                            RCHFLX_sub,            & ! inout: reach flux data structure for subsurface flow
                            ierr, message, & ! output: error control
                            ixSubRch)        ! optional input: subset of reach indices to be processed
 implicit none
 ! input
 integer(i4b), intent(in)                 :: iens            ! ith ensemble
 type(RCHTOPO),intent(in),   allocatable  :: NETOPO_in(:)    ! River Network topology
 ! inout
 type(STRFLX), intent(inout), allocatable :: RCHFLX_sub(:,:) ! Reach fluxes (ensembles, space [reaches]) for decomposed domains
 ! output
 integer(I4B), intent(out)                :: ierr            ! error code
 character(*), intent(out)                :: message         ! error message
 ! input (optional)
 integer(i4b), intent(in),   optional     :: ixSubRch(:)     ! subset of reach indices to be processed
 ! local variables
 integer(i4b)                             :: nSeg            ! number of reaches to be processed
 integer(i4b)                             :: iSeg            ! reach loop indix
 logical(lgt),               allocatable  :: doRoute(:)      ! logical to indicate which reaches are processed
 character(len=strLen)                    :: cmessage        ! error message from subroutines

 ierr=0; message='IRF_route_basin/'

 nSeg = size(RCHFLX_sub(iens,:))

 allocate(doRoute(nSeg), stat=ierr)
 if(ierr/=0)then; message=trim(message)//'unable to allocate space for [doRoute]'; return; endif

 ! if a subset of reaches is processed
 if (present(ixSubRch))then
  doRoute(:) = .false.
  doRoute(ixSubRch) = .true. ! only subset of reaches are on
 else
  doRoute(:) = .true.
 endif

!$OMP PARALLEL DO schedule(dynamic,1)   &
!$OMP          private(iSeg)            & ! loop index
!$OMP          private(ierr, cmessage)  & ! private for a given thread
!$OMP          shared(doRoute)          & ! data array shared
!$OMP          shared(RCHFLX_sub)       & ! data structure shared
!$OMP          shared(NETOPO_in)        & ! data structure shared
!$OMP          shared(iEns)             & ! indices shared
!$OMP          firstprivate(nSeg)
 do iSeg=1,nSeg

  if (.not. doRoute(iSeg)) cycle

  call hru_irf(iEns, iSeg, NETOPO_in, .true., RCHFLX_sub, ierr, cmessage)
!  f(ierr/=0)then; ixmessage(iSeg)=trim(message)//trim(cmessage); exit; endif

 end do
!$OMP END PARALLEL DO

 END SUBROUTINE IRF_route_basin_subsurf

 ! *********************************************************************
 ! subroutine: perform one basin UH routing to a iSeg reach at one time
 ! *********************************************************************
 subroutine hru_irf(iens,         &    ! input: index of runoff ensemble to be processed
                    iSeg,         &    ! input: index of runoff ensemble to be processed
                    NETOPO_in,    &    ! input: reach topology
                    flag_subsurf, &    ! input: whether it is in subsurface routing
                    RCHFLX_out,   &    ! inout: reach flux data structure
                    ierr, message)     ! output: error control
 ! External modules
 USE globalData, ONLY: FRAC_FUTURE     !
 USE globalData, ONLY: FRAC_FUTURE_SUB !
 USE public_var, ONLY: is_lake_sim     ! logical whether or not lake should be simulated
 implicit none
 ! Input
 INTEGER(I4B), intent(IN)                 :: iEns           ! runoff ensemble to be routed
 INTEGER(I4B), intent(IN)                 :: iSeg           ! segment where routing is performed
 type(RCHTOPO),intent(in),   allocatable  :: NETOPO_in(:)   ! River Network topology
 LOGICAL                                  :: flag_subsurf   ! whether it is in subsurface routing
 ! inout
 TYPE(STRFLX), intent(inout), allocatable :: RCHFLX_out(:,:)! Reach fluxes (ensembles, space [reaches]) for decomposed domains
 ! Output
 integer(i4b), intent(out)                :: ierr                  ! error code
 character(*), intent(out)                :: message               ! error message
 ! Local variables to
 real(dp),     allocatable                :: FRAC_FUTURE_local (:) ! local FRAC_FUTURE so that it can be changed for lakes to impulse
 INTEGER(I4B)                             :: ntdh                  ! number of time steps in IRF
 character(len=strLen)                    :: cmessage              ! error message from subroutine

 ierr=0; message='hru_irf/'

 ! initialize the first time step q future
  if (.not.allocated(RCHFLX_out(iens,iSeg)%QFUTURE))then
    if (flag_subsurf)then 
      ntdh= size(FRAC_FUTURE_SUB) 
    else
   ntdh = size(FRAC_FUTURE)
   endif
   allocate(RCHFLX_out(iens,iSeg)%QFUTURE(ntdh), stat=ierr)
   if(ierr/=0)then; message=trim(message)//'unable to allocate space for RCHFLX_out(iens,segIndex)%QFUTURE'; return; endif

   RCHFLX_out(iens,iSeg)%QFUTURE(:) = 0._dp

  end if
  if (flag_subsurf)then 
  allocate(FRAC_FUTURE_local, source=FRAC_FUTURE_SUB, stat=ierr)
  else 
  allocate(FRAC_FUTURE_local, source=FRAC_FUTURE, stat=ierr)
  endif
  if(ierr/=0)then; message=trim(message)//'unable to allocate space for FRAC_FUTURE_local'; return; endif

  ! if the segment is flaged as lake and is_lake is on then no lagged flow for lakes
  if ((NETOPO_in(iSeg)%islake).and.(is_lake_sim).and.(.not.flag_subsurf)) then;
    FRAC_FUTURE_local(:) = 0._dp
    FRAC_FUTURE_local(1) = 1._dp
  endif
  
  if (SUM(FRAC_FUTURE_local)==0)then
    print*, 'Warning: UH in subsurface routing is not instantiated...' 
  endif   

  ! perform river network UH routing
  call irf_conv(FRAC_FUTURE_local,               &    ! input: unit hydrograph
                RCHFLX_out(iens,iSeg)%BASIN_QI,  &    ! input: upstream fluxes
                RCHFLX_out(iens,iSeg)%QFUTURE,   &    ! inout: updated q future time series
                RCHFLX_out(iens,iSeg)%BASIN_QR,  &    ! inout: updated fluxes at reach
               ierr, message)                            ! output: error control
  if(ierr/=0)then; message=trim(message)//trim(cmessage); return; endif

 end subroutine hru_irf


 ! ---------------------------------------------------------------------------------------
 ! Private subroutine: Perform UH convolutions
 ! ---------------------------------------------------------------------------------------
 SUBROUTINE irf_conv(uh,        &    ! input: normalized unit hydrograph
                     inq,       &    ! input: instantaneous runoff
                     qfuture,   &    ! inout: convoluted runoff including future time step
                     delayq,    &    ! inout: delayed runoff to segment at a current and previous time step
                     ierr, message)
  implicit none
  ! input
  real(dp),             intent(in)     :: uh(:)         ! normalized unit hydrograph
  real(dp),             intent(in)     :: inq           ! basin instantaneous runoff
  real(dp),             intent(inout)  :: qfuture(:)    ! convoluted runoff including future time steps
  real(dp),             intent(inout)  :: delayq(0:1)   ! delayed runoff to a segment at a current and previous time step
  ! output
  integer(I4B),         intent(out)    :: ierr          ! error code
  character(*),         intent(out)    :: message       ! error message
  ! local variables
  integer(i4b)                         :: itdh          ! index loop for basin, time, respectively
  integer(i4b)                         :: ntdh          ! number of time step for future flow

  ierr=0; message='irf_conv/'

  ntdh = size(qfuture)

  ! place a fraction of runoff in future time steps and add to current state of q in the future
  do itdh=1,ntdh
   qfuture(itdh) = qfuture(itdh) + uh(itdh)*inq
  end do

  ! save the routed runoff
  delayq(0) = delayq(1)  ! (save the runoff from the previous time step)
  delayq(1) = qfuture(1)

  ! move array back
  do itdh=2,ntdh
   qfuture(itdh-1) = qfuture(itdh)
  end do
  qfuture(ntdh)    = 0._dp

  END SUBROUTINE irf_conv

END MODULE basinUH_module
