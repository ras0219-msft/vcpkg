function(vcpkg_msbuild_install)
    cmake_parse_arguments(
        PARSE_ARGV 0
        "arg"
        "USE_VCPKG_INTEGRATION;ALLOW_ROOT_INCLUDES;REMOVE_ROOT_INCLUDES"
        "SOURCE_PATH;PROJECT_SUBPATH;INCLUDES_SUBPATH;LICENSE_SUBPATH;RELEASE_CONFIGURATION;DEBUG_CONFIGURATION"
        "OPTIONS;OPTIONS_RELEASE;OPTIONS_DEBUG"
    )

    if(DEFINED arg_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "vcpkg_msbuild_install was passed extra arguments: ${arg_UNPARSED_ARGUMENTS}")
    endif()

    if(NOT DEFINED arg_RELEASE_CONFIGURATION)
        set(arg_RELEASE_CONFIGURATION Release)
    endif()
    if(NOT DEFINED arg_DEBUG_CONFIGURATION)
        set(arg_DEBUG_CONFIGURATION Debug)
    endif()

    set(options "")

    if(arg_USE_VCPKG_INTEGRATION)
        list(APPEND options "USE_VCPKG_INTEGRATION")
    endif()

    vcpkg_cmake_get_vars(cmake_vars_path)
    include("${cmake_vars_path}")

    set(ENV{CXX} "${VCPKG_DETECTED_CMAKE_CXX_COMPILER}")
    set(ENV{CC} "${VCPKG_DETECTED_CMAKE_C_COMPILER}")
    set(ENV{LD} "${VCPKG_DETECTED_CMAKE_LINKER}")
    set(ENV{AR} "${VCPKG_DETECTED_CMAKE_AR}")

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
        file(REMOVE_RECURSE "${work}")
        file(MAKE_DIRECTORY "${work}")
        file(GLOB sources "${SOURCE_PATH}/*")
        file(COPY ${sources} DESTINATION "${work}")

        set(ENV{ARFLAGS} "${VCPKG_COMBINED_STATIC_LINKER_FLAGS_${flavor}}")
        set(ENV{CXXFLAGS} "${VCPKG_COMBINED_CXX_FLAGS_${flavor}}")
        set(ENV{LDFLAGS} "${VCPKG_COMBINED_SHARED_LINKER_FLAGS_${flavor}}")
        set(ENV{CFLAGS} "${VCPKG_COMBINED_C_FLAGS_${flavor}}")
        message(STATUS "Building ${arg_PROJECT_SUBPATH} for ${arg_${flavor}_CONFIGURATION}")
        vcpkg_msbuild_execute(
            PROJECT_PATH "${work}/${arg_PROJECT_SUBPATH}"
            ${flavor}
            CONFIGURATION "${arg_${flavor}_CONFIGURATION}"
            ${options}
            OPTIONS
                "/p:SolutionDir=${work}/"
                ${arg_OPTIONS}
                ${arg_OPTIONS_${flavor}}
            LOGNAME "build-${suffix}"
        )
        file(GLOB_RECURSE libs "${work}/*.lib")
        file(GLOB_RECURSE dlls "${work}/*.dll")
        if(NOT libs STREQUAL "")
            file(COPY ${libs} DESTINATION "${dst}/lib")
        endif()
        if(NOT dlls STREQUAL "")
            file(COPY ${dlls} DESTINATION "${dst}/bin")
        endif()
    endforeach()

    file(GLOB_RECURSE exes "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/*.exe")
    if(NOT exes STREQUAL "")
        file(COPY ${exes} DESTINATION "${CURRENT_PACKAGES_DIR}/tools/${PORT}")
        vcpkg_copy_tool_dependencies("${CURRENT_PACKAGES_DIR}/tools/${PORT}")
    endif()

    vcpkg_copy_pdbs()

    if(DEFINED arg_INCLUDES_SUBPATH)
        file(COPY "${arg_SOURCE_PATH}/${arg_INCLUDES_SUBPATH}/"
            DESTINATION "${CURRENT_PACKAGES_DIR}/include/"
        )
        file(GLOB root_includes
            LIST_DIRECTORIES false
            "${CURRENT_PACKAGES_DIR}/include/*")
        if(NOT root_includes STREQUAL "")
            if(arg_REMOVE_ROOT_INCLUDES)
                file(REMOVE ${root_includes})
            elseif(arg_ALLOW_ROOT_INCLUDES)
            else()
                message(FATAL_ERROR "Top-level files were found in ${CURRENT_PACKAGES_DIR}/include; this may indicate a problem with the call to `vcpkg_install_msbuild()`.\nTo avoid conflicts with other libraries, it is recommended to not put includes into the root `include/` directory.\nPass either ALLOW_ROOT_INCLUDES or REMOVE_ROOT_INCLUDES to handle these files.\n")
            endif()
        endif()
    endif()

    if(DEFINED arg_LICENSE_SUBPATH)
        file(INSTALL "${arg_SOURCE_PATH}/${arg_LICENSE_SUBPATH}"
            DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
            RENAME copyright
        )
    endif()
endfunction()
