#!/bin/echo smooth move, Einstein. try sourcing:

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#
# hackable maybe in the future? #
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#
fakePN="portage"
fakeCATEGORY="sys-apps"
overlay_dir="${EPREFIX%/}/overlay"
#%%%%%%%%%#
# the end #
#%%%%%%%%%#

#-----------------------------------#
# probably-correct-as-is variables: #
#-----------------------------------#
ebuild_dir="${overlay_dir}/${fakeCATEGORY}/${fakePN}"
ebuild_filesdir="${ebuild_dir}/files"
ebuild_file="$( ls ${ebuild_dir%/}/${fakePN}-*.ebuild | sort | tail -n 1 )"
fakePV="${ebuild_file#${ebuild_dir%/}/${fakePN}-}"
fakePV="${fakePV%.ebuild}"
p_dir="${EPREFIX%/}/var/tmp/portage/${fakeCATEGORY}/${fakePN}-${fakePV}"
p_workdir="${p_dir}/work"

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#
# inline-hacking-friendly variables: #
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#
hack_patch_default="${fakePN}-${fakePV}-cygdll_protect.patch"
patch_pile_series_default="cygdllprotect.wip"
patch_pile_default="/home/greg/src"
pwork="prefix-portage-${fakePV}"
garbage_files=( "autom4te.cache" "config.log" "config.status" "tags" "*.orig" "*.swp" ".gitignore" )
codegrep_specs=( "-name '*.py'" "-name '*.sh'" "-path './bin/*'" )
#%%%%%%%%%#
# the end #
#%%%%%%%%%#

cold_vars=${cold_vars:-no}
case ${cold_vars:-${coldvars:-${COLD_VARS:-${COLDVARS:-no}}}} in
	y|yes|Y|YES|Yes|T|True|TRUE|t|true|1|cold|COLD|Cold|ice|freezing|yep|please|asawitchestitty)
	unset patch_pile
	unset patch_pile_series
	unset hack_patch
	cold_vars=yes
	;;
esac

pwork_full="${p_workdir%/}/${pwork}"
patch_pile="${patch_pile:-${patch_pile_default}}"
patch_pile_series="${patch_pile_series:-${patch_pile_series_default}}"
hack_patch="${hack_patch:-${hack_patch_default}}"
pwork_full_orig="${pwork_full}.orig"

showit() {
    echo
    echo Crudely guessed "configuration":
    echo ================================
    echo "cold_vars=\"${cold_vars}\""
    echo "ebuild_file=\"${ebuild_file}\""
    echo "ebuild_filesdir=\"${ebuild_filesdir}\""
    echo "fakeCATEGORY=\"${fakeCATEGORY}\"; fakePN=\"${fakePN}\"; fakePV=\"${fakePV}\""
    echo "garbage_files=( $( for f in "${garbage_files[@]}" ; do echo -n "\"${f}\" " ; done ))" 
    echo "p_dir=\"${p_dir}\""
    echo "p_workdir=\"${p_workdir}\""
    echo "pwork=\"${pwork}\""
    echo "pwork_full=\"${pwork_full}\""
    echo "pwork_full_orig=\"${pwork_full_orig}\""
    echo "patch_pile_default=\"${patch_pile_default}\""
    echo "patch_pile=\"${patch_pile}\""
    echo "patch_pile_series_default=\"${patch_pile_series_default}\""
    echo "patch_pile_series=\"${patch_pile_series}\""
    echo "hack_patch_default=\"${hack_patch_default}\""
    echo "hack_patch=\"${hack_patch}\""
    echo
}

showit

if [[ $cold_vars == yes ]] ; then
	echo "(fyi: unset-ting cold_vars!)"
	echo
	unset cold_vars
	unset coldvars
	unset COLD_VARS
	unset COLDVARS
fi

