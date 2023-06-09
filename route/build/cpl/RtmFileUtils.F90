module RtmFileUtils

!-----------------------------------------------------------------------
! Module containing file I/O utilities
!
! !USES:
  USE shr_sys_mod , ONLY : shr_sys_abort
  USE shr_file_mod, ONLY : shr_file_get, shr_file_getUnit, shr_file_freeUnit
  USE globalData  , ONLY : masterproc
  USE public_var  , ONLY : iulog
!
! !PUBLIC TYPES:
  implicit none
  save
!
! !PUBLIC MEMBER FUNCTIONS:
  public :: get_filename  !Returns filename given full pathname
  public :: opnfil        !Open local unformatted or formatted file
  public :: getfil        !Obtain local copy of file
  public :: relavu        !Close and release Fortran unit no longer in use
  public :: getavu        !Get next available Fortran unit number
!
! !REVISION HISTORY:
! Created by Mariana Vertenstein
!
!
! !PRIVATE MEMBER FUNCTIONS: None
!-----------------------------------------------------------------------

contains

!-----------------------------------------------------------------------

  character(len=256) function get_filename (fulpath)

    ! !DESCRIPTION:
    ! Returns filename given full pathname
    !
    ! !ARGUMENTS:
    implicit none
    character(len=*), intent(in)  :: fulpath !full pathname
    !
    ! !LOCAL VARIABLES:
    integer i     !loop index
    integer klen  !length of fulpath character string
    !----------------------------------------------------------

    klen = len_trim(fulpath)
    do i = klen, 1, -1
       if (fulpath(i:i) == '/') go to 10
    end do
    i = 0
10  get_filename = fulpath(i+1:klen)

  end function get_filename

!-----------------------------------------------------------------------

  character(len=256) function get_dirname (fulpath)

    ! !DESCRIPTION:
    ! Returns directory name given full pathname
    !
    ! !ARGUMENTS:
    implicit none
    character(len=*), intent(in)  :: fulpath !full pathname
    !
    ! !LOCAL VARIABLES:
    integer i     !loop index
    integer klen  !length of fulpath character string
    !----------------------------------------------------------

    klen = len_trim(fulpath)
    do i = klen, 1, -1
       if (fulpath(i:i) == '/') go to 10
    end do
    i = 0
10  get_dirname = fulpath(1:i)

  end function get_dirname

!------------------------------------------------------------------------

!------------------------------------------------------------------------

   subroutine getfil (fulpath, dir, locfn, iflag)

     ! !DESCRIPTION:
     ! Obtain local copy of file. First check current working directory,
     ! Next check full pathname[fulpath] on disk
     !
     ! !ARGUMENTS:
     implicit none
     character(len=*), intent(in)  :: fulpath !Archival or permanent disk full pathname
     character(len=*), intent(out) :: dir     !output directory name
     character(len=*), intent(out) :: locfn   !output local file name
     integer,          intent(in)  :: iflag   !0=>abort if file not found 1=>do not abort

     ! !LOCAL VARIABLES:
     integer i               !loop index
     integer klen            !length of fulpath character string
     logical lexist          !true if local file exists
     !--------------------------------------------------

     ! get local file name from full name
     locfn = get_filename( fulpath )
     dir   = get_dirname ( fulpath )
     if (len_trim(locfn) == 0) then
        if (masterproc) write(iulog,*)'(GETFIL): local filename has zero length'
        call shr_sys_abort()
     else
        if (masterproc) write(iulog,*)'(GETFIL): attempting to find local file ',  &
             trim(locfn)
     endif

     ! first check if file is in current working directory.
     inquire (file=locfn,exist=lexist)
     if (lexist) then
        if (masterproc) write(iulog,*) '(GETFIL): using ',trim(locfn), &
             ' in current working directory'
        RETURN
     endif

     ! second check for full pathname on disk
     locfn = fulpath

     inquire (file=fulpath,exist=lexist)
     if (lexist) then
        if (masterproc) write(iulog,*) '(GETFIL): using ',trim(fulpath)
        RETURN
     else
        if (masterproc) write(iulog,*)'(GETFIL): failed getting file from full path: ', fulpath
        if (iflag==0) then
           call shr_sys_abort ('GETFIL: FAILED to get '//trim(fulpath))
        else
           RETURN
        endif
     endif

   end subroutine getfil

!------------------------------------------------------------------------

   subroutine opnfil (locfn, iun, form)

     ! !DESCRIPTION:
     ! Open file locfn in unformatted or formatted form on unit iun
     !
     ! !ARGUMENTS:
     implicit none
     character(len=*), intent(in):: locfn  !file name
     integer, intent(in):: iun             !fortran unit number
     character(len=1), intent(in):: form   !file format: u = unformatted,

     ! !LOCAL VARIABLES:
     integer ioe             !error return from fortran open
     character(len=11) ft    !format type: formatted. unformatted
     !-----------------------------------------------------------

     if (len_trim(locfn) == 0) then
        write(iulog,*)'(OPNFIL): local filename has zero length'
        call shr_sys_abort()
     endif
     if (form=='u' .or. form=='U') then
        ft = 'unformatted'
     else
        ft = 'formatted  '
     end if
     open (unit=iun,file=locfn,status='unknown',form=ft,iostat=ioe)
     if (ioe /= 0) then
        write(iulog,*)'(OPNFIL): failed to open file ',trim(locfn),        &
             &     ' on unit ',iun,' ierr=',ioe
        call shr_sys_abort()
     else if ( masterproc )then
        write(iulog,*)'(OPNFIL): Successfully opened file ',trim(locfn),   &
             &     ' on unit= ',iun
     end if

   end subroutine opnfil

!------------------------------------------------------------------------

  integer function getavu()

    ! !DESCRIPTION:
    ! Get next available Fortran unit number.
    implicit none

    getavu = shr_file_getunit()

  end function getavu

!------------------------------------------------------------------------

  subroutine relavu (iunit)

    ! !DESCRIPTION:
    ! Close and release Fortran unit no longer in use!

    ! !ARGUMENTS:
    implicit none
    integer, intent(in) :: iunit    !Fortran unit number
    !----------------------------------------------------

    close(iunit)
    call shr_file_freeUnit(iunit)

  end subroutine relavu

end module RtmFileUtils
