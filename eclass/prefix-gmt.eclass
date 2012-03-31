# Copyright 1999-2005 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

#
# Original Author: Greg Turner <gmturner007@ameritech.net>
# Purpose: shebang prefixification for lazy people
#

# arguments: a list of filenames (each positional argument is treated as its own file)
# suspected to begin with bash shebangs in need of prefixification.  */sh and */bash are
# both replaced with ${EPREFIX}/bin/bash.
bash_shebang_prefixify() {
	[[ "${EPREFIX}" ]] || return 0
	local f before
	local silent=no
	if [[ $1 == -s || $1 == --silent ]] ; then
		silent=yes
	fi
	for f in "${@}" ; do
		[[ -f ${f} ]] || continue
		before="$( head -n 1 ${f} )"
		sed -e '1s&^\(#![[:space:]]*\).*/\(ba\)\?sh\([^[:graph:]]\|$\)&\1'"${EPREFIX%/}"'/bin/bash\3&' -i "${f}"
		[[ "${before}" != "$( head -n 1 ${f} )" && $silent == no ]] && \
			einfo "Prefixifying bash shebang in file: \"${f}\""
	done
}

# note: does not handle files beginning with "."
bash_shebang_prefixify_dirs() {
	[[ "${EPREFIX}" ]] || return 0
	local recursive=no dir dirfile
	[[ $1 == -r || $1 == --recursive ]] && { recursive=yes ; shift ; }
	for dir in "$@" ; do
		einfo "Prefixifying bash shebangs in dir: \"${dir}\""
		for dirfile in "${dir}"/* ; do
			if [[ -h "${dirfile}" ]] ; then
				continue
			elif [[ -d "${dirfile}" ]] ; then
				if [[ $recursive == yes ]] ; then
					bash_shebang_prefixify_dirs -r "${dirfile}"
				else
					continue
				fi
			elif [[ -f "${dirfile}" ]] ; then
				bash_shebang_prefixify -s "${dirfile}"
			fi
		done
	done
	return 0
}

eprefixify_patch() {
	# Let the rest of the code process one user arg at a time --
	# each arg may expand into multiple patches, and each arg may
	# need to start off with the default global EPATCH_xxx values
	if (( $# > 1 )) ; then
		local m
		for m in "$@" ; do
			einfo "calling eprefixify_patch \"${m}\""
			eprefixify_patch "${m}"
		done
		return 0
	elif [[ $# == 0 ]] ; then
		die "eprefixify_patch does not support EPATCH_SOURCE (requires an argument)"
	fi

	local x="$1"
	[[ -f $x ]] || die "eprefixify_patch does not support patchdirs or whatever \"${x}\" is."

	local PIPE_CMD
	case ${x##*\.} in
		xz)      PIPE_CMD="xz -dc"    ;;
		lzma)    PIPE_CMD="lzma -dc"  ;;
		bz2)     PIPE_CMD="bzip2 -dc" ;;
		gz|Z|z)  PIPE_CMD="gzip -dc"  ;;
		ZIP|zip) PIPE_CMD="unzip -p"  ;;
		*)       PIPE_CMD="cat"       ;;
	esac

	local patchname=${x##*/}

	# Let people filter things dynamically
	if [[ -n ${EPATCH_EXCLUDE} ]] ; then
		# let people use globs in the exclude
		eshopts_push -o noglob

		local ex
		for ex in ${EPATCH_EXCLUDE} ; do
			if [[ ${patchname} == ${ex} ]] ; then
				eshopts_pop
				return 2
			fi
		done

		eshopts_pop
	fi

	einfo "Prefixifying patch: ${patchname} ..."

	local PATCH_TARGET
	PATCH_TARGET="${T}/prefix_${patchname}.patch"
	local STDERR_TARGET="${T}/prefix_${patchname}_err.out"
	if [[ -e ${STDERR_TARGET} ]] ; then
		STDERR_TARGET="${T}/prefix_${patchname}_err_$$.out"
	fi

	# FIXME: @#$%@#$!  How to make a regex that matches '+x+ foo' and '++x foo' but not '+++ foo'?
	local PIPE_CMD_DISP="${PIPE_CMD} | sed -e /^+/s|@GENTOO_PORTAGE_EPREFIX@|${EPREFIX}|g"

	local errinfo="executing: ${PIPE_CMD_DISP} ${x} > ${PATCH_TARGET} >> ${STDERR_TARGET}"

	if ! ( ${PIPE_CMD} "${x}" | sed -e '/^+/s|@GENTOO_PORTAGE_EPREFIX@|'"${EPREFIX}"'|g' \
		> "${PATCH_TARGET}" ) >> "${STDERR_TARGET}" 2>&1 ; then
		echo
		die "error $errinfo"
	fi
	epatch "${PATCH_TARGET}"
}
# vim: syntax=sh
