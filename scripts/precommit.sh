#!/bin/sh
# Written by Douglas Goldstein <cardoe@gentoo.org>
# This code is hereby placed into the public domain
#
# $Id: use_desc_gen.sh,v 1.6 2008/08/23 21:28:28 robbat2 Exp $

overlaydir=${OVERLAY:-${EPREFIX:-$(portageq envvar EPREFIX 2>/dev/null )}/overlay}

for x in "$@" ; do
	if [[ $x == -h || $x == --help ]] ; then
		${overlaydir}/scripts/gendiffs "$@"
	fi
done

limiting_filepath=
for arg in "$@" ; do
	if [[ $arg != -h && $arg != --help && arg != -c && arg != --clean ]] ; then
		limiting_filepath="${arg}"
		if echo "${limiting_filepath}" | grep -s '/.*/.' ; then
			echo "limiting_filepath \"${limiting_filepath}\" is too deep, shorten it!" >&2
			exit 1
		fi
	fi
done

[[ -n $limiting_filepath ]] || { git status || : ; } # fixup time-stamp-only changes in the index

${overlaydir}/scripts/metadata_gen.sh "${overlaydir}" ${limiting_filepath} || {
	echo "Failed on metadata_gen" >&2
	exit 1
}

if [[ -z $limiting_filepath ]] ; then
	rm -rvf ${overlaydir}/portage_diffs/latest || exit 1
fi

${overlaydir}/scripts/gendiffs ${limiting_filepath}

