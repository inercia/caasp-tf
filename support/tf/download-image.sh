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
IMG_LOCAL_NAME="images/devel/caasp.qcow2"
IMG_REFRESH=1
IMG_PURGE=
UPLOAD_IMG=
UPLOAD_POOL=

LOCAL_VIRSH="virsh"
REM_VIRSH="virsh"

WGET="wget"

RUN_AT=

# ssh options
SSH_OPTS="-q -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oConnectTimeout=10"

log()   { echo >&2 "### $@ " ;  }
abort() { echo >&2 "!!! FATAL: $@. Aborting." ; exit 1 ; }

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
    --sudo-virsh)
      case $2 in
      local)
        LOCAL_VIRSH="sudo virsh"
        ;;
      remote)
        REM_VIRSH="sudo virsh"
        ;;
      both)
        LOCAL_VIRSH="sudo virsh"
        REM_VIRSH="sudo virsh"
        ;;
      none)
        ;;
      esac
      shift
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

[ -n "$IMG_LOCAL_NAME" ] || IMG_LOCAL_NAME=$(mktemp /tmp/caasp-image.XXXXXX)

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

############################################

if [ -n "$RUN_AT" ] ; then
  [ -n "$IMG_SRC_FILENAME" ] || abort "--src-filename required when using --run-at"

  log "Downloading at $RUN_AT"
  IMG_LOCAL_NAME=$(rem_cmd mktemp /tmp/caasp-image.XXXXXX)
  log "... ignoring --local argument: will download to $IMG_LOCAL_NAME"
  rem_cmd "$WGET --no-verbose -O '$IMG_LOCAL_NAME' '$IMG_SRC_BASE/$IMG_SRC_FILENAME'"
else
  IMG_LOCAL_BASENAME=$(basename "$IMG_LOCAL_NAME")
  IMG_LOCAL_DIRNAME=$(dirname "$IMG_LOCAL_NAME")

  log "Using \"$IMG_LOCAL_DIRNAME\" as local directory for downloads"
  mkdir -p "$IMG_LOCAL_DIRNAME"

  pushd $(pwd)
  cd "$IMG_LOCAL_DIRNAME"

  if [ -n "$IMG_REFRESH" ] || ! has_volume "$IMG_LOCAL_BASENAME" ; then
    log "Downloading the latest image for importing as $IMG_LOCAL_BASENAME"
    hash $WGET 2>/dev/null || abort "wget required"
    $WGET $WGET_OPTS $WGET_REC_OPTS $IMG_SRC_BASE
    [ $? -eq 0 ] || abort "download failed"
  fi

  latest_image="$(images | head -n1 2>/dev/null)"
  [ -n "$latest_image" ] || abort "could not determine the latest image (with glob $IMG_GLOB)"

  log "Latest image: $IMG_LOCAL_BASENAME -> $latest_image"
  rm -f "$IMG_LOCAL_BASENAME"
  ln -sf "$latest_image" "$IMG_LOCAL_BASENAME"

  if [ -n "$IMG_PURGE" ] ; then
    log "Moving previous downloads to /tmp"
    images | tail -n-2 2>/dev/null | xargs --no-run-if-empty -I{} mv -f {} /tmp/
  fi

  IMG_LOCAL_NAME=$(realpath $latest_image)
  popd
fi

if [ -n "$UPLOAD_IMG" ] ; then
  [ -n "$UPLOAD_POOL" ] || abort "--pool required"

  log "Removing previous volume $UPLOAD_IMG (ignoring errors)"
  virsh_cmd vol-delete --pool "$UPLOAD_POOL" "$UPLOAD_IMG" 2>/dev/null || /bin/true

  log "Creating new volume $UPLOAD_IMG"
  size=$(rem_cmd "stat -c%s $IMG_LOCAL_NAME")
  [ $? -ne 0 ] && abort "could not get file size for $IMG_LOCAL_NAME."

  virsh_cmd vol-create-as "$UPLOAD_POOL" "$UPLOAD_IMG" $size --format raw || \
    abort "could not create volume $UPLOAD_IMG (provided with --upload-to-img)"

  log "Uploading $IMG_LOCAL_NAME to $UPLOAD_POOL/$UPLOAD_IMG"
  virsh_cmd vol-upload --pool "$UPLOAD_POOL" "$UPLOAD_IMG" "$IMG_LOCAL_NAME" || \
    abort "could not upload to volume $UPLOAD_IMG (provided with --upload-to-img) from $IMG_LOCAL_NAME"

  log "Giving some time to the upload"
  sleep 20
fi

log "Done!."
exit 0
