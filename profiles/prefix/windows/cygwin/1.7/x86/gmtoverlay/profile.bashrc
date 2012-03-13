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

# the environment variable warnings can get a bit excessive
# squelch duplicates by checking if we already warned them
cyg_already-warned() {
	local already_warned_file="${T}/cyg-already-warned"
	local sed="$( cyg_which sed )"
	local warnspec
	local warnspec_part
	local warnspec_in
	local already_warned="no"
	for warnspec_part in "${@}" ; do
		warnspec_part="$( echo "${warnspec_part}" | ${sed} 's/"/_/' )"
		warnspec="${warnspec} \"${warnspec_part}\""
		warnspec="${warnspec# }"
	done

	# if "${T}" doesn't exist yet there's no point in continuing
	[[ ! -d "${T}" ]] && return 1

	[[ -f ${already_warned_file} ]] || touch ${already_warned_file}

	while read warnspec_in ; do
		if [[ "${warnspec_in}" == "${warnspec}" ]] ; then
			already_warned=yes
			break
		fi
	done < ${already_warned_file}
	if [[ $already_warned == yes ]] ; then
		return 0
	else
		echo "${warnspec}" >> ${already_warned_file}
		return 1
	fi
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
			cyg_already-warned "changed" "${lv}" "${old_val}" "${rv}" "${andalsoexported}" || \
				ewarn "Changed ${exported}environment variable '${lv}' from '${old_val}' to '${rv}'${andalsoexported}"
		else
			if [[ $lvexported == no ]] ; then
				cyg_already-warned "exported" "${lv}" || \
					ewarn "Exported previously un-exported environment variable ${lv}='${rv}'"
			fi
		fi
	fi
}

CYG_REBASE="${CYG_REBASE:-$( cyg_which rebase )}"
CYG_PEFLAGS="${CYG_PEFLAGS:-$( cyg_which peflags )}"

