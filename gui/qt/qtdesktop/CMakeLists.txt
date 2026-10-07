cmake_minimum_required(VERSION 3.21)
project(Dvx3BackupManagerQt VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(Qt6 6.4 REQUIRED COMPONENTS Core Widgets)

qt_add_executable(dvx3-backup-manager
    main.cpp
    resources.qrc
)

target_link_libraries(dvx3-backup-manager PRIVATE Qt6::Core Qt6::Widgets)

target_compile_options(dvx3-backup-manager PRIVATE
    $<$<CXX_COMPILER_ID:GNU,Clang>:-Wall -Wextra -Wpedantic>
)

install(TARGETS dvx3-backup-manager
    BUNDLE DESTINATION .
    RUNTIME DESTINATION bin
)
