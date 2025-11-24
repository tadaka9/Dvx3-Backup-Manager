cmake_minimum_required(VERSION 3.14)
project(dvx3-tests CXX)
enable_language(C)

# Calculate repository root (parent of tests directory)
get_filename_component(REPO_ROOT ${CMAKE_CURRENT_LIST_DIR} DIRECTORY)

include(GNUInstallDirs)

# Prefer system-installed GoogleTest when available; otherwise fall back to FetchContent
find_package(GTest QUIET)
if (NOT GTest_FOUND)
  include(FetchContent)
  FetchContent_Declare(
    googletest
    URL https://github.com/google/googletest/archive/refs/tags/release-1.13.0.zip
  )
  FetchContent_MakeAvailable(googletest)
  find_package(GTest REQUIRED)
endif()

find_package(PkgConfig REQUIRED)
pkg_check_modules(GLIB REQUIRED glib-2.0 gio-2.0 json-glib-1.0 libsodium)


enable_testing()

# If gen-c is not present, attempt to generate it via valac for test builds.
if(NOT EXISTS ${REPO_ROOT}/gen-c/libdvx3.c)
  find_program(VALAC_EXECUTABLE valac)
  if(VALAC_EXECUTABLE)
    message(STATUS "Generating gen-c source files for tests via valac: ${VALAC_EXECUTABLE}")
    # Use add_custom_command to declare the output file, allowing CMake to determine
    # the target language even when the source doesn't exist yet.
    # Generate the C output into the build directory so CMake can determine linking language
    set(GEN_C_OUT "${CMAKE_CURRENT_BINARY_DIR}/libdvx3.c")
    add_custom_command(
      OUTPUT ${GEN_C_OUT}
      COMMAND ${VALAC_EXECUTABLE} -C -d ${CMAKE_CURRENT_BINARY_DIR} ${REPO_ROOT}/libdvx3.vala
      DEPENDS ${REPO_ROOT}/libdvx3.vala
      COMMENT "Generating gen-c/libdvx3.c via valac into build dir"
    )
    add_custom_target(generate_gen_c DEPENDS ${GEN_C_OUT})
  else()
    message(STATUS "valac not found from CMake. Valac: ${VALAC_EXECUTABLE}")
    message(WARNING "valac not found; tests will fail if gen-c sources are not present in gen-c/ directory")
  endif()
endif()

# Create a static library from gen-c/libdvx3.c so tests can link against it.
if (TARGET generate_gen_c)
  message(STATUS "GEN_C_OUT=${GEN_C_OUT}")
  message(STATUS "Adding dvx3c from generated file ${GEN_C_OUT}")
  set_source_files_properties(${GEN_C_OUT} PROPERTIES LANGUAGE C)
  add_library(dvx3c STATIC ${GEN_C_OUT})
  add_dependencies(dvx3c generate_gen_c)
else()
  message(STATUS "Adding dvx3c from repo file ${REPO_ROOT}/gen-c/libdvx3.c")
  set_source_files_properties(${REPO_ROOT}/gen-c/libdvx3.c PROPERTIES LANGUAGE C)
  add_library(dvx3c STATIC ${REPO_ROOT}/gen-c/libdvx3.c)
endif()
if(TARGET generate_gen_c)
  add_dependencies(dvx3c generate_gen_c)
endif()
target_include_directories(dvx3c PRIVATE ${REPO_ROOT})
target_compile_options(dvx3c PRIVATE ${GLIB_CFLAGS_OTHER})
target_compile_options(dvx3c PRIVATE ${GLIB_CFLAGS})
target_link_libraries(dvx3c PRIVATE ${GLIB_LIBRARIES})
target_compile_options(dvx3c PRIVATE -Wno-discarded-qualifiers -Wno-incompatible-pointer-types)

# GLib compile options for test targets: added after target creation

add_executable(test_simple ${CMAKE_CURRENT_LIST_DIR}/test_simple.cpp)
target_include_directories(test_simple PRIVATE ${REPO_ROOT})
target_compile_definitions(test_simple PRIVATE -D_GNU_SOURCE)
if (TARGET GTest::gtest_main)
  set(GTEST_MAIN_TARGET GTest::gtest_main)
elseif (TARGET gtest_main)
  set(GTEST_MAIN_TARGET gtest_main)
else()
  set(GTEST_MAIN_TARGET gtest_main)
endif()

target_link_libraries(test_simple PRIVATE ${GTEST_MAIN_TARGET} dvx3c ${GLIB_LIBRARIES})
target_compile_options(test_simple PRIVATE ${GLIB_CFLAGS_OTHER})
target_compile_options(test_simple PRIVATE ${GLIB_CFLAGS})

add_executable(test_exclusion ${CMAKE_CURRENT_LIST_DIR}/test_exclusion.cpp)
target_include_directories(test_exclusion PRIVATE ${REPO_ROOT})
target_compile_definitions(test_exclusion PRIVATE -D_GNU_SOURCE)
target_link_libraries(test_exclusion PRIVATE ${GTEST_MAIN_TARGET} dvx3c ${GLIB_LIBRARIES})
target_compile_options(test_exclusion PRIVATE ${GLIB_CFLAGS_OTHER})
target_compile_options(test_exclusion PRIVATE ${GLIB_CFLAGS})

include(GoogleTest)
gtest_discover_tests(test_simple)
gtest_discover_tests(test_exclusion)