# kludge to re-source this file when hacking on it
sourceit() {
	if [[ $1 == --cold ]] ; then
		cold_vars=yes
	elif [[ $1 == --help || $1 == -h ]] ; then
		echo 'usage: sourceit [--cold]'
		return 0
	fi
	source "${overlay_dir}"/scripts/portage_workdir_hacktool.sh
}

files_equal () 
{ 
    local filea="${1}";
    local fileb="${2}";
    [[ -f "${filea}" && -f "${fileb}" ]] || { 
        echo "Can't find files \"${filea}\" and \"${fileb}\"." 1>&2;
        return 2
    };
    local atext="$(< "${filea}" )";
    local btext="$(< "${fileb}" )";
    if [[ "${atext}" == "${btext}" ]]; then
        return 0;
    else
        return 1;
    fi
}

tamepatch () 
{ 
    cat "${1}" | \
	sed -e 's/^\(\(---\|+++\).*[^[:space:]]\)[[:space:]]*[[:digit:]]\{4\}-[[:digit:]]\{2\}-[[:digit:]]\{2\}[[:space:]].*$/\1/' \
	    -e '/^diff/s/\([[:space:]]\+\)-x\([[:space:]]\+[^[:space:]]*\)/\1/g;/^diff/s/[[:space:]][[:space:]]*/ /g' \
	    -e '/^Binary files [^[:space:]]* and [^[:space:]]* differ$/d'
}

patches_equiv()
{
	local result=1
	tamepatch "${1}" > /tmp/foo_pe_1_$$
	tamepatch "${2}" > /tmp/foo_pe_2_$$
	if diff -u /tmp/foo_pe_1_$$ /tmp/foo_pe_2_$$ >/dev/null ; then
		result=0
	fi
	rm /tmp/foo_pe_{1,2}_$$
	return $result
}

latestpatch() 
{ 
    int_fmt "$( ls ${patch_pile}/${patch_pile_series}.[0-9][0-9][0-9].patch | sort \
    	| tail -n 1 | sed -e 's/^\(.*\.\)\([[:digit:]][[:digit:]][[:digit:]]\)\.patch/\2/;s/^0*//' )" 000
}

lateststash()
{
    int_fmt "$( ls ${patch_pile}/${patch_pile_series}_stash/[0-9][0-9][0-9][0-9].patch 2>/dev/null | sort \
    |tail -n 1 | sed -e 's/^\(.*\)\([[:digit:]][[:digit:]][[:digit:]]\)\.patch/\2/;s/^0*//' )" 0000
}


latestpatchp1() 
{ 
    int_fmt $(( $( latestpatch| sed 's/^0*//' ) + 1 )) 000
}

lateststashp1()
{
    int_fmt $(( $( lateststash | sed 's/^0*//' ) + 1 )) 0000
}

nukeit()
{
    local spoo
    # p_dir better not be important....
    if [[ -e ${p_dir} ]] ; then
    	echo ">> cd /" && \
        cd / && \
	echo -n ">> rm -rf ${p_dir} # ( !" && \
	for spoo in $(seq 6) ; do
	    sleep '.500'
	    echo -n " !" || { echo "aborted..." ; return 1 ; }
	done && \
	echo " )" && \
	rm -rf "${p_dir}"
    else
	if [[ $1 != "-q" ]] ; then
	    echo "## nukeit: nothing to nuke."
	fi
    fi
}

