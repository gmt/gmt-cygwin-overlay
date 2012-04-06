# Copyright 1999-2011 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI="2" #356089

LIBTOOLIZE="true" #225559
WANT_LIBTOOL="none"
inherit eutils autotools multilib prefix-gmt

if [[ ${PV} == "9999" ]] ; then
	EGIT_REPO_URI="git://git.savannah.gnu.org/${PN}.git
		http://git.savannah.gnu.org/r/${PN}.git"
	inherit git-2
else
	SRC_URI="mirror://gnu/${PN}/${P}.tar.xz"
	KEYWORDS="~ppc-aix ~x64-freebsd ~x86-freebsd ~hppa-hpux ~ia64-hpux ~x86-interix ~amd64-linux ~ia64-linux ~x86-linux ~ppc-macos ~x64-macos ~x86-macos ~m68k-mint ~sparc-solaris ~sparc64-solaris ~x64-solaris ~x86-solaris"
fi

DESCRIPTION="A shared library tool for developers"
HOMEPAGE="http://www.gnu.org/software/libtool/"

LICENSE="GPL-2"
SLOT="2"
IUSE="static-libs test vanilla ultra-prefixify"

RDEPEND="sys-devel/gnuconfig
	!<sys-devel/autoconf-2.62:2.5
	!<sys-devel/automake-1.11.1:1.11
	!=sys-devel/libtool-2*:1.5"
DEPEND="${RDEPEND}
	test? ( || ( >=sys-devel/binutils-2.20
		sys-devel/binutils-apple sys-devel/native-cctools ) )
	app-arch/xz-utils"
[[ ${PV} == "9999" ]] && DEPEND+=" sys-apps/help2man"

src_unpack() {
	if [[ ${PV} == "9999" ]] ; then
		git-2_src_unpack
		cd "${S}"
		./bootstrap || die
	else
		xz -dc "${DISTDIR}"/${A} > ${P}.tar #356089
		unpack ./${P}.tar
	fi
}

src_prepare() {
	use vanilla && return 0

	[[ ${CHOST} == *-winnt* ]] &&
		epatch "${FILESDIR}"/2.2.6a/${PN}-2.2.6a-winnt.patch
	epatch "${FILESDIR}"/2.2.6b/${PN}-2.2.6b-mint.patch
	epatch "${FILESDIR}"/2.2.6b/${PN}-2.2.6b-irix.patch

	if [[ ${CHOST} == *-cygwin* ]] ; then
		epatch "${FILESDIR}"/2.4/${PN}-2.4-cygwin-02-manifest-gen.patch
		epatch "${FILESDIR}"/2.4/${PN}-2.4-cygwin-03-gcc-flags.patch
		epatch "${FILESDIR}"/2.4/${PN}-2.4-cygwin-04-fstack-protector.patch
		epatch "${FILESDIR}"/2.4/${PN}-2.4.2-cygwin-install-sh-unc-suppression.patch
	fi

	# seems that libtool has to know about EPREFIX a little bit better,
	# since it fails to find prefix paths to search libs from, resulting in
	# some packages building static only, since libtool is fooled into
	# thinking that libraries are unavailable (argh...). This could also be
	# fixed by making the gcc wrapper return the correct result for
	# -print-search-dirs (doesn't include prefix dirs ...).
	if use prefix ; then
		eprefixify_patch "${FILESDIR}"/2.2.10/${PN}-2.2.10-eprefix.patch
	fi

	cd libltdl/m4
	epatch "${FILESDIR}"/1.5.20/${PN}-1.5.20-use-linux-version-in-fbsd.patch #109105
	epatch "${FILESDIR}"/2.2.6a/${PN}-2.2.6a-darwin-module-bundle.patch
	epatch "${FILESDIR}"/2.2.6a/${PN}-2.2.6a-darwin-use-linux-version.patch
	epatch "${FILESDIR}"/2.4/${PN}-2.4-interix.patch

	# better to ultra-prefixify after all autotools stuff is over
	if use ultra-prefixify ; then
		# fire up a subshell so we can wreak some havoc
		(
		cd "${S}"
		# avoid maintainer-mode trouble... for the most part
		epatch "${FILESDIR}"/2.4/${PN}-2.4-anti-maintainer-mode.patch
		eprefixify_patch "${FILESDIR}"/2.4/${PN}-2.4.2-ultra-prefixification.patch
		bash_shebang_prefixify bootstrap libltdl/config/compile \
			libltdl/config/{config.{guess,sub},depcomp,edit-readme-alpha,missing,mkstamp} \
			libtoolize.in 
		bash_shebang_prefixify_dirs tests
		# unfortunately the above touches enough files to cause utter havoc.
		# for now we take a very crude brute-force approach by aping almost everything
		# in the bootstrap script.
		# FIXME: this is horrible, unacceptable, and frankly, kinda embarassing
		find . -depth \( -name autom4te.cache -o -name libtool \) -print \
			  | grep -v '{arch}' | xargs rm -rf
		rm -f acinclude.m4 libltdl/config.h argz.c lt__dirent.c lt__strl.c

  		reconfdirs="$( echo $( for d in . libltdl tests/*demo tests/*demo[0-9] ; do
						[[ -d "$d" && -f "${d}"/configure.ac ]] || continue
						echo $d
			               done ) )"
		PACKAGE="${PN}"
		PACKAGE_NAME="${PN:0:1}"
		PACKAGE_NAME="${PACKAGE_NAME^^}"
		PACKAGE_NAME="${PACKAGE_NAME}${PN:1}"
		if grep 'AC_INIT.*GNU' configure.ac >/dev/null; then
			PACKAGE_NAME="GNU $PACKAGE_NAME"
			PACKAGE_URL="http://www.gnu.org/software/$PACKAGE/"
		fi
		VERSION="${PV}"
		unset WANT_AUTOCONF
		unset WANT_AUTOMAKE
		export WANT_AUTOCONF
		export WANT_AUTOMAKE
		# whip up a dirty Makefile... eGods forgive me, just following the recipe as I got it...
		sed '/^if /,/^endif$/d;/^else$/,/^endif$/d;/^include /d' Makefile.am libltdl/Makefile.inc > Makefile
		rm -f libltdl/config/ltmain.sh libltdl/m4/ltversion.m4
		# note: added libtool.info to avoid maintainer-mode stuff
		make libltdl/config/ltmain.sh libltdl/m4/ltversion.m4 \
			./libtoolize.in ./tests/defs.in ./tests/package.m4 \
			./tests/testsuite ./libltdl/Makefile.am ./doc/notes.txt doc/libtool.info \
			srcdir=. top_srcdir=. PACKAGE="$PACKAGE" VERSION="$VERSION" \
			PACKAGE_NAME="$PACKAGE_NAME" PACKAGE_URL="$PACKAGE_URL" \
			PACKAGE_BUGREPORT="bug-$PACKAGE@gnu.org" M4SH="autom4te --language=m4sh" \
			AUTOTEST="autom4te --language=autotest" SED="sed" MAKEINFO="makeinfo" \
			GREP="grep" FGREP="fgrep" EGREP="egrep" LN_S="ln -s"
		rm -f Makefile
		cat > libltdl/config/libtoolize <<'EOF'
