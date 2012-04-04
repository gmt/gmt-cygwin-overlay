# Copyright 1999-2011 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/sys-devel/gettext/gettext-0.18.1.1-r2.ebuild,v 1.2 2011/04/08 19:40:29 betelgeuse Exp $

EAPI="2"

inherit flag-o-matic eutils multilib toolchain-funcs mono libtool java-pkg-opt-2 autotools prefix-gmt

DESCRIPTION="GNU locale utilities"
HOMEPAGE="http://www.gnu.org/software/gettext/"
SRC_URI="mirror://gnu/${PN}/${P}.tar.gz"

LICENSE="GPL-3 LGPL-2"
SLOT="0"
KEYWORDS="~ppc-aix ~x64-freebsd ~x86-freebsd ~hppa-hpux ~ia64-hpux ~x86-interix ~amd64-linux ~ia64-linux ~x86-linux ~ppc-macos ~x64-macos ~x86-macos ~m68k-mint ~sparc-solaris ~sparc64-solaris ~x64-solaris ~x86-solaris ~x86-winnt"
IUSE="acl doc emacs +git java nls nocxx openmp elibc_glibc ultra-prefixify"

DEPEND="virtual/libiconv
	dev-libs/libxml2
	!x86-winnt? ( sys-libs/ncurses )
	dev-libs/expat
	acl? ( virtual/acl )
	java? ( >=virtual/jdk-1.4 )"
RDEPEND="${DEPEND}
	git? ( dev-vcs/git )
	java? ( >=virtual/jre-1.4 )"
PDEPEND="emacs? ( app-emacs/po-mode )"

src_prepare() {
	java-pkg-opt-2_src_prepare
	if use m68k-mint && ! use prefix; then #334671
		export AT_NO_RECURSIVE=yes
		cd "${S}"/gettext-runtime || die
		AT_M4DIR="m4 gnulib-m4" eautoreconf
		cd "${S}"/gettext-runtime/libasprintf || die
		AT_M4DIR="../../m4 ../m4" eautoreconf
	fi
	# this script uses syntax that Solaris /bin/sh doesn't grok
	if use ultra-prefixify ; then
	sed -i -e '1c\#!'"${EPREFIX}"'/usr/bin/env sh' \
		"${S}"/gettext-tools/misc/convert-archive.in || die
	else
	sed -i -e '1c\#!/usr/bin/env sh' \
		"${S}"/gettext-tools/misc/convert-archive.in || die
	fi

	# work around problem in gnulib on OSX Lion
	if [[ ${CHOST} == *-darwin11 ]] ; then
		sed -i -e '/^#ifndef weak_alias$/a\# undef __stpncpy' \
			gettext-tools/gnulib-lib/stpncpy.c || die
		sed -i -e '/^# undef __stpncpy$/a\# undef stpncpy' \
			gettext-tools/gnulib-lib/stpncpy.c || die
	fi

	epunt_cxx

	if use ultra-prefixify ; then
		cd "${S}"
		# Note: Some of the below may get wiped out during reconfig.  You are welcome to sort that shit
		# out for me if you like, patches welcome. in the meanwhile we err on the side of caution :) -gmt
		bash_shebang_prefixify $( find . -name 'config.charset' -o -name 'config.guess' -o -name 'config.sub' -o \
			-name 'x-to-1.in' -o -name 'autoclean.sh' -o -name 'autogen.sh' ) \
			gettext-tools/libgettextpo/exported.sh.in gettext-tools/examples \
			gettext-tools/misc/{add-to-archive,autopoint.in,gettextize.in} \
			./gettext-tools/src/user-email.sh.in ./gnulib-local/build-aux/moopp \
			./gnulib-local/tests/test-term-ostream-xterm
		bash_shebang_prefixify_dirs -r gettext-tools/gnulib-tests gettext-tools/projects \
			gettext-tools/tests build-aux gettext-tools/examples
		eprefixify_patch "${FILESDIR}"/${PN}-${PV}-ultra-eprefixification.patch
	fi

	if [[ ${CHOST} == *-cygwin* ]] ; then
		epatch "${FILESDIR}"/${PN}-${PV}-cygport.patch
		epatch "${FILESDIR}"/${PN}-${PV}-cygport-00-reloc.patch
		epatch "${FILESDIR}"/${PN}-${PV}-cygport-01-reloc.patch
		epatch "${FILESDIR}"/${PN}-${PV}-cygport-02-locale.patch
		epatch "${FILESDIR}"/${PN}-${PV}-cygport-03-locale-tests.patch
		epatch "${FILESDIR}"/${PN}-${PV}-woe-is-us.patch
		epatch "${FILESDIR}"/${PN}-${PV}-cygwin1.7-hostglob.patch
	fi

	if [[ ${CHOST} == *-cygwin* ]] || use ultra-prefixify ; then
		einfo "running elibtoolize --force in ."
		elibtoolize --force || die

		einfo "doing autogen stuff for ./gettext-runtime/libasprintf"
		cd "${S}"/gettext-runtime/libasprintf || die
		einfo Running fixaclocal
		../../build-aux/fixaclocal aclocal -I ../../m4 -I ../m4 -I gnulib-m4 || die
		eautoconf || die
		eautoheader || die
		eautomake || die

		einfo "doing autogen stuff for ./gettext-runtime"
		cd "${S}"/gettext-runtime || die
		einfo Running fixaclocal
		../build-aux/fixaclocal aclocal -I m4 -I ../m4 -I gnulib-m4 || die
		eautoconf || die
		eautoheader || die
		touch config.h.in
		eautomake || die

		einfo "doing autogen stuff for ./gettext-tools/examples"
		cd "${S}"/gettext-tools/examples || die
		eautoconf || die
		eautomake || die
		
		einfo "doing autogen stuff for ./gettext-tools"
		cd "${S}"/gettext-tools || die
		einfo Running fixaclocal
		../build-aux/fixaclocal aclocal -I m4 -I ../gettext-runtime/m4 -I ../m4 \
                	-I gnulib-m4 -I libgrep/gnulib-m4 -I libgettextpo/gnulib-m4 || die
		eautoconf || die
		eautoheader || die
		touch config.h.in
		test -d intl || mkdir intl
		eautomake || die

		einfo "doing autogenstuff for ."
		cd "${S}" || die
		cp -pv gettext-runtime/ABOUT-NLS gettext-tools/ABOUT-NLS
		einfo Running fixaclocal
		build-aux/fixaclocal aclocal -I m4 || die
		eautoconf || die
		eautomake || die
	else
		elibtoolize
	fi
}

