#!/bin/sh
# Written by Douglas Goldstein <cardoe@gentoo.org>
# This code is hereby placed into the public domain
#
# $Id: use_desc_gen.sh,v 1.6 2008/08/23 21:28:28 robbat2 Exp $

overlaydir=${OVERLAY:-/g2pfx/overlay}

usage() {
	echo "$(basename "$1") /path/to/portage/tree"
	exit 1;
}

if [ $# -eq 0 ]; then
	echo "no arguments: assuming you meant: ${0} ${overlaydir}"
	set -- "${overlaydir}"
fi

if [ $# -ne 1 ]; then
	usage "$0";
fi

if [ "x${1}" = "x-h" -o "x${1}" = "x--help" ]; then
	usage "$0";
fi

if [ ! -f "${1}/profiles/use.local.desc" ]; then
	usage "$0";
fi

pid=$(echo $$)

cd "${1}"

echo "Generating \"${1}\"/profiles/categories..."

ls | egrep -v '^(README|TODO|metadata|portage_diffs|scripts|eclass|profiles)$' | sort | tee profiles/categories

# take comments from existing use.local.desc
grep '^#' "${1}/profiles/use.local.desc" > /tmp/${pid}.use.local.desc || exit 2
echo "" >> /tmp/${pid}.use.local.desc || exit 2

# the secret sauce, append to new use.local.desc
python2 scripts/use_desc_gen.py --repo_path "${1}" > /tmp/${pid}.new.use || exit 2

# let's keep it sorted: use major category, minor category, and package name
# as primary, secondary, and tertiary sort keys, respectively
sort -t: -k1,1 -k2 /tmp/${pid}.new.use | sort -s -t/ -k1,1 \
    >> /tmp/${pid}.use.local.desc || exit 2

# clean up
rm -rf /tmp/${pid}.new.use

mv /tmp/${pid}.use.local.desc profiles/use.local.desc

echo "OK, use.local.desc is done; now generating metadata."
egencache --update --repo=gmt_cygwin_overlay --jobs=4 --load-average=2 --tolerant
