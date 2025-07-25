#!/bin/bash
# shellcheck disable=SC2154

 # Script For Building Android arm64 Kernel
 #
 # Copyright (c) 2018-2021 Panchajanya1999 <rsk52959@gmail.com>
 #
 # Licensed under the Apache License, Version 2.0 (the "License");
 # you may not use this file except in compliance with the License.
 # You may obtain a copy of the License at
 #
 #      http://www.apache.org/licenses/LICENSE-2.0
 #
 # Unless required by applicable law or agreed to in writing, software
 # distributed under the License is distributed on an "AS IS" BASIS,
 # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 # See the License for the specific language governing permissions and
 # limitations under the License.
 #

# Bail out if script fails
set -e
# Function to show an informational message
msger()
{
	while getopts ":n:e:" opt
	do
		case "${opt}" in
			n) printf "[*] $2 \n" ;;
			e) printf "[×] $2 \n"; return 1 ;;
		esac
	done
}

cdir()
{
	cd "$1" 2>/dev/null || msger -e "The directory $1 doesn't exists !"
}

##------------------------------------------------------##
##----------Basic Informations, COMPULSORY--------------##

# The defult directory where the kernel should be placed
KERNEL_DIR="$(pwd)"
BASEDIR="$(basename "$KERNEL_DIR")"

# PATCH KERNELSU & RELEASE VERSION
KSU=0
if [ $KSU = 1 ]
then
	curl -LSs "https://raw.githubusercontent.com/rsuntk/KernelSU/main/kernel/setup.sh" | bash -s v0.9.5
	KSU_GIT_VERSION=$(cd KernelSU && git rev-list --count HEAD)
	KERNELSU_VERSION=$(($KSU_GIT_VERSION + 10000 + 200))
fi

# The name of the Kernel, to name the ZIP
if [ $KSU = 1 ]
then
   ZIPNAME="xve-KSU-$VER"
else
	ZIPNAME="xve-KSU-$VER"
fi

# Build Author
# Take care, it should be a universal and most probably, case-sensitive
AUTHOR="unknown"
HOSTR="nowhere"

# Architecture
ARCH=arm64

# The name of the device for which the kernel is built
MODEL="Redmi 10C"

# The codename of the device
DEVICE="fog"

# The defconfig which should be used. Get it from config.gz from
# your device or check source
DEFCONFIG=vendor/fog-perf_defconfig

# Specify compiler.
# 'clang' or 'gcc'
COMPILER=${COMP}

# Build modules. 0 = NO | 1 = YES
MODULES=0

# Default linker to use for builds.
export LINKER="ld.lld"

# Clean source prior building. 1 is NO(default) | 0 is YES
INCREMENTAL=0

# Push ZIP to Telegram. 1 is YES | 0 is NO(default)
PTTG=1

# Generate a full DEFCONFIG prior building. 1 is YES | 0 is NO(default)
DEF_REG=0

# For evagcc realese
GCCVER=17072025

# Files/artifacts
FILES=Image.gz

# Build dtbo.img (select this only if your source has support to building dtbo.img)
# 1 is YES | 0 is NO(default)
BUILD_DTBO=1
sudo dnf install -y python

# Sign the zipfile
# 1 is YES | 0 is NO
SIGN=1
if [ $SIGN = 1 ]
then
sudo dnf install -y java-17-openjdk
	#Check for java
	if ! hash java 2>/dev/null 2>&1; then
		SIGN=0
		msger -n "you may need to install java, if you wanna have Signing enabled"
	else
		SIGN=1
	fi
fi

# Silence the compilation
# 1 is YES(default) | 0 is NO
SILENCE=0

# Verbose build
# 0 is Quiet(default)) | 1 is verbose | 2 gives reason for rebuilding targets
VERBOSE=0

# Debug purpose. Send logs on every successfull builds
# 1 is YES | 0 is NO(default)
LOG_DEBUG=1

##------------------------------------------------------##
##---------Do Not Touch Anything Beyond This------------##

# Check if we are using a dedicated CI ( Continuous Integration ), and
# set KBUILD_BUILD_VERSION and KBUILD_BUILD_HOST and CI_BRANCH

## Set defaults first

# shellcheck source=/etc/os-release
export DISTRO=$(source /etc/os-release && echo "${NAME}")
echo $DISTRO
export KBUILD_BUILD_HOST=$(uname -a | awk '{print $2}')
TERM=xterm

