find_package(PkgConfig)
find_package(Curses)
# CMake FindCurses is goofed up on some platforms, missing the include directory!
if(CURSES_FOUND)
  pkg_check_modules(NC ncurses)
  find_path(NCI NAMES curses.h HINTS ${NC_INCLUDE_DIRS} ${CURSES_INCLUDE_DIRS}/ncurses)
  if(NCI)
    list(APPEND CURSES_INCLUDE_DIRS ${NCI})
  endif()
  message(STATUS "CURSES include: ${CURSES_INCLUDE_DIRS}")
endif()
