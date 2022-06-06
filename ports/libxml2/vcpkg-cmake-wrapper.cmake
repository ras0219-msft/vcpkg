set(z_vcpkg_libxml2_module_path "${CMAKE_MODULES_PATH}")
set(CMAKE_MODULES_PATH "${CMAKE_MODULES_PATH};${CMAKE_CURRENT_LIST_DIR}")

_find_package(${ARGS})

set(CMAKE_MODULES_PATH "${z_vcpkg_libxml2_module_path}")
unset(z_vcpkg_libxml2_module_path)
