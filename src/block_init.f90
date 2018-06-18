module fields
use, intrinsic:: iso_c_binding, only: c_int
implicit none
private

type, public :: Field
  ! Microseconds between each automatic downward move
  real :: move_time = 0.5 ! seconds
  integer(c_int) :: sleep_incr = 5e4 !  keyboard polling and screen refresh interval (microseconds).
  ! 1e6 microsec: mushy controls. 1e5 microsec a little laggy. 5e4 about right. 1e4 microsec screen flicker.
  real :: difffact = 1.
  integer :: level = 1
  real :: diffinc = 1.2 ! factor by which level jumps difficulty

  integer :: score = 0
  integer :: Nblock = 0
  integer :: Ncleared = 0 ! total number of lines cleared
  integer :: lines_per_level = 10 ! how many lines to clear to advance to next level
  integer :: bonus(-1:4) = [-100,0,40,100,300,1200]

  character(1) :: blockseq(10000) = "" ! record of blocks player experienced
! NOTE: uses eoshift to avoid indexing beyond array, discarding earliest turns

  integer :: toc, tic ! for each field's update time tracking
  integer :: H,W  ! playfield height, width
  integer :: x0  ! master horizontal origin display coordinate for each playfield
  ! Playfield: 0 for blank
  integer, allocatable :: screen(:,:)

  logical :: debug = .false.
  integer :: udbg
  
  logical :: newhit = .false.
  logical :: cheat = .false.
  logical :: AI

contains

! one per line for PGI, FLang
  procedure, public :: setup
  procedure, public :: levelup
  procedure, public :: clear_lines

end type


contains

subroutine setup(self, W, H, x0, AI, difffact, debug)

  class(Field), intent(inout) :: self

  integer, intent(in) :: H,W
  integer, intent(in), optional :: x0
  logical, intent(in), optional :: AI
  real, intent(in), optional :: difffact
  logical, intent(in), optional :: debug

  self%H = H
  self%W = W

  self%x0 = 1
  if (present(x0)) self%x0 = x0
  
  self%AI = .false.
  if (present(AI)) self%AI = AI
  
  if (present(difffact)) self%difffact = difffact

  if(present(debug)) self%debug = debug

  allocate(self%screen(self%H, self%W))
  self%screen = 0

end subroutine setup


subroutine levelup(self)

  class(field), intent(inout) :: self

  self%newhit = .false.
  
  self%level = self%level + 1
  self%difffact = self%difffact * self%diffinc
  self%move_time = self%move_time / self%difffact
end subroutine levelup


subroutine clear_lines(self)
  class(field), intent(inout) :: self
  logical :: lines_to_clear(self%H)
  integer :: i, counter

  lines_to_clear = all(self%screen==1,2) ! mask of lines that need clearing
  
  counter = count(lines_to_clear)   ! how many lines are cleared
  if (counter == 0) return
  
  if (self%cheat) then
    counter = -1  ! penalty
    self%cheat = .false.
  endif

  self%Ncleared = self%Ncleared + counter
  if (self%debug) write(self%udbg,*) lines_to_clear, counter

  self%score = self%score + self%bonus(counter)
! not concurrent since it could clear lines above shifted by other concurrent iterations
! i.e. in some cases, it would check an OK line that turns bad after clearing by another elemental iteration.
! also note non-adjacent lines can be cleared at once.
  do i = 1, self%H
    if (.not.lines_to_clear(i)) cycle
    self%newhit = .true.
    self%screen(i,:) = 0 ! wipe away cleared lines
    self%screen(:i, :) = cshift(self%screen(:i, :), shift=-1, dim=1)
    ! Bring everything down
  end do
end subroutine clear_lines

end module fields

!==============================================================================

module shapes

use, intrinsic:: iso_c_binding, only: c_int
use, intrinsic:: iso_fortran_env, only: stdout=>output_unit, stderr=>error_unit
use rotflip, only: rot90, fliplr, flipud
use fields, only: field
use rand, only: randint
implicit none

