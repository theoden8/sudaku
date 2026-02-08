cmake_minimum_required(VERSION 3.10.2)
project(sudoku_native)

add_library(sudoku_native SHARED
    ${CMAKE_CURRENT_SOURCE_DIR}/../../../../../native/sudoku_native.c
)

target_compile_options(sudoku_native PRIVATE -O3 -fvisibility=default)
target_link_libraries(sudoku_native m log)
