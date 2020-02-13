
add_executable(blockrand randtest.f90)
target_link_libraries(blockrand PRIVATE shapes)
add_test(NAME RandomBlocks COMMAND blockrand)

add_executable(shapetest test_shapes.f90)
target_link_libraries(shapetest PRIVATE shapes)
add_test(NAME BlockShapes COMMAND shapetest)

add_executable(motiontest test_motion.f90)
target_link_libraries(motiontest PRIVATE shapes)
add_test(NAME BlockMotion COMMAND motiontest)

add_executable(curses_test test_curses.f90)
target_link_libraries(curses_test PRIVATE cinter)
if(NOT ENV{CI})
  add_test(NAME CursesLibGUI COMMAND curses_test)
endif()

add_executable(testkeys keytest.f90)
target_link_libraries(testkeys PRIVATE errs cinter keys)

add_executable(menu_test test_menu.f90)
target_link_libraries(menu_test PRIVATE cinter menu)
if(NOT ENV{CI})
  add_test(NAME TitleScreenGUI COMMAND menu_test)
  set_tests_properties(TitleScreenGUI PROPERTIES TIMEOUT 10)
endif()