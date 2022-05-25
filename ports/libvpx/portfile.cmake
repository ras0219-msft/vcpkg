vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

set(LIBVPX_VERSION 1.11.0)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO webmproject/libvpx
    REF v${LIBVPX_VERSION}
    SHA512 7aa5d30afa956dccda60917fd82f6f9992944ca893437c8cd53a04d1b7a94e0210431954aa136594dc400340123cc166dcc855753e493c8d929667f4c42b65a5
    HEAD_REF master
    PATCHES
        0002-Fix-nasm-debug-format-flag.patch
        0003-add-uwp-and-v142-support.patch
        0004-remove-library-suffixes.patch
)

vcpkg_find_acquire_program(PERL)

get_filename_component(PERL_EXE_PATH ${PERL} DIRECTORY)

if(CMAKE_HOST_WIN32)
	vcpkg_acquire_msys(MSYS_ROOT PACKAGES make)
	set(BASH ${MSYS_ROOT}/usr/bin/bash.exe)
	set(ENV{PATH} "${MSYS_ROOT}/usr/bin;$ENV{PATH};${PERL_EXE_PATH}")
else()
	set(BASH /bin/bash)
	set(ENV{PATH} "$ENV{PATH}:${PERL_EXE_PATH}")
endif()

vcpkg_find_acquire_program(NASM)
get_filename_component(NASM_EXE_PATH ${NASM} DIRECTORY)
vcpkg_add_to_path(${NASM_EXE_PATH})

if(VCPKG_TARGET_ARCHITECTURE STREQUAL x86)
    set(LIBVPX_TARGET_ARCH "x86")
elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL x64)
    set(LIBVPX_TARGET_ARCH "x86_64")
elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL arm64)
    set(LIBVPX_TARGET_ARCH "arm64")
elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL arm)
    set(LIBVPX_TARGET_ARCH "armv7")
else()
    message(FATAL_ERROR "libvpx does not support architecture ${VCPKG_TARGET_ARCHITECTURE}")
endif()

set(OPTIONS "--disable-unit-tests --disable-examples --disable-tools --disable-docs --enable-pic --disable-werror")

if("realtime" IN_LIST FEATURES)
    string(APPEND OPTIONS " --enable-realtime-only")
endif()

if("highbitdepth" IN_LIST FEATURES)
    string(APPEND OPTIONS " --enable-vp9-highbitdepth")
endif()

if(VCPKG_TARGET_IS_WINDOWS AND NOT VCPKG_TARGET_IS_MINGW)

    vcpkg_cmake_get_vars(cmake_vars_path)
    include("${cmake_vars_path}")
    set(ENV{CXX} "${VCPKG_DETECTED_CMAKE_CXX_COMPILER}")
    set(ENV{CC} "${VCPKG_DETECTED_CMAKE_C_COMPILER}")
    set(ENV{LD} "${VCPKG_DETECTED_CMAKE_LINKER}")
    set(ENV{AR} "${VCPKG_DETECTED_CMAKE_AR}")

    if(VCPKG_CMAKE_SYSTEM_NAME STREQUAL "WindowsStore")
        set(LIBVPX_TARGET_OS "uwp")
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x86" OR VCPKG_TARGET_ARCHITECTURE STREQUAL "arm")
        set(LIBVPX_TARGET_OS "win32")
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64" OR VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
        set(LIBVPX_TARGET_OS "win64")
    endif()

    set(LIBVPX_TARGET_VS "vs15")

    string(APPEND OPTIONS " --enable-external-build --disable-optimizations")

    set(flavors RELEASE)
    if(NOT VCPKG_BUILD_TYPE)
        list(APPEND flavors DEBUG)
    endif()
    foreach(flavor IN LISTS flavors)
        if(flavor STREQUAL "RELEASE")
            set(suffix "${TARGET_TRIPLET}-rel")
            set(dst "${CURRENT_PACKAGES_DIR}")
        else()
            set(suffix "${TARGET_TRIPLET}-dbg")
            set(dst "${CURRENT_PACKAGES_DIR}/debug")
        endif()
        set(work "${CURRENT_BUILDTREES_DIR}/${suffix}")
        message(STATUS "Generating makefile")
        file(REMOVE_RECURSE "${work}")
        file(MAKE_DIRECTORY "${work}")
        set(ENV{LDFLAGS} "")
        set(ENV{CFLAGS} "")
        set(ENV{ARFLAGS} "")
        set(ENV{CXXFLAGS} "")
        vcpkg_execute_required_process(
            COMMAND
                ${BASH} --noprofile --norc
                "${SOURCE_PATH}/configure"
                --target=${LIBVPX_TARGET_ARCH}-${LIBVPX_TARGET_OS}-vs15
                ${LIBVPX_CRT_LINKAGE}
                ${OPTIONS}
                --as=nasm
            WORKING_DIRECTORY "${work}"
            LOGNAME configure-${suffix}
        )

        message(STATUS "Generating MSBuild projects")
        vcpkg_execute_required_process(
            COMMAND
                ${BASH} --noprofile --norc -c "make dist"
            WORKING_DIRECTORY "${work}"
            LOGNAME generate-${suffix}
        )

        set(ENV{ARFLAGS} "${VCPKG_COMBINED_STATIC_LINKER_FLAGS_${flavor}}")
        set(ENV{CXXFLAGS} "${VCPKG_COMBINED_CXX_FLAGS_${flavor}}")
        set(ENV{LDFLAGS} "${VCPKG_COMBINED_SHARED_LINKER_FLAGS_${flavor}}")
        set(ENV{CFLAGS} "${VCPKG_COMBINED_C_FLAGS_${flavor}}")
        message(STATUS "Building MSBuild projects")
        vcpkg_msbuild_execute(
            PROJECT_PATH "${work}/vpx.vcxproj"
            ${flavor}
            LOGNAME build-${suffix}
        )

        file(GLOB_RECURSE libs "${work}/*.lib")
        file(GLOB_RECURSE bins "${work}/*.dll" "${work}/*.pdb")

        if(libs)
            file(INSTALL ${libs} DESTINATION "${dst}/lib")
        endif()
        if(bins)
            file(INSTALL ${bins} DESTINATION "${dst}/bin")
        endif()
        set(LIBVPX_PREFIX "${dst}")
        configure_file("${CMAKE_CURRENT_LIST_DIR}/vpx.pc.in" "${dst}/lib/pkgconfig/vpx.pc" @ONLY)
    endforeach()

    file(GLOB inc "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/*/include/vpx")
    file(COPY "${inc}" DESTINATION "${CURRENT_PACKAGES_DIR}/include")

