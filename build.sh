#!/usr/bin/env bash
# shellcheck disable=SC2154

# Script For Building Android arm64 Kernel#
# Copyright (c) 2018-2021 Panchajanya1999 <rsk52959@gmail.com>
# Copyright (c) 2023 Hoppless <hoppless@proton.me>
# Rewrites script by: Hoppless <hoppless@proton.me>
# Rewrites script by: Tanmsyffa <sltnmsyffaa@gmail.com>

set -e

cdir() {
	cd "$1" 2>/dev/null || msger -e "The directory $1 doesn't exists !"
}

# Directory info
KERNEL_DIR="$(pwd)"
GCC64_DIR=$KERNEL_DIR/gcc64
GCC32_DIR=$KERNEL_DIR/gcc32
TC_DIR=$KERNEL_DIR/neutron-clang

# Kernel info
VERSION="$VER"
AUTHOR="Sultanㅤ👾 ⁪⁬⁮⁮⁮⁮ ‌‌‌"
ARCH=arm64
CONFIG="vendor/fog-perf_defconfig"
COMPILER="$COMP"
LTO=0
POLLY=0
LINKER=ld.lld

# Device info
MODEL="Redmi 10C"
DEVICE="fog"

# Misc info
CLEAN=1
SIGN=0
STATUS="$STATUS"

# KSU
KSU=1
if [[ $KSU == 1 ]]; then
	curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -s v0.9.5
	KSU_GIT_VERSION=$(cd KernelSU && git rev-list --count HEAD)
	KERNELSU_VERSION=$(($KSU_GIT_VERSION + 10000 + 200))
fi

# Sign
if [[ $SIGN == 1 ]]; then
	#Check for java
	if ! hash java 2>/dev/null 2>&1; then
		SIGN=0
		msger -n "you may need to install java, if you wanna have Signing enabled"
	else
		SIGN=1
	fi
fi
HOST="EagleProject"
export DISTRO=$(source /etc/os-release && echo "${NAME}")
KERVER=$(make kernelversion)
COMMIT_HEAD=$(git log --oneline -1)

# Date info
DATE=$(date +"%d-%m-%Y")
ZDATE="$(date "+%d%m%Y")"

clone() {
	echo " "
	if [[ $COMPILER == "gcc" ]]; then
	    echo -e "\n\e[1;93m[*] Cloning Eva GCC \e[0m"
	    git clone --depth=1 https://github.com/mvaisakh/gcc-arm gcc32
	    git clone --depth=1 https://github.com/mvaisakh/gcc-arm64 gcc64
	else
	    if [ ! -f "${KERNEL_DIR}/neutron-clang/bin/clang" ]; then
			rm -rf "${KERNEL_DIR}"/neutron-clang
			mkdir "${KERNEL_DIR}"/neutron-clang
			cd "${KERNEL_DIR}"/neutron-clang || exit 1
			bash <(curl -s "https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman") -S
			cd ..
		fi
	fi

	echo -e "\n\e[1;93m[*] Cloning AnyKernel3 \e[0m"
    git clone --depth 1 --no-single-branch https://github.com/Eagle-Projekt/Anykernel3.git -b master AnyKernel3
}

##------------------------------------------------------##

exports() {
	KBUILD_BUILD_HOST="$HOST"
	KBUILD_BUILD_USER="$AUTHOR"
	SUBARCH=$ARCH

	if [[ $COMPILER == "gcc" ]]; then
		KBUILD_COMPILER_STRING=$("$GCC64_DIR"/bin/aarch64-elf-gcc --version | head -n 1)
		PATH=$GCC64_DIR/bin/:$GCC32_DIR/bin/:/usr/bin:$PATH
	else
	    KBUILD_COMPILER_STRING=$("$TC_DIR"/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
		PATH=$TC_DIR/bin/:$PATH
	fi
	PROCS=$(nproc --all)

	export KBUILD_BUILD_USER KBUILD_BUILD_HOST \
		KBUILD_COMPILER_STRING ARCH SUBARCH \
		PATH
}

##---------------------------------------------------------##
if [ ! -d "Telegram" ]; then
  git clone --depth=1 https://github.com/Hopireika/telegram.sh Telegram
fi
TELEGRAM="$(pwd)/Telegram/telegram"
tgm() {
	"${TELEGRAM}" -H -D \
		"$(
			for POST in "${@}"; do
				echo "${POST}"
			done
		)"
}

tgf() {
	"${TELEGRAM}" -H \
		-f "$1" \
		"$2"
}

##----------------------------------------------------------##