#Check Kernel Version
KERVER=$(make kernelversion)

#Check kernel branch
KBRANCH=${BRANCH}

# Set a commit head
COMMIT_HEAD=$(git log --oneline -1)

# Set Date
DATE=$(TZ=Asia/Jakarta date +"%Y%m%d-%T")
WAKTU=$(date +"%F-%S")

#Now Its time for other stuffs like cloning, exporting, etc

 clone()
 {
	echo " "
	if [ $COMPILER = "gcc" ]
	then
		msger -n "|| Cloning GCC  ||"
		if [ ! -d "${KDIR}/gcc64" ]; then
			curl -LO https://github.com/mvaisakh/gcc-build/releases/download/"${GCCVER}"/eva-gcc-arm64-"${GCCVER}".xz
                        tar -xvf eva-gcc-arm64-"${GCCVER}".xz
			mv "${KERNEL_DIR}"/gcc-arm64 "${KERNEL_DIR}"/gcc64
		fi
  		if [ ! -d "${KDIR}/gcc32" ]; then
			curl -LO https://github.com/mvaisakh/gcc-build/releases/download/"${GCCVER}"/eva-gcc-arm-"${GCCVER}".xz
                        tar -xvf eva-gcc-arm-"${GCCVER}".xz
			mv ${KERNEL_DIR}/gcc-arm ${KERNEL_DIR}/gcc32
   		fi
		GCC64_DIR=$KERNEL_DIR/gcc64
		GCC32_DIR=$KERNEL_DIR/gcc32
                sudo dnf install -y ccache
                ccache --max-size=20G
                ccache --set-config=compression=true
		export CCACHE_SIZE=20G
                export USE_CCACHE=1
                export CCACHE_COMPRESS=1
	fi

	if [ $COMPILER = "clang" ]
	then
                mkdir clang-llvm
		cd clang-llvm
		curl -LO "https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman"
                chmod +x antman
                ./antman -S
		git clone https://github.com/ZyCromerZ/aarch64-zyc-linux-gnu -b 14 gcc64 --depth=1
                git clone https://github.com/ZyCromerZ/arm-zyc-linux-gnueabi -b 14 gcc32 --depth=1
		GCC64_DIR=$KERNEL_DIR/gcc64
		GCC32_DIR=$KERNEL_DIR/gcc32
  		for64=aarch64-zyc-linux-gnu
  		for32=arm-zyc-linux-gnueabi
		# Toolchain Directory defaults to clang-llvm
		TC_DIR=$KERNEL_DIR/clang-llvm
  		export LLVM=1
		export LLVM_IAS=1
                export LD_LIBRARY_PATH=$TC_DIR/bin/:$GCC64_DIR/bin/:$GCC32_DIR/bin/:$LD_LIBRARY_PATH
	fi

	msger -n "|| Cloning Anykernel ||"
	git clone --depth=1 https://github.com/Dwyor-tmx/AnyKernel3-680 AnyKernel3

	if [ $BUILD_DTBO = 1 ]
	then
		msger -n "|| Cloning libufdt ||"
		git clone https://android.googlesource.com/platform/system/libufdt "$KERNEL_DIR"/scripts/ufdt/libufdt
	fi
}

##------------------------------------------------------##

