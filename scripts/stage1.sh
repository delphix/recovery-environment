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
	# searching the normal paths if it fails to find its dependencies, but
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
		rsync -aKL "$workdir/$dep" "$output/$dep"
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

#
# Starting with Ubuntu 20.04, several top level directories symlink into /usr.
# See https://wiki.debian.org/UsrMerge for more info.
#
for dir in bin lib lib32 lib64 libx32 sbin; do
	mkdir -p "usr/$dir"
	ln -s "usr/$dir" "$dir"
	mkdir -p "$img/usr/$dir"
	ln -s "usr/$dir" "$img/$dir"
done

mkdir pkgs
for file in *.deb "$repo"/external-debs/*.deb; do dpkg-deb -x "$file" pkgs; done

rsync -aK pkgs/ .

#
# Perform installation process
#
cd "$base"

rsync -aK ../base_img/ "$img/"

for file in /bin/busybox /bin/kmod /bin/systemd-tmpfiles /bin/udevadm \
	/lib/systemd/systemd-networkd /lib/systemd/systemd-udevd /lib/systemd/systemd-resolved \
	/usr/sbin/dropbear /usr/lib/dropbear/dropbearconvert /sbin/zfs \
	/sbin/zpool /sbin/zdb /usr/sbin/nginx; do
	mkdir -p "$img/$(dirname $file)"
	rsync -aK "$workdir/$file" "$img/$file"
	get_deps "$img/$file" "$img"
done
ln -rs "$img/bin/busybox" "$img/bin/sh"
ln -rs "$img/bin/sh" "$img/bin/bash"

loader_path="$(readelf -l /bin/ls | grep 'Requesting' | cut -d':' -f2 | tr -d ' ]')"
arch_triple="$(dpkg-architecture -q DEB_HOST_MULTIARCH)"

rsync -aKL "$workdir/$loader_path" "$img/$(dirname $loader_path)"
mkdir -p "$img/usr/share/nginx"
rsync -aKL "$workdir/usr/share/nginx/modules" "$img/usr/share/nginx/"
rsync -aKL "$workdir/etc/nginx" "$img/etc/"
rm "$img/etc/nginx/nginx.conf"
mkdir -p "$img/lib/$arch_triple/"
rsync -aKL "$workdir/lib/$arch_triple"/libnss* "$img/lib/$arch_triple/"
rsync -aK "$workdir/lib/modprobe.d" "$img/lib/"

mkdir -p "$img"/etc/{systemd/network,network,dhcp}
mkdir -p "$img/etc/dropbear"

cd "$img"
find . -print0 | cpio --null --create --format=newc | gzip -7 >"$target" 2>/dev/null
