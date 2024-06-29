project(burrito)
cmake_minimum_required(VERSION 3.18...3.27)
find_package(Python 3.8 COMPONENTS Interpreter Development.Module REQUIRED)

if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()

#if (NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
#  set(CMAKE_BUILD_TYPE Release CACHE STRING "Choose the type of build." FORCE)
#  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug" "Release" "MinSizeRel" "RelWithDebInfo")
#endif()

message(CMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE}")

set(CMAKE_CXX_FLAGS "-Wall -Wextra")
set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -g")
set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -fsanitize=address")
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

nanobind_add_module(burrito burrito.cpp)
target_compile_features(burrito PRIVATE cxx_std_17)

# set(OpenMP_C "${CMAKE_C_COMPILER}")
# set(OpenMP_C_FLAGS "-Xclang -fopenmp -I/opt/homebrew/opt/libomp/include")
# set(OpenMP_C_LIB_NAMES "libomp")
# set(OpenMP_libomp_LIBRARY "omp")

# set(OpenMP_CXX "${CMAKE_CXX_COMPILER}")
# set(OpenMP_CXX_FLAGS "-Xclang -fopenmp -I/opt/homebrew/opt/libomp/include")
# set(OpenMP_CXX_LIB_NAMES "libomp")
# set(OpenMP_libomp_LIBRARY "omp")

# find_package(OpenMP REQUIRED)

link_directories("/opt/homebrew/opt/libomp/lib/")
target_link_directories(${PROJECT_NAME} PRIVATE "/opt/homebrew/opt/libomp/lib/")

# target_link_libraries(burrito PRIVATE OpenMP::OpenMP_CXX)

