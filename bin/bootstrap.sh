#!/usr/bin/env bash

#
# TODO convert this to a brew package
#
set -e;

PREFIX=${PREFIX:-"/usr/local"}

if [ ! "$CXX" ]; then
  if [ ! -z "$LOCALAPPDATA" ]; then
    if which clang++ >/dev/null 2>&1; then
      CXX="$(which clang++)"
    fi
  fi

  if [ ! "$CXX" ]; then
    if which g++ >/dev/null 2>&1; then
      CXX="$(which g++)"
    elif which clang++ >/dev/null 2>&1; then
      CXX="$(which clang++)"
    fi
  fi

  if [ ! "$CXX" ]; then
    echo "• error: Could not determine \$CXX environment variable"
    exit 1
  else
    echo "• Warning: \$CXX environment variable not set, assuming '$CXX'"
fi
  fi

if ! which sudo > /dev/null 2>&1; then
  sudo () {
    $@
    return $?
  }
fi

function _build {
  echo '• Building op'
  "$CXX" src/cli.cc ${CXX_FLAGS} ${CXXFLAGS} \
    -o bin/cli \
    -std=c++2a \
    -DVERSION_HASH=`git rev-parse --short HEAD` \
    -DVERSION=`cat VERSION.txt` \

  if [ ! $? = 0 ]; then
    echo '• Unable to build. See trouble shooting guide in the README.md file'
    exit 1
  fi
  echo '• Success'
}

