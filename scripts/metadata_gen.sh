#!/bin/bash
# Written by Douglas Goldstein <cardoe@gentoo.org>
# This code is hereby placed into the public domain
#
# $Id: use_desc_gen.sh,v 1.6 2008/08/23 21:28:28 robbat2 Exp $

overlaydir=${OVERLAY:-${EPREFIX:-$(portageq envvar EPREFIX)}/overlay}

usage() {
	echo "$(basename "$1") /path/to/portage/tree [limit-dir]"
	exit 1;
}

if [ $# -eq 0 ]; then
	echo "no arguments: assuming you meant: ${0} ${overlaydir}"
	set -- "${overlaydir}"
fi

if [ $# -gt 2 ]; then
	usage "$0";
fi

for arg in "$@" ; do
	if [ "x${arg}" = "x-h" -o "x${arg}" = "x--help" ]; then
		usage "$0";
	fi
done

if [ ! -f "${1}/profiles/use.local.desc" ]; then
	usage "$0";
fi

limitdir=
if [[ -n ${2} ]] ; then
	limitdir="$2"
	if echo "${limitdir}" | grep -s '/.*/.' ; then
		echo "limiting_filepath \"${limiting_filepath}\" is too deep, shorten it!" >&2
		exit 1
	fi
fi



pid=$(echo $$)

cd "${1}"

if [[ -z $limitdir ]] ; then
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
	echo "OK, use.local.desc is done."
fi

echo "Now generating metadata."

atoms=
if [[ -n $limitdir ]] ; then case $limitdir in
	*/*/|*/*)
		atoms="${limitdir%/}"
		;;
	*)
		atoms=$(
			for d in $( cd "${limitdir}" && ls ) ; do
				echo "${limitdir}/${d}"
			done
		)
		;;
esac ; fi

if [[ -n $atoms ]] ; then
	echo "(only for these atoms: $( echo ${atoms} ))"
fi

egencache --repo=gmt_cygwin_overlay --jobs=4 --load-average=2 --tolerant --update ${atoms}