private

type,extends(Field),public :: Piece
 character :: btype
 character(80) :: why
 character :: ch(12)
 integer :: Nx,Ny ! dims of current realization of piece
 integer :: x,y   ! location of piece in playfield
 integer, allocatable :: values(:,:) ! pixels of piece (third dim is rotation)
 logical :: landed ! this piece cannot move anymore
 logical :: movereq ! piece has requested to move in any direction, need to evaluate if collision first.
contains
! one per line for PGI, Flang
 procedure, public  :: init => init_block
 procedure, private :: init_block
 procedure, public :: check_collision
 procedure, public :: move_right
 procedure, public :: move_left
 procedure, public :: rotate
 procedure, public :: move_down
 procedure, public :: dissolve
 procedure, public :: spawn_block
 procedure, public :: vertflip
 procedure, public :: horizflip
 procedure, private :: randomx
 procedure, private :: tell_why
 procedure, private :: hit_horiz
 procedure, private :: hit_floor
 procedure, private :: hit_block
end type

public :: gen_type  ! for benchmarking

contains

subroutine init_block(self,F,btype,x,y)
  class(Piece), intent(inout) :: self
  class(field), intent(in) :: F
  character, intent(in), optional :: btype
  integer, intent(in), optional :: x,y

  integer :: i,j
  integer, parameter :: Nl = 10

  ! Flang / PGF chokes on backslash, so do achar(92).
  ! also FLang / PGF wants defined length.
  character, parameter :: ch(12) = ["#","$","@","%","&","^","-","/","|", achar(92), "*", "."]



! dynamic generated shapes
integer :: line(4,4) = 0
integer :: tee(3,3) = 0
integer :: ell(3,3) = 0
integer :: jay(3,3) = 0
integer :: ess(3,3) = 0
integer :: zee(3,3) = 0
integer :: oh(2,2) = 1
integer :: dot(1,1) = 1

integer :: Lt(Nl, Nl) = 0
integer :: Le(Nl, Nl) = 0
integer :: Lr(Nl, Nl) = 0
integer :: La(Nl, Nl) = 0
integer :: Ln(Nl, Nl) = 0
!-----

line(2,:) = 1

tee(2,:) = 1
tee(3,2) = 1

ell(2,1:3) = 1
ell(3,1) = 1

jay(2,1:3) = 1
jay(3,3) = 1

ess(2,2:3) = 1
ess(3,1:2) = 1

zee(2,1:2) = 1
zee(3,2:3) = 1

Lt(1,:) = 1
Lt(:, Nl/2) = 1

Le(::Nl/2,:) = 1
Le(Nl,:) = 1
Le(:,1) = 1


Lr(::Nl/2,:) = 1
Lr(:,1) = 1
Lr(1:Nl/2, Nl) = 1
j = Nl/2
do i = Nl/2+1,Nl
  j = j+1
  Lr(i,j) = 1
enddo

La(:,1) = 1
La(:,Nl) = 1
La(:Nl-1:Nl/2,:) = 1

Ln(:,1) = 1
Ln(:,Nl) = 1
j = 0
do i =1,Nl
  j = j+1
  Ln(i,j) = 1
