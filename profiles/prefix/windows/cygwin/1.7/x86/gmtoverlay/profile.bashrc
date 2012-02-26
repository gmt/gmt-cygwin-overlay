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

# paranoia: lets go ahead and overrdie BASH, CONFIG_SHELL
warn_export BASH="$( cyg_which bash )"
warn_export CONFIG_SHELL="${BASH}"

# update LDFLAGS
cyg_update-ldflags() {
	declare -a force_ldflags
	declare -a old_ldflags

	if [[ ${LDFLAGS+yes} == yes ]] ; then
		force_ldflags=(

			# modifying this list will force the listed LDFLAGS into the ebuild environment

			"-Wl,--enable-auto-image-base"
			"-L${EPREFIX}/usr/lib"	# FIXME: only needed for bootstrap?
			"-L${EPREFIX}/lib"	#  "       "     "    "      "

		)
		old_ldflags=( $LDFLAGS )

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

# vim: syntax=sh
