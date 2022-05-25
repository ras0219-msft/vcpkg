if(Z_VCPKG_MSBUILD_INSTALL_GUARD)
    return()
endif()
set(Z_VCPKG_MSBUILD_INSTALL_GUARD ON CACHE INTERNAL "guard variable")
set(Z_VCPKG_MSBUILD_DIR "${CMAKE_CURRENT_LIST_DIR}")

include("${CMAKE_CURRENT_LIST_DIR}/../vcpkg-cmake/vcpkg-port-config.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/vcpkg_msbuild_execute.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/vcpkg_msbuild_install.cmake")
