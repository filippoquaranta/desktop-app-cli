#!/bin/sh

# Usage example:
#   build-packages.sh -v 0.0.1

# To be able to build packages the 'fpm' tool shall be installed
# (https://fpm.readthedocs.io/en/latest/installing.html)

# Useful commands (Ubuntu):
#
# To view *.deb package content:
#     dpkg -c ivpn_1.0_amd64.deb
# List of installet packets:
#     dpkg --list [<mask>]
# Install package:
#     apt-get install <pkg-name>
# Remove packet:
#     dpkg --remove <packetname>
# Remove (2):
#     apt-get remove ivpn
#     apt-get purge curl
#     apt-get autoremove
# Remove repository (https://www.ostechnix.com/how-to-delete-a-repository-and-gpg-key-in-ubuntu/):
#     add-apt-repository -r ppa:wireguard/wireguard
#     apt update
# List of services:
#     systemctl --type=service
# Start service:
#     systemctl start ivpn-service
# Remove BROKEN package (which is unable to uninstall by normal ways)
#     sudo mv /var/lib/dpkg/info/ivpn.* /tmp/
#     sudo dpkg --remove --force-remove-reinstreq ivpn

cd "$(dirname "$0")"

# check result of last executed command
CheckLastResult()
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

if [ -z "$VERSION" ]
then
  echo "Usage:"
  echo "    $0 -v <version>"
  exit 1
fi

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
TMPDIRSRVC="$TMPDIR/srvc"
if [ -d "$TMPDIR" ]; then rm -Rf $TMPDIR; fi
mkdir -p $TMPDIR
mkdir -p $TMPDIRSRVC

cd $TMPDIRSRVC

echo "Preparing service..."
fpm -v $VERSION -n ivpn-service -s pleaserun -t dir --deb-no-default-config-files /usr/local/bin/ivpn-service


CreatePackage()
{
  PKG_TYPE=$1
  EXTRA_ARGS=$2

  cd $TMPDIR

  # Scripts order is different for different types of packages
  # DEB Install:
  #   (On Install)      (On Upgrade)
  #                     before_remove
  #   before_install    before_upgrade\before_install
  #                     after_remove
  #   after_install     after_upgrade\after_install
  #
  # DEB remove
  #   before_remove
  #   after_remove
  #
  # RPM Install:
  #   (On Install)      (On Upgrade)
  #   before_install    before_upgrade\before_install
  #   after_install     after_upgrade\after_install
  #                     before_remove
  #                     after_remove
  #
  # RPM remove
  #   before_remove
  #   after_remove
  #
  # NOTE! 'remove' scripts is using from old version!

  fpm -d openvpn $EXTRA_ARGS \
    --deb-no-default-config-files -s dir -t $PKG_TYPE -n ivpn -v $VERSION --url https://www.ivpn.net --license "GNU GPL3" \
    --template-scripts --template-value pkg=$PKG_TYPE \
    --vendor "Privatus Limited" --maintainer "Privatus Limited" \
    --description "$(printf "Client for IVPN service (https://www.ivpn.net)\nCommand line interface v$VERSION. Try 'ivpn' from command line.")" \
    --before-install "$SCRIPT_DIR/package_scripts/before-install.sh" \
    --after-install "$SCRIPT_DIR/package_scripts/after-install.sh" \
    --before-remove "$SCRIPT_DIR/package_scripts/before-remove.sh" \
    --after-remove "$SCRIPT_DIR/package_scripts/after-remove.sh" \
    $DAEMON_REPO_ABS_PATH/References/Linux/etc=/opt/ivpn/ \
    $DAEMON_REPO_ABS_PATH/References/Linux/scripts/_out_bin/ivpn-service=/usr/local/bin/ \
    $OUT_DIR/ivpn=/usr/local/bin/ \
    $TMPDIRSRVC/ivpn-service.dir/usr/share/pleaserun/=/usr/share/pleaserun
}

echo '---------------------------'
echo "DEB package..."
# to add dependency from another packet add extra arg "-d", example: "-d obfsproxy"
CreatePackage "deb"

echo '---------------------------'
echo "RPM package..."
CreatePackage "rpm"

echo '---------------------------'
echo "Copying compiled pachages to '$OUT_DIR'..."
mkdir -p $OUT_DIR
yes | cp -f $TMPDIR/*.* $OUT_DIR

set +e