#! /bin/sh
# sheesh, what is with this sed statement!?  The... horror...
echo "$0: Bootstrap detected, no files installed." | sed 's,^.*/,,g'
exit 0
EOF
		chmod 755 libltdl/config/libtoolize
		LIBTOOLIZE=`pwd`/libltdl/config/libtoolize
		export LIBTOOLIZE
		for sub in $reconfdirs; do
			# eautoreconf no workee, is it really worth "investigating" this doomed code?  I'm gonna say no.
			autoreconf --force --verbose --install $sub
		done
		sleep 2 && touch libltdl/config-h.in
		rm -f libltdl/config/libtoolize
		rm -f Makefile libltdl/Makefile libtool vcl.tmp
		for macro in LT_INIT AC_PROG_LIBTOOL AM_PROG_LIBTOOL; do
			if grep $macro aclocal.m4 libltdl/aclocal.m4; then
				die "Bogus $macro macro contents in an aclocal.m4 file."
			fi
		done
		)
	fi

	cd ..
	AT_NOELIBTOOLIZE=yes eautoreconf
	cd ..
	AT_NOELIBTOOLIZE=yes eautoreconf

	# see bug #410877
	use test || \
		epatch "${FILESDIR}"/2.4/${PN}-2.4.2-epunt_cxx.patch
		# epunt_cxx
}

src_configure() {
	# the libtool script uses bash code in it and at configure time, tries
	# to find a bash shell.  if /bin/sh is bash, it uses that.  this can
	# cause problems for people who switch /bin/sh on the fly to other
	# shells, so just force libtool to use /bin/bash all the time.
	export CONFIG_SHELL="$(type -P bash)"

	local myconf
	# usr/bin/libtool is provided by binutils-apple
	[[ ${CHOST} == *-darwin* ]] && myconf="--program-prefix=g"
	econf ${myconf} $(use_enable static-libs static) || die
}

src_install() {
	emake DESTDIR="${D}" install || die
	dodoc AUTHORS ChangeLog* NEWS README THANKS TODO doc/PLATFORMS

	# While the libltdl.la file is not used directly, the m4 ltdl logic
	# keys off of its existence when searching for ltdl support. #293921
	#use static-libs || find "${ED}" -name libltdl.la -delete

	# Building libtool with --disable-static will cause the installed
	# helper to not build static objects by default.  This is undesirable
	# for crappy packages that utilize the system libtool, so undo that.
	dosed '1,/^build_old_libs=/{/^build_old_libs=/{s:=.*:=yes:}}' /usr/bin/libtool || die

	for x in $(find "${ED}" -name config.guess -o -name config.sub) ; do
		rm -f "${x}" ; ln -sf "${EPREFIX}"/usr/share/gnuconfig/${x##*/} "${x}"
	done
}

pkg_preinst() {
	preserve_old_lib /usr/$(get_libdir)/libltdl$(get_libname 3)
}

pkg_postinst() {
	preserve_old_lib_notify /usr/$(get_libdir)/libltdl$(get_libname 3)
}