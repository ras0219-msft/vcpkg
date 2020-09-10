# Schema
#
# An entry can be a simple string. In this case, it is considered an active, tag-based library with no other special handling.
#
# Otherwise, an entry should be an object with the following fields:
#
#   port - Required. The name of the port.
#   regex - Optional. Used to filter the tags from the repo.
#   skipRelease - Optional. If the computed new tag is equal to this string, don't upgrade. Used to handle cases where we've pinned a newer version than the latest release.
#   replaceFrom/replaceTo - Optional. Together form a regex replacement pair that is applied to the tag to determine the string to put into the CONTROL's version field.
#   failingFrom - Optional. Indicates the port currently fails automatic upgrade. Should be set to the _current_ CONTROL version string. Will only disable upgrades if matches current string.
#   rolling - Optional. Indicates the port should be treated as a rolling release. Must be set to a "true-ish" value.
#   disabled - Optional. Indicates the port should not be automatically upgraded. Must be set to a "true-ish" value, such as a comment about why updating is disabled.

$allPorts = $(
    $tagPorts = @(
        ([PSCustomObject]@{ "port"="assimp"; "regex"="^[v0-9\.]+`$" }),
        "aws-sdk-cpp",
        "azure-storage-cpp",
        "benchmark",
        [PSCustomObject]@{ "port"="binn"; "regex"="[2-9]\." },
        "brynet",
        ([PSCustomObject]@{ "port"="c-ares"; "skipRelease"="cares-1_15_0" }),
        "caf",
        "cartographer",
        ([PSCustomObject]@{ "port"="catch2"; "regex"="^v[2-9]\.[\d\.]+`$" }),
        "cctz",
        ([PSCustomObject]@{ "port"="celero"; "skipRelease"="v2.4.0" }),
        ([PSCustomObject]@{ "port"="cgal"; "regex"="releases/CGAL-5\."; "replaceFrom"="releases/CGAL-"; "replaceTo"=""; "failingFrom"="4.14-3" }),
        "chakracore",
        [PSCustomObject]@{ "port"="cimg"; "failingFrom"="2.6.2" },
        "coroutine",
        "cppzmq",
        [PSCustomObject]@{ "port"="cpp-redis"; "regex"="^[\d\.]+`$" },
        [PSCustomObject]@{ "port"="curl"; "failingFrom"="7.61.1-7"; "replaceFrom"="_"; "replaceTo"="." },
        [PSCustomObject]@{ "port"="date"; "skipRelease"="v2.4.1" },
        "dimcli",
        "directxmesh",
        ([PSCustomObject]@{ "port"="directxtex"; "regex"="^[^\d]+\d+[^\d]?$" }),
        ([PSCustomObject]@{ "port"="directxtk"; "regex"="^[^\d]+\d+[^\d]?$" }),
        "discord-rpc",
        "doctest",
        "eastl",
        "eigen3",
        "ensmallen",
        ([PSCustomObject]@{ "port"="entt"; "regex"="^v[\d\.]+`$"; "glob"="v*" }),
        [PSCustomObject]@{ "port"="expat"; "replaceFrom"="R?_(\d)_(\d)_(\d)"; "replaceTo"="`$1.`$2.`$3"; "failingFrom"="2.2.7" },
        "fizz",
        "fmi4cpp",
        "fmt",
        [PSCustomObject]@{ "port"="folly"; "failingFrom"="2019.10.28.00" },
        "forest",
        "gflags",
        [PSCustomObject]@{ "port"="glbinding"; "failingFrom"="3.0.2-5" },
        ([PSCustomObject]@{ "port"="glm"; "regex"="^[\d\.]+`$" }),
        "glog",
        "google-cloud-cpp",
        ([PSCustomObject]@{ "port"="grpc"; "regex"="^v[\d\.]+`$"; "failingFrom"="1.23.1-1" }),
        "harfbuzz",
        "imgui",
        ([PSCustomObject]@{ "port"="jsoncpp"; "regex"="^[1-9]\." }),
        "openal-soft",
        ([PSCustomObject]@{ "port"="libevent"; "regex"="^release-[\d\.]+-stable" }),
        ([PSCustomObject]@{ "port"="libffi"; "regex"="^v[\d\.]+`$"; "failingFrom"="3.1-6" }),
        [PSCustomObject]@{ "port"="libjpeg-turbo"; "failingFrom"="2.0.1-1" },
        "liblinear",
        [PSCustomObject]@{ "port"="libogg"; "skipRelease"="v1.3.4" },
        ([PSCustomObject]@{ "port"="libpng"; "regex"="v[\d\.]+`$" }),
        [PSCustomObject]@{ "port"="librabbitmq"; "replaceFrom"="-master"; "replaceTo"=""; "skipRelease"="v0.9.0-master" },
        "libsodium",
        "libuv",
        "libwebsockets",
        [PSCustomObject]@{ "port"="libzip"; "replaceFrom"="rel-(\d)-(\d)-(\d)"; "replaceTo"="`$1.`$2.`$3" },
        "lz4",
        "matio",
        ([PSCustomObject]@{ "port"="mbedtls"; "regex"="^mbedtls-2\.19\."; "failingFrom"="2.16.3" }),
        "mhook",
        "mlpack",
        "mpark-variant",
        "nana",
        "openblas",
        ([PSCustomObject]@{ "port"="openimageio"; "regex"="^Release-[\d\.]+`$"; "disabled"="Update to 2.0.8 fails" }),
        "openjpeg",
        [PSCustomObject]@{ "port"="pegtl"; "skipRelease"="2.8.1" },
        "plog",
        [PSCustomObject]@{ "port"="poco"; "replaceFrom"="-release"; "replaceTo"="" },
        ([PSCustomObject]@{ "port"="protobuf"; "regex"="^v[\d\.]+`$" }),
        [PSCustomObject]@{ "port"="rapidjson"; "rolling"="$True" },
        "reproc",
        [PSCustomObject]@{ "port"="rocksdb"; "failingFrom"="6.1.2-1" },
        "rpclib",
        "sdl2",
        "sdl2pp",
        "sfml",
        "snappy",
        [PSCustomObject]@{ "port"="soci"; "skipRelease"="3.2.3" },
        [PSCustomObject]@{ "port"="spdlog"; "failingFrom"="1.4.2" },
        "sqlite-orm",
        [PSCustomObject]@{ "port"="stlab"; "failingFrom"="1.4.1-1" },
        ([PSCustomObject]@{ "port"="tbb"; "regex"="^[\d]+_" }),
        "trompeloeil",
        "uriparser",
        "uvatlas",
        ([PSCustomObject]@{ "port"="uwebsockets"; "regex"="^v[\d\.]+`$" }),
        "wangle",
        ([PSCustomObject]@{ "port"="wt"; "regex"="^[\d\.]+`$" }),
        ([PSCustomObject]@{ "port"="wxwidgets"; "regex"="v3.1" }),
        "xeus",
        "xsimd",
        "xtensor-blas",
        "xtensor",
        "xtl",
        [PSCustomObject]@{ "port"="yaml-cpp"; "failingFrom"="0.6.2-3" },
        "yoga",
        "zziplib",

        "3fd",
        "ade",
        "aixlog",
        "alembic",
        "aliyun-oss-c-sdk",
        ([PSCustomObject]@{ "port"="allegro5"; "regex"="^5" }),
        "amqpcpp",
        "anax",
        [PSCustomObject]@{ "port"="arb"; "failingFrom"="2.16.0" },
        [PSCustomObject]@{ "port"="arrow"; "replaceFrom"="apache-arrow-"; "replaceTo"="" },
        ([PSCustomObject]@{ "port"="asio"; "replaceFrom"="-"; "replaceTo"="."; "failingFrom"="1.14.0" }),
        "asyncplusplus",
        "aubio",
        "autobahn",
        [PSCustomObject]@{ "port"="avro-c"; "failingFrom"="1.8.2-3"; "regex"="^[\d\.]+`$" },
        [PSCustomObject]@{ "port"="aws-c-common"; "failingFrom"="0.4.1" },
        "aws-c-event-stream",
        "aws-checksums",
        [PSCustomObject]@{ "port"="aws-lambda-cpp"; "failingFrom"="0.1.0-1" },
        "azmq",
        "bitsery",
        "blosc",
        "boost-histogram",
        "boost-outcome",
        [PSCustomObject]@{ "port"="botan"; "failingFrom"="2.11.0" },
        "brotli",
        "brunocodutra-metal",
        "bullet3",
        ([PSCustomObject]@{ "port"="caffe2"; "disabled"="Replaced by pytorch -- TODO fix" }),
        "capnproto",
        "ccd",
        "cereal",
        "ceres",
        "chaiscript",
        "check",
        [PSCustomObject]@{ "port"="chipmunk"; "replaceFrom"="Chipmunk-"; "replaceTo"="" },
        [PSCustomObject]@{ "port"="civetweb"; "skipRelease"="v1.11" },
        "clblas",
        "clblast",
        "clfft",
        "cli",
        "cli11",
        [PSCustomObject]@{ "port"="clockutils"; "skipRelease"="1.1.1" },
        [PSCustomObject]@{ "port"="clp"; "replaceFrom"="releases/"; "replaceTo"="" },
        "cmark",
        [PSCustomObject]@{ "port"="coinutils"; "replaceFrom"="releases/"; "replaceTo"="" },
        [PSCustomObject]@{ "port"="collada-dom"; "skipRelease"="v2.5.0" },
        [PSCustomObject]@{ "port"="concurrentqueue"; "skipRelease"="v1.0.0-beta" },
        [PSCustomObject]@{ "port"="console-bridge"; "failingFrom"="0.3.2-3" },
        "constexpr",
        [PSCustomObject]@{ "port"="coolprop"; "failingFrom"="6.1.0-4" },
        "corrade",
        "cppcms",
        "cppfs",
        "cppgraphqlgen",
        "cpp-netlib",
        "cpprestsdk",
        [PSCustomObject]@{ "port"="cpptoml"; "skipRelease"="v0.1.1" },
        [PSCustomObject]@{ "port"="cppwinrt"; "failingFrom"="fall_2017_creators_update_for_vs_15.3-2" },
        "cpr",
        "crc32c",
        [PSCustomObject]@{ "port"="crossguid"; "skipRelease"="v0.2.2" },
        "crow",
        [PSCustomObject]@{ "port"="cryptopp"; "disabled"="multiple-repo versioning" },
        "ctre",
        "cub",
        "cutelyst2",
        "cxxopts",
        [PSCustomObject]@{ "port"="darknet"; "disabled"="Unknown versioning scheme" },
        "darts-clone",
        [PSCustomObject]@{ "port"="dcmtk"; "skipRelease"="DCMTK-3.6.4" },
        "decimal-for-cpp",
        "detours",
        "devil",
        "dirent",
        [PSCustomObject]@{ "port"="dlib"; "disabled"="Requires manual handling for update" },
        "double-conversion",
        [PSCustomObject]@{ "port"="draco"; "failingFrom"="1.3.3-2" },
        "dtl",
        "duilib",
        "duktape",
        "dx",
        "easyloggingpp",
        "ebml",
        [PSCustomObject]@{ "port"="ecm"; "regex"="v\d.\d+.\d+`$" },
        "ecsutil",
        "effolkronium-random",
        [PSCustomObject]@{ "port"="embree2"; "regex"="^v2[\.\d]+`$" },
        [PSCustomObject]@{ "port"="embree3"; "regex"="^v3[\.\d]+`$" },
        "enet",
        "entityx",
        [PSCustomObject]@{ "port"="evpp"; "disabled"="Requires manual handling for update" },
        "fann",
        [PSCustomObject]@{ "port"="fastcdr"; "failingFrom"="1.0.6-2" },
        "fastlz",
        [PSCustomObject]@{ "port"="fastrtps"; "failingFrom"="1.5.0-2" },
        [PSCustomObject]@{ "port"="fcl"; "skipRelease"="0.5.0"; "regex"="0\.[5-9]\.\d$" },
        [PSCustomObject]@{ "port"="flann"; "rolling"=$True },
        [PSCustomObject]@{ "port"="flatbuffers"; "skipRelease"="1.11.0" },
        [PSCustomObject]@{ "port"="fluidsynth"; "regex"="v[\d\.]+$" },
        "fmem",
        [PSCustomObject]@{ "port"="forge"; "skipRelease"="v1.0.4" },
        "freerdp",
        "fruit",
        "ftgl",
        "fuzzylite",
        "g2o",
        [PSCustomObject]@{ "port"="gamma"; "skipRelease"="0.9.8" },
        "gcem",
        "gdcm",
        "getopt-win32",
        [PSCustomObject]@{ "port"="gherkin-c"; "skipRelease"="4.1.2"; "disabled"="Upstream (https://github.com/cucumber/gherkin-c) seems active; we need to migrate" },
        "glad",
        "glfw3",
        [PSCustomObject]@{ "port"="globjects"; "skipRelease"="v1.1.0" },
        [PSCustomObject]@{ "port"="gmmlib"; "replaceFrom"="intel-gmmlib-"; "replaceTo"="" },
        [PSCustomObject]@{ "port"="graphite2"; "failingFrom"="1.3.12" },
        [PSCustomObject]@{ "port"="graphqlparser"; "skipRelease"="0.7.0" },
        "gts",
        "gumbo",
        "highfive",
        [PSCustomObject]@{ "port"="hpx"; "regex"="^[.\d]+`$" },
        "http-parser",
        "hunspell",
        [PSCustomObject]@{ "port"="hwloc"; "failingFrom"="1.11.7-3" },
        "ideviceinstaller",
        "idevicerestore",
        "if97",
        "igloo",
        [PSCustomObject]@{ "port"="inih"; "replaceFrom"="r"; "replaceTo"="" },
        "inja",
        [PSCustomObject]@{ "port"="ismrmrd"; "failingFrom"="1.3.2-4" },
        [PSCustomObject]@{ "port"="itk"; "regex"="^[v.\d]+`$"; "failingFrom"="4.13.0-906736bd-3" },
        "jack2",
        "jansson",
        [PSCustomObject]@{ "port"="jasper"; "replaceFrom"="version-"; "replaceTo"="" },
        "jbig2dec",
        "jemalloc",
        "jsoncons",
        [PSCustomObject]@{ "port"="json-spirit"; "disabled"="No updates since 2015" },
        [PSCustomObject]@{ "port"="jsonnet"; "failingFrom"="0.13.0" },
        "jxrlib",
        "kangaru",
        [PSCustomObject]@{ "port"="kd-soap"; "failingFrom"="1.7.0" },
        "keystone",
        [PSCustomObject]@{ "port"="kf5archive"; "regex"="^[v.\d]+`$"},
        [PSCustomObject]@{ "port"="kf5holidays"; "regex"="^[v.\d]+`$"},
        [PSCustomObject]@{ "port"="kf5plotting"; "regex"="^[v.\d]+`$"},
        "laszip",
        "lcm",
        [PSCustomObject]@{ "port"="lcms"; "replaceFrom"="lcms"; "replaceTo"="" },
        [PSCustomObject]@{ "port"="leptonica"; "failingFrom"="1.76.0" },
        "lest",
        "libarchive",
        [PSCustomObject]@{ "port"="libass"; "skipRelease"="0.14.0" },
        "libbf",
        [PSCustomObject]@{ "port"="libbson"; "replaceFrom"="debian/"; "replaceTo"="" },
        "libcds",
        "libconfig",
        "libcopp",
        "libepoxy",
        [PSCustomObject]@{ "port"="libflac"; "failingFrom"="1.3.2-6" },
        "libfreenect2",
        "libgd",
        [PSCustomObject]@{ "port"="libgit2"; "regex"="^v0\.(28|29|[3-9])" },
        [PSCustomObject]@{ "port"="libgo"; "replaceFrom"="-stable"; "replaceTo"=""; "failingFrom"="2.8-2" },
        [PSCustomObject]@{ "port"="libics"; "skipRelease"="1.6.2" },
        "libideviceactivation",
        "libimobiledevice",
        "libirecovery",
        "libkml",
        "liblo",
        [PSCustomObject]@{ "port"="liblsl"; "disabled"="Requires manual editing after update" },
        "liblzma",
        "libmariadb",
        "libmaxminddb",
        [PSCustomObject]@{ "port"="libmodbus"; "regex"="^v(3\.[1-9]|4)" },
        [PSCustomObject]@{ "port"="libmupdf"; "regex"="^[\d\.]+`$" },
        [PSCustomObject]@{ "port"="libnoise"; "skipRelease"="1.0.0" },
        "libopusenc",
        [PSCustomObject]@{ "port"="libplist"; "failingFrom"="1.2.77" },
        [PSCustomObject]@{ "port"="libpng-apng"; "disabled"="Complex port" },
        "libpqxx",
        [PSCustomObject]@{ "port"="libqglviewer"; "skipRelease"="2.7.0" },
        "libqrencode",
        [PSCustomObject]@{ "port"="libraw"; "skipRelease"="0.19.5" },
        "librsync",
        [PSCustomObject]@{ "port"="libsndfile"; "skipRelease"="1.0.28" },
        "libssh2",
        "libstk",
        [PSCustomObject]@{ "port"="libtheora"; "skipRelease"="v1.2.0alpha1" },
        "libtins",
        [PSCustomObject]@{ "port"="libunibreak"; "replaceFrom"="libunibreak_(\d)_(\d(-\d)?)"; "replaceTo"="`$1.`$2-0" },
        [PSCustomObject]@{ "port"="libusb"; "regex"="^[v.\d]+`$"; "failingFrom"="1.0.22-4" },
        "libusbmuxd",
        [PSCustomObject]@{ "port"="libvorbis"; "skipRelease"="v1.3.6" },
        "libwebm",
        [PSCustomObject]@{ "port"="libwebp"; "failingFrom"="1.0.2-7" },
        "libxml2",
        [PSCustomObject]@{ "port"="libyaml"; "regex"="^\d" },
        "linalg",
        [PSCustomObject]@{ "port"="lmdb"; "replaceFrom"="LMDB_"; "replaceTo"="" },
        [PSCustomObject]@{ "port"="log4cplus"; "replaceFrom"="REL_(\d)_(\d)_"; "replaceTo"="`$1.`$2." },
        "loguru",
        "luabridge",
        [PSCustomObject]@{ "port"="luafilesystem"; "skipRelease"="v1_7_0_2" },
        [PSCustomObject]@{ "port"="luajit"; "regex"="^[v.\d]+`$" },
        "lzfse",
        "magnum",
        "magnum-extras",
        "magnum-integration",
        "magnum-plugins",
        [PSCustomObject]@{ "port"="mapbox-variant"; "skipRelease"="v1.1.6" },
        "matroska",
        "milerius-sfml-imgui",
        "minhook",
        [PSCustomObject]@{ "port"="minisat-master-keying"; "skipRelease"="releases/2.2.0" },
        [PSCustomObject]@{ "port"="miniupnpc"; "regex"="miniupnpc" },
        "miniz",
        "minizip",
        "mman",
        [PSCustomObject]@{ "port"="mongo-c-driver"; "replaceFrom"="debian/"; "replaceTo"="" },
        [PSCustomObject]@{ "port"="mongo-cxx-driver"; "replaceFrom"="debian/"; "replaceTo"=""; "disabled"="Requires manual upgrade" },
        "moos-core",
        [PSCustomObject]@{ "port"="moos-essential"; "skipRelease"="10.0.1-release" },
        "morton-nd",
        "mosquitto",
        [PSCustomObject]@{ "port"="mozjpeg"; "disabled"="Disabled in CI" },
        [PSCustomObject]@{ "port"="mpir"; "disabled"="Requires manual upgrade" },
        [PSCustomObject]@{ "port"="msgpack"; "replaceFrom"="cpp-"; "replaceTo"="" },
        [PSCustomObject]@{ "port"="msix"; "failingFrom"="MsixCoreInstaller-preview-1" },
        "muparser",
        [PSCustomObject]@{ "port"="nanodbc"; "skipRelease"="v2.12.4" },
        "nanomsg",
        [PSCustomObject]@{ "port"="nano-signal-slot"; "rolling"=$true },
        [PSCustomObject]@{ "port"="netcdf-c"; "failingFrom"="4.7.0-4" },
        "netcdf-cxx4",
        "nlopt",
        "nmslib",
        "nvtt",
        "ogre",
        "oniguruma",
        "open62541",
        "opencsg",
        [PSCustomObject]@{ "port"="openexr"; "disabled"="Requires manual update" },
        [PSCustomObject]@{ "port"="openmama"; "replaceFrom"="-release"; "replaceTo"="" },
        "openmvg",
        "openni2",
        [PSCustomObject]@{ "port"="openssl-uwp"; "replaceFrom"="OpenSSL_(.)_(.)_(..)_WinRT"; "replaceTo"="`$1.`$2.`$3" },
        [PSCustomObject]@{ "port"="opentracing"; "skipRelease"="v1.5.1" },
        "openvdb",
        "openvr",
        "opusfile",
        [PSCustomObject]@{ "port"="orc"; "skipRelease"="rel/release-1.5.5"; "replaceFrom"="rel/release-"; "replaceTo"="" },
        [PSCustomObject]@{ "port"="orocos-kdl"; "skipRelease"="1.3.2" },
        [PSCustomObject]@{ "port"="osg"; "regex"="OpenSceneGraph-[v\.\d]+`$" },
        [PSCustomObject]@{ "port"="osgearth"; "regex"="osgearth-\d" },
        "osg-qt",
        [PSCustomObject]@{ "port"="osi"; "replaceFrom"="releases/"; "replaceTo"="" },
        [PSCustomObject]@{ "port"="paho-mqtt"; "failingFrom"="1.2.1" },
        "pangolin",
        "parallel-hashmap",
        "pcg",
        "pcl",
        "pdal-c",
        "pdcurses",
        "pegtl-2",
        [PSCustomObject]@{ "port"="physx"; "disabled"="Unknown release scheme" },
        "pixel",
        [PSCustomObject]@{ "port"="platform-folders"; "regex"="^[456789]" },
        "plibsys",
        [PSCustomObject]@{ "port"="plustache"; "skipRelease"="0.4.0" },
        "pngwriter",
        "ponder",
        "prometheus-cpp",
        "ptex",
        "pugixml",
        "pybind11",
        "pystring",
        [PSCustomObject]@{ "port"="python3"; "disabled"="Complex release scheme" },
        "qca",
        "qhull",
        "qpid-proton",
        [PSCustomObject]@{ "port"="qt5-mqtt"; "regex"="^[v\.\d]+`$"; "skipRelease"="v5.12.3"; "disabled"="Portfile uses variables for versions" },
        "quirc",
        "rang",
        "range-v3",
        [PSCustomObject]@{ "port"="range-v3-vs2015"; "disabled"="Unknown release scheme" },
        "rapidxml-ns",
        "readerwriterqueue",
        "recast",
        [PSCustomObject]@{ "port"="restbed"; "skipRelease"="4.6" },
        "rhash",
        "robin-map",
        "rtmidi",
        "rttr",
        "rxcpp",
        "safeint",
        [PSCustomObject]@{ "port"="sdl1"; "disabled"="No longer receiving updates" },
        "selene",
        "sf2cute",
        "sfgui",
        "shiva",
        "shiva-sfml",
        [PSCustomObject]@{ "port"="shogun"; "replaceFrom"="shogun_"; "replaceTo"="" },
        "signalrclient",
        [PSCustomObject]@{ "port"="sndfile"; "skipRelease"="1.0.28" },
        "snowhouse",
        "socket-io-client",
        [PSCustomObject]@{ "port"="sol2"; "regex"="^[v\.\d]+`$" },
        "sophus",
        "sparsepp",
        "spectra",
        "speex",
        "spirit-po",
        "sqlitecpp",
        [PSCustomObject]@{ "port"="sqlite-modern-cpp"; "skipRelease"="v3.2" },
        "sqlpp11",
        "sqlpp11-connector-mysql",
        "sqlpp11-connector-sqlite3",
        [PSCustomObject]@{ "port"="strict-variant"; "skipRelease"="0.5" },
        "string-theory",
        "tacopie",
        [PSCustomObject]@{ "port"="taglib"; "regex"="v[\.\d]+`$"; "skipRelease"="v1.11.1" },
        "telnetpp",
        [PSCustomObject]@{ "port"="tesseract"; "regex"="^[v\.\d]+`$" },
        "tgui",
        "theia",
        "thor",
        "tidy-html5",
        "tinydir",
        [PSCustomObject]@{ "port"="tinyexif"; "skipRelease"="1.0.2" },
        [PSCustomObject]@{ "port"="tinyexr"; "skipRelease"="v0.9.5" },
        "tinygltf",
        [PSCustomObject]@{ "port"="tinyobjloader"; "regex"="^v\d+(\.\d+)+`$"; "failingFrom"="1.4.1-1" },
        [PSCustomObject]@{ "port"="tinyspline"; "regex"="[\d\.]" },
        [PSCustomObject]@{ "port"="tinyutf8"; "failingFrom"="3.0.1" },
        "tinyxml2",
        "tl-expected",
        "tl-optional",
        "tmx",
        "tmxparser",
        "treehopper",
        "tsl-hopscotch-map",
        "tsl-ordered-map",
        "tsl-sparse-map",
        [PSCustomObject]@{ "port"="units"; "regex"="^[v\.\d]+`$"; "failingFrom"="2.3.0" },
        "unittest-cpp",
        "urdfdom",
        "urdfdom-headers",
        "usbmuxd",
        "usd",
        "usockets",
        "utf8proc",
        "utfcpp",
        "utfz",
        [PSCustomObject]@{ "port"="uvw"; "replaceFrom"="_libuv.*"; "replaceTo"="" },
        "vcglib",
        "visit-struct",
        "vlpp",
        [PSCustomObject]@{ "port"="vtk"; "disabled"="Requires manual updating" },
        "vtk-dicom",
        "vulkan-memory-allocator",
        [PSCustomObject]@{ "port"="vxl"; "failingFrom"="v1.18.0-3" },
        [PSCustomObject]@{ "port"="wavpack"; "skipRelease"="5.1.0" },
        [PSCustomObject]@{ "port"="websocketpp"; "disabled"="No longer receiving updates" },
        "wildmidi",
        "woff2",
        "x264",
        "xerces-c",
        "xlnt",
        [PSCustomObject]@{ "port"="xmsh"; "failingFrom"="0.4.1" },
        [PSCustomObject]@{ "port"="xxhash"; "failingFrom"="0.7.0" },
        "yajl",
        [PSCustomObject]@{ "port"="z3"; "regex"="z3-"; "failingFrom"="4.8.5-1" },
        "z85",
        [PSCustomObject]@{ "port"="zeromq"; "skipRelease"="v4.3.2-win" },
        "zstd"
    )

    $rollingPorts = @(
        "abseil",
        "alac",
        "angle",
        "args",
        "asmjit",
        "aurora",
        "breakpad",
        "butteraugli",
        "ctemplate",
        "freetype-gl",
        "guetzli",
        "io2d",
        "libharu",
        "libudis86",
        "luasocket",
        "ms-gsl",
        "msinttypes",
        "nuklear",
        "parson",
        "picosha2",
        "piex",
        "re2",
        "rs-core-lib",
        "stb",
        "strtk",
        "exprtk",
        "taocpp-json",
        "thrift",
        "tiny-dnn",
        "torch-th",
        "unicorn-lib",
        "unicorn"
    )

    $disabledPorts = @(
        "azure-iot-sdk-c", # Difficult to automatically update due to multiple source versions
        "azure-c-shared-utility", # Difficult to automatically update due to multiple source versions
        "azure-uamqp-c", # Difficult to automatically update due to multiple source versions
        "azure-uhttp-c", # Difficult to automatically update due to multiple source versions
        "azure-umqtt-c", # Difficult to automatically update due to multiple source versions
        "boost-accumulators",
        "boost-algorithm",
        "boost-align",
        "boost-any",
        "boost-array",
        "boost-asio",
        "boost-assert",
        "boost-assign",
        "boost-atomic",
        "boost-beast",
        "boost-bimap",
        "boost-bind",
        "boost-build",
        "boost-callable-traits",
        "boost-chrono",
        "boost-circular-buffer",
        "boost-compatibility",
        "boost-compute",
        "boost-concept-check",
        "boost-config",
        "boost-container",
        "boost-container-hash",
        "boost-context",
        "boost-contract",
        "boost-conversion",
        "boost-convert",
        "boost-core",
        "boost-coroutine",
        "boost-coroutine2",
        "boost-crc",
        "boost-date-time",
        "boost-detail",
        "boost-disjoint-sets",
        "boost-dll",
        "boost-dynamic-bitset",
        "boost-endian",
        "boost-exception",
        "boost-fiber",
        "boost-filesystem",
        "boost-flyweight",
        "boost-foreach",
        "boost-format",
        "boost-function",
        "boost-functional",
        "boost-function-types",
        "boost-fusion",
        "boost-geometry",
        "boost-gil",
        "boost-graph",
        "boost-graph-parallel",
        "boost-hana",
        "boost-heap",
        "boost-hof",
        "boost-icl",
        "boost-integer",
        "boost-interprocess",
        "boost-interval",
        "boost-intrusive",
        "boost-io",
        "boost-iostreams",
        "boost-iterator",
        "boost-lambda",
        "boost-lexical-cast",
        "boost-locale",
        "boost-local-function",
        "boost-lockfree",
        "boost-log",
        "boost-logic",
        "boost-math",
        "boost-metaparse",
        "boost-move",
        "boost-mp11",
        "boost-mpi",
        "boost-mpl",
        "boost-msm",
        "boost-multi-array",
        "boost-multi-index",
        "boost-multiprecision",
        "boost-numeric-conversion",
        "boost-odeint",
        "boost-optional",
        "boost-parameter",
        "boost-parameter-python",
        "boost-phoenix",
        "boost-poly-collection",
        "boost-polygon",
        "boost-pool",
        "boost-predef",
        "boost-preprocessor",
        "boost-process",
        "boost-program-options",
        "boost-property-map",
        "boost-property-tree",
        "boost-proto",
        "boost-ptr-container",
        "boost-python",
        "boost-qvm",
        "boost-random",
        "boost-range",
        "boost-ratio",
        "boost-rational",
        "boost-regex",
        "boost-safe-numerics",
        "boost-scope-exit",
        "boost-serialization",
        "boost-signals",
        "boost-signals2",
        "boost-smart-ptr",
        "boost-sort",
        "boost-spirit",
        "boost-stacktrace",
        "boost-statechart",
        "boost-static-assert",
        "boost-system",
        "boost-test",
        "boost-thread",
        "boost-throw-exception",
        "boost-timer",
        "boost-tokenizer",
        "boost-tti",
        "boost-tuple",
        "boost-type-erasure",
        "boost-type-index",
        "boost-typeof",
        "boost-type-traits",
        "boost-ublas",
        "boost-units",
        "boost-unordered",
        "boost-utility",
        "boost-uuid",
        "boost-variant",
        "boost-vmd",
        "boost-wave",
        "boost-winapi",
        "boost-xpressive",
        "boost-yap",
        "box2d", # No longer in active development (2019-10-01)
        "capstone",
        "clara", # No longer maintained. Superceded by https://github.com/bfgroup/Lyra
        "exiv2", # Upgrade to 2b7e4c046af6610f97ed06f71b892e38efa5a358 fails (2019-01-09)
        "fdk-aac", # Upgrade to 2326faaf8f2cdf2c3a9108ccdaf1d7551aec543e fails (2019-01-09)
        "glslang",
        "gtest", # Upgrade to 1.8.1 fails
        "libmysql", # ([PSCustomObject]@{ "port"="libmysql"; "regex"="^mysql-[\d\.]+$" }), # Upgrade to 8.0.13 fails
        "lodepng", # Upgrade to 071e37c5c734841256fac3769ff10e794ddaf118 fails (2018-10-26)
        "mujs", # Upgrade to 7448a82448aa4eff952a4fdb836f197b844e3d1d fails (2018-10-26)
        "opencv",
        "pmdk", # ([PSCustomObject]@{ "port"="pmdk"; "regex"="^[\d\.]+`$" }),
        "realsense2", # Upgrade to 2.16.2 fails
        "refprop-headers",
        "secp256k1",
        "shaderc",
        "spirv-tools",

        "bde", # Isn't updating
        "readline-win32", # Isn't updating
        "tap-windows6", # Version is embedded in repo as a file
        "zxing-cpp" # Maybe version is embedded in repo as a file?
    )

    $tagPorts
    $rollingPorts | % { [PSCustomObject]@{ "port"=$_; "rolling"=$True } }
    $disabledPorts | % { [PSCustomObject]@{ "port"=$_; "disabled"=$True } }
)
