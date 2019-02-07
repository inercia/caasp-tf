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
# NOTE: we assume that "images/kubic-beta.qcow2" will end up in
#       a volume named "kubic-beta.qcow2"
#
IMG_SRC_BASE=""
IMG_SRC_FILENAME=

# a component in the image filename
# note: depending on the component, some features will be availiable or not
# IMG_REGEX="kubeadm-cri-o-hardware"
# IMG_REGEX="MicroOS-cri-o-kvm-and-xen"
# IMG_REGEX="MicroOS-docker-kvm-and-xen"
IMG_REGEX=""

IMG_LOCAL_NAME="images/kubic.qcow2"
IMG_REFRESH=1
IMG_PURGE=
UPLOAD_IMG=
UPLOAD_POOL=
UPLOAD_TIME=20

LOCAL_VIRSH="virsh"
REM_VIRSH="virsh"
VIRSH_ARGS=""

WGET="wget"
# wget regular opts: 1) timestamps 2) try to continue downloads 3) progress on megas
WGET_OPTS="-N -c --progress=dot:mega"
# wget recursive opts
WGET_REC_OPTS="-r \
               --no-directories \
               --no-host-directories \
               --no-parent \
               --accept=*.qcow2"

RUN_AT=

# ssh options
SSH_OPTS="-q -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oConnectTimeout=10"

log()   { echo >&2 "### $@ " ;  }
abort() { echo >&2 "!!! FATAL: $@. Aborting." ; exit 1 ; }

while [ $# -gt 0 ] ; do
  case $1 in
    --libvirt-uri|--libvirt|--uri|--connect)
      VIRSH_ARGS="$VIRSH_ARGS --connect=$2"
      shift
      ;;
    --src-base|--source-base|-s|--img-src-base)
      IMG_SRC_BASE=$2
      shift
      ;;
    --src-filename|--img-src-filename)
      IMG_SRC_FILENAME=$2
      shift
      ;;
    --refresh|--img-refresh)
      case $2 in
      False|false|FALSE|No|no|NO|0)
        log "(disabling refresh for images)"
        IMG_REFRESH=
        ;;
      esac
      shift
      ;;
    --regex|--img-regex)
      IMG_REGEX="$2"
      shift
      ;;
    --local|--L|--img-local)
      IMG_LOCAL_NAME=$2
      shift
      ;;
    --run-at|--img-run-at)
      RUN_AT=$2
      shift
      ;;
    --purge|--img-purge)
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
          LOCAL_VIRSH="virsh"
          REM_VIRSH="virsh"
          ;;
        *)
          log "Unknown --sud-virsh argument '$2'"
          exit 1
          ;;
      esac
      shift
      ;;
    *)
      echo "Unknown argument '--$1'"
      exit 1
      ;;
  esac
  shift
done

############################################

IMG_GLOB=*$(echo "$IMG_REGEX" | sed -e 's|\.\*|\*|g')*.qcow2
WGET_REC_OPTS="$WGET_REC_OPTS --accept-regex=$IMG_REGEX"

[ -n "$IMG_LOCAL_NAME" ] || IMG_LOCAL_NAME=$(mktemp /tmp/kubic-image.XXXXXX)

images() {
  ls -1 -t $IMG_GLOB 2>/dev/null
}

latest_image() {
  echo "$(images | head -n1 2>/dev/null)"
}

download_image() {
  log "Downloading the latest image for importing as $1"
  hash $WGET 2>/dev/null || abort "wget required"
  $WGET $WGET_OPTS $WGET_REC_OPTS "$IMG_SRC_BASE"
  [ $? -eq 0 ] || abort "download failed"
}

rem_cmd() {
  if [ -n "$RUN_AT" ] ; then
    ssh $SSH_OPTS $RUN_AT "$@"
  else
    exec $@
  fi
}

# run a virshh command, maybe local or remotely
virsh_cmd() {
  if [ -n "$RUN_AT" ] ; then
    rem_cmd $REM_VIRSH $VIRSH_ARGS $@
  else
    $LOCAL_VIRSH $VIRSH_ARGS $@
  fi
}

