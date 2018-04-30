#!/bin/bash
#
# Author(s): Alvaro Saurin <alvaro.saurin@suse.com>
#
# Copyright (c) 2017 SUSE LINUX GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.
#
# NOTE: we assume that "images/caasp-beta.qcow2" will end up in
#       a volume named "caasp-beta.qcow2"
#
IMG_SRC_BASE="http://download.suse.de/install/SUSE-CaaSP-1.0-Beta3/"
IMG_SRC_FILENAME=
IMG_REGEX="SUSE-CaaS-Platform.*-KVM-and-Xen.*x86_64.*Build"
IMG_GLOB=$(echo "$IMG_REGEX" | sed -e 's|\.\*|\*|g')*.qcow2
IMG_LOCAL_NAME="images/beta/caasp.qcow2"
IMG_REFRESH=1
IMG_PURGE=
UPLOAD_IMG=
UPLOAD_POOL=

LOCAL_VIRSH="sudo virsh"
REM_VIRSH="virsh"

WGET="wget"

RUN_AT=

# ssh options
SSH_OPTS="-q -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oConnectTimeout=10"


while [ $# -gt 0 ] ; do
  case $1 in
    --src-base|--source-base|-s)
      IMG_SRC_BASE=$2
      shift
      ;;
    --src-filename)
      IMG_SRC_FILENAME=$2
      shift
      ;;
    --refresh)
      case $2 in
      False|false|FALSE|No|no|NO|0)
        echo "(disabling refresh for images)"
        IMG_REFRESH=
        ;;
      esac
      shift
      ;;
    --local|--L)
      IMG_LOCAL_NAME=$2
      shift
      ;;
    --run-at)
      RUN_AT=$2
      shift
      ;;
    --purge)
      IMG_PURGE=1
      ;;
    --upload-to-img)
      UPLOAD_IMG=$2
      shift
      ;;
    --upload-to-pool)
      UPLOAD_POOL=$2
      shift
      ;;
    --debug)
      set -x
      ;;
    *)
      echo "Unknown argument $1"
      exit 1
      ;;
  esac
  shift
done

############################################

# wget regular opts: use timestamps and try to continue downloads
WGET_OPTS="-N -c"

# wget recursive opts
WGET_REC_OPTS="-r \
               --no-directories \
               --no-host-directories \
               --no-parent \
               --accept=*.qcow2 \
               --accept-regex=$IMG_REGEX"

img_vol_name=$(basename "$IMG_LOCAL_NAME")
img_down_dir=$(dirname "$IMG_LOCAL_NAME")

images() {
  ls -1 -t $IMG_GLOB 2>/dev/null
}

has_volume() {
  find . -name "$IMG_GLOB" &>/dev/null
}

rem_cmd() {
  if [ -n "$RUN_AT" ] ; then
    ssh $SSH_OPTS $RUN_AT "$@"
  else
    exec $@
  fi
}

virsh_cmd() {
  if [ -n "$RUN_AT" ] ; then
    rem_cmd $REM_VIRSH $@
  else
    $LOCAL_VIRSH $@
  fi
}

if [ -n "$RUN_AT" ] ; then
  [ -n "$IMG_SRC_FILENAME" ] || { echo >&2 "FATAL: filename required. Aborting." ; exit 1 ; }

  echo ">>> Downloading at $RUN_AT"
  rem_cmd "$WGET --progress=dot -O '$IMG_LOCAL_NAME' '$IMG_SRC_BASE/$IMG_SRC_FILENAME'"
  local_image_to_upload=$IMG_LOCAL_NAME
else
  echo ">>> Using \"$img_down_dir\" as downloads directory"
  mkdir -p "$img_down_dir"
  cd "$img_down_dir"

  if [ -n "$IMG_REFRESH" ] || ! has_volume "$img_vol_name" ; then
    echo ">>> Downloading the latest image for importing as $img_vol_name"
    hash $WGET 2>/dev/null || { echo >&2 "FATAL: wget required. Aborting." ; exit 1 ; }
    $WGET $WGET_OPTS $WGET_REC_OPTS $IMG_SRC_BASE
    [ $? -eq 0 ] || { echo >&2 "FATAL: download failed. Aborting." ; exit 1 ; }
  fi

  latest_image="$(images | head -n1 2>/dev/null)"
  [ -n "$latest_image" ] || { echo >&2 "FATAL: could not determine the latest image (with glob $IMG_GLOB). Aborting." ; exit 1 ; }

  echo ">>> Latest image: $img_vol_name -> $latest_image"
  rm -f "$img_vol_name"
  ln -sf "$latest_image" "$img_vol_name"

  if [ -n "$IMG_PURGE" ] ; then
    echo ">>> Moving previous downloads to /tmp"
    images | tail -n-2 2>/dev/null | xargs --no-run-if-empty -I{} mv -f {} /tmp/
  fi

  local_image_to_upload=$latest_image
fi


if [ -n "$UPLOAD_IMG" ] ; then
  [ -n "$UPLOAD_POOL" ] || { echo >&2 "FATAL: pool required. Aborting." ; exit 1 ; }

  echo ">>> Removing previous volume $UPLOAD_IMG"
  virsh_cmd vol-delete --pool "$UPLOAD_POOL" "$UPLOAD_IMG" || /bin/true

  echo ">>> Creating new volume $UPLOAD_IMG"
  size=$(rem_cmd "stat -c%s $IMG_LOCAL_NAME")
  if [ $? -ne 0 ] ; then
    echo >&2 "FATAL: could not get file size for $IMG_LOCAL_NAME."
    exit 1
  fi

  virsh_cmd vol-create-as "$UPLOAD_POOL" "$UPLOAD_IMG" $size --format raw
  if [ $? -ne 0 ] ; then
    echo >&2 "FATAL: could not create volume $UPLOAD_IMG. Aborting."
    exit 1
  fi

  echo ">>> Uploading $local_image_to_upload to $UPLOAD_POOL/$UPLOAD_IMG"
  virsh_cmd vol-upload --pool "$UPLOAD_POOL" "$UPLOAD_IMG" "$local_image_to_upload"
  if [ $? -ne 0 ] ; then
    echo >&2 "FATAL: could not upload to volume $UPLOAD_IMG from $local_image_to_upload. Aborting."
    exit 1
  fi

  echo ">>> Giving some time to the upload"
  sleep 20
fi

echo ">>> Done!."
exit 0
