# gmt overylay profile.bashrc

cyg_which() {
	# which which?  Might seem crazy but we really want to avoid 
	# using unprefixed executables as much as possible, as they
	# are somewhat likely to trigger fork failures system-wide.
	local which=which
	[[ -x "${EPREFIX}"/bin/which ]] && which="${EPREFIX}"/bin/which
	[[ -x "${EPREFIX}"/usr/bin/which ]] && which="${EPREFIX}"/usr/bin/which

	${which} "$1" 2>/dev/null || {
		if [[ -x ${EPREFIX}/bin/false ]] ; then
			echo "${EPREFIX}/bin/false"
		else
			# sigh, what else can we do?
			echo "/bin/false"
		fi
	}
}

# sigh, what a pita -- we just want to warn the user if we changed their environment variables
# (i.e., if they set them in make.conf)
warn_export() {
	local lv="${1/=*}"
	local rv="${1#${lv}=}"
	local printenv="$( cyg_which printenv )"
	local sed="$( cyg_which sed )"
	local grep="$( cyg_which grep )"

	[[ -z "${lv}" ]] && return 1

	local lvexported=no
	local lvset
	eval lvset=\${${lv}+yes}

	declare -p | ${sed} -e 's/^[^[:space:]]*[[:space:]].//'| ${grep} '^x' | ${sed} -e 's/^..//;s/=.*$//' | ${grep} "^${lv}$" >& /dev/null && {
		# if we get here then the variable was exported...
		lvexported=yes
	}

	local old_val=
	[[ $lvset == yes ]] && {
		if [[ $lvexported == yes ]] ; then
			old_val="$( ${printenv} ${lv} )"
		else
			eval old_val=\${${lv}}
		fi
	}

	export ${lv}="${rv}"

	if [[ $lvset == yes ]] ; then
		if [[ "${old_val}" != "${rv}" ]] ; then
			local andalsoexported=
			local exported=""
			if [[ $lvexported == no ]] ; then
				andalsoexported=" (and also exported it)"
			else
				exported="exported "
			fi
			ewarn "Changed ${exported}environment variable '${lv}' from '${old_val}' to '${rv}'${andalsoexported}"
		else
			[[ $lvexported == no ]] && \
				ewarn "Exported previously un-exported environment variable ${lv}='${rv}'"
		fi
	fi
}

CYG_REBASE="${CYG_REBASE:-$( cyg_which rebase )}"
CYG_PEFLAGS="${CYG_PEFLAGS:-$( cyg_which peflags )}"

# paranoia: overrdie BASH, CONFIG_SHELL
# FIXME: do these even /do/ anything?
warn_export BASH="$( cyg_which bash )"
warn_export CONFIG_SHELL="${BASH}"

###############################################################
# 2d associative array hack i.e.,
#
#  this=( 'is=( an example )' 'of=( a "2d associative" array )'
###############################################################