# fixme: maybe this belongs in prefix profile?  I'd say probably yes
# or better yet figure out where all this /bin/bash is coming from and
# fix it in portage (or wherever).
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
	declare -a force_ldflags_needed
	declare -a censor_ldflags
	declare -a old_ldflags
	declare -a new_ldflags

	if [[ ${LDFLAGS+yes} == yes ]] ; then
		new_ldflags=( )
		local old_ldflag
		local censor_ldflag
		local force_ldflag
		local handled_ldflag
		local force_ldflag_needed
		local ldflag_whitespace_pre
		local ldflag_whitespace_post
		local i

		local sed="$( cyg_which sed )"

		# in order to avoid pointless warnings, remember leading/trailing whitespace
		# this still doesn't help if the whitespace in question happens to be
		# interspersed -- but w/e
		ldflag_whitespace_pre="$( echo "${LDFLAGS}" | ${sed} -e 's/^\([[:space:]]*\).*$/\1/' )"
		ldflag_whitespace_post="$( echo "${LDFLAGS}" | ${sed} -e 's/^[[:space:]]*//;s/^.*[^[:space:]]\([[:space:]]*\)$/\1/' )"

		# modifying this list will force the listed LDFLAGS into the ebuild environment
		force_ldflags=( \
			"-Wl,--enable-auto-image-base" \
			"$( cyg_fix-retarded-compiler-flag ld -L${EPREFIX}/usr/lib )" \
			"$( cyg_fix-retarded-compiler-flag ld -L${EPREFIX}/lib )" \
		)
		force_ldflags_needed=( "${force_ldflags[@]}" )
		# FIXME: if they did "-Wl,--image-base -Wl,0xf00" (instead of, say,
		# "-Wl,--image-base=0xf00"), we break shit here
		censor_ldflags=( \
			"-Wl,--image-base" \
		)
		old_ldflags=( $LDFLAGS )

		for old_ldflag in "${old_ldflags[@]}" ; do
			handled_ldflag=no
			old_ldflag="$( cyg_fix-retarded-compiler-flag ld ${old_ldflag} )"
			for censor_ldflag in ${censor_ldflag[@]} ; do
				if [[ $old_ldflag == ${censor_ldflag}* ]] ; then
					handled_ldflag=yes
					break
				fi
			done
			[[ $handled_ldflag == yes ]] && continue
			for force_ldflag in "${force_ldflags[@]}" ; do
				if [[ $old_ldflag == ${force_ldflag}* ]] ; then
					# remove $old_ldflag from ${force_ldflags_needed} since
					# we found it in old_ldflags
					for i in ${!force_ldflags_needed[*]} ; do
						if [[ ${force_ldflags_needed[i]} == ${force_ldflag} ]] ; then
							unset force_ldflags_needed[i]
							new_ldflags[${#new_ldflags[*]}]="${old_ldflag}"
							handled_ldflag=yes
							break
						fi
					done
					if [[ $handled_ldflag == no ]] ; then
						# ideally we would remove all duplicate ldflags.
						# however, this is not neccesarily smart -- there could
						# be legitimate reasons for duplicate ld flags to
						# be used.  But, at least, amongst the forced ldflags
						# we are confident that it is safe to remove duplicates.
						#
						# we know this was a duplicate because we searched force_ldflags_needed
						# for the flag in question, but it wasn't there; therefore, it had
						# already been removed and, hence, found.
						handled_ldflag=yes
					fi
					break
				fi
			done
			if [[ $handled_ldflag == no ]] ; then
				# pass the flag along unmodified
				new_ldflags[${#new_ldflags[*]}]="${old_ldflag}"
			fi
		done
		new_ldflags=( "${force_ldflags_needed[@]}" "${new_ldflags[@]}" )
		# FIXME: was that unneccesarily complicated enough?  couldn't we somehow add more
		# useless bells and whistles to further slow down portage?  anyhow...
		# new_ldflags now has everything and just needs to be composed and exported.
		warn_export LDFLAGS="${ldflag_whitespace_pre}$( echo "${new_ldflags[@]}" )${ldflag_whitespace_post}"
	else
		LDFLAGS="-Wl,--enable-auto-image-base -L${EPREFIX}/usr/lib -L${EPREFIX}/lib"
		einfo "added LDFLAGS: \"${LDFLAGS}\""
	fi
}

cyg_update-ldflags

# $1 == rebase adderss
# $2 == dir
# $3 == dir
# ...
cyg_rebase-dirs() {
	local rebase_base_address
	local rebase_lst
	local i
	declare -a rebase_dirs

	local mktemp="$( cyg_which mktemp )"
	local grep="$( cyg_which grep )"
	local sed="$( cyg_which sed )"
	local uname="$( cyg_which uname )"
	local cat="$( cyg_which cat )"
	local rm="$( cyg_which rm )"
	local cyg_rebase_suffixes="${CYG_REBASE_SUFFIXES:-dll|so}"
	local rebase_offset="${CYG_REBASE_OFFSET:-0}"
	local rebase_verbose="${CYG_REBASE_VERBOSE:-}"
	[[ $rebase_verbose == 1 || $rebase_verbose == [Yy][Ee][Ss] || $rebase_verbose == [Tt][Rr][Uu][Ee] ]] && \
		rebase_verbose="-v"
	local rebase_mach
	local rslt=0

	[[ $CYG_DONT_REBASE == 1 || $CYG_DONT_REBASE == [Yy][Ee][Ss] || $CYG_DONT_REBASE == [Tt][Rr][Uu][Ee] ]] && \
		CYG_DONT_REBASE="1"
	if [[ ${CYG_DONT_REBASE:-0} == 1 ]] ; then
		return 0
	fi

	rebase_base_address="$1"
	[[ -z "${rebase_base_address}" ]] && {
		ewarn cyg_rebase-dirs called without rebase_base_address argument
		return 1
	}
	shift

	rebase_dirs=( "$@" )
	[[ ${#rebase_dirs[*]} == 0 ]] &&  {
		ewarn cyg_rebase-dirs called without any dirs
		return 1
	}

	for i in ${!rebase_dirs[*]} ; do
		if [[ ! -d "${rebase_dirs[i]}" ]] ; then
			ewarn "Removing directory \"${rebase_dirs[i]}\" from list: not a directory!"
			unset rebase_dirs[i]
		fi
	done

	rebase_lst="$( ${mktemp} "${T}"/cyg_rebase_XXXX.lst )"

	case `${uname} -m` in
		i[3456]86) rebase_mach="-4" ;;
		x86_64)    rebase_mach="-8" ;;
		*)         ewarn "Can't determine 'mach' for rebase" ; return 1 ;;
	esac

	( for i in "${rebase_dirs[@]}" ; do
		find "${i}" -type f
	done ) | \
		${grep} -E "\.($cyg_rebase_suffixes)\$" | \
		${sed} -e '/cygwin1\.dll$/d' -e '/cyglsa.*\.dll$/d' \
		-e '/ebuild-helpers\/dolib.so$/d' \
		-e '/ebuild-helpers\/newlib.so$/d' \
		-e '/\/_cygdll_[^/]*$/d' \
		-e '/\/shlib\/[^/]*\.so$/d' \
		-e '/rebase\.exe$/d' >"${rebase_lst}"

	ebegin "Rebasing files from $( declare -i countdirs
			countdirs=0
			dirstr=
			for d in "${rebase_dirs[@]}" ; do
				countdirs=$(( countdirs + 1 ))
				dirstr="${dirstr:+${dirstr}, }"
				(( countdirs > 1 )) && \
					[[ "${d}" == "${rebase_dirs[${#rebase_dirs[*]}]}" ]] && \
						dirstr="${dirstr} and "
				dirstr="${dirstr}\"${d}\""
			done
			echo -n "${dirstr}" ) from listfile \"${rebase_lst}\""

	local rebase_line
	local rebase_failage=no
	while read rebase_line ; do
		if [[ ${rebase_verbose} == -v ]] ; then
			einfo "RVB: ${rebase_line}"
		else
			rebase_line="$( echo $rebase_line )" # whitespace trim
			case ${rebase_line} in
			ReBaseImage*failed*error*)
				rebase_failage=yes
				local targetfile
				targetfile="$( echo $rebase_line | ${sed} -e 's/^.*(\(.*\)).*$/\1/' )"
				targetfile="${targetfile:-[unknown]}"
				local error
				error="$( echo $rebase_line | ${sed} -e 's/^.*error[[:space:]]*=[[:space:]]*\([[:digit:]]*\)[[:space:]]*$/\1/' )"
				error="${error:-[unknown]}"
				ewarn "  Rebasing failed for file \"${targetfile}\" (error ${error})"
				;;

			*)
				ewarn "  ${rebase_line}"
				;;
			esac
		fi
	done < <( ${CYG_REBASE} "${rebase_verbose}" -s "${rebase_mach}" -b "${rebase_base_address}" \
		-o "${rebase_offset}" -T "${rebase_lst}" 2>&1 )
	[[ ${CYG_PRESERVE_REBASE_LST:-0} == 0 && ${rebase_failage} == no ]] && \
		${rm} "${rebase_lst}"

	# always treat everything as ok for now
	eend 0

	return 0
}

