add_library(AI OBJECT ai.f90)
target_link_libraries(AI PRIVATE shapes)

if(f18random)
set(_random_init "call random_init(repeatable, image_distinct)")
else()
set(_random_init "
integer, allocatable :: seed(:)
integer :: i,n
call random_seed(size=n)
allocate(seed(n))
do i = 1,n
  seed(i) = randint(-1073741823, 1073741823)
end do
")
endif()

configure_file(random.in.f90 random.f90)
add_library(shapes OBJECT shapes.f90 fields.f90 rot90.f90
  ${CMAKE_CURRENT_BINARY_DIR}/random.f90)


add_library(cinterc OBJECT cinter.c)
target_link_libraries(cinterc PRIVATE Curses::Curses)

add_library(cinter OBJECT cinter.f90)
target_link_libraries(cinter PRIVATE cinterc Curses::Curses)
if(WIN32)
  target_sources(cinter PRIVATE wincinter.f90)
else()
  target_sources(cinter PRIVATE unixcinter.f90)
endif()

add_library(errs OBJECT err.f90)
target_link_libraries(errs PRIVATE cinter Curses::Curses)

add_library(menu OBJECT menu.f90)
target_link_libraries(menu PRIVATE cinter shapes blocks)


add_library(blocks OBJECT blocks.f90)
target_link_libraries(blocks PRIVATE cinter shapes)

add_library(keys OBJECT keys.f90)
target_link_libraries(keys PRIVATE AI cinter blocks)

foreach(t AI shapes blocks cinter cinterc errs keys menu)
  target_include_directories(${t}
    PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/include  # necessary in general for IBM XL
    INTERFACE ${CMAKE_CURRENT_BINARY_DIR}/include)
  set_target_properties(${t} PROPERTIES Fortran_MODULE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/include)
endforeach()
