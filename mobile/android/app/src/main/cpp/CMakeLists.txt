cmake_minimum_required(VERSION 3.18)
project(poma_focus_audio LANGUAGES CXX)
add_library(poma_focus_audio SHARED
  focus_audio_jni.cpp
  ../../../../../native/focus_audio_runtime.cpp)
target_include_directories(poma_focus_audio PRIVATE ../../../../../native)
target_compile_features(poma_focus_audio PRIVATE cxx_std_17)
target_link_libraries(poma_focus_audio PRIVATE android log dl)
target_link_options(poma_focus_audio PRIVATE "-Wl,-z,max-page-size=16384")
