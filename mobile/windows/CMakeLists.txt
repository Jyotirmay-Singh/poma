# Project-level configuration.
cmake_minimum_required(VERSION 3.14)
project(poma LANGUAGES CXX)

# The name of the executable created for the application. Change this to change
# the on-disk name of your application.
set(BINARY_NAME "poma")

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# Define build configuration option.
get_property(IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(IS_MULTICONFIG)
  set(CMAKE_CONFIGURATION_TYPES "Debug;Profile;Release"
    CACHE STRING "" FORCE)
else()
  if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Debug" CACHE
      STRING "Flutter build mode" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
      "Debug" "Profile" "Release")
  endif()
endif()
# Define settings for the Profile build mode.
set(CMAKE_EXE_LINKER_FLAGS_PROFILE "${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
set(CMAKE_SHARED_LINKER_FLAGS_PROFILE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}")
set(CMAKE_C_FLAGS_PROFILE "${CMAKE_C_FLAGS_RELEASE}")
set(CMAKE_CXX_FLAGS_PROFILE "${CMAKE_CXX_FLAGS_RELEASE}")

# Use Unicode for all projects.
add_definitions(-DUNICODE -D_UNICODE)

# Compilation settings that should be applied to most targets.
#
# Be cautious about adding new options here, as plugins use this function by
# default. In most cases, you should add new options to specific targets instead
# of modifying this function.
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_17)
  target_compile_options(${TARGET} PRIVATE /W4 /WX /wd"4100")
  target_compile_options(${TARGET} PRIVATE /EHsc)
  target_compile_definitions(${TARGET} PRIVATE "_HAS_EXCEPTIONS=0")
  target_compile_definitions(${TARGET} PRIVATE "$<$<CONFIG:Debug>:_DEBUG>")
endfunction()

# Flutter library and tool build rules.
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# Application build; see runner/CMakeLists.txt.
add_subdirectory("runner")


# Generated plugin build rules, which manage building the plugins and adding
# them to the application.
include(flutter/generated_plugins.cmake)

# The locked notification FFI plugin uses ATL solely for three UTF-8 conversions.
# Build a local source copy using C++/WinRT's equivalent conversions, so this
# project needs no optional ATL installation. Never alter the user's pub cache.
# Poma's Windows adapter does not initialize this plugin or its registry writer.
if(TARGET flutter_local_notifications_windows)
  get_target_property(NOTIFICATION_SOURCE flutter_local_notifications_windows SOURCE_DIR)
  file(READ "${NOTIFICATION_SOURCE}/plugin.cpp" NOTIFICATION_COMPAT)
  if(NOT NOTIFICATION_COMPAT MATCHES "CW2A")
    message(FATAL_ERROR "Review the locked Windows notification compatibility patch")
  endif()
  string(REPLACE "#include <atlbase.h>" "" NOTIFICATION_COMPAT "${NOTIFICATION_COMPAT}")
  string(REPLACE "CW2A(item.Key, CP_UTF8)" "winrt::to_string(item.Key)" NOTIFICATION_COMPAT "${NOTIFICATION_COMPAT}")
  string(REPLACE "CW2A(item.Value, CP_UTF8)" "winrt::to_string(item.Value)" NOTIFICATION_COMPAT "${NOTIFICATION_COMPAT}")
  string(REPLACE "CW2A(args, CP_UTF8)" "winrt::to_string(args ? args : L\"\")" NOTIFICATION_COMPAT "${NOTIFICATION_COMPAT}")
  file(MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/notification_compat")
  set(NOTIFICATION_COMPAT_PATH "${CMAKE_CURRENT_BINARY_DIR}/notification_compat/plugin.cpp")
  if(EXISTS "${NOTIFICATION_COMPAT_PATH}")
    file(READ "${NOTIFICATION_COMPAT_PATH}" EXISTING_NOTIFICATION_COMPAT)
  endif()
  if(NOT NOTIFICATION_COMPAT STREQUAL EXISTING_NOTIFICATION_COMPAT)
    file(WRITE "${NOTIFICATION_COMPAT_PATH}" "${NOTIFICATION_COMPAT}")
  endif()
  get_target_property(NOTIFICATION_SOURCES flutter_local_notifications_windows SOURCES)
  list(REMOVE_ITEM NOTIFICATION_SOURCES "plugin.cpp")
  list(TRANSFORM NOTIFICATION_SOURCES PREPEND "${NOTIFICATION_SOURCE}/")
  list(APPEND NOTIFICATION_SOURCES "${CMAKE_CURRENT_BINARY_DIR}/notification_compat/plugin.cpp")
  set_property(TARGET flutter_local_notifications_windows PROPERTY SOURCES "${NOTIFICATION_SOURCES}")
  target_include_directories(flutter_local_notifications_windows PRIVATE "${NOTIFICATION_SOURCE}")
endif()


# === Installation ===
# Support files are copied into place next to the executable, so that it can
# run in place. This is done instead of making a separate bundle (as on Linux)
# so that building and running from within Visual Studio will work.
set(BUILD_BUNDLE_DIR "$<TARGET_FILE_DIR:${BINARY_NAME}>")
# Make the "install" step default, as it's required to run.
set(CMAKE_VS_INCLUDE_INSTALL_TO_DEFAULT_BUILD 1)
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)
endif()

set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}")

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

if(PLUGIN_BUNDLED_LIBRARIES)
  install(FILES "${PLUGIN_BUNDLED_LIBRARIES}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()

# Copy the native assets provided by the build.dart from all packages.
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/windows/")
install(DIRECTORY "${NATIVE_ASSETS_DIR}"
   DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
   COMPONENT Runtime)

# Fully re-copy the assets directory on each build to avoid having stale files
# from a previous install.
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
install(CODE "
  file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")
  " COMPONENT Runtime)
install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)

# Install the AOT library on non-Debug builds only.
install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  CONFIGURATIONS Profile;Release
  COMPONENT Runtime)
