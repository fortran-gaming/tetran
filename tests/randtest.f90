program randblock
! confirms random distribution of block types
use blocks, only: generate_next_type, init_random_seed
use cinter, only: err
implicit none

character(*), parameter :: types = 'ITLJSZB'
integer,parameter :: Ntypes=len(types)
real, parameter :: rtol = 0.01
character,allocatable :: b(:)
integer :: i,n, c(Ntypes)
character(32) :: buf

N=1000000
call get_command_argument(1,buf,status=i)
if (i==0) read(buf,*) N

allocate(b(N))

call init_random_seed()

call generate_next_type(b)

do i=1,Ntypes
!do concurrent (i=1:Ntypes) ! even with ifort -parallel, still single core (with print commented)
  c(i) = countletters(b,types(i:i))
  print *,types(i:i),c(i)
  
  ! randomness simple check -- sufficiently uniformly random
  if (abs(c(i)-c(1)) / real(c(1)) > rtol) then 
    call err('non-uniform randomness posssible. Is N > 1000000?')
  endif
  
enddo




contains

  pure integer function countletters(str,let) result (c)
  
 
    character, intent(in) :: str(:)  ! array of single characters
    character, intent(in) :: let
  
    integer :: i
    
    c = 0
    
    do i = 1,size(str)
      if (str(i) == let) c=c+1
    enddo
  
  end function countletters


end program