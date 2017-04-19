#!/bin/bash

GITHUB_URL="https://github.com/Lanchon/haystack.git"
PATCH_CORE="sigspoof-core"
CWD="${PWD}"

error () {
	echo -e "${@}"
	exit 1
}

help () {

echo -e "haystack framework patcher helper

provide Android Version like:
	framework-patcher.sh [version]

there version is one of:
	4.1	[JB]
	4.2	[JB]
	4.3	[JB]
	4.4	[KK]
	5.0	[LL]
	5.1	[LL]
	6.0	[MM]
	7.0	[N]
	7.1	[N]

your device must be in TWRP and connected to PC."

exit 0

}

case "${1}" in
	4.1 )	API=16	;;
	4.2 )	API=17	;;
	4.3 )	API=18	;;
	4.4 )	API=19	;;
	5.0 )	API=21	;;
	5.1 )	API=22	;;
	6.0 )	API=23	;;
	7.0 )	API=24	;;
	7.1 )	API=25	;;
	*   )	help	;;
esac

if [[ ${API} -lt 24 ]]; then
	PATCH_HOOK="sigspoof-hook-4.1-6.0"
else	PATCH_HOOK="sigspoof-hook-7.0"
fi

[[ -d ${CWD}/haystack ]] && rm -rf "${CWD}/haystack"
git clone "${GITHUB_URL}" || error "Failed to down haystack!"

cd "${CWD}/haystack"

if [[ "$OSTYPE" == "darwin"* ]]; then
	if ! [ -x "$(command -v brew)" ]; then
		/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
	fi
	if ! [ -x "$(command -v greadlink)" ]; then
		brew install coreutils
	fi
	alias readlink=greadlink
	alias cp=gcp
fi

adb shell "mount -oro /system" || error "Failed to mount /system"

"${PWD}/pull-fileset" mydevice || error "Failed to pull files from device!"

"${PWD}/patch-fileset" "${PWD}/patches/${PATCH_HOOK}" \
	"${API}" "${PWD}/mydevice" || \
	error "Failed applying sigspoof hook patch!"

"${PWD}/patch-fileset" "${PWD}/patches/${PATCH_CORE}" "${API}" \
	"${PWD}/mydevice__${PATCH_HOOK}" \
	|| error "Failed applying sigspoof core patch!"

echo -e "\nWhere to install patched services.jar?

1)	NanoMod (full package)
2)	NanoMod (microG only)
3)	ROM (directly to /system)

enter either 1, 2 or 3"
read -r MOD

case ${MOD} in
	1 )	MODPATH="/magisk/NanoMod"	;;
	2 )	MODPATH="/magisk/NanoModmicroG"	;;
	3 )	MODPATH=""			;;
	* )	error "wrong module given" ;;
esac

if [[ ${MODPATH} == /magisk* ]]; then
	adb push "${CWD}/mount-magisk.sh" /tmp/ || \
		error "Failed to push helper script to device"
	adb shell "chmod 0755 /tmp/mount-magisk.sh" || \
		error "Failed to set permissions for helper script"
	adb shell "/tmp/mount-magisk.sh" || \
		error "Failed to mount Magisk image"
fi

adb shell "mkdir -p ${MODPATH}/system/framework" || \
	error "Failed to create framework directory"
adb push "${PWD}/mydevice__${PATCH_HOOK}__${PATCH_CORE}/services.jar" \
		"${MODPATH}/system/framework" || \
		error "Failed to push services.jar to device"

if [[ ${MODPATH} == /magisk* ]]; then
	adb shell "/tmp/mount-magisk.sh" || \
		error "Failed to unmount Magisk"
fi

echo -e "\nNow reboot device and enjoy microG!"

rm -rf "${CWD}/haystack"
