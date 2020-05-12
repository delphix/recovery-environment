#!/bin/bash
#
# This script is run at package build time to create the base recovery
# environment image. This image is then modified by the postinst script when
# the package is installed, and the recovery_sync script is used on the
# destination system to keep it up to date with configuration changes.
#

set -euxo pipefail

function die
{
	echo "$1" >&2
	exit 1
}

[[ $# -eq 1 ]] || die "Illegal number of parameters"
target="$1"
workdir=$(mktemp -d)
img=$workdir/img
base="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

#
# Set up working directory
#
cd $workdir
mkdir img
chmod 0755 img

#
# Perform installation process
#
cd $base
rsync -a ../base_img/ $img/

mkdir -p $img/bin/

for file in /bin/busybox /bin/kmod /bin/systemd-tmpfiles /bin/udevadm \
	/lib/systemd/systemd-networkd /lib/systemd/systemd-udevd \
	/usr/sbin/dropbear /usr/lib/dropbear/dropbearconvert; do
	mkdir -p $img/$(dirname $file)
	rsync -a $file $img/$file
	./get_deps $img/$file $img
done
ln -rs $img/bin/busybox $img/bin/sh

rsync -aL /lib64/ld-linux-x86-64.so.2 $img/lib64/
mkdir -p $img/lib/x86_64-linux-gnu/
ls $img/lib/x86_64-linux-gnu/
rsync -aL /lib/x86_64-linux-gnu/libnss* $img/lib/x86_64-linux-gnu/
ls $img/lib/x86_64-linux-gnu/
rsync -a /lib/modprobe.d $img/lib/

rsync -a /etc/{shells,nsswitch.conf} $img/etc/
mkdir -p $img/etc/systemd/network
rsync -a /etc/network/ $img/etc/network/
rsync -a /etc/dhcp/ $img/etc/dhcp/
mkdir -p $img/etc/dropbear

cd $img
find . -print0 | cpio --verbose --null --create --format=newc | gzip -7 | tee $target >/dev/null 2>/dev/null