fudgeit()
{
    # copy over any files that seem to be generated from "*.in" files; conversely,
    # if such files appear to be left over from previous fudgeits, remove them.
    local fromdir="$1"
    local todir="$2"
    files=$( cd ${fromdir} ; find . -type f -name '*.in' | sed 's|^\./||' )
    for f in $files ; do
	fout="${f%.in}"
	if [[ -f "${fromdir}/${fout}" && ! -e "${todir}/${fout}" ]] ; then
		cp "${fromdir}/${fout}" "${todir}/${fout}" || return 1
	elif [[ -f "${todir}/${fout}" && ! -e "${fromdir}/${fout}" ]] ; then
		rm "${todir}/${fout}" || return 1
	elif [[ -f "${todir}/${fout}" && -f "${fromdir}/${fout}" ]] ; then
	    if [[ -f "${todir}/${f}" && -f "${fromdir}/${f}" ]] ; then
		# ok, looks like $f generates $fout and is present everywhere, so just make
		# the generated files equal and hope for the best.
		cp "${fromdir}/${fout}" "${todir}/${fout}" || return 1
	    # if the files have differing shebangs, fudgeit, this is probably some prefix nonsense.
	    elif diff "${todir}/${fout}" "${fromdir}/${fout}" >/dev/null ; then
		head -n 1 "${todir}/${fout}" | grep '^#!' >/dev/null && \
		head -n 1 "${fromdir}/${fout}" | grep '^#!' >/dev/null && \
	        [[ $(head -n 1 "${todir}/${fout}" ) == $(head -n 1 "${fromdir}/${fout}" )  ]] || {
		    { head -n 1 "${fromdir}/${fout}" ; tail -n +2 "${todir}/${fout}" ; } > "${todir}/${fout}.lolfudgery"
		    mv "${todir}/${fout}.lolfudgery" "${todir}/${fout}"
		}
	    fi
	fi
    done
    return 0
}

diffit()
{
    local delcompdir=no
    local dostash=no
    local doportage=no
    local dogit=yes
    local compdir="${pwork}.orig"
    local terminal=no
    [[ -t 1 ]] && terminal=yes
    [[ "$1" ]] && case $1 in
    	--stash|stash|-s)
	[[ -f "${patch_pile}"/${patch_pile_series}_stash/$(lateststash).patch ]] || {
	    echo "Cant find \"${patch_pile}/${patch_pile_series}_stash/$(lateststash).patch\"." >&2
	    return 1
	}
	delcompdir=yes
	compdir="${pwork}.stash"
	dostash=yes
	shift
	;;
	--portage|portage|-p)
	delcompdir=yes
	compdir="${pwork}.portage"
	doportage=yes
	shift
	;;
	--git|git|-g)
	delcompdir=yes
	compdir="${pwork}.git"
	dogit=yes
	shift
	;;
	--help|-h)
	echo "Usage: diffit [--help/-h|--stash/stash/-s|--portage/portage/-p] [diff arguments]" >&2
	return 1
	;;
    esac
    local dashu="-u"
    for arg in "$@" ; do
	case $arg in
	    --side-by-side|-y|-u|--normal|-e|--ed|-U)
		dashu=""
		;;
	esac
    done
    { 
	pushd "${p_workdir}" >/dev/null
	if [[ $dostash == yes ]] ; then
		# somehow a leftover one from last time, should be ok to wipe it
		[[ -d "${pwork}.stash" ]] && rm -rf "${pwork}.stash"
		cp -a "${pwork}.orig" "${pwork}.stash"
		cd "${pwork}.stash"
		patch -p1 < "${patch_pile}"/${patch_pile_series}_stash/$(lateststash).patch >/dev/null || { echo "Patch error" >&2 ; return 1 ; }
		cd ..
	elif [[ $doportage == yes ]] ; then
		# somehow a leftover one from last time, should be ok to wipe it
		[[ -d "${pwork}.portage" ]] && rm -rf "${pwork}.portage"
		cp -a "${pwork}.orig" "${pwork}.portage"
		cd "${pwork}.portage"
		patch -p1 < "${patch_pile}"/${patch_pile_series}.$(latestpatch).patch >/dev/null || { echo "Patch error" >&2 ; return 1 ; }
		cd ..
	elif [[ $dogit == yes ]] ; then
		# somehow a leftover one from last time, should be ok to wipe it
		[[ -d "${pwork}.git" ]] && rm -rf "${pwork}.git"
		cp -a "${pwork}.orig" "${pwork}.git"
		cd "${pwork}.git"
		{ ( cd "${overlay_dir}" ; git show "HEAD:${fakeCATEGORY}/${fakePN}/files/${hack_patch}" ) | patch -p1 ; } || { echo "Patch error" >&2 ; return 1 ; }
		cd ..
	fi
	fudgeit "${pwork}" "${compdir}" || { echo "fudge factor: what gives?" >&2 ; return 1 ; }
	local ignorance=""
	for ign in "${garbage_files[@]}" ; do
	    ignorance="${ignorance}${ignorance:+ }-x ${ign}"
	done
	diff $dashu -rN ${ignorance} "${compdir}" "${pwork}" "$@" && { [[ $terminal == yes ]] && echo '(trees are identical)' ; }
	popd > /dev/null
    } | if [[ $terminal == yes ]] ; then
	colordiff | less -FKqXR
    else
	tee /dev/null
    fi
    [[ $delcompdir == yes ]] && rm -rf "${compdir}"
}

