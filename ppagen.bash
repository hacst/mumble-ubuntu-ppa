#!/bin/bash

set -e
trap exit SIGINT SIGTERM

VERSION=${1}
DIST=${2}
PPAVER=${3}
OPTIONS=${*:4}
BUILD=0
DRY_RUN=0
TARGET=""

function usage() {
	echo "ppagen.bash <version> <dist> <ppaver< [options]"
	echo
	echo "Generates an Ubuntu ppa for mumble \$VERSION for Ubuntu \$DIST"
	echo "and uploads it to the Mumble team's PPA."
	echo "Also includes other similar features for testing."
	echo
	echo "This script tries to verify the signature of the downloaded"
	echo "Mumble source tarball. Because of that, you need the signer's"
	echo "public key in your GPG keychain."
	echo
	echo "To build a source package and upload it to the Mumble team PPA:"
	echo " ppagen.bash 1.2.4~rc1-8-gb115a29 quantal 3 --snapshot  # Build a source package and upload it to the mumble-snapshot PPA."
	echo " ppagen.bash 1.2.4~rc1-8-gb115a29 quantal 3 --release   # Build a source package and upload it to the mumble-release PPA."
	echo
	echo "To build a source pacakge in dry run mode (for local testing):"
	echo " ppagen.bash 1.2.4~rc1-8-gb115a29 quantal 3 --dry-run   # Build a source package and do not upload it. Results can be inspected."
	echo
	echo "To build a binary package (for local testing):"
	echo " ppagen.bash 1.2.4~rc1-8-gb115a29 quantal 3 --build     # Build a binary package for quantal named 1.2.4~rc1-8-gb115a29-1~ppa3~quantal1"
	echo
	exit 1
}

if [ "${VERSION}" == "" ]; then
	usage
fi

if [ "${DIST}" == "" ]; then
	usage
fi

if [ "${PPAVER}" == "" ]; then
	PPAVER="1"
fi

if [[ "${OPTIONS}" == *"--dry-run"* ]]; then
	DRY_RUN=1
	echo "In dry-run mode. will not upload any resulting products."
fi

if [[ "${OPTIONS}" == *"--build"* ]]; then
	BUILD=1
	echo "Doing local build."
fi

if [ $BUILD -eq 0 ]; then
	if [[ "${OPTIONS}" == *"--snapshot"* ]]; then
		TARGET="mumble-snapshot"
		echo "Targetting mumble-snapshot PPA"
	fi

	if [[ "${OPTIONS}" == *"--release"* ]]; then
		TARGET="mumble-release"
		echo "Targetting mumble-release PPA"
	fi

	if [ "$TARGET" == "" ]; then
		if [ $DRY_RUN -eq 0 ]; then
			echo "No target set, please pass either --snapshot or --release to pick the target PPA."
			exit
		fi
	fi
fi

DEBVER="-1~ppa${PPAVER}~${DIST}1"
echo "Debian version set to ${DEBVER}"

tempdir=$(mktemp -d)
cd ${tempdir}
wget http://mumble.info/snapshot/mumble-${VERSION}.tar.gz -O mumble_${VERSION}.orig.tar.gz
wget http://mumble.info/snapshot/mumble-${VERSION}.tar.gz.sig -O mumble_${VERSION}.orig.tar.gz.sig
gpg --verify mumble_${VERSION}.orig.tar.gz.sig
tar -zxf mumble_${VERSION}.orig.tar.gz
cd mumble-${VERSION}
git clone git://github.com/mumble-voip/mumble-ubuntu-ppa.git debian
if [ -x debian/backports/${DIST} ]; then perl debian/backports/${DIST}; fi
cd debian
dch -v ${VERSION}${DEBVER} -D ${DIST} "PPA Upload of ${VERSION} snapshot for Ubuntu ${DIST}"

if [ $BUILD -eq 0 ]; then
	debuild -S -sa
	cd ../../
	if [ $DRY_RUN -eq 0 ]; then
		dput mumble-snapshot mumble_${VERSION}${DEBVER}_source.changes
		rm -rf ${tempdir}
	else
		echo "Skipping puload of source.changes in dry run mode."
		echo "Skipping temp dir removal in dry run mode. Directory is ${tempdir}"
	fi
else
	debuild -us -uc
	echo "Successfully built mumble ${VERSION}${DEBVER} in ${tempdir}"
fi