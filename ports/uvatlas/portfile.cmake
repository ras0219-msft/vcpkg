vcpkg_check_linkage(ONLY_STATIC_LIBRARY ONLY_DYNAMIC_CRT)

if(NOT VCPKG_TARGET_IS_WINDOWS)
    message(FATAL_ERROR "UVAtlas only supports Windows Desktop")
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO Microsoft/UVAtlas
    REF 60e2f2d5175f3a9fa6987516c4b44a4f0de3e1fa # aug2020
    SHA512 6ff99148d8d26345d3e935840d43536558a8174346492d794a4583f50b89a0648bfba3c5a9a433d803fcfd6092716b2f482ff5d1bad896fc4933971dc8107d6d
    HEAD_REF master
)

IF(TRIPLET_SYSTEM_ARCH MATCHES "x86")
	SET(BUILD_ARCH "Win32")
ELSE()
	SET(BUILD_ARCH ${TRIPLET_SYSTEM_ARCH})
ENDIF()

vcpkg_build_msbuild(
    PROJECT_PATH ${SOURCE_PATH}/UVAtlas/UVAtlas_2015.sln
	PLATFORM ${BUILD_ARCH}
)

file(INSTALL
	${SOURCE_PATH}/UVAtlas/Inc/
    DESTINATION ${CURRENT_PACKAGES_DIR}/include)
file(INSTALL
	${SOURCE_PATH}/UVAtlas/Bin/Desktop_2015/${BUILD_ARCH}/Release/UVAtlas.lib
	DESTINATION ${CURRENT_PACKAGES_DIR}/lib)
file(INSTALL
	${SOURCE_PATH}/UVAtlas/Bin/Desktop_2015/${BUILD_ARCH}/Debug/UVAtlas.lib
	DESTINATION ${CURRENT_PACKAGES_DIR}/debug/lib)

vcpkg_download_distfile(uvatlastool
    URLS "https://github.com/Microsoft/UVAtlas/releases/download/sept2016/uvatlastool.exe"
    FILENAME "uvatlastool.exe"
    SHA512 2583ba8179d0a58fb85d871368b17571e36242436b5a5dbaf6f99ec2f2ee09f4e11e8f922b29563da3cb3b5bacdb771036c84d5b94f405c7988bfe5f2881c3df
)

file(MAKE_DIRECTORY "${CURRENT_PACKAGES_DIR}/tools/uvatlas/")

file(INSTALL
	${DOWNLOADS}/uvatlastool.exe
	DESTINATION ${CURRENT_PACKAGES_DIR}/tools/uvatlas/)

	# Handle copyright
file(INSTALL ${SOURCE_PATH}/LICENSE DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT} RENAME copyright)
