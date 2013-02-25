#!/bin/bash
#
# Build script for ARM Cortex toolchain
# This script is based on the summon-arm-toolchain (https://github.com/esden/summon-arm-toolchain)
#
# Philipp Sommer <philipp.sommer@csiro.au>
#
# Requirements
#
# apt-get install flex bison libgmp3-dev libmpfr-dev libncurses5-dev \
# libmpc-dev autoconf texinfo build-essential


# Stop if any command fails
set -e

##############################################################################
# Default settings section
# You probably want to customize those
# You can also pass them as parameters to the script
##############################################################################
TARGET=arm-none-eabi

case "$(uname)" in
	Darwin)
        DARWIN_OPT_PATH=/usr/local	# Path in which MacPorts or Fink is installed
        echo "DARWIN_OPT_PATH=$DARWIN_OPT_PATH"
        ;;
esac

echo "Settings used for this build are:"
echo "TARGET=$TARGET"
echo "PREFIX=$PREFIX"
echo "DESTDIR=$DESTDIR"

##############################################################################
# Version and download url settings section
##############################################################################

# For Linaro GCC:
GCCRELEASE=4.7-2013.01
GCCVERSION=4.7-2013.01
GCC=gcc-linaro-${GCCVERSION}
GCCURL=http://launchpad.net/gcc-linaro/4.7/${GCCRELEASE}/+download/${GCC}.tar.bz2

# For Linaro GDB:
GDBRELEASE=7.5-2012.12-1
GDBVERSION=7.5-2012.12-1
GDB=gdb-linaro-${GDBVERSION}
GDBURL=http://launchpad.net/gdb-linaro/7.5/${GDBRELEASE}/+download/${GDB}.tar.bz2


BINUTILS=binutils-2.23.1
NEWLIB=newlib-1.20.0


##############################################################################
# Flags section
##############################################################################

if which getconf > /dev/null; then
	CPUS=$(getconf _NPROCESSORS_ONLN)
else
	CPUS=1
fi
PARALLEL=-j$((CPUS + 1))

echo "${CPUS} cpu's detected running make with '${PARALLEL}' flag"


GDBFLAGS=
BINUTILFLAGS=

MAKEFLAGS=${PARALLEL}
TARFLAGS=

export PATH="${DESTDIR}${PREFIX}/bin:${PATH}"

WORKING_DIR=$(pwd)
SOURCES=${WORKING_DIR}/sources


##############################################################################
# Tool section
##############################################################################
TAR=tar

##############################################################################
# OS and Tooldetection section
# Detects which tools and flags to use
##############################################################################

case "$(uname)" in
	Linux)
	echo "Found Linux OS."
	;;
	Darwin)
	echo "Found Darwin OS."
	GCCFLAGS="${GCCFLAGS} \
                  --with-gmp=${DARWIN_OPT_PATH} \
	          --with-mpfr=${DARWIN_OPT_PATH} \
	          --with-mpc=${DARWIN_OPT_PATH} \
		  --with-libiconv-prefix=${DARWIN_OPT_PATH}"

	if gcc --version | grep llvm-gcc > /dev/null ; then
		echo "Found you are using llvm gcc, switching to clang for gcc compile."
		GCC_CC=clang
	fi
	;;
	CYGWIN*)
	echo "Found CygWin that means Windows most likely."
	;;
	*)
	echo "Found unknown OS. Aborting!"
	exit 1
	;;
esac

##############################################################################
# Building section
# You probably don't have to touch anything after this
##############################################################################

# Fetch a versioned file from a URL
function fetch {
    log "Downloading $1 sources..."
    wget -nv -c --no-check-certificate $2
}

# Log a message out to the console
function log {
    echo "******************************************************************"
    echo "* $*"
    echo "******************************************************************"
}

# Unpack an archive
function unpack {
    log Unpacking $*
    # Use 'auto' mode decompression.  Replace with a switch if tar doesn't support -a
    ARCHIVE=$(ls ${SOURCES}/$1.tar.*)
    case ${ARCHIVE} in
	*.bz2)
	    TYPE=j
	    ;;
	*.gz)
	    TYPE=z
	    ;;
	*)
	    echo "Unknown archive type of $1"
	    echo ${ARCHIVE}
	    exit 1
	    ;;
    esac
    ${TAR} xf${TYPE}${TARFLAGS} ${SOURCES}/$1.tar.*
}

