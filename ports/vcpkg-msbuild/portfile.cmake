if(NOT TARGET_TRIPLET STREQUAL _HOST_TRIPLET)
    # make FATAL_ERROR in CI when issue #16773 fixed
    message(WARNING "vcpkg-cmake is a host-only port; please mark it as a host port in your dependencies.")
endif()

vcpkg_download_distfile(
    dotnetsdk
    URLS "https://download.visualstudio.microsoft.com/download/pr/b1461027-6daa-467d-aebe-6326343e5840/01656d95b28f16c53cd947a8072d004b/dotnet-sdk-6.0.202-win-x64.zip"
    SHA512 fc3299972e50a26ec7d2485b25afac7a5c345076eef35ff1e8de02fac01915f4e33deaf3c94b92d4ab6a446326339fd121b6f45f796e899d980c0ee27f4e2ffc
    FILENAME dotnet-sdk-6.0.202-win-x64.zip
)

set(VCPKG_POLICY_EMPTY_PACKAGE enabled)

vcpkg_extract_source_archive(
    source_path
    ARCHIVE "${dotnetsdk}"
    WORKING_DIRECTORY "${CURRENT_PACKAGES_DIR}/tools/vcpkg-msbuild"
    NO_REMOVE_ONE_LEVEL
)
