cmake_minimum_required(VERSION 3.14)

project(hello LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

include(CTest)
include(FetchContent)
include(GoogleTest)

if(MSVC)
	set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
endif()

FetchContent_Declare(
	googletest
	GIT_REPOSITORY https://github.com/google/googletest.git
	GIT_TAG v1.16.0
	GIT_SHALLOW TRUE
)
FetchContent_MakeAvailable(googletest)

add_library(math_operations STATIC math_operations.cpp)

add_executable(hello main.cpp)
target_link_libraries(hello PRIVATE math_operations)

add_executable(unit_tests tests/unit_tests.cpp)
target_link_libraries(unit_tests PRIVATE math_operations GTest::gtest_main)
gtest_discover_tests(unit_tests)
