#!/bin/bash
#
# Copyright (C) 2018-2020 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

DEVICE_COMMON=universal7880-common
VENDOR=samsung

# Load extractutils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$MY_DIR" ]]; then MY_DIR="$PWD"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

KANG=
SECTION=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        -n | --no-cleanup )
                CLEAN_VENDOR=false
                ;;
        -k | --kang )
                KANG="--kang"
                ;;
        -s | --section )
                SECTION="${2}"; shift
                CLEAN_VENDOR=false
                ;;
        * )
                SRC="${1}"
                ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

# Initialize the helper
setup_vendor "${DEVICE_COMMON}" "${VENDOR}" "${ANDROID_ROOT}" true "${CLEAN_VENDOR}"

extract "${MY_DIR}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"

# Fix proprietary blobs
BLOB_ROOT="$ANDROID_ROOT"/vendor/"$VENDOR"/"$DEVICE_COMMON"/proprietary

# Replace protobuf with vndk29 compat libs for specified libs
"${PATCHELF}" --replace-needed libprotobuf-cpp-lite.so libprotobuf-cpp-lite-v29.so $BLOB_ROOT/vendor/lib/libwvhidl.so
"${PATCHELF}" --replace-needed libprotobuf-cpp-lite.so libprotobuf-cpp-lite-v29.so $BLOB_ROOT/vendor/lib/mediadrm/libwvdrmengine.so

# Replace libvndsecril-client with libsecril-client
patchelf --replace-needed libvndsecril-client.so libsecril-client.so $BLOB_ROOT/vendor/lib/libwrappergps.so
patchelf --replace-needed libvndsecril-client.so libsecril-client.so $BLOB_ROOT/vendor/lib64/libwrappergps.so

# Use libhidlbase-v32 for select Android P blobs
patchelf --replace-needed libhidlbase.so libhidlbase-v32.so $BLOB_ROOT/vendor/bin/hw/android.hardware.bluetooth@1.0-service-qti

# RIL patches
xxd -p -c0 $BLOB_ROOT/vendor/lib64/libsec-ril-dsds.so | sed "s/600e40f9820c8052e10315aae30314aa/600e40f9820c8052e10315aa030080d2/g" | xxd -r -p > $BLOB_ROOT/proprietary/vendor/lib64/libsec-ril-dsds.so.patched
mv $BLOB_ROOT/vendor/lib64/libsec-ril-dsds.so.patched $BLOB_ROOT/proprietary/vendor/lib64/libsec-ril-dsds.so

xxd -p -c0 $BLOB_ROOT/vendor/lib64/libsec-ril.so | sed "s/600e40f9820c8052e10315aae30314aa/600e40f9820c8052e10315aa030080d2/g" | xxd -r -p > $BLOB_ROOT/proprietary/vendor/lib64/libsec-ril.so.patched
mv $BLOB_ROOT/vendor/lib64/libsec-ril.so.patched $BLOB_ROOT/proprietary/vendor/lib64/libsec-ril.so

"${MY_DIR}/setup-makefiles.sh"
