# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
project(dart_get_map_version_library VERSION 0.0.1 LANGUAGES CXX)

set(third_party_dir ${CMAKE_CURRENT_SOURCE_DIR}/../third_party)

# ADD AND CONFIG httplib
find_package(OpenSSL REQUIRED)
if(OPENSSL_FOUND)
    set(HTTPLIB_IS_USING_OPENSSL TRUE)
endif()

add_subdirectory(${third_party_dir}/cpp-get-map-version ${CMAKE_CURRENT_BINARY_DIR}/cpp-get-map-version)

add_library(dart_get_map_version SHARED
  "dart_get_map_version.cpp"
)

set_target_properties(dart_get_map_version PROPERTIES
  PUBLIC_HEADER dart_get_map_version.h
  OUTPUT_NAME "dart_get_map_version"
)

target_link_libraries(dart_get_map_version $<TARGET_FILE:spreadsheetLib> OpenSSL::SSL OpenSSL::Crypto)
target_include_directories(dart_get_map_version BEFORE PUBLIC "${third_party_dir}/cpp-get-map-version/src")

target_compile_definitions(dart_get_map_version PUBLIC DART_SHARED_LIB)
target_compile_features(dart_get_map_version PUBLIC cxx_std_20)