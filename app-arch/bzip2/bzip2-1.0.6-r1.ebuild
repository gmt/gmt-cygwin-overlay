# Copyright 1999-2010 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/app-arch/bzip2/bzip2-1.0.6-r1.ebuild,v 1.1 2010/09/23 09:19:49 vapier Exp $

EAPI=2

inherit eutils multilib toolchain-funcs flag-o-matic prefix autotools

DESCRIPTION="A high-quality data compressor used extensively by Gentoo Linux"
HOMEPAGE="http://www.bzip.org/"
SRC_URI="http://www.bzip.org/${PV}/${P}.tar.gz"

LICENSE="BZIP2"
SLOT="0"
KEYWORDS="~ppc-aix ~x64-freebsd ~x86-freebsd ~hppa-hpux ~ia64-hpux ~x86-interix ~amd64-linux ~ia64-linux ~x86-linux ~ppc-macos ~x64-macos ~x86-macos ~m68k-mint ~sparc-solaris ~sparc64-solaris ~x64-solaris ~x86-solaris ~x86-winnt"
IUSE="static"

src_unpack() {
	unpack ${A}
	cd "${S}"
	epatch "${FILESDIR}"/${PN}-1.0.4-makefile-CFLAGS.patch
	epatch "${FILESDIR}"/${PN}-1.0.6-saneso.patch
	epatch "${FILESDIR}"/${PN}-1.0.4-man-links.patch #172986
	epatch "${FILESDIR}"/${PN}-1.0.2-progress.patch
	epatch "${FILESDIR}"/${PN}-1.0.3-no-test.patch
	epatch "${FILESDIR}"/${PN}-1.0.4-POSIX-shell.patch #193365
	epatch "${FILESDIR}"/${PN}-1.0.5-checkenv.patch # for AIX, Darwin?
	epatch "${FILESDIR}"/${PN}-1.0.4-prefix.patch
	if [[ ${CHOST} == *-cygwin* ]] ; then
		epatch "${FILESDIR}"/${PN}-1.0.6-cygport.patch
		epatch "${FILESDIR}"/${PN}-1.0.6-cygport-autotools.patch
	fi
	eprefixify bz{diff,grep,more}
	# this a makefile for Darwin, which already "includes" saneso
	cp "${FILESDIR}"/${P}-Makefile-libbz2_dylib Makefile-libbz2_dylib || die

	if [[ ${CHOST} == *-hpux* ]] ; then
		sed -i -e 's,-soname,+h,' Makefile-libbz2_so || die "cannot replace -soname with +h"
		if [[ ${CHOST} == hppa*-hpux* && ${CHOST} != hppa64*-hpux* ]] ; then
			sed -i -e '/^SOEXT/s,so,sl,' Makefile-libbz2_so || die "cannot replace so with sl"
			sed -i -e '/^SONAME/s,=,=${EPREFIX}/lib/,' Makefile-libbz2_so || die "cannt set soname"
		fi
	elif [[ ${CHOST} == *-interix* ]] ; then
		sed -i -e 's,-soname,-h,' Makefile-libbz2_so || die "cannot replace -soname with -h"
		sed -i -e 's,-fpic,,' -e 's,-fPIC,,' Makefile-libbz2_so || die "cannot replace pic options"
	elif [[ ${CHOST} == *-cygwin* ]] ; then
		rm Makefile
		eautoreconf
	fi
}

bemake() {
	emake \
		CC="$(tc-getCC)" \
		AR="$(tc-getAR)" \
		RANLIB="$(tc-getRANLIB)" \
		"$@" || die
}

src_configure() {
	if [[ ${CHOST} == *-cygwin* ]] ; then
		econf --enable-shared
	else
		einfo "No configure script required, hurray!"
	fi

        # - Use right man path
        # - Generate symlinks instead of hardlinks
        # - pass custom variables to control libdir
        sed -i \
                -e 's:\$(PREFIX)/man:\$(PREFIX)/share/man:g' \
                -e 's:ln -s -f $(PREFIX)/bin/:ln -s :' \
                -e 's:$(PREFIX)/lib:$(PREFIX)/$(LIBDIR):g' \
                Makefile || die
}

src_compile() {
	local checkopts=

	case "${CHOST}" in
		*-darwin*)
			bemake PREFIX="${EPREFIX}"/usr -f Makefile-libbz2_dylib || die
			use static && append-flags -static
			bemake all || die
		;;
		*-mint*)
			# do nothing, no shared libraries
			:
			use static && append-flags -static
			bemake all || die
		;;
		*-cygwin*)
			emake || die
		;;
		*)
			bemake -f Makefile-libbz2_so all || die
			use static && append-flags -static
			bemake all || die
		;;
	esac
}

src_install() {
	make PREFIX="${D}${EPREFIX}"/usr LIBDIR="$(get_libdir)" install || die
	dodoc README* CHANGES bzip2.txt manual.*

	if [[ ${CHOST} != *-cygwin* && $(get_libname) != ".irrelevant" ]] ; then

		# Install the shared lib manually.  We install:
		#  .x.x.x - standard shared lib behavior
		#  .x.x   - SONAME some distros use #338321
		#  .x     - SONAME Gentoo uses

		dolib.so libbz2$(get_libname ${PV}) || die
		local s
		for v in libbz2$(get_libname) libbz2$(get_libname ${PV%%.*}) libbz2$(get_libname ${PV%.*}) ; do
			dosym libbz2$(get_libname ${PV}) /usr/$(get_libdir)/${v} || die
		done
		gen_usr_ldscript -a bz2

		if ! use static ; then
			newbin bzip2-shared bzip2 || die
		fi
	fi

	# move "important" bzip2 binaries to /bin and use the shared libbz2.so
	dodir /bin
	if [[ ${CHOST} == *-cygwin* ]] ; then
		for exe in bzip2 ; do
			einfo "Moving \"/usr/bin/${exe}.exe\" to \"/bin/\""
			mv "${ED}"usr/bin/${exe}.exe "${ED}"bin/
		done
		for exe in bunzip2 bzcat ; do
			einfo "Replacing \"/usr/bin/${exe}.exe\" with symlink in \"/bin/\""
			rm -v "${ED}"usr/bin/${exe}.exe
			dosym bzip2.exe /bin/${exe}.exe
		done
		# replace foo symlinks with foo.exe symlinks
		for f in /bin/{bunzip2,bzcat} ; do
			if [[ -L "${ED}"usr${f} ]] ; then
				einfo "fixing up symlink for \"${f}.exe\""
				rm -v "${ED}"usr${f}
				dosym bzip2.exe ${f}.exe
			fi
		done
	else
		mv "${ED}"/usr/bin/b{zip2,zcat,unzip2} "${ED}"/bin/ || die
		dosym bzip2 /bin/bzcat || die
		dosym bzip2 /bin/bunzip2 || die
	fi

	if [[ ${CHOST} == *-winnt* ]]; then
		dolib.so libbz2$(get_libname ${PV}).dll || die "dolib shared"

		# on windows, we want to continue using bzip2 from interix.
		# building bzip2 on windows gives the libraries only!
		rm -rf "${ED}"/bin "${ED}"/usr/bin
	fi
}