exports()
{
	KBUILD_BUILD_USER=$AUTHOR
	KBUILD_BUILD_HOST=$HOSTR
	SUBARCH=$ARCH

	if [ $COMPILER = "clang" ]
	then
		KBUILD_COMPILER_STRING=$("${TC_DIR}"/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
		export PATH=${TC_DIR}/bin/:${PATH}
  		export LD_LIBRARY_PATH=${TC_DIR}/bin:${LD_LIBRARY_PATH}
	elif [ $COMPILER = "gcc" ]
	then
		KBUILD_COMPILER_STRING=$("${GCC64_DIR}"/bin/aarch64-elf-gcc --version | head -n 1)
		export PATH="${KERNEL_DIR}"/gcc32/bin:"${KERNEL_DIR}"/gcc64/bin:/usr/bin/:${PATH}
	fi

	BOT_MSG_URL="https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage"
	BOT_BUILD_URL="https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument"
	PROCS=$(nproc --all)

	export KBUILD_BUILD_USER ARCH SUBARCH PATH \
	       KBUILD_COMPILER_STRING BOT_MSG_URL \
	       BOT_BUILD_URL PROCS

        # Version
        echo "-$VER" >> localversion
}

##---------------------------------------------------------##

tg_post_msg()
{
	curl -s -X POST "$BOT_MSG_URL" -d chat_id="$TELEGRAM_CHAT" \
	-d "disable_web_page_preview=true" \
	-d "parse_mode=html" \
	-d text="$1"

}

##----------------------------------------------------------##

tg_post_build()
{
	# Post MD5Checksum alongwith for easeness
	MD5CHECK=$(md5sum "$1" | cut -d' ' -f1)

	# Show the Checksum alongwith caption
	curl --progress-bar -F document=@"$1" "$BOT_BUILD_URL" \
	-F chat_id="$TELEGRAM_CHAT"  \
	-F "disable_web_page_preview=true" \
	-F "parse_mode=Markdown" \
	-F caption="$2 | *MD5 Checksum : *\`$MD5CHECK\`"
}

##----------------------------------------------------------##

build_kernel()
{
	if [ $INCREMENTAL = 0 ]
	then
		msger -n "|| Cleaning Sources ||"
	fi

	if [ $"KBRANCH" = r-oss ]
	then
		tg_post_msg "<b>Stable kernel incoming!</b>"
    else
		tg_post_msg "<b>WIP kernel incoming!</b>"
    fi

	if [ "$KSU" = 1 ]
 	then
		tg_post_msg "<b>Kernel Build Triggered</b>%0A<b>Docker OS: </b><code>$DISTRO</code>%0A<b>Kernel Version : </b><code>$KERVER</code>%0A<b>Date : </b><code>$(TZ=Asia/Jakarta date)</code>%0A<b>Device : </b><code>$MODEL [$DEVICE]</code>%0A<b>Host Core Count : </b><code>$PROCS</code>%0A<b>Compiler Used : </b><code>$KBUILD_COMPILER_STRING</code>%0A<b>KernelSU: </b><code>$KERNELSU_VERSION</code>%0A<b>Top Commit : </b><code>$COMMIT_HEAD</code>"
	else
		tg_post_msg "<b>Kernel Build Triggered</b>%0A<b>Docker OS: </b><code>$DISTRO</code>%0A<b>Kernel Version : </b><code>$KERVER</code>%0A<b>Date : </b><code>$(TZ=Asia/Jakarta date)</code>%0A<b>Device : </b><code>$MODEL [$DEVICE]</code>%0A<b>Host Core Count : </b><code>$PROCS</code>%0A<b>Compiler Used : </b><code>$KBUILD_COMPILER_STRING</code>%0A<b>NON KernelSU:<code>This is not KSU</code>%0A</b><b>Top Commit : </b><code>$COMMIT_HEAD</code>"
    fi

	make O=out $DEFCONFIG
	if [ $DEF_REG = 1 ]
	then
		cp .config arch/arm64/configs/$DEFCONFIG
		git add arch/arm64/configs/$DEFCONFIG
		git commit -m "$DEFCONFIG: Regenerate

						This is an auto-generated commit"
	fi

        if [ $KSU = 1 ]
	then
           for patch_file in $KERNEL_DIR/patchs/KernelSU.patch
	do
           patch -p1 < "$patch_file"
        done
        fi

	BUILD_START=$(date +"%s")

		if [ $COMPILER = "clang" ]
	then
		MAKE+=(
  			CC=clang \
			CROSS_COMPILE=aarch64-zyc-linux-gnu- \
			CROSS_COMPILE_ARM32=arm-zyc-linux-gnueabi- \
   			CLANG_TRIPLE=aarch64-linux-gnu- \
        		HOSTCC=gcc \
	                LD="${KERNEL_DIR}"/gcc64/bin/aarch64-zyc-linux-gnu-"${LINKER}" \
		        LLVM=1
	                LLVM_IAS=1
	  		HOSTCXX=g++
     ) 
	elif [ $COMPILER = "gcc" ]
	then
		MAKE+=(
    CROSS_COMPILE=aarch64-elf-
    CROSS_COMPILE_ARM32=arm-eabi-
    LD="${KERNEL_DIR}"/gcc64/bin/aarch64-elf-"${LINKER}"
    AR=aarch64-elf-ar
    AS="ccache aarch64-elf-as"  # If you want to cache assembler invocations
    NM=aarch64-elf-nm
    STRIP=aarch64-elf-strip
    OBJDUMP=aarch64-elf-objdump
    OBJCOPY=aarch64-elf-objcopy
    CC="ccache aarch64-elf-gcc"
    CXX="ccache aarch64-elf-g++"
    CPP="ccache aarch64-elf-cpp"
    AS="ccache aarch64-elf-as"  # Included twice; might be redundant
    DWP=aarch64-elf-dwp
    CXXFLAGS="-O2 -g"
    RANLIB=aarch64-elf-ranlib
    GPROF=aarch64-elf-gprof
    GFORTRAN="ccache aarch64-elf-gfortran"  # Cache Fortran compiler too
    SIZE=aarch64-elf-size
    STRINGS=aarch64-elf-strings
)
	fi

	if [ $SILENCE = "1" ]
	then
		MAKE+=( -s )
	fi

	msger -n "|| Started Compilation ||"
	make -kj"$PROCS" O=out \
		V=$VERBOSE \
		"${MAKE[@]}" 2>&1 | tee error.log
	if [ $MODULES = "1" ]
	then
	    msger -n "|| Started Compiling Modules ||"
	    make -j"$PROCS" O=out \
		 "${MAKE[@]}" modules_prepare
	    make -j"$PROCS" O=out \
		 "${MAKE[@]}" modules INSTALL_MOD_PATH="$KERNEL_DIR"/out/modules
	    make -j"$PROCS" O=out \
		 "${MAKE[@]}" modules_install INSTALL_MOD_PATH="$KERNEL_DIR"/out/modules
	    find "$KERNEL_DIR"/out/modules -type f -iname '*.ko' -exec cp {} AnyKernel3/modules/system/lib/modules/ \;
	fi

		BUILD_END=$(date +"%s")
		DIFF=$((BUILD_END - BUILD_START))

		if [ -f "$KERNEL_DIR"/out/arch/arm64/boot/$FILES ]
		then
			msger -n "|| Kernel successfully compiled ||"
			if [ $BUILD_DTBO = 0 ]
			then
				msger -n "|| Building DTBO ||"
				tg_post_msg "<code>Building DTBO..</code>"
				python3 "$KERNEL_DIR/scripts/ufdt/libufdt/utils/src/mkdtboimg.py" \
					create "$KERNEL_DIR/out/arch/arm64/boot/dtbo.img" --page_size=4096 "$KERNEL_DIR/out/arch/arm64/boot/dts/$DTBO_PATH"
			fi
				gen_zip
			else
			if [ "$PTTG" = 1 ]
 			then
				tg_post_build "error.log" "*Build failed to compile after $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds*"
			fi
		fi

}

##--------------------------------------------------------------##

gen_zip()
{
	msger -n "|| Zipping into a flashable zip ||"
	mv "$KERNEL_DIR"/out/arch/arm64/boot/$FILES AnyKernel3/$FILES
	if [ $BUILD_DTBO = 1 ]
	then
		mv "$KERNEL_DIR"/out/arch/arm64/boot/dtbo.img AnyKernel3/dtbo.img
	fi
	cdir AnyKernel3
	zip -r $DEVICE-$ZIPNAME-"$WAKTU" . -x ".git*" -x "README.md" -x "*.zip"

	## Prepare a final zip variable
	ZIP_FINAL="$DEVICE-$ZIPNAME-$WAKTU"

	if [ $SIGN = 1 ]
	then
		## Sign the zip before sending it to telegram
		if [ "$PTTG" = 1 ]
 		then
 			msger -n "|| Signing Zip ||"
			tg_post_msg "<code>Signing Zip file with AOSP keys..</code>"
 		fi
		curl -sLo zipsigner-3.0.jar https://github.com/Magisk-Modules-Repo/zipsigner/raw/master/bin/zipsigner-3.0-dexed.jar
		java -jar zipsigner-3.0.jar "$ZIP_FINAL".zip "$ZIP_FINAL"-signed.zip
		ZIP_FINAL="$ZIP_FINAL-signed"
	fi

	if [ "$PTTG" = 1 ]
 	then
		tg_post_build "$ZIP_FINAL.zip" "Build took : $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)"
	fi
	cd ..
}

clone
exports
build_kernel
ccache -s
if [ $LOG_DEBUG = "1" ]
then
	tg_post_build "error.log" "$TELEGRAM_CHAT" "Debug Mode Logs"
fi

##----------------*****-----------------------