# determine the latest image in a HTTP directory
latest_image_in_url() {
  python - <<END
from bs4 import BeautifulSoup
import requests
import re

url = "$IMG_SRC_BASE"
ext = 'qcow2'

def listFD(url, ext=''):
    page = requests.get(url).text
    soup = BeautifulSoup(page, 'html.parser')
    return set([url + '/' + node.get('href')
            for node in soup.find_all('a')
            if re.match(".*" + "$IMG_REGEX" + ".*" + ext + "$", node.get('href'))])

for file in listFD(url, ext):
    print file
END
}

############################################

IMG_SRC="$(latest_image_in_url)"
log "Latest image seems to be: $IMG_SRC"
[ -n "$IMG_SRC_FILENAME" ] && IMG_SRC="$IMG_SRC_BASE/$IMG_SRC_FILENAME"

if [ -n "$RUN_AT" ] ; then
  log "Downloading at $RUN_AT"
  IMG_LOCAL_NAME=$(rem_cmd mktemp /tmp/kubic-image.XXXXXX)
  log "... ignoring --local argument: will download to $IMG_LOCAL_NAME"
  rem_cmd "$WGET $WGET_OPTS -O $IMG_LOCAL_NAME $IMG_SRC"
else
  IMG_LOCAL_BASENAME=$(basename "$IMG_LOCAL_NAME")
  IMG_LOCAL_DIRNAME=$(dirname "$IMG_LOCAL_NAME")

  log "Using \"$IMG_LOCAL_DIRNAME\" as local directory for downloads"
  mkdir -p "$IMG_LOCAL_DIRNAME"

  pushd $(pwd)
  cd "$IMG_LOCAL_DIRNAME"

  # if there are no images, force the refresh
  [ -n "$(latest_image)" ] || IMG_REFRESH="true"

  # download the image
  [ -z "$IMG_REFRESH" ] || $WGET $WGET_OPTS -O $IMG_LOCAL_NAME $IMG_SRC

  # set a link pointing to the latest image in the images directory
  [ -n "$(latest_image)" ] || abort "could not determine the latest image (using glob $IMG_GLOB)"
  l=$(latest_image)
  log "Latest image: $IMG_LOCAL_BASENAME -> $l"
  rm -f "$IMG_LOCAL_BASENAME"
  ln -sf "$l" "$IMG_LOCAL_BASENAME"
  IMG_LOCAL_NAME=$(realpath $l)

  # purge previous images (optional)
  if [ -n "$IMG_PURGE" ] ; then
    log "Moving previous downloads to /tmp"
    images | tail -n-2 2>/dev/null | xargs --no-run-if-empty -I{} mv -f {} /tmp/
  fi

  popd
fi

# perform an upload to the libvirt pool (optional)
if [ -n "$UPLOAD_IMG" ] ; then
  [ -n "$UPLOAD_POOL" ] || \
    abort "--pool required ... did you forget to set the right Terraform variables?"

  log "Removing previous volume $UPLOAD_IMG (ignoring errors)"
  virsh_cmd vol-delete --pool "$UPLOAD_POOL" "$UPLOAD_IMG" 2>/dev/null || /bin/true

  log "Creating new volume $UPLOAD_IMG"
  size=$(rem_cmd "stat -c%s $IMG_LOCAL_NAME")
  [ $? -ne 0 ] && abort "could not get file size for $IMG_LOCAL_NAME."

  virsh_cmd vol-create-as "$UPLOAD_POOL" "$UPLOAD_IMG" $size --format raw || \
    abort "could not create volume $UPLOAD_IMG (provided with --upload-to-img)"

  log "Uploading $IMG_LOCAL_NAME to [$UPLOAD_POOL]:$UPLOAD_IMG"
  virsh_cmd vol-upload --pool "$UPLOAD_POOL" "$UPLOAD_IMG" "$IMG_LOCAL_NAME" || \
    abort "could not upload to volume $UPLOAD_IMG (provided with --upload-to-img) from $IMG_LOCAL_NAME"

  log "Giving some time to the upload to finish... (will wait $UPLOAD_TIME seconds)"
  sleep $UPLOAD_TIME

  log "Current volumes in pool:$UPLOAD_POOL"
  virsh_cmd vol-list --pool "$UPLOAD_POOL"
fi

log "Done!."
exit 0
