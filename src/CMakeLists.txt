# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(dart_get_map_version_library VERSION 0.0.1 LANGUAGES C)

add_library(dart_get_map_version SHARED
  "dart_get_map_version.c"
)

set_target_properties(dart_get_map_version PROPERTIES
  PUBLIC_HEADER dart_get_map_version.h
  OUTPUT_NAME "dart_get_map_version"
)

target_compile_definitions(dart_get_map_version PUBLIC DART_SHARED_LIB)
