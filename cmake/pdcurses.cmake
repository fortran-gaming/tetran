include(FetchContent)

FetchContent_Declare(pdcurses_proj
  GIT_REPOSITORY https://github.com/scivision/PDCurses.git
  GIT_TAG cmake
)

FetchContent_MakeAvailable(pdcurses_proj)
