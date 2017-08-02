#!/bin/bash -x

#$1 : version string
#$2 : output path

DATE=`date +%Y%m%d`
VERSION="V"$1
BL_LINARO_RELEASE="17.04"
BL_BUILD_NUMBER="79"
INSTALLER_LINARO_RELEASE="17.06"
INSTALLER_BUILD_VERSION="20170628-252"
TARGET_OS="Android"
STORED="output"
RSB_4760="true"
EPC_R4761="false"
ANDROID_OUTPUT_PATH=$2

ANDROID_FILE_LIST="emmc_appsboot.mbn boot.img system.img userdata.img persist.img recovery.img cache.img"

echo "[ADV] DATE = ${DATE}"
echo "[ADV] VERSION = ${VERSION}"
echo "[ADV] BL_LINARO_RELEASE = ${BL_LINARO_RELEASE}"
echo "[ADV] BL_BUILD_NUMBER = ${BL_BUILD_NUMBER}"
echo "[ADV] INSTALLER_LINARO_RELEASE = ${INSTALLER_LINARO_RELEASE}"
echo "[ADV] INSTALLER_BUILD_VERSION = ${INSTALLER_BUILD_VERSION}"
echo "[ADV] TARGET_OS = ${TARGET_OS}"
echo "[ADV] STORED = ${STORED}"
CURR_PATH="$PWD"
STORAGE_PATH="$CURR_PATH/$STORED"

# === 1. Put the installer images into out/ folder. =================================================
function get_installer_images()
{
    # Get Linaro boot toolsNUM2=`expr $VERSION : '.*[.]\([0-9]*\)'`
    git clone --depth 1 -b master https://github.com/ADVANTECH-Corp/db-boot-tools.git
    # record commit info in build log
    cd db-boot-tools
    git log -1

    # Get SD and EMMC bootloader package
    wget --progress=dot -e dotbytes=2M \
         https://github.com/ADVANTECH-Corp/db-boot-tools/raw/${BL_LINARO_RELEASE}-adv/advantech_bootloader_sd_linux-${BL_BUILD_NUMBER}.zip
    wget --progress=dot -e dotbytes=2M \
         https://github.com/ADVANTECH-Corp/db-boot-tools/raw/${BL_LINARO_RELEASE}-adv/advantech_bootloader_emmc_linux-${BL_BUILD_NUMBER}.zip
    wget --progress=dot -e dotbytes=2M \
         https://github.com/ADVANTECH-Corp/db-boot-tools/raw/${BL_LINARO_RELEASE}-adv/advantech_bootloader_emmc_android-${BL_BUILD_NUMBER}.zip

    unzip -d out advantech_bootloader_sd_linux-${BL_BUILD_NUMBER}.zip

    # Get installer boot & rootfs
    wget --progress=dot -e dotbytes=2M \
         http://advgitlab.eastasia.cloudapp.azure.com/db410c/sd-installer/raw/${INSTALLER_LINARO_RELEASE}/boot-installer-linaro-stretch-qcom-snapdragon-arm64-${INSTALLER_BUILD_VERSION}.img.gz
    wget --progress=dot -e dotbytes=2M \
         http://advgitlab.eastasia.cloudapp.azure.com/db410c/sd-installer/raw/${INSTALLER_LINARO_RELEASE}/linaro-stretch-installer-qcom-snapdragon-arm64-${INSTALLER_BUILD_VERSION}.img.gz

    cp boot-installer-linaro-stretch-qcom-snapdragon-arm64-${INSTALLER_BUILD_VERSION}.img.gz out/boot.img.gz
    cp linaro-stretch-installer-qcom-snapdragon-arm64-${INSTALLER_BUILD_VERSION}.img.gz out/rootfs.img.gz
    gunzip out/{boot,rootfs}.img.gz
}

