#!/bin/bash

# To be able to build packages the 'fpm' tool shall be installed 
# (https://fpm.readthedocs.io/en/latest/installing.html)

# Useful commands:
#   To view *.deb package content:
#     dpkg -c ivpn_1.0_amd64.deb

cd "$(dirname "$0")"

# check result of last executed command
function CheckLastResult
{
  if ! [ $? -eq 0 ]
  then #check result of last command
    if [ -n "$1" ]
    then
      echo $1
    else
      echo "FAILED"
    fi
    exit 1
  fi
}

SCRIPT_DIR="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
OUT_DIR="$SCRIPT_DIR/_out_bin"

DAEMON_REPO_ABS_PATH=$("./../config/daemon_repo_local_path_abs.sh")
CheckLastResult "Failed to determine location of IVPN Daemon sources. Plase check 'config/daemon_repo_local_path.txt'"

# ---------------------------------------------------------
# version info variables
VERSION=""
DATE="$(date "+%Y-%m-%d")"
COMMIT="$(git rev-list -1 HEAD)"

# reading version info from arguments
while getopts ":v:" opt; do
  case $opt in
    v) VERSION="$OPTARG"
    ;;
#    \?) echo "Invalid option -$OPTARG" >&2
#   ;;
  esac
done
echo '---------------------------'
echo "Building IVPN Daemon ($DAEMON_REPO_ABS_PATH)...";
echo '---------------------------'
$DAEMON_REPO_ABS_PATH/References/Linux/scripts/build-all.sh -v $VERSION
CheckLastResult "ERROR building IVPN Daemon"

echo '---------------------------'
echo "Building IVPN CLI ...";
echo '---------------------------'
$SCRIPT_DIR/build.sh -v $VERSION
CheckLastResult "ERROR building IVPN CLI"

echo "======================================================"
echo "============== Building packages ====================="
echo "======================================================"

set -e

TMPDIR="$SCRIPT_DIR/_tmp"
if [ -d "$TMPDIR" ]; then rm -Rf $TMPDIR; fi
mkdir -p $TMPDIR

cd $TMPDIR

echo "DEB package..."
fpm --deb-no-default-config-files -s dir -t deb -n ivpn -v $VERSION --url https://www.ivpn.net --license "GNU GPL3" \
  --description "Client for IVPN service (https://www.ivpn.net)" \
  $DAEMON_REPO_ABS_PATH/References/Linux/etc=/opt/ivpn/ \
  $DAEMON_REPO_ABS_PATH/References/Linux/obfsproxy=/opt/ivpn/ \
  $DAEMON_REPO_ABS_PATH/References/Linux/scripts/_out_bin/ivpn-service=/usr/local/bin/ \
  $OUT_DIR/ivpn=/usr/local/bin/

echo '---------------------------'

echo "RPM package..."
fpm --deb-no-default-config-files -s dir -t rpm -n ivpn -v $VERSION --url https://www.ivpn.net --license "GNU GPL3" \
  --description "Client for IVPN service (https://www.ivpn.net)" \
  $DAEMON_REPO_ABS_PATH/References/Linux/etc=/opt/ivpn/ \
  $DAEMON_REPO_ABS_PATH/References/Linux/obfsproxy=/opt/ivpn/ \
  $DAEMON_REPO_ABS_PATH/References/Linux/scripts/_out_bin/ivpn-service=/usr/local/bin/ \
  $OUT_DIR/ivpn=/usr/local/bin/

mkdir -p $OUT_DIR
yes | cp -rf $TMPDIR/* $OUT_DIR

set +e