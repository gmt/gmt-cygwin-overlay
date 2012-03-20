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
	unset patch_pile_default
	unset patch_pile_series_default
	unset hack_patch_default
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
sourceit() { source "${overlay_dir}"/portage_workdir_hacktool.sh ; }

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
	    -e '/^diff/s/\([[:space:]]\+\)-x\([[:space:]]\+[^[:space:]]*\)/\1/g;s/[[:space:]][[:space:]]*/ /g' \
	    -e '/^Binary files [^[:space:]]* and [^[:space:]]* differ$/d'
}

patches_equiv()
{
	diff -u <( tamepatch "${1}" ) <( tamepatch "${2}" ) > /dev/null
}

pile_patches_equiv() 
{ 
    patches_equiv "${patch_pile}/${patch_pile_series}.${1}.patch" "${patch_pile}/${patch_pile_series}.${2}.patch"
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
	    # if the files have differing shebangs, fudgeit, this is probably some prefix nonsense.
	    ! diff "${todir}/${fout}" "${fromdir}/${fout}" >/dev/null && {
		head -n 1 "${todir}/${fout}" | grep '^#!' >/dev/null && \
		head -n 1 "${fromdir}/${fout}" | grep '^#!' >/dev/null && \
	        diff <( head -n 1 "${todir}/${fout}" ) <( head -n 1 "${fromdir}/${fout}" ) >/dev/null || {
		    { head -n 1 "${fromdir}/${fout}" ; tail -n +2 "${todir}/${fout}" ; } > "${todir}/${fout}.lolfudgery"
		    mv "${todir}/${fout}.lolfudgery" "${todir}/${fout}"
		}
	    }
	fi
    done
    return 0
}

diffit()
{
    local delcompdir=no
    local dostash=no
    local doportage=no
    local compdir="${pwork}.orig"
    local terminal=no
    [[ -t 1 ]] && terminal=yes
    [[ "$1" ]] && case $1 in
    	--stash|stash|-s)
	[[ -f "${patch_pile}"/${patch_pile_series}_stash/$(lateststash).patch ]] || {
	    echo "Cant find \"${patch_pile}/${patch_pile_series}_stash/$(lateststash).patch\"." >&2
	    exit 1
	}
	delcompdir=yes
	compdir="${pwork}.stash"
	dostash=yes
	;;
	--portage|portage|-p)
	delcompdir=yes
	compdir="${pwork}.portage"
	doportage=yes
	;;
	*)
	echo "Usage: diffit [--stash/stash/-s|--portage/portage/-p]" >&2
	return 1
	;;
    esac
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
	fi
	fudgeit "${pwork}" "${compdir}" || { echo "fudge factor: what gives?" >&2 ; exit 1 ; }
	local ignorance=""
	for ign in "${garbage_files[@]}" ; do
	    ignorance="${ignorance}${ignorance:+ }-x ${ign}"
	done
	diff -urN ${ignorance} "${compdir}" "${pwork}" && { [[ $terminal == yes ]] && echo '(trees are identical)' ; }
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
    files_equal "${ebuild_filesdir}"/${hack_patch} "${patch_pile}"/${patch_pile_series}.$(latestpatch).patch || { 
        echo "Patch mismatch" >&2;
        return 1
    };
    [[ -d ${pwork_full} ]] && {
	patches_equiv "${patch_pile}"/${patch_pile_series}.$(latestpatch).patch <( diffit ) || {
	    echo "Probable unpreserved changes detected in \"${pwork_full}\".  Won't auto-nuke, do it manually." >&2
	    return 1
	}
    }
    echo ">> USE=\"cygdll-protect\" FEATURES=\"-collision-protect keepwork\" CYG_DONT_REBASE=1 ebuild ${ebuild_file} digest" && \
    USE="cygdll-protect" FEATURES="-collision-protect keepwork" CYG_DONT_REBASE=1 ebuild "${ebuild_file}" digest && \
    nukeit -q && \
    echo ">> USE=\"cygdll-protect\" FEATURES=\"-collision-protect keepwork\" CYG_DONT_REBASE=1 ebuild ${ebuild_file} prepare" && \
    USE="cygdll-protect" FEATURES="-collision-protect keepwork" CYG_DONT_REBASE=1 ebuild "${ebuild_file}" prepare && \
    echo ">> cd ${pwork_full}" && \
    cd "${pwork_full}" && \
    echo ">> patch -p1 -R < ${ebuild_filesdir}/${hack_patch}" && \
    patch -p1 -R < "${ebuild_filesdir}"/${hack_patch} && \
    echo ">> cd .." && \
    cd .. && \
    echo '>> cp -a' "${pwork}" "${pwork}.orig" && \
    cp -a "${pwork}" "${pwork}.orig" && \
    echo ">> cd ${pwork}" && \
    cd "${pwork}" && \
    echo '>> patch -p1 < '"${ebuild_filesdir}"/${hack_patch} && \
    patch -p1 < "${ebuild_filesdir}"/${hack_patch} && \
    echo '>> ctags -R' && \
    ctags -R
}