# we are using the following assumptions to guide our rebase hacks:

# I have not done any reasearch into whether these values are reasonable/safe/etc
# I simply pulled them out of a hat.  So looking into this might be something TODO.

# 0x70000000: regular cygwin rebase address (FIXME: vanilla?)
# 0x90000000: rebaseall_pfx -- prefix full-system rebase base
#             this would also be used, presumably, for any portage
#             rebase driver/script
# 0xA0000000: WORKDIR rebase address (cyg_rebase-portage-workdir)
# 0xC0000000: DESTDIR rebase address (cyg_rebase-portage-destdir)

cyg_rebase-portage-workdir() {
	[[ ${CYG_DONT_REBASE_WORKDIR:-0} == 0 ]] || return 0
	cyg_rebase-dirs 0xA0000000 "${WORKDIR}"
}

cyg_rebase-portage-destdir() {
	[[ ${CYG_DONT_REBASE_DESTDIR:-0} == 0 ]] || return 0
	cyg_rebase-dirs 0xC0000000 "${D}"
}

# move any '{/usr,}/bin' to the end of PATH
cyg_path-fix() {
	[[ ${CYG_DONT_FIX_PATH:-0} == 0 ]] || return 0
	local IFS_set=${IFS+yes}
	local old_IFS="${IFS}"
	local got_bin=
	local got_usr_bin=
	local new_PATH=
	IFS=:
	local p
	for p in $PATH ; do
		case $p in
			/usr/bin) got_usr_bin=yes ;;
			/bin) got_bin=yes ;;
			*) new_PATH="${new_PATH}${new_PATH:+:}${p}"
		esac
	done

	if [[ ${IFS_set} == yes ]] ; then
		IFS="${old_IFS}"
	else
		unset IFS
	fi
	new_PATH="${new_PATH}${got_bin:+${new_PATH:+:}/bin}"
	warn_export PATH="${new_PATH}${got_usr_bin:+${new_PATH:+:}/usr/bin}"
}

cyg_path-fix

# FIXME, comment this out
# einfo "gmt overlay profile.bashrc: EBUILD_PHASE=\"${EBUILD_PHASE}\""

if [[ "${EBUILD_PHASE}" == "test" ]] ; then
	cyg_rebase-portage-workdir
elif [[ "${EBUILD_PHASE}" == "preinst" ]] ; then
	cyg_rebase-portage-destdir
fi

# vim: syntax=sh tabstop=8