function _install {
  local libdir=""

  ## must be a windows environment
  if [ ! -z "$LOCALAPPDATA" ]; then
    libdir="$LOCALAPPDATA/Programs/socketsupply"
  else
    libdir="$PREFIX/lib/op"
  fi

  echo "• Installing op"
  sudo rm -rf "$libdir"

  sudo mkdir -p "$libdir"
  sudo cp -r `pwd`/src "$libdir"

  echo "• Copying sources to $libdir/src"
  if [ -d `pwd`/lib ]; then
    echo "• Copying libraries to $libdir/lib"
    sudo mkdir -p "$libdir/lib"
    sudo cp -r `pwd`/lib/* "$libdir/lib"
  fi

  echo "• Moving binary to $PREFIX/bin"
  sudo mv `pwd`/bin/cli "$PREFIX/bin/op"

  if [ ! $? = 0 ]; then
    echo "• Unable to move binary into place"
    exit 1
  fi

  echo -e '• Finished. Type "op -h" for help'
  exit 0
}

#
# Re-compile libudx for iOS (and the iOS simulator).
#
function _setSDKVersion {
  sdks=`ls $PLATFORMPATH/$1.platform/Developer/SDKs`
  arr=()
  for sdk in $sdks
  do
   echo $sdk
   arr[${#arr[@]}]=$sdk
  done

  # Last item will be the current SDK, since it is alpha ordered
  count=${#arr[@]}
  if [ $count -gt 0 ]; then
   sdk=${arr[$count-1]:${#1}}
   num=`expr ${#sdk}-4`
   SDKVERSION=${sdk:0:$num}
  else
   SDKVERSION="8.0"
  fi
}

function _compile {
  target=$1
  hosttarget=$1
  platform=$2

  if [[ $hosttarget == "x86_64" ]]; then
    xxhosttarget="i386"
  elif [[ $hosttarget == "arm64" ]]; then
    hosttarget="arm"
  fi

  export PLATFORM=$platform
  export CC="$(xcrun -sdk iphoneos -find clang)"
  export STRIP="$(xcrun -sdk iphoneos -find strip)"
  export LD="$(xcrun -sdk iphoneos -find ld)"
  export CPP="$CC -E"
  export CFLAGS="-fembed-bitcode -arch ${target} -isysroot $PLATFORMPATH/$platform.platform/Developer/SDKs/$platform$SDKVERSION.sdk -miphoneos-version-min=$SDKMINVERSION"
  export AR=$(xcrun -sdk iphoneos -find ar)
  export RANLIB=$(xcrun -sdk iphoneos -find ranlib)
  export CPPFLAGS="-fembed-bitcode -arch ${target} -isysroot $PLATFORMPATH/$platform.platform/Developer/SDKs/$platform$SDKVERSION.sdk -miphoneos-version-min=$SDKMINVERSION"
  export LDFLAGS="-Wc,-fembed-bitcode -arch ${target} -isysroot $PLATFORMPATH/$platform.platform/Developer/SDKs/$platform$SDKVERSION.sdk"

  ./configure --prefix="$BUILD_DIR/output/$target" --host=$hosttarget-apple-darwin

  make clean
  make
  make install
  install_name_tool -id libuv.1.dylib $BUILD_DIR/output/$target/lib/libuv.1.dylib
}

function _cross_compile {
  PLATFORMPATH="/Applications/Xcode.app/Contents/Developer/Platforms"
  TOOLSPATH="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin"

  export IPHONEOS_DEPLOYMENT_TARGET="8.0"
  OLD_CWD=`pwd`
  BUILD_DIR=`pwd`/lib/build
  rm -rf `pwd`/lib/uv

  xcrun -sdk iphoneos -find texturetool

  #
  # Shallow clone the main branch of libuv
  #
  rm -rf $BUILD_DIR
  git clone --depth=1 git@github.com:libuv/libuv.git lib/build
  cd $BUILD_DIR
  sh autogen.sh

  _setSDKVersion iPhoneOS
  SDKMINVERSION="8.0"

  #
  # Build artifacts for all platforms
  #
  _compile armv7 iPhoneOS
  _compile armv7s iPhoneOS
  _compile arm64 iPhoneOS
  _compile i386 iPhoneSimulator
  _compile x86_64 iPhoneSimulator

  #
  # Combine the build artifacts
  #
  LIPO=$(xcrun -sdk iphoneos -find lipo)

  $LIPO -create \
    $BUILD_DIR/output/armv7/lib/libuv.a \
    $BUILD_DIR/output/armv7s/lib/libuv.a \
    $BUILD_DIR/output/arm64/lib/libuv.a \
    $BUILD_DIR/output/x86_64/lib/libuv.a \
    $BUILD_DIR/output/i386/lib/libuv.a \
    -output libuv.a
  $LIPO -create \
    $BUILD_DIR/output/armv7/lib/libuv.1.dylib \
    $BUILD_DIR/output/armv7s/lib/libuv.1.dylib \
    $BUILD_DIR/output/arm64/lib/libuv.1.dylib \
    $BUILD_DIR/output/x86_64/lib/libuv.1.dylib \
    $BUILD_DIR/output/i386/lib/libuv.1.dylib \
    -output libuv.1.dylib

  install_name_tool -id @rpath/libuv.1.dylib libuv.1.dylib

  $LIPO -info libuv.a

  #
  # Copy the build into the project and delete leftover build artifacts.
  #
  DEST_DIR=$BUILD_DIR/../uv
  mkdir $DEST_DIR

  cp libuv.a $DEST_DIR
  cp libuv.1.dylib $DEST_DIR
  cp -r $BUILD_DIR/include $DEST_DIR

  rm -rf $BUILD_DIR
  cd $OLD_CWD
}

#
# This will re-compile libuv for iOS (and the iOS simulator).
#
if [ "$2" == "ios" ]; then
  _cross_compile
  exit 0
fi

#
# Clone
#
if [ -z "$1" ]; then
  TMPD=$(mktemp -d)

  echo '• Cloning from Github'
  git clone --depth=1 git@github.com:socketsupply/operatorframework.git $TMPD > /dev/null 2>&1

  if [ ! $? = 0 ]; then
    echo "• Unable to clone"
    exit 1
  fi

  cd $TMPD
fi

#
# Build and Install
#
_build
_install
