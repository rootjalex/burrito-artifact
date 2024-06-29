project(io_coo)
cmake_minimum_required(VERSION 3.18...3.27)
find_package(Python 3.8 COMPONENTS Interpreter Development.Module REQUIRED)

if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()

message(CMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE}")

set(CMAKE_CXX_FLAGS "-Wall -Wextra")
set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -g")
# set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -fsanitize=address")
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -O3")
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -ffast-math")
# set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -lto")
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -march=native")


# Detect the installed nanobind package and import it into CMake
#execute_process(
#  COMMAND "${Python_EXECUTABLE}" -m nanobind --cmake_dir
#  OUTPUT_STRIP_TRAILING_WHITESPACE OUTPUT_VARIABLE NB_DIR)
#list(APPEND CMAKE_PREFIX_PATH "${NB_DIR}")
#find_package(nanobind CONFIG REQUIRED)
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/../ext/nanobind [EXCLUDE_FROM_ALL])

nanobind_add_module(io_coo io_coo.cpp)
target_compile_features(io_coo PRIVATE cxx_std_17)
