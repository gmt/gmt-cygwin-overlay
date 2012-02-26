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
	local f before 
	for f in "${@}" ; do
		[[ -f ${f} ]] || continue
		before="$( head -n 1 ${f} )"
		sed -e '1s&^\(#![[:space:]]*\).*/\(ba\)\?sh\([^[:graph:]]\|$\)&\1'"${EPREFIX%/}"'/bin/bash\3&' -i "${f}"
		[[ "${before}" != "$( head -n 1 ${f} )" ]] && \
			einfo "Corrected bash shebang in \"${f}\""	
	done
}