build_kernel() {
	if [[ $CLEAN == "1" ]]; then
		echo -e "\n\e[1;93m[*] Cleaning source and out/ directory! \e[0m"
		make clean && make mrproper && rm -rf out
	fi

	tgm "
<b>🛠 SantuyKernel Build Triggered</b>
<b>-----------------------------------------</b>
<b>[*] Architecture</b>   : <code>$ARCH</code>
<b>[*] Build Date</b>     : <code>$DATE</code>
<b>[*] Device Name</b>    : <code>${MODEL} [${DEVICE}]</code>
<b>[*] Defconfig</b>      : <code>$CONFIG</code>
<b>[*] Kernel Name</b>    : <code>-SantuyKernel${VER}</code>
<b>[*] Linux Version</b>  : <code>$(make kernelversion)</code>
<b>[*] Compiler Name</b>  : <code>${KBUILD_COMPILER_STRING}</code>
<b>-----------------------------------------</b>
"
	# KSU Patch
	if [ $KSU = 1 ]
	then
           for patch_file in $KERNEL_DIR/patch/KernelSU.patch
	do
           patch -p1 < "$patch_file"
		   done
    fi

	echo "-$VERSION" >>localversion
	make O=out $CONFIG
	BUILD_START=$(date +"%s")

	if [[ $COMPILER == "gcc" ]]; then
		MAKE+=(
			CROSS_COMPILE_COMPAT=arm-eabi-
			CROSS_COMPILE=aarch64-elf-
			AR=llvm-ar
			NM=llvm-nm
			OBJCOPY=llvm-objcopy
			OBJDUMP=llvm-objdump
			STRIP=llvm-strip
			OBJSIZE=llvm-size
			LD=aarch64-elf-$LINKER
		)
	else
		MAKE+=(
			LLVM=1
			LLVM_IAS=1
		)
	fi

	echo -e "\n\e[1;93m[*] Building Kernel! \e[0m"
	make -kj"$PROCS" O=out \
		V=$VERBOSE \
		"${MAKE[@]}" 2>&1 | tee build.txt

	BUILD_END=$(date +"%s")
	DIFF=$((BUILD_END - BUILD_START))

	if [[ -f "$KERNEL_DIR"/out/arch/arm64/boot/Image ]]; then
		echo -e "\n\e[1;32m[✓] Kernel successfully compiled! \e[0m"
		gen_zip
		push
	else
		echo -e "\n\e[1;32m[✗] Build Failed! \e[0m"
		tgf "build.txt" "[X] Build failed to compile after $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds*"
		exit 1
	fi

}

##--------------------------------------------------------------##

gen_zip() {
	echo -e "\n\e[1;32m[*] Create a flashable zip! \e[0m"
	mv "$KERNEL_DIR"/out/arch/arm64/boot/Image.gz AnyKernel3
	cdir AnyKernel3
	zip -r "$VERSION-$DEVICE-$ZDATE".zip . -x ".git*" -x "README.md" -x "*.zip"
	ZIP_FINAL="$VERSION-$DEVICE-$ZDATE"
	if [[ $SIGN == 1 ]]; then
		## Sign the zip before sending it to telegram
		echo -e "\n\e[1;32m[*] Sgining a zip! \e[0m"
		tgm "<b>[*] Signing Zip file with AOSP keys!</b>"
		curl -sLo zipsigner-3.0.jar https://github.com/Magisk-Modules-Repo/zipsigner/raw/master/bin/zipsigner-3.0-dexed.jar
		java -jar zipsigner-3.0.jar "$ZIP_FINAL".zip "$ZIP_FINAL"-signed.zip
		ZIP_SIGN="$ZIP_FINAL-signed"
		echo -e "\n\e[1;32m[✓] Zip Signed! \e[0m"
	fi
	cd ..
	echo -e "\n\e[1;32m[✓] Create flashable kernel completed! \e[0m"
}

push() {
	# Create kernel info
	echo -e "\n\e[1;93m[*] Generate source changelogs! \e[0m"
	log="$(git log --oneline -n 10)"
	flog="$(echo "$log" | sed -E 's/^([a-zA-Z0-9]+) (.*)/* \2/')"

	cd AnyKernel3

	if [[ $SIGN == 1 ]]; then
		rel_file="$ZIP_SIGN.zip"
	else
		rel_file="$ZIP_FINAL.zip"
	fi

	tgf "$rel_file" "<b>[*] Compiler</b>: <code>${KBUILD_COMPILER_STRING}</code>"
	cd ..
}

clone
exports
build_kernel
##--------------------------------------------------##