# Install a build
function install {
    log $1
    MAKEFLAGS_TMP=${MAKEFLAGS}
    if [ $2 == "install" ]; then
        MAKEFLAGS=$(echo ${MAKEFLAGS} | sed 's@-j[0-9]\+@@g')
    fi
    ${SUDO} make ${MAKEFLAGS} $2 $3 $4 $5 $6 $7 $8 DESTDIR=${DESTDIR}
    MAKEFLAGS=${MAKEFLAGS_TMP}
}



mkdir -p ${SOURCES}

cd ${SOURCES}

fetch ${BINUTILS} http://ftp.gnu.org/gnu/binutils/${BINUTILS}.tar.bz2
fetch ${GCC} ${GCCURL}
fetch ${NEWLIB} ftp://sourceware.org/pub/newlib/${NEWLIB}.tar.gz
fetch ${GDB} ${GDBURL}


cd ${WORKING_DIR}

if [ ! -e build ]; then
    mkdir build
fi

unpack ${BINUTILS}
log "Patching binutils"
cd ${BINUTILS}
patch -p0 -i ../patches/patch-binutils-svc-cortex-m3.diff
cd ..

cd build
log "Configuring ${BINUTILS}"
../${BINUTILS}/configure --target=${TARGET} \
                             --prefix=${PREFIX} \
                             --enable-interwork \
                             --enable-multilib \
                             --with-gnu-as \
                             --with-gnu-ld \
                             --disable-nls \
                             --disable-werror \
                             ${BINUTILFLAGS}
log "Building ${BINUTILS}"
make ${MAKEFLAGS}
install ${BINUTILS} install
cd ..
log "Cleaning up ${BINUTILS}"
rm -rf build/* ${BINUTILS}


unpack ${GCC}
unpack ${NEWLIB}

log "Adding newlib symlink to gcc"
ln -f -s `pwd`/${NEWLIB}/newlib ${GCC}
log "Adding libgloss symlink to gcc"
ln -f -s `pwd`/${NEWLIB}/libgloss ${GCC}

log "Patching multilib for gcc"
cd ${GCC}
patch -p0 -i ../patches/patch-gcc-config-arm-t-arm-elf.diff
cd ..

cd build
if [ "X${GCC_CC}" != "X" ] ; then
   export GLOBAL_CC=${CC}
   log "Overriding the default compiler with: \"${GCC_CC}\""
   export CC=${GCC_CC}
fi

log "Configuring ${GCC} and ${NEWLIB}"
../${GCC}/configure --target=${TARGET} \
                      --prefix=${PREFIX} \
                      --enable-interwork \
                      --enable-multilib \
                      --enable-languages="c" \
                      --with-newlib \
                      --with-gnu-as \
                      --with-gnu-ld \
                      --disable-nls \
                      --disable-shared \
		      --disable-threads \
                      --with-headers=../${GCC}/newlib/libc/include \
		      --disable-libssp \
		      --disable-libstdcxx-pch \
		      --disable-libmudflap \
		      --disable-libgomp \
                      --disable-werror \
		      --with-system-zlib \
		      --disable-newlib-supplied-syscalls \
		      ${GCCFLAGS}
log "Building ${GCC} and ${NEWLIB}"
make ${MAKEFLAGS}
install ${GCC} install
cd ..
log "Cleaning up ${GCC} and ${NEWLIB}"

if [ "X${GCC_CC}" != "X" ] ; then
   unset CC
   CC=${GLOBAL_CC}
   unset GLOBAL_CC
fi

rm -rf build/* ${GCC} ${NEWLIB}



unpack ${GDB}
cd build
log "Configuring ${GDB}"
../${GDB}/configure --target=${TARGET} \
                      --prefix=${PREFIX} \
                      --enable-interwork \
                      --enable-multilib \
                      --disable-werror \
		      ${GDBFLAGS}
log "Building ${GDB}"
make ${MAKEFLAGS}
install ${GDB} install
cd ..
log "Cleaning up ${GDB}"
rm -rf build/* ${GDB}

