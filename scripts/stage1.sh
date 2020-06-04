#!/bin/bash
#
# This script is run at package build time to create the base recovery
# environment image. This image is then modified by the postinst script when
# the package is installed, and the recovery_sync script is used on the
# destination system to keep it up to date with configuration changes.
#
# shellcheck disable=SC2001

set -euxo pipefail

function die() {
	echo "$1" >&2
	exit 1
}

function get_deps() {
	(ldd "$1" 2>/dev/null || true) | while read -r line; do
		if ! echo "$line" | grep "=>" &>/dev/null; then
			continue
		fi
		dep=$(echo "$line" | sed 's/.*=> \(.*\) (.*/\1/')
		dn=$(dirname "$dep")
		mkdir -p "$2/$dn"
		rsync -aL "$dep" "$2/$dep"
	done
}

[[ $# -eq 1 ]] || die "Illegal number of parameters"
target="$1"
workdir=$(mktemp -d)
img="$workdir/img"
base="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

#
# Set up working directory
#
cd "$workdir"
mkdir img
chmod 0755 img

apt-get download dropbear-bin=2017.75-3build1 \
	busybox-static=1:1.27.2-2ubuntu3.2 \
	kmod=24-1ubuntu3.4 \
	systemd=237-3ubuntu10.40 \
	udev=237-3ubuntu10.40 \
	libc6=2.27-3ubuntu1
for file in *.deb; do dpkg-deb -x "$file" .; done

#
# Perform installation process
#
cd "$base"
rsync -a ../base_img/ "$img/"

mkdir -p "$img/bin/"

for file in /bin/busybox /bin/kmod /bin/systemd-tmpfiles /bin/udevadm \
	/lib/systemd/systemd-networkd /lib/systemd/systemd-udevd \
	/usr/sbin/dropbear /usr/lib/dropbear/dropbearconvert; do
	mkdir -p "$img/$(dirname $file)"
	rsync -a "$workdir/$file" "$img/$file"
	get_deps "$img/$file" "$img"
done
ln -rs "$img/bin/busybox" "$img/bin/sh"

rsync -aL "$workdir/lib64/ld-linux-x86-64.so.2" "$img/lib64/"
mkdir -p "$img/lib/x86_64-linux-gnu/"
rsync -aL "$workdir"/lib/x86_64-linux-gnu/libnss* "$img/lib/x86_64-linux-gnu/"
rsync -a "$workdir/lib/modprobe.d" "$img/lib/"

mkdir -p "$img"/etc/{systemd/network,network,dhcp}
mkdir -p "$img/etc/dropbear"

cd "$img"
find . -print0 | cpio --verbose --null --create --format=newc | gzip -7 | tee "$target" >/dev/null 2>/dev/null
