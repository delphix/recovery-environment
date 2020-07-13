#!/bin/bash
#
# This script is run at package build time to create the base recovery
# environment image. This image is then modified by the postinst script when
# the package is installed, and the recovery_sync script is used on the
# destination system to keep it up to date with configuration changes.
#
# shellcheck disable=SC2001
# shellcheck disable=SC2086
# shellcheck disable=SC2046

set -euxo pipefail

function die() {
	echo "$1" >&2
	exit 1
}

function get_deps() {
	local binary="$1"
	local output="$2"
	local line=""
	#
	# Cause ldd to search paths inside of the workdir before searching
	# system paths. Unfortunately, we can't easily prevent ldd from
	# searching the normal paths if it fails to find its dependecies, but
	# that shouldn't happen as long as apt correctly derives the recursive
	# dependency list.
	#
	sudo rm /etc/ld.so.cache
	sudo ldconfig
	(LD_LIBRARY_PATH="$(ldconfig -v 2>/dev/null | grep -v ^$'\t' | sed "s@^@$workdir@" | tr -d '\n'):$workdir/lib/systemd" \
		ldd "$binary" 2>/dev/null || true) | while read -r line; do
		if ! echo "$line" | grep "=>" &>/dev/null; then
			continue
		fi
		local dep=""
		dep=$(echo "$line" | sed 's/.*=> \(.*\) (.*/\1/')

		[[ "$dep" =~ $workdir ]] || die "ldd found dependency outside of workdir"
		dep=$(realpath -s --relative-to="$workdir" $dep)
		local dn=""
		dn=$(dirname "$dep")
		mkdir -p "$output/$dn"
		rsync -aL "$workdir/$dep" "$output/$dep"
	done
}

[[ $# -eq 1 ]] || die "Illegal number of parameters"
target="$1"
workdir=$(mktemp -d)
img="$workdir/img"
base="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
repo="$(pwd)"

#
# Set up working directory
#
cd "$workdir"
mkdir img
chmod 0755 img

PACKAGES="dropbear-bin \
	busybox-static \
	kmod \
	systemd \
	udev \
	libssl1.1 \
	nginx-extras"

apt-get download $(apt-cache depends --recurse --no-recommends --no-suggests \
	--no-conflicts --no-breaks --no-replaces --no-enhances \
	${PACKAGES} | grep "^\w")

for file in *.deb "$repo"/external-debs/*.deb; do dpkg-deb -x "$file" .; done

#
# Perform installation process
#
cd "$base"
rsync -a ../base_img/ "$img/"

mkdir -p "$img/bin/"

for file in /bin/busybox /bin/kmod /bin/systemd-tmpfiles /bin/udevadm \
	/lib/systemd/systemd-networkd /lib/systemd/systemd-udevd \
	/usr/sbin/dropbear /usr/lib/dropbear/dropbearconvert /sbin/zfs \
	/sbin/zpool /sbin/zdb /usr/sbin/nginx; do
	mkdir -p "$img/$(dirname $file)"
	rsync -a "$workdir/$file" "$img/$file"
	get_deps "$img/$file" "$img"
done
ln -rs "$img/bin/busybox" "$img/bin/sh"
ln -rs "$img/bin/sh" "$img/bin/bash"

rsync -aL "$workdir/lib64/ld-linux-x86-64.so.2" "$img/lib64/"
mkdir -p "$img/usr/share/nginx"
rsync -aL "$workdir/usr/share/nginx/modules" "$img/usr/share/nginx/"
rsync -aL "$workdir/etc/nginx" "$img/etc/"
rm "$img/etc/nginx/nginx.conf"
mkdir -p "$img/lib/x86_64-linux-gnu/"
rsync -aL "$workdir"/lib/x86_64-linux-gnu/libnss* "$img/lib/x86_64-linux-gnu/"
rsync -a "$workdir/lib/modprobe.d" "$img/lib/"

mkdir -p "$img"/etc/{systemd/network,network,dhcp}
mkdir -p "$img/etc/dropbear"

cd "$img"
find . -print0 | cpio --null --create --format=newc | gzip -7 >"$target" 2>/dev/null