prepit() 
{
    local forceit=false
    [[ $1 == --force ]] && forceit=true
    files_equal "${ebuild_filesdir}"/${hack_patch} "${patch_pile}"/${patch_pile_series}.$(latestpatch).patch || { 
        echo "Patch mismatch" >&2
	if $forceit ; then
	    echo "Ignoring due to --force!" >&2
	else
            return 1
	fi
    };
    [[ -d ${pwork_full} ]] && {
	diffit > /tmp/prepit_$$
	patches_equiv "${patch_pile}"/${patch_pile_series}.$(latestpatch).patch /tmp/prepit_$$ || {
	    echo "Probable unpreserved changes detected in \"${pwork_full}\".  Won't auto-nuke, do it manually." >&2
	    if $forceit ; then
		echo "Ignoring due to --force!" >&2
	    else
		rm /tmp/prepit_$$
		return 1
	    fi
	}
	rm /tmp/prepit_$$
    }

    echo ">> USE=\"cygdll-protect\" FEATURES=\"-collision-protect keepwork\" CYG_DONT_REBASE=1 ebuild ${ebuild_file} digest" && \
    USE="cygdll-protect" FEATURES="-collision-protect keepwork" CYG_DONT_REBASE=1 ebuild "${ebuild_file}" digest && \
    nukeit -q && \
    echo ">> USE=\"cygdll-protect\" FEATURES=\"-collision-protect keepwork\" CYG_DONT_REBASE=1 ebuild ${ebuild_file} prepare" && \
    USE="cygdll-protect" FEATURES="-collision-protect keepwork" CYG_DONT_REBASE=1 ebuild "${ebuild_file}" prepare && \
    echo ">> cd ${p_workdir}" && \
    cd "${p_workdir}" && \
    echo ">> cp -a \"${pwork}\" \"${pwork}.orig\"" && \
    cp -a "${pwork}" "${pwork}.orig" && \
    echo ">> cd \"${pwork}.orig\"" && \
    cd "${pwork}.orig" && \
    echo ">> patch -p1 -R < \"${ebuild_filesdir}/${hack_patch}\"" && \
    patch -p1 -R < "${ebuild_filesdir}"/${hack_patch} && \
    echo ">> cd \"../${pwork}\"" && \
    cd "../${pwork}" && \
    echo ">> ctags -R" && \
    ctags -R
}