# === 2. Prepare Target OS images ===================================================================
function prepare_target_os()
{
# --- [Advantech] ---
    if [ -e os ] ; then
        rm -rf os
    fi
    mkdir -p os/${TARGET_OS}

    for SRC_IMAGE in $ANDROID_FILE_LIST
    do
        if [ ! -f ${ANDROID_OUTPUT_PATH}${SRC_IMAGE} ]; then
            echo "Can't find ${ANDROID_OUTPUT_PATH}${SRC_IMAGE}"
            exit 1
        fi
    done

    case ${TARGET_OS} in
    "Yocto")
        # To-Do
        ;;
    "Debian")
        # To-Do
        ;;
    "Android")
        cp ${ANDROID_OUTPUT_PATH}emmc_appsboot.mbn os/${TARGET_OS}/.
        cp ${ANDROID_OUTPUT_PATH}boot.img os/${TARGET_OS}/.
        cp ${ANDROID_OUTPUT_PATH}system.img os/${TARGET_OS}/.
        cp ${ANDROID_OUTPUT_PATH}userdata.img os/${TARGET_OS}/.
        cp ${ANDROID_OUTPUT_PATH}persist.img os/${TARGET_OS}/.
        cp ${ANDROID_OUTPUT_PATH}recovery.img os/${TARGET_OS}/.
        cp ${ANDROID_OUTPUT_PATH}cache.img os/${TARGET_OS}/.
        ;;
    esac
# ------

    cat << EOF >> os/${TARGET_OS}/os.json
{
"name": "Advantech ${TARGET_OS} OS image",
"url": "",
"version": "${RELEASE_VERSION}",
"release_date": "${DATE}",
"description": "Official Release (${VERSION}) for ${PRODUCT}"
}
EOF

    cp mksdcard flash os/

    if [ ${TARGET_OS} == "Android" ]; then
        cp dragonboard410c/android/partitions.txt os/${TARGET_OS}
        unzip -n -d os/${TARGET_OS} advantech_bootloader_emmc_android-${BL_BUILD_NUMBER}.zip
    else
        cp dragonboard410c/linux/partitions.txt os/${TARGET_OS}
        unzip -d os/${TARGET_OS} advantech_bootloader_emmc_linux-${BL_BUILD_NUMBER}.zip
    fi
}

# === 3. Generate os.img & execute mksdcard script ==================================================
function make_os_img()
{
    # get size of OS partition
    size_os=$(du -sk os | cut -f1)
    size_os=$(((($size_os + 1024 - 1) / 1024) * 1024))
    size_os=$(($size_os + 200*1024))
    # pad for SD image size (including rootfs and bootloaders)
    size_img=$(($size_os + 1024*1024 + 300*1024))

    # create OS image
    sudo rm -f out/os.img
    sudo mkfs.fat -a -F32 -n "OS" -C out/os.img $size_os

    if [ -e mnt ] ; then
        sudo rm -rf mnt
    fi

    mkdir -p mnt
    sudo mount -o loop out/os.img mnt
    sudo cp -r os/* mnt/
    sudo umount mnt
    sudo ./mksdcard -p dragonboard410c/linux/installer.txt -s $size_img -i out -o ${RELEASE_VERSION}_sd_install.img

    if [ ! -d $STORAGE_PATH ]; then
        mkdir $STORAGE_PATH
    fi

    cp ${RELEASE_VERSION}_sd_install.img $STORAGE_PATH

    # create archive for publishing
    gzip -c9 ${RELEASE_VERSION}_sd_install.img > ${RELEASE_VERSION}_sd_install.img.gz
    mv ${RELEASE_VERSION}_sd_install.img.gz $STORAGE_PATH"/."
}

# === [Main] List Official Build Version ============================================================
if [ $RSB_4760 == true ]; then
    MACHINE_LIST="$MACHINE_LIST 4760"
fi
if [ $EPC_R4761 == true ]; then
    MACHINE_LIST="$MACHINE_LIST 4761"
fi

NUM1=`expr $VERSION : 'V\([0-9]*\)'`
NUM2=`expr $VERSION : '.*[.]\([0-9]*\)'`
VERSION_NUM=$NUM1$NUM2

if [ $TARGET_OS == "Yocto" ]; then
    OS_PREFIX="L"
elif [ $TARGET_OS == "Debian" ]; then
    OS_PREFIX="D"
elif [ $TARGET_OS == "Android" ]; then
    OS_PREFIX="A"
    if [ "$1" == "" ]; then
        echo "Please input android output path!"
        exit 1
    fi
fi

get_installer_images

for NEW_MACHINE in $MACHINE_LIST
do
    RELEASE_VERSION="${NEW_MACHINE}${OS_PREFIX}IV${VERSION_NUM}"
    if [ $NEW_MACHINE == "4760" ]; then
        PRODUCT="RSB-4760"
    elif [ $NEW_MACHINE == "4761" ]; then
        PRODUCT="EPC-R4761"
    fi

    prepare_target_os
    make_os_img
done
