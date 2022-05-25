function(vcpkg_msbuild_execute)
    cmake_parse_arguments(
        PARSE_ARGV 0
        arg
        "USE_VCPKG_INTEGRATION;RELEASE;DEBUG"
        "PROJECT_PATH;CONFIGURATION;LOGNAME"
        "OPTIONS"
    )

    if(DEFINED arg_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "vcpkg_msbuild_execute was passed extra arguments: ${arg_UNPARSED_ARGUMENTS}")
    endif()

    if(NOT DEFINED arg_LOGNAME)
        message(FATAL_ERROR "vcpkg_msbuild_execute requires LOGNAME to be specified")
    endif()

    if(NOT DEFINED arg_PROJECT_PATH)
        message(FATAL_ERROR "vcpkg_msbuild_execute requires PROJECT_PATH to be specified")
    endif()

    if((NOT DEFINED arg_RELEASE AND NOT DEFINED arg_DEBUG) OR (arg_RELEASE AND arg_DEBUG))
        message(FATAL_ERROR "vcpkg_msbuild_execute requires either RELEASE or DEBUG to be passed")
    endif()

    if(NOT DEFINED arg_CONFIGURATION)
        if(DEFINED arg_RELEASE)
            set(arg_CONFIGURATION Release)
        else()
            set(arg_CONFIGURATION Debug)
        endif()
    endif()
    if(NOT DEFINED arg_PLATFORM)
        if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
            set(arg_PLATFORM x64)
        elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x86")
            set(arg_PLATFORM Win32)
        elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm")
            set(arg_PLATFORM ARM)
        elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
            set(arg_PLATFORM arm64)
        else()
            message(FATAL_ERROR "Unsupported target architecture")
        endif()
    endif()

    list(APPEND arg_OPTIONS
        "/p:Platform=${arg_PLATFORM}"
        "/p:VCPkgLocalAppDataDisabled=true"
        "/p:UseIntelMKL=No"
        "/p:VcpkgTriplet=${TARGET_TRIPLET}"
        "/p:VcpkgInstalledDir=${_VCPKG_INSTALLED_DIR}"
        "/p:VcpkgManifestInstall=false"
        "/m:${VCPKG_CONCURRENCY}"
        "/p:VCTargetsPath=${Z_VCPKG_MSBUILD_DIR}/vctargets"
        "-lowPriority"
        "-nr:false"
        "-v:diag"
        "-noAutoRsp"
    )

    if(arg_USE_VCPKG_INTEGRATION)
        list(APPEND arg_OPTIONS
            "/p:ForceImportBeforeCppTargets=${SCRIPTS}/buildsystems/msbuild/vcpkg.targets"
            "/p:VcpkgApplocalDeps=false"
        )
    endif()

    get_filename_component(dir "${arg_PROJECT_PATH}" DIRECTORY)
    vcpkg_execute_required_process(
        COMMAND "${CURRENT_HOST_INSTALLED_DIR}/tools/vcpkg-msbuild/tnet-sdk-6-1901befa7f/dotnet.exe" msbuild "${arg_PROJECT_PATH}"
            "/p:Configuration=${arg_CONFIGURATION}"
            ${arg_OPTIONS}
        WORKING_DIRECTORY "${dir}"
        LOGNAME "${arg_LOGNAME}"
    )
endfunction()