stashit()
{
    
    [[ ! -d ${pwork_full} ]] && {
	echo "No directory ${pwork_full} exists, no can do" >&2
	return 1
    }
    [[ ! -d ${pwork_full_orig} ]] && {
	echo "No directory ${pwork_full_orig} exists, no can do" >&2
	return 1
    }
    patches_equiv "${patch_pile}"/${patch_pile_series}.$(latestpatch).patch <( diffit ) && {
	echo "No need, ${patch_pile}/${patch_pile_series}.$(latestpatch).patch matches working tree." >&2
	return 1
    }
    if [[ ! -d "${patch_pile}/${patch_pile_series}_stash" ]] ; then
	echo ">> mkdir -p ${patch_pile}/${patch_pile_series}_stash"
	mkdir -p "${patch_pile}"/${patch_pile_series}_stash
    fi
    if [[ -f "${patch_pile}"/${patch_pile_series}_stash/$(lateststash).patch ]] ; then
	patches_equiv "${patch_pile}"/${patch_pile_series}_stash/$(lateststash).patch <( diffit ) && {
		echo "No need, same patch already stashed at \"${patch_pile}/${patch_pile_series}_stash/$(lateststash).patch\"." >&2
		return 1
	}
	diffit > "${patch_pile}"/${patch_pile_series}_stash/$(lateststashp1).patch
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
    patches_equiv "${patch_pile}"/${patch_pile_series}.$(latestpatch).patch <( diffit ) && { 
        echo No changes since last bump. >&2;
        return 1
    }
    oldpatch=$(latestpatch);
    nupatch="$(latestpatchp1)";
    diffit > "${patch_pile}"/${patch_pile_series}.$(latestpatchp1).patch;
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

    [[ "$1" ]] || { echo "for what?" >&2 ; exit 1 ; }
    local grepfor="$1"
    shift

    declare -a grep_args
    grep_args=( "-C${context_lines}" "-n" "--color=yes" )
    # "$@" : args > 1 are passed along to grep.
    for grep_arg in "$@" ; do
	grep_args=( "${grep_args[@]}" "${grep_arg}" )
    done
    grep_args=( "${grep_args[@]}" "${grepfor}" )

    {
	pushd "${pwork_full}"/ > /dev/null
	local findcmd="find . -type f \\( "
	local firstiter=yes
	for codegrep_spec in "${codegrep_specs[@]}" ; do
	    [[ $firstiter == no ]] && findcmd="${findcmd} -o "
	    findcmd="${findcmd} \\( ${codegrep_spec} \\)"
	    firstiter=no
	done
	findcmd="${findcmd} \\) -print0"
	echo ">> ( cd ${pwork_full}; ${findcmd} ) | xargs -0 grep $( for arg in "${grep_args[@]}" ; do \
		echo -n "\"${arg}\" " ; done ) | less -FKqXR"
	eval "${findcmd}"
	popd > /dev/null
    } | xargs -0 grep -C${context_lines} -n --color=yes "${grep_args[@]}" 2>/dev/null | less -FKqXR
    # above, we drop stderr from xargs because when less quits before grep finishes,
    # annoying messages end up on the console
}
