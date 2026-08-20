cmake_minimum_required(VERSION 3.16)
project(gnix-effects)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(ECM REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

# Only Core and Gui are used directly; Widgets is required because KWin's
# exported CMake target lists Qt6::Widgets in its link interface without
# finding it for the consumer.
find_package(Qt6 REQUIRED COMPONENTS Core Gui Widgets)
find_package(KF6CoreAddons REQUIRED)
find_package(KDecoration3 REQUIRED)
find_package(KWin REQUIRED)

add_library(gnix-effects MODULE
    src/gnix.cpp
    src/shaders.qrc
)
set_target_properties(gnix-effects PROPERTIES PREFIX "")

target_link_libraries(gnix-effects PRIVATE
    KWin::kwin
    KF6::CoreAddons
    KDecoration3::KDecoration
    Qt6::Core
    Qt6::Gui
)

install(TARGETS gnix-effects
    LIBRARY DESTINATION lib/qt-6/plugins/kwin/effects/plugins
)
