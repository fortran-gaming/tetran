program randblock
! confirms random distribution of block types
use shapes, only: gen_type
use rand, only: random_init, randint, std, mean
use errs, only: err
implicit none

character(*), parameter :: types = 'ITLJSZOD'
integer,parameter :: Ntypes=len(types)
real, parameter :: rtol = 0.01
real :: ideal
character,allocatable :: b(:)
real, allocatable :: e(:)
integer, allocatable :: f(:), g(:)
integer :: i,n, c(Ntypes), u
character(16) :: buf

call random_init()

do i=1,10
  print*,randint(1,8)
enddo

N=1000000
call get_command_argument(1,buf,status=i)
if (i==0) read(buf,*) N

ideal = N/Ntypes

allocate(b(N), e(N), f(N), g(N))

do i = 1,N
  b(i) = gen_type()
enddo
! results
print *,''
print *,'ideal count:',int(ideal)
print *,''
print '(A5,A16,A10)','Block','Count','Error %'
print '(A5,A16,A10)','-----','-----','-------'
do i=1,Ntypes
!do concurrent (i=1:Ntypes) ! even with ifort -parallel, still single core (with print commented)
  c(i) = count(b==types(i:i))
  e(i) = abs(c(i)-ideal) / ideal
  print '(A5,I16,F10.3)',types(i:i), c(i), e(i)*100
enddo

! randomness simple check -- sufficiently uniformly random
if (any(e > rtol)) then 
  call err('non-uniform randomness posssible. Is N > 1000000?')
endif

! -----------

do i = 1,N
  f(i) = randint()
enddo

print *,new_line(' '),'huge(int)',huge(0), 'huge(real)',huge(0.)
print *,'expected std, mean',huge(0)/sqrt(12.), 0.
print *,'std, mean randint()',std(f), mean(f)
print *,'a few values',f(:6)

print *,new_line(' '),'/dev/urandom a few values...'
open(newunit=u, file='/dev/urandom', access="stream", form="unformatted", action="read", status="old")
read(u) G
close(u)

print *,'std, mean /dev/urandom',std(g), mean(g)


end program