src_configure() {
	local myconf=""
	# Build with --without-included-gettext (on glibc systems)
	if use elibc_glibc ; then
		myconf="${myconf} --without-included-gettext $(use_enable nls)"
	else
		myconf="${myconf} --with-included-gettext --enable-nls"
	fi
	use nocxx && export CXX=$(tc-getCC)

	if [[ ${CHOST} == *-cygwin* ]] ; then
#		append-cppflags -I/usr/include/ncursesw
#		append-ldflags -L/usr/lib/ncursesw
		filter-ldflags -Wl,--disable-auto-import
		econf="${econf} --enable-shared --enable-static --enable-silent-rules"
		econf="${econf} --with-included-gettext --with-included-libxml --disable-native-java"
	fi

	# --without-emacs: Emacs support is now in a separate package
	# --with-included-glib: glib depends on us so avoid circular deps
	# --with-included-libcroco: libcroco depends on glib which ... ^^^
	#
	# --with-included-libunistring will _disable_ libunistring (since
	# --it's not bundled), see bug #326477
	econf \
		--docdir="${EPREFIX}/usr/share/doc/${PF}" \
		--without-emacs \
		--without-lispdir \
		$(use_enable java) \
		--with-included-glib \
		--with-included-libcroco \
		--with-included-libunistring \
		$(use_enable acl) \
		$(use_enable openmp) \
		$(use_with git) \
		--without-cvs
}

src_install() {
	emake install DESTDIR="${D}" || die "install failed"
	use nls || rm -r "${ED}"/usr/share/locale
	dosym msgfmt /usr/bin/gmsgfmt #43435
	dobin gettext-tools/misc/gettextize || die "gettextize"

	# remove stuff that glibc handles
	if use elibc_glibc ; then
		rm -f "${ED}"/usr/include/libintl.h
		rm -f "${ED}"/usr/$(get_libdir)/libintl.*
	fi
	rm -f "${ED}"/usr/share/locale/locale.alias "${ED}"/usr/lib/charset.alias

	if [[ ${USERLAND} == "BSD" ]] ; then
		libname="libintl$(get_libname)"
		# Move dynamic libs and creates ldscripts into /usr/lib
		dodir /$(get_libdir)
		mv "${ED}"/usr/$(get_libdir)/${libname}* "${ED}"/$(get_libdir)/
		gen_usr_ldscript ${libname}
	fi

	if use java ; then
		java-pkg_dojar "${ED}"/usr/share/${PN}/*.jar
		rm -f "${ED}"/usr/share/${PN}/*.jar
		rm -f "${ED}"/usr/share/${PN}/*.class
		if use doc ; then
			java-pkg_dojavadoc "${ED}"/usr/share/doc/${PF}/javadoc2
			rm -rf "${ED}"/usr/share/doc/${PF}/javadoc2
		fi
	fi

	if use doc ; then
		dohtml "${ED}"/usr/share/doc/${PF}/*.html
	else
		rm -rf "${ED}"/usr/share/doc/${PF}/{csharpdoc,examples,javadoc2,javadoc1}
	fi
	rm -f "${ED}"/usr/share/doc/${PF}/*.html

	dodoc AUTHORS ChangeLog NEWS README THANKS
}

pkg_preinst() {
	# older gettext's sometimes installed libintl ...
	# need to keep the linked version or the system
	# could die (things like sed link against it :/)
	preserve_old_lib /{,usr/}$(get_libdir)/libintl$(get_libname 7)

	java-pkg-opt-2_pkg_preinst
}

pkg_postinst() {
	preserve_old_lib_notify /{,usr/}$(get_libdir)/libintl$(get_libname 7)
}
