cmake_minimum_required(VERSION 3.16)
project(Dvx3BackupManager VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find Qt5 Desktop components
find_package(Qt5 REQUIRED COMPONENTS Core Gui Widgets Network Concurrent)

# Include directories
include_directories(${PROJECT_SOURCE_DIR}/.. ${PROJECT_SOURCE_DIR})

# Add executable
add_executable(backup-manager-qtdesktop
    backup-manager-qtdesktop.cpp
)

# Link Qt libraries
target_link_libraries(backup-manager-qtdesktop
    Qt5::Core
    Qt5::Gui
    Qt5::Widgets
    Qt5::Network
    Qt5::Concurrent
)

# Set output name
set_target_properties(backup-manager-qtdesktop PROPERTIES
    OUTPUT_NAME "dvx3-backup-manager"
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
)

install(TARGETS backup-manager-qtdesktop
    RUNTIME DESTINATION bin
)
