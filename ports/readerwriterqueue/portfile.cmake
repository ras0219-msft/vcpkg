# header-only library
include(vcpkg_common_functions)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO cameron314/readerwriterqueue
    REF 435e36540e306cac40fcfeab8cc0a22d48464509 # v1.0.3
    SHA512 2946c0574ff2fa3eb2e09ab2729935bdd2d737a85ae66d669e80b48ac32ed9160b5d31e9b7e15fe21b2d33e42c052d81e1c92f5465af8a0e450027eb0f4af943
    HEAD_REF master
)

file(INSTALL ${SOURCE_PATH}/LICENSE.md DESTINATION ${CURRENT_PACKAGES_DIR}/share/readerwriterqueue RENAME copyright)

file(GLOB HEADER_FILES ${SOURCE_PATH}/*.h)
file(COPY ${HEADER_FILES} DESTINATION ${CURRENT_PACKAGES_DIR}/include/readerwriterqueue)
