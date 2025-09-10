cmake_minimum_required(VERSION 3.16)
project(engine C CXX)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/../third_party/whisper.cpp ${CMAKE_CURRENT_BINARY_DIR}/whisper)

add_library(engine SHARED engine.cpp)
target_include_directories(engine PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/../third_party/whisper.cpp)
target_link_libraries(engine PRIVATE whisper)
