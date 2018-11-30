if(CMAKE_BUILD_TYPE STREQUAL Debug)
  add_compile_options(-g -O0)
else()
  add_compile_options(-O3)
endif()

if(CMAKE_Fortran_COMPILER_ID STREQUAL GNU)
  list(APPEND FFLAGS -march=native -Wall -Wextra -Wpedantic -Werror=array-bounds
      -finit-real=nan -Wconversion -fimplicit-none) #-Warray-temporaries
  
  if(CMAKE_BUILD_TYPE STREQUAL Debug)
    list(APPEND FFLAGS -fcheck=all -fexceptions -ffpe-trap=invalid,zero,overflow) 
  endif()
  
  if (UNIX AND NOT (APPLE OR CYGWIN))
    list(APPEND FFLAGS -fstack-protector-all)
  endif()

  if(CMAKE_Fortran_COMPILER_VERSION VERSION_GREATER_EQUAL 8)
    list(APPEND FFLAGS -std=f2018)
  endif()
  
elseif(CMAKE_Fortran_COMPILER_ID STREQUAL Intel)
  list(APPEND FFLAGS -warn -traceback)
  
  if(CMAKE_BUILD_TYPE STREQUAL Debug)
    list(APPEND FFLAGS -fpe0 -debug extended -check all)
  endif()
elseif(CMAKE_Fortran_COMPILER_ID STREQUAL Flang)  # https://github.com/flang-compiler/flang/wiki/Fortran-2008
  list(APPEND FFLAGS -Mallocatable=03)
  list(APPEND FLIBS -static-flang-libs)
elseif(CMAKE_Fortran_COMPILER_ID STREQUAL PGI)

elseif(CMAKE_Fortran_COMPILER_ID STREQUAL NAG)

endif()

# ---

include(CheckFortranSourceCompiles)

check_fortran_source_compiles("program a; error stop; end" f08errorstop SRC_EXT f90)

check_fortran_source_compiles("program a; call random_init(); end" f18random SRC_EXT f90)

check_fortran_source_compiles("
module b
interface
module subroutine d
end subroutine d
end interface
end

submodule (b) c
contains
module procedure d
end
end

program a
end"
  f08submod SRC_EXT f90)
  
if(NOT f08submod)
  message(FATAL_ERROR "Fortran 2008 submodule support required, and " ${CMAKE_Fortran_COMPILER_ID} " " ${CMAKE_Fortran_COMPILER_VERSION} " does not seem to support.")
endif()
