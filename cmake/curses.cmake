find_package(PkgConfig)

find_package(Curses)

if(NOT Curses_FOUND)
  include(${CMAKE_CURRENT_LIST_DIR}/pdcurses.cmake)
  return()
endif()

# CMake FindCurses is goofed up on some platforms, missing the include directory!
pkg_check_modules(pc_ncurses ncurses QUIET)
find_path(_ncinc NAMES curses.h
  HINTS ${pc_ncurses_INCLUDE_DIRS} ${CURSES_INCLUDE_DIRS}/ncurses)

if(_ncinc)
  list(APPEND CURSES_INCLUDE_DIRS ${_ncinc})
endif()

message(VERBOSE " Curses include: ${CURSES_INCLUDE_DIRS}")

add_library(Curses::Curses INTERFACE IMPORTED GLOBAL)
set_target_properties(Curses::Curses PROPERTIES
  INTERFACE_LINK_LIBRARIES ${CURSES_LIBRARIES}
  INTERFACE_INCLUDE_DIRECTORIES "${CURSES_INCLUDE_DIRS}")