else()

    set(OPTIONS_DEBUG "--enable-debug-libs --enable-debug --prefix=${CURRENT_PACKAGES_DIR}/debug")
    set(OPTIONS_RELEASE "--prefix=${CURRENT_PACKAGES_DIR}")

    if(VCPKG_LIBRARY_LINKAGE STREQUAL "dynamic")
        string(APPEND OPTIONS " --disable-static --enable-shared")
    else()
        string(APPEND OPTIONS " --enable-static --disable-shared")
    endif()

    if(VCPKG_TARGET_IS_WINDOWS)
		if(LIBVPX_TARGET_ARCH STREQUAL "x86")
			set(LIBVPX_TARGET "x86-win32-gcc")
		else()
			set(LIBVPX_TARGET "x86_64-win64-gcc")
		endif()
	elseif(VCPKG_TARGET_IS_LINUX)
        set(LIBVPX_TARGET "${LIBVPX_TARGET_ARCH}-linux-gcc")
    elseif(VCPKG_TARGET_IS_OSX)
        if(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
            set(LIBVPX_TARGET "arm64-darwin20-gcc")
        else()
            set(LIBVPX_TARGET "${LIBVPX_TARGET_ARCH}-darwin17-gcc") # enable latest CPU instructions for best performance and less CPU usage on MacOS
        endif()
    else()
        set(LIBVPX_TARGET "generic-gnu") # use default target
    endif()

    message(STATUS "Build info. Target: ${LIBVPX_TARGET}; Options: ${OPTIONS}")

    if(NOT DEFINED VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "release")
        message(STATUS "Configuring libvpx for Release")
        file(MAKE_DIRECTORY "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel")
        vcpkg_execute_required_process(
        COMMAND
            ${BASH} --noprofile --norc
            "${SOURCE_PATH}/configure"
            --target=${LIBVPX_TARGET}
            ${OPTIONS}
            ${OPTIONS_RELEASE}
            --as=nasm
        WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel"
        LOGNAME configure-${TARGET_TRIPLET}-rel)

        message(STATUS "Building libvpx for Release")
        vcpkg_execute_required_process(
            COMMAND
                ${BASH} --noprofile --norc -c "make -j8"
            WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel"
            LOGNAME build-${TARGET_TRIPLET}-rel
        )

        message(STATUS "Installing libvpx for Release")
        vcpkg_execute_required_process(
            COMMAND
                ${BASH} --noprofile --norc -c "make install"
            WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel"
            LOGNAME install-${TARGET_TRIPLET}-rel
        )
    endif()

    # --- --- ---

    if(NOT DEFINED VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "debug")
        message(STATUS "Configuring libvpx for Debug")
        file(MAKE_DIRECTORY "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg")
        vcpkg_execute_required_process(
        COMMAND
            ${BASH} --noprofile --norc
            "${SOURCE_PATH}/configure"
            --target=${LIBVPX_TARGET}
            ${OPTIONS}
            ${OPTIONS_DEBUG}
            --as=nasm
        WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg"
        LOGNAME configure-${TARGET_TRIPLET}-dbg)

        message(STATUS "Building libvpx for Debug")
        vcpkg_execute_required_process(
            COMMAND
                ${BASH} --noprofile --norc -c "make -j8"
            WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg"
            LOGNAME build-${TARGET_TRIPLET}-dbg
        )

        message(STATUS "Installing libvpx for Debug")
        vcpkg_execute_required_process(
            COMMAND
                ${BASH} --noprofile --norc -c "make install"
            WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg"
            LOGNAME install-${TARGET_TRIPLET}-dbg
        )

        file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
        file(REMOVE "${CURRENT_PACKAGES_DIR}/debug/lib/libvpx_g.a")
    endif()
endif()

vcpkg_copy_pdbs()

vcpkg_fixup_pkgconfig()

if(NOT DEFINED VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "debug")
    set(LIBVPX_CONFIG_DEBUG ON)
else()
    set(LIBVPX_CONFIG_DEBUG OFF)
endif()

configure_file("${CMAKE_CURRENT_LIST_DIR}/unofficial-libvpx-config.cmake.in" "${CURRENT_PACKAGES_DIR}/share/unofficial-libvpx/unofficial-libvpx-config.cmake" @ONLY)

file(INSTALL "${SOURCE_PATH}/LICENSE" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)