stashit()
{
    local forceit=false
    [[ $1 == --force ]] && forceit=true
    [[ ! -d ${pwork_full} ]] && {
	echo "No directory ${pwork_full} exists, no can do" >&2
	return 1
    }
    [[ ! -d ${pwork_full_orig} ]] && {
	echo "No directory ${pwork_full_orig} exists, no can do" >&2
	return 1
    }
    diffit > /tmp/stashit_$$
    patches_equiv "${patch_pile}"/${patch_pile_series}.$(latestpatch).patch /tmp/stashit_$$ && {
	echo "No need, ${patch_pile}/${patch_pile_series}.$(latestpatch).patch matches working tree." >&2
	if $forceit ; then
	    echo "Proceeding anyhow due to --force" >&2
	else
	    rm /tmp/stashit_$$
	    return 1
	fi
    }
    if [[ ! -d "${patch_pile}/${patch_pile_series}_stash" ]] ; then
	echo ">> mkdir -p ${patch_pile}/${patch_pile_series}_stash"
	mkdir -p "${patch_pile}"/${patch_pile_series}_stash
    fi
    if [[ -f "${patch_pile}"/${patch_pile_series}_stash/$(lateststash).patch ]] ; then
	patches_equiv "${patch_pile}"/${patch_pile_series}_stash/$(lateststash).patch /tmp/stashit_$$ && {
		echo "No need, same patch already stashed at \"${patch_pile}/${patch_pile_series}_stash/$(lateststash).patch\"." >&2
		if $forceit ; then
		    echo "Proceeding anyhow due to --force" >&2
		else
		    rm /tmp/stashit_$$
		    return 1
		fi
	}
	mv -v /tmp/stashit_$$ "${patch_pile}"/${patch_pile_series}_stash/$(lateststashp1).patch
	echo "## good idea.  stashed as \"${patch_pile}/${patch_pile_series}_stash/$(lateststash).patch\"."
    else
	[[ "$(lateststash)" == "0000" && ! -e "${patch_pile}"/${patch_pile_series}_stash/0000.patch ]] || {
	    echo "Unexpected stash condition: wtfbbq!?" >&2
	    return 1
	}
	echo "## good idea.  stashed as \"${patch_pile}/${patch_pile_series}_stash/0000.patch\"."
	diffit > "${patch_pile}"/${patch_pile_series}_stash/0000.patch
    fi
}

# unix lacks an "it" command?
# omg, logging on to sourceforge to piss out my territory out right now!
it()
{
    echo ">> cd ${pwork_full}"
    cd "${pwork_full}"/
}