# $1 == array variable name
# $2 == first dimension index (string)
# $3 == second dimension index (int)
# output: element value
cyg_2d-elt() {
	# clone the array contents from the variable name in $1
	declare -a arr
	eval arr=\( \"\${${1}[@]}\" \)

	# eval each array element so that we now have a local
	# variable instantiated for each index (in a serious implementation we'd)
	# do something smarter in the backticks below
	local sub
	eval `for sub in "${arr[@]}" ; do echo local "${sub}" ; done`

	# extract the sub array by name and retrieve the result by index
	eval echo \"\${${2}[${3}]}\"
	return 0
}

# $1 == array variable name
# $2 == first dimension index (string)
# output: evaltext sutable for array assignment i.e. result=( "$(cyg_2d-sub input index)" )
cyg_2d-sub() {
	local sed="$( cyg_which sed )"

	# clone the array contents from the variable name in $1
	declare -a arr
	eval arr=\( \"\${${1}[@]}\" \)

	local idxsubmap
	local idx
	for idxsubmap in "${arr[@]}" ; do
		# FIXME: not robust to wierd corner cases -- I need to learn how to
		# use the sed buffers and revise.
		idx="$( echo "${idxsubmap}" | ${sed} -e '1s/^\([^=]*\)=.*$/\1/' )"
		if [[ $idx == $2 ]]; then
			# try to just lop off the 'foo=(' and trailing ')' and dump
			echo "${idxsubmap}" | ${sed} -e '1s/^[^=]*=[[:space:]]*([[:space:]]*//' | \
				${sed} -e '$s/)[[:space:]]*$//'
			break
		fi
	done
	return 0
}

cyg_fix-dirflag-dir() {
	local sed="$( cyg_which sed )"
	local egrep="$( cyg_which egrep )"

	local dir="$*"

	local initial_slash=
	local trailing_slash=
	[[ $dir == /* ]] && initial_slash=/
	[[ $dir == */ ]] && trailing_slash=/
	declare -a resultparts
	resultparts=( )
	local pathpart
	while read pathpart ; do
		[[ $pathpart == "." ]] && continue
		if [[ $pathpart == ".." ]] ; then
			if (( ${#resultparts[*]} > 0 )) ; then
				unset resultparts[${#resultparts[*]}-1]
			fi
		else
			resultparts[${#resultparts[*]}]="${pathpart}"
		fi
	done < <(echo "$( echo "${dir}" | ${sed} 's|\/|\n|g' | ${egrep} -v '^[[:space:]]*$' )" )
	# the grep -v in the above line is responsible for ridding us of duplicate slashes

	local result=
	for pathpart in "${resultparts[@]}" ; do
		if [[ -z "${result}" ]] ; then
			result="${pathpart}"
		else
			result="${result}/${pathpart}"
		fi
	done
	result="${initial_slash}${result}${trailing_slash}"
	echo "${result}"
}

# usage: cyg_fix-retarded-compiler-flag 'c|cxx|ld' [flag]
#
# ie:
#   x=$( cyg_fix-retarded-compiler-flag "cxx" "-I////re///tar/../../ded/compiler/../flag" )
#   echo ${x} should be "-I/ded/flag"
#
#   if the flag is not whitelisted as something we understand then we should ignore it, lest this
#   approach become counterproductive
#
#   this routine only understands one flag at a time; in principle it could contain spaces
#   although in practice we are naievely assuming all spaces are flag sparators
#
cyg_fix-retarded-compiler-flag() {
	# some really gross patterns are pretty standard to be floating around in {C{,XX},LD}FLAGS-ville:
	#
	# o -X////too////many///slashes: actually, dangerous in cygwin, since //X is not /X at all (cygwin
	#   gentoo prefix doesn't support this usage, but you can put them in /etc/fstab or the mount table
	#   to put your prefix on these).
	#
	# o -X/paths/with/../containing/superfluous/siblings: This is really gross IMO -- I suppose
	#   there might be some semantic value in this, as a way of saying "I want the /a/b/c directory,
	#   but only if the /a/z/y directory exists ("/a/z/y/../../b/c") and is traversable by me, and
	#   otherwise I want an error.
	#
	# Note that cyg_update-{c{,xx},ld}flags are only fixing the former syntax.
	#
	# Sorry for doing it this way, it's pretty pointlessly abstract/obscure right now.
	# Eventually I have vague designs to flesh this code out and move into a compiler-flag-hacking
	# library -- which is still pretty silly as I'd be reinventing the wheel.  I guess I like
	# suffering pointlessly or something.

	declare -a dir_flag_support_matrix
	dir_flag_support_matrix=( \
	  'ld=(	 -L               )' \
	  'c=(	 -I -L -iquote -B )' \
	  'cxx=( -I -L -iquote -B )' \
	)

	local dirflags
	eval dirflags=( "$( cyg_2d-sub dir_flag_support_matrix $1 )" )
	local dirflag
	for dirflag in "${dirflags[@]}" ; do
		if [[ $2 == ${dirflag}* ]] ; then
			local dirflag_dir="${2#${dirflag}}"
			echo "${dirflag}$( cyg_fix-dirflag-dir ${dirflag_dir})"
			return 0
		fi
	done

	# no match so just echo back unchanged
	echo "$2"
	return 0
}

# update LDFLAGS
cyg_update-ldflags() {
	declare -a force_ldflags
	declare -a old_ldflags
	declare -a resultant_ldflags

	resultant_ldflags=( )

	if [[ ${LDFLAGS+yes} == yes ]] ; then
		# modifying this list will force the listed LDFLAGS into the ebuild environment
		force_ldflags=( \
			"-Wl,--enable-auto-image-base" \
			"-L${EPREFIX}/usr/lib" \
			"-L${EPREFIX}/lib" \
		)
		old_ldflags=( $LDFLAGS )
		# we want to err on the side of /not/ changing LDFLAGS unnecesarily so drop items
		# from force_ldflags if they are already in LDFLAGS
	else
		LDFLAGS="-Wl,--enable-auto-image-base -L${EPREFIX}/usr/lib -L${EPREFIX}/lib"
	fi
}

cyg_update-ldflags

cyg_rebase-portage-workdir() {
	einfo "Rebasing dynamic libraries in \"${WORKDIR}\"..."
}

cyg_rebase-portage-destdir() {
	einfo "Rebasing dynamic libraries in \"${D}\"..."

	die
}

# FIXME, comment this out
einfo "gmt overlay profile.bashrc: EBUILD_PHASE=\"${EBUILD_PHASE}\""

if [[ "${EBUILD_PHASE}" == "test" ]] ; then
	cyg_rebase-portage-workdir
elif [[ "${EBUILD_PHASE}" == "preinst" ]] ; then
	cyg_rebase-portage-destdir
fi

# vim: syntax=sh tabstop=8