enddo
!===============================================================================
  if(.not.allocated(F%screen)) call err('must initialize playfield before piece')
  self%screen = F%screen

  self%W = size(self%screen,2)
  self%H = size(self%screen,1)
  self%x0 = F%x0


  self%landed = .false.
  self%movereq = .false.

  self%y = -1
  if(present(y)) self%y = y

  self%ch = ch
  
  
  if (present(btype)) then
    self%btype = btype
  else
    self%btype = gen_type()
  endif

  ! Fortran 2003+ allocate-on-assign
  select case (self%btype)
    case ("I")
      self%values = line
    case ("T")
      self%values = tee
    case ("L")
      self%values = ell
    case ("J")
      self%values = jay
    case ("S")
      self%values = ess
    case ("Z")
      self%values = zee
    case ("O")
      self%values = oh
    case ("D")
      self%values = dot
      
    case ("t")
      self%values = Lt
    case ("e")
      self%values = Le
    case ("r")
      self%values = Lr
    case ("a")
      self%values = La
    case ("n")
      self%values = Ln
      
    case default
      call err('unknown shape '//self%btype)
  end select

  self%Ny = size(self%values, 1)
  self%Nx = size(self%values, 2)

  !-------- must come after self%Nx assigned!
  self%x = self%randomx()
  if(present(x)) self%x = x
  !--------

  if(self%debug) then
    print *,'shape ',self%btype,': Ny,Nx ',self%Ny,self%Nx
  endif

end subroutine init_block


subroutine spawn_block(self, F, NP)

  class(piece), intent(inout) :: self
  class(field), intent(inout) :: F
  class(piece), intent(inout), optional :: NP
  
  integer :: ib

  ! make new current piece -- have to do this since "=" copys pointers, NOT deep copy for derived types!
  call self%init(F, NP%btype)

  call NP%init(F, x=F%W+5, y=F%H/2)
  
! track block count
  F%Nblock = F%Nblock + 1  ! for game stats

! ----- logging ---------
  if (F%Nblock > size(F%blockseq)) then
    ib = size(F%blockseq)
    F%blockseq = eoshift(F%blockseq,1)  !OK array-temp
  else
    ib = F%Nblock
  endif

  F%blockseq(ib) = self%btype
! ------ end logging
end subroutine spawn_block


character function gen_type() result(next)
! not elemental because there is no input argument. No need for elemental (could be made so as subroutine)
  character, parameter :: Btypes(8) = ['I','T','L','J','S','Z','O','D']

  next = Btypes(randint(1,size(Btypes)))
  
end function gen_type


subroutine dissolve(self)
  class(Piece), intent(inout) :: self

  where (self%values /= 0)
     self%values = modulo(self%values + 1, size(self%ch)+1)
  endwhere

end subroutine dissolve


subroutine move_left(self, slam)
  class(Piece), intent(inout) :: self
  logical, intent(in), optional :: slam
  integer :: i
  
  if (present(slam)) then
    if (slam) then
      do i = 1,self%W
        self%x = self%x - 1
        if (self%check_collision()) then
          self%x = self%x + 1
          return
        endif
      enddo
    endif
  endif
  
!-- one pixel move left attempt
  self%x = self%x - 1
  if (self%check_collision()) then
    self%x = self%x + 1
    call self%tell_why()
  endif
  
end subroutine move_left


subroutine move_right(self, slam)
  class(Piece), intent(inout) :: self
  logical, intent(in), optional :: slam
  integer :: i
  
  if (present(slam)) then
    if (slam) then
      do i = 1,self%W
        self%x = self%x + 1
        if (self%check_collision()) then
          self%x = self%x -1
          return
        endif
      enddo
    endif
  endif

  self%x = self%x + 1
  if (self%check_collision()) then
    self%x = self%x - 1
    call self%tell_why()
  endif
end subroutine move_right


recursive subroutine move_down(self, slam)
  class(Piece), intent(inout) :: self
  logical, intent(in), optional :: slam
  
  if(self%landed) then
    self%why = 'no movement allowed after landing'
    return 
  endif
  
  if(present(slam)) then
    if (slam) then
      do while(.not.self%landed)
        call self%move_down()
      enddo
      return
    endif
  endif

  ! move down 1 pixel
  self%y = self%y+1
  if (self%check_collision()) then  ! landed
    self%landed = .true.
    self%y = self%y - 1
    call self%tell_why()   
  endif
end subroutine move_down


subroutine rotate(self)
  class(Piece), intent(inout) :: self

  self%values = rot90(self%values, 1)

  if (self%check_collision()) then
    call self%tell_why('NO rotation:')
    self%values = rot90(self%values, -1)
  endif
end subroutine rotate


subroutine vertflip(self)
  class(Piece), intent(inout) :: self

  self%values = flipud(self%values)
  
  if (self%check_collision()) then
    call self%tell_why('NO vertical flip:')
    self%values = flipud(self%values)
  endif

end subroutine vertflip


subroutine horizflip(self)
  class(Piece), intent(inout) :: self

  self%values = fliplr(self%values)
  
  if (self%check_collision()) then
    call self%tell_why('NO horizontal flip:')
    self%values = fliplr(self%values)
  endif

end subroutine horizflip


logical function check_collision(self) result (collided)
  class(Piece), intent(inout) :: self

! always check all, in case rotation

  collided = self%hit_floor()
  if (collided) return

  collided = self%hit_horiz()
  if (collided) return

  collided = self%hit_block()

end function check_collision


logical function hit_floor(self)
! NOTE: do NOT set self%alanded in this function, as this will break rotation attempts near floor!
  class(Piece), intent(inout) :: self
  integer :: i
  
  hit_floor = .false. 
  
  do i = 1,self%Ny
    if (all(self%values(i,:) == 0)) cycle

    hit_floor = self%y + (i-1) > self%H 
    if (hit_floor) exit
  enddo
  
  if (hit_floor) then
    write(self%why,'(A20,I3,A3,I3)') 'floor hit, y0=',self%y,'y=',self%y+(i-1)
  endif

end function hit_floor


logical function hit_horiz(self)
  class(Piece), intent(inout) :: self
  integer :: i
  
  hit_horiz = .false.

  do i = 1,self%Nx
    if(all(self%values(:,i) == 0)) cycle

    hit_horiz = self%x + (i-1) < 1 .or. self%x + (i-1) > self%W
    if (hit_horiz) exit
  enddo
  
  if (hit_horiz) write(self%why,'(A21,I3,A3,I3)') 'wall hit, x0=',self%x,'x=',self%x+(i-1)

end function hit_horiz


logical function hit_block(self)
  class(Piece), intent(inout) :: self
  integer :: i, ix, ixs
  
  hit_block = .false.
  
  ix = max(1,self%x)
  ixs = min(self%W, ix + self%Nx - (ix-self%x) - 1)
  do i = 1, self%Ny
    if (self%y + (i-1) < 1) cycle        ! this block row above playfield
    if (all(self%values(i,:) == 0)) cycle ! no part of block in this block row

    hit_block = any(self%screen(self%y + (i-1), ix:ixs) + self%values(i,ix-self%x+1:ixs-self%x+1) > &
                    maxval(self%values(i,ix-self%x+1:ixs-self%x+1)))
    
    if(hit_block) exit
  enddo
  
   if (hit_block) write(self%why,'(A20,I3,A4,I3)')  'block hit, x=',self%x,' y=',self%y

end function hit_block


integer function randomx(self)
! NOTE: even if elemental, because it's part of a class, have to %init() then %randomx() each time, if using externally (which would be unusual)
  class(Piece), intent(in) :: self

  if (self%W==0) call err('playfield has zero width. Be sure to intialize playfield before piece?')
  if (.not.allocated(self%values)) call err('piece was not allocated')
  if (self%Nx <1 .or. self%Nx >= self%W) then
    write(stderr,'(A,I3,A,I3)') 'Nx',self%Nx,'  W',self%W
    call err('piece outside playfield @ initial x position')
  endif

  randomx = randint(1, self%W-self%Nx)   ! 1 to screen width, minus block width

end function randomx


subroutine tell_why(self, msg)
  class(Piece), intent(in) :: self
  character(*), intent(in), optional :: msg

  character(:), allocatable :: str

  if (.not.self%debug) return

  if (present(msg)) then
    str = trim(msg)//' '//trim(self%why)
  else
    str = self%why
  endif

  write(stdout,'(A50,A1)', advance='no') str, achar(13)
  flush(stdout)

end subroutine tell_why


subroutine err(msg)
  character(*),intent(in) :: msg

  write(stderr,*) msg

  stop -1

end subroutine err

end module shapes
