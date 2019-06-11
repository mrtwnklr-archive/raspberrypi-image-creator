#!/bin/bash

# Config
readonly PI_GPU_MEMORY=${1:-16}
readonly RASPBIAN_RELEASE_DATE=${2:-2019-04-09}
readonly RASPBIAN_IMAGE_DATE=${3:-2019-04-08}
readonly RASPBIAN_IMAGE=${RASPBIAN_IMAGE_DATE}-raspbian-stretch-lite
readonly RASPBIAN_IMAGE_URL=https://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-${RASPBIAN_RELEASE_DATE}/${RASPBIAN_IMAGE}.zip

readonly RASPBERRYPI_IMAGES_CACHE_DIR=~/.cache/raspberrypi_images
readonly TARGET_IMAGE_DIR=$(pwd)
readonly TARGET_IMAGE_PATH=${TARGET_IMAGE_DIR}/${RASPBIAN_IMAGE}.img


function download_images() {
    mkdir --parents "${RASPBERRYPI_IMAGES_CACHE_DIR}"
    
    pushd "${RASPBERRYPI_IMAGES_CACHE_DIR}" 1>/dev/null

    if [[ ! -f $(basename ${RASPBIAN_IMAGE_URL}) ]]
    then
        wget ${RASPBIAN_IMAGE_URL}
    fi

    popd 1>/dev/null
}

function mount_partition() {
    local partition_marker="${1}" ; shift
    local mount_point="${1}" ; shift

    local sector=$( fdisk --list "${TARGET_IMAGE_PATH}" | grep ${partition_marker} | awk '{ print $2 }' )
    local offset=$(( sector * 512 ))

    mkdir --parents "${mount_point}"

    sudo mount "${TARGET_IMAGE_PATH}" --options offset=${offset} "${mount_point}"
}

function get_mount_point_boot() {
    echo "${TARGET_IMAGE_DIR}/imageMountBoot"
}

function mount_boot_partition() {
    mount_partition "FAT32" "$(get_mount_point_boot)"
}

function unmount_boot_partition() {
    sudo umount "$(get_mount_point_boot)"
    sudo rm -rf "$(get_mount_point_boot)"
}

function get_mount_point_root() {
    echo "${TARGET_IMAGE_DIR}/imageMountRoot"
}

function mount_root_partition() {
    mount_partition "Linux" "$(get_mount_point_root)"
}

function unmount_root_partition() {
    sudo umount "$(get_mount_point_root)"
    sudo rm -rf "$(get_mount_point_root)"
}

function configure_ssh() {
    mount_boot_partition

    sudo touch "$(get_mount_point_boot)/ssh"

    unmount_boot_partition
}

function configure_memory_split() {

    mount_boot_partition

    echo "gpu_mem=${PI_GPU_MEMORY}" | sudo tee "$(get_mount_point_boot)/config.txt"

    unmount_boot_partition
}

function configure_wifi() {

    if [[ ! -z ${WIFI_PASSWORD} ]]
    then
        mount_root_partition

        cat >> "${TARGET_IMAGE_DIR}/wpa_supplicant.conf" << EOF
country=DE
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
    scan_ssid=1
    ssid="${WIFI_SSID}"
    psk="${WIFI_PASSWORD}"
}
EOF

        sudo cp --force "${TARGET_IMAGE_DIR}/wpa_supplicant.conf" "$(get_mount_point_root)/etc/wpa_supplicant/wpa_supplicant.conf"

        rm "${TARGET_IMAGE_DIR}/wpa_supplicant.conf"

        unmount_root_partition
    fi
}

function prepare_image() {
    if [[ ! -f "${TARGET_IMAGE_PATH}" ]]
    then
        unzip "${RASPBERRYPI_IMAGES_CACHE_DIR}/$(basename ${RASPBIAN_IMAGE_URL})" -d "${TARGET_IMAGE_DIR}"
    fi

    configure_ssh
    configure_memory_split
    configure_wifi
}


if [[ ! -d "${TARGET_IMAGE_DIR}" ]]
then
    mkdir --parents "${TARGET_IMAGE_DIR}"
fi

if [[ ! -f "${TARGET_IMAGE_PATH}" ]]
then
    download_images
fi

prepare_image