mergeit () 
{
    if [[ $1 == --help || $1 == -h ]] ; then
	echo
	echo "mergeit [-f|--force [egrep-regex [egrep-regex [...]]]"
	echo
	return 0
    elif [[ $1 == -f || $1 == --force ]] ; then
        shift
	egrep_regexen=( "$@" )
	if [[ ${fakePN} == portage && ${fakeCATEGORY} == sys-apps ]] ; then
	    (
		echo ">> ( cd ${pwork_full}"
		cd ${pwork_full}
		if [[ ${#egrep_regexen[*]} == 0 ]] ; then
		    echo ">> find pym -name '*.py' | grep -v 'const_autotool' | while read pyf ; do [[ -e \"${EPREFIX}/usr/lib/portage/\${pyf}\" ]] && cp -v \"\${pyf}\" \"${EPREFIX}/usr/lib/portage/\${pyf}\" ; done"
		    find pym -name '*.py' | grep -v 'const_autotool' | while read pyf ; do
			[[ -e "${EPREFIX}"/usr/lib/portage/${pyf} ]] && cp -v "${pyf}" "${EPREFIX}"/usr/lib/portage/${pyf}
		    done
		else
		    first=yes
		    echo -e ">> find pym -name '*.py' | grep -v 'const_autotool' | while read pyf ; do"
		    echo "       [[ -e \"${EPREFIX}/usr/lib/portage/\${pyf}\" ]] && \\"
		    echo -n "           {"
		    for egrep_regex in "${egrep_regexen[@]}" ; do
			if [[ ${first} == no ]] ; then
			    echo -n ' || \'
			else
			    first=no
			fi
			echo -e -n '\n               echo "${pyf}" | egrep'
			echo -n " \"${egrep_regex}\" > /dev/null"
		    done
		    echo
		    echo "           } && cp -v \"\${pyf}\" \"${EPREFIX}/usr/lib/portage/\${pyf}\""
		    echo "   done"
		    find pym -name '*.py' | grep -v 'const_autotool' | while read pyf ; do
		        [[ -e "${EPREFIX}"/usr/lib/portage/${pyf} ]] && \
			    for egrep_regex in "${egrep_regexen[@]}" ; do
				dopyf=no
				{ echo "${pyf}" | egrep "${egrep_regex}" 2>/dev/null ; } && { dopyf=yes ; break ; }
				[[ ${dopyf} == yes ]] && cp -v "${pyf}" "${EPREFIX}"/usr/lib/portage/${pyf}
			    done
		    done
		fi
	    )
	else
	    echo "force only supported for sys-apps/portage, sorry."
	    return 1
	fi
    fi
    for goner in image .configured .compiled .installed ; do
	    echo ">> rm -rvf ${p_dir}/${goner}"
	    rm -rvf "${p_dir}"/${goner}
    done
    echo ">> USE=\"cygdll-protect\" FEATURES=\"-collision-protect keepwork\" CYG_DONT_REBASE=1 ebuild ${ebuild_file} digest install" && \
    USE="cygdll-protect" FEATURES="-collision-protect keepwork" CYG_DONT_REBASE=1 ebuild ${ebuild_file} digest install && \
    echo ">> USE=\"cygdll-protect\" FEATURES=\"-collision-protect keepwork\" CYG_DONT_REBASE=1 ebuild ${ebuild_file} merge" && \
    USE="cygdll-protect" FEATURES="-collision-protect keepwork" CYG_DONT_REBASE=1 ebuild ${ebuild_file} merge
}

bumpit() 
{ 
    local forceit=false
    [[ $1 == --force ]] && forceit=true
    diffit > /tmp/bumpit_$$
    patches_equiv "${patch_pile}"/${patch_pile_series}.$(latestpatch).patch /tmp/bumpit_$$ && {
        echo No changes since last bump. >&2
        $forceit || { rm /tmp/bumpit_$$ ; return 1 ; }
	echo Ignoring due to --force >&2
    }
    oldpatch=$(latestpatch);
    nupatch="$(latestpatchp1)";
    mv -v /tmp/bumpit_$$ "${patch_pile}"/${patch_pile_series}.$(latestpatchp1).patch;
    cat "${patch_pile}"/${patch_pile_series}.$(latestpatch).patch | colordiff | less -R && echo -n 'ok? y/n: ';
    while read yn; do
        if [[ $yn == y || $yn == n ]]; then
            break;
        else
            echo -n 'y/n: ';
        fi;
    done;
    if [[ $yn == y ]]; then
	echo ">> cp -v \"${patch_pile}/${patch_pile_series}.$(latestpatch).patch\" \"${ebuild_filesdir}/${hack_patch}\"" && \
	cp -v "${patch_pile}"/${patch_pile_series}.$(latestpatch).patch "${ebuild_filesdir}"/${hack_patch} && \
	echo ">> ebuild \"${ebuild_file}\" digest" && \
        ebuild "${ebuild_file}" digest
    else
	echo ">> rm -v \"${patch_pile}/${patch_pile_series}.$(latestpatch).patch"
	rm -v "${patch_pile}"/${patch_pile_series}.$(latestpatch).patch
        return 1;
    fi
}

# convenience function, arguably doesn't belong here
grepit()
{
    local context_lines=${codegrep_context_lines:-3}

    [[ "$1" ]] || { echo "for what?" >&2 ; return 1 ; }

    if [[ $1 == --help ]] ; then
	    echo "grepit [for what] [grep-arg [grep-arg ...]]"
	    return 0
    fi

    local grepfor="$1"
    shift

    declare -a grep_args
    grep_args=( "-C${context_lines}" "-n" "--color=yes" )
    # "$@" : args > 1 are passed along to grep.
    for grep_arg in "$@" ; do
	grep_args=( "${grep_args[@]}" "${grep_arg}" )
    done
    grep_args=( "${grep_args[@]}" "${grepfor}" )
    # we need cwd=${pwork_full} when we do xargs grep as well as find; but we don't want
    # the end users' pwd to change -- hence this subshell.
    (
    cd "${pwork_full}"/
    {
	local findcmd="find . -type f \\( "
	local firstiter=yes
	for codegrep_spec in "${codegrep_specs[@]}" ; do
	    [[ $firstiter == no ]] && findcmd="${findcmd} -o "
	    findcmd="${findcmd} \\( ${codegrep_spec} \\)"
	    firstiter=no
	done
	findcmd="${findcmd} \\) -print0"
	echo ">> cd ${pwork_full}; ( ${findcmd} | xargs -0 grep $( for arg in "${grep_args[@]}" ; do \
		echo -n "\"${arg}\" " ; done ) | less -FKqXR" >&2
	eval "${findcmd}"
    } | xargs -0 grep -C${context_lines} -n --color=yes "${grep_args[@]}" 2>/dev/null | less -FKqXR
    # above, we drop stderr from xargs because when less quits before grep finishes,
    # annoying messages end up on the console
    )
}
int_fmt () 
{ 
    [[ ${2} =~ ^[[:space:]]*-?0+.$ ]] || { 
        echo "int_fmt: bad fmt \"${2}\"." 1>&2;
        return 1
    };
    declare -i int;
    local int="${1}";
    local fmt="${2}";
    [[ "${int}" == "" ]] && int=0;
    is_int "${int}" || { 
        echo "int_fmt: bad int \"${int}\"." 1>&2;
        return 1
    };
    local whitespc=;
    while [[ ${fmt:0:1} =~ [[:space:]] ]]; do
        whitespc="${whitespc}${fmt:0:1}";
        fmt="${fmt:1:$(( ${#fmt} - 1 ))}";
    done;
    local minus=no;
    if [[ ${fmt:0:1} == - ]]; then
        minus=yes;
        fmt="${fmt:1:$(( ${#fmt} - 1 ))}";
    fi;
    declare -i zeros;
    zeros=0;
    while [[ ${fmt:0:1} == 0 ]]; do
        zeros=$(( zeros + 1 ));
        fmt="${fmt:1:$(( ${#fmt} - 1 ))}";
    done;
    commas=;
    case ${#fmt} in 
        0)

        ;;
        1)
            commas="${fmt}"
        ;;
        *)
            echo "int_fmt: unexpected bad fmt." 1>&2;
            return 1
        ;;
    esac;
    local negative=no;
    (( int < 0 )) && { 
        negative=yes;
        int=$(( - int ))
    };
    local numlen=${#int};
    if [[ ${negative} == yes && ${minus} == yes ]]; then
        (( zeros > 1 )) && zeros=$(( zeros - 1 ));
    fi;
    local prefix="${whitespc}";
    [[ $negative == yes ]] && prefix="${prefix}-";
    (( numlen < zeros )) && prefix="${prefix}$( for x in $( seq $(( zeros - numlen )) ) ; do echo -n '0' ; done )";
    local intstr="${int}";
    if [[ -n "$commas" ]]; then
        local commacount=$(( ( ${#intstr} - 1 ) / 3 ));
        local s;
        declare -i trail_len;
        declare -i lchunk_len;
        for s in $( seq ${commacount} );
        do
            trail_len=$(( 4 * s - 1 ));
            lchunk_len=$(( ${#intstr} - trail_len ));
            intstr="${intstr:0:${lchunk_len}}${commas}${intstr:${lchunk_len}:${trail_len}}";
        done;
    fi;
    echo -e -n "${prefix}${intstr}"
}
is_int () 
{ 
    return $(test "$@" -eq "$@" > /dev/null 2>&1)
}
