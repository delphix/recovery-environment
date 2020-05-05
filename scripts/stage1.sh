#!/bin/bash

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
sudo mkdir img
sudo chmod 0755 img

#
# Perform installation process
#
cd $base
sudo rsync -a ../base_img/ $img/

sudo mkdir -p $img/bin/

for file in /bin/busybox /bin/kmod /bin/systemd-tmpfiles /bin/udevadm \
	/lib/systemd/systemd-networkd /lib/systemd/systemd-udevd \
	/usr/sbin/dropbear /usr/lib/dropbear/dropbearconvert; do
	sudo mkdir -p $img/$(dirname $file)
	sudo rsync -a $file $img/$file
	./get_deps $img/$file $img
done
sudo ln -rs $img/bin/busybox $img/bin/sh

sudo rsync -aL /lib64/ld-linux-x86-64.so.2 $img/lib64/
sudo mkdir -p $img/lib/x86_64-linux-gnu/
ls $img/lib/x86_64-linux-gnu/
sudo rsync -aL /lib/x86_64-linux-gnu/libnss* $img/lib/x86_64-linux-gnu/
ls $img/lib/x86_64-linux-gnu/
sudo rsync -a /lib/modprobe.d $img/lib/

sudo rsync -a /etc/{group,passwd,shadow}{,-} $img/etc/
sudo sed -i 's@/bin/bash@/bin/sh@g' $img/etc/passwd{,-}
sudo sed -i 's@/opt/delphix/server/bin/supportlogin@/bin/sh@g' $img/etc/passwd{,-}
sudo rsync -a /etc/{shells,nsswitch.conf} $img/etc/
sudo mkdir -p $img/etc/systemd/network
sudo rsync -a /etc/network/ $img/etc/network/
sudo rsync -a /etc/dhcp/ $img/etc/dhcp/
sudo mkdir -p $img/etc/dropbear

cd $img
sudo find . -print0 | sudo cpio --verbose --null --create --format=newc | gzip -7 | sudo tee $target >/dev/null 2>/dev/null
