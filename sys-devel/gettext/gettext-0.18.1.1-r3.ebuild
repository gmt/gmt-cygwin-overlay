# Copyright 1999-2012 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI="2"

inherit flag-o-matic eutils multilib toolchain-funcs mono libtool java-pkg-opt-2 autotools

DESCRIPTION="GNU locale utilities"
HOMEPAGE="http://www.gnu.org/software/gettext/"
SRC_URI="mirror://gnu/${PN}/${P}.tar.gz"

LICENSE="GPL-3 LGPL-2"
SLOT="0"
KEYWORDS="~ppc-aix ~x64-freebsd ~x86-freebsd ~hppa-hpux ~ia64-hpux ~x86-interix ~amd64-linux ~ia64-linux ~x86-linux ~ppc-macos ~x64-macos ~x86-macos ~m68k-mint ~sparc-solaris ~sparc64-solaris ~x64-solaris ~x86-solaris ~x86-winnt"
IUSE="acl -cvs doc emacs git java nls +cxx openmp static-libs elibc_glibc"

DEPEND="virtual/libiconv
	dev-libs/libxml2
	!x86-winnt? ( sys-libs/ncurses )
	dev-libs/expat
	acl? ( virtual/acl )
	java? ( >=virtual/jdk-1.4 )"
RDEPEND="${DEPEND}
	!git? ( cvs? ( dev-vcs/cvs ) )
	git? ( dev-vcs/git )
	java? ( >=virtual/jre-1.4 )"
PDEPEND="emacs? ( app-emacs/po-mode )"

src_prepare() {
	java-pkg-opt-2_src_prepare
	if use m68k-mint ; then #334671
		export AT_NO_RECURSIVE=yes
		cd "${S}"/gettext-runtime || die
		AT_M4DIR="m4 gnulib-m4" eautoreconf
		cd "${S}"/gettext-runtime/libasprintf || die
		AT_M4DIR="../../m4 ../m4" eautoreconf
	fi
	# this script uses syntax that Solaris /bin/sh doesn't grok
	sed -i -e '1c\#!/usr/bin/env sh' \
		"${S}"/gettext-tools/misc/convert-archive.in || die

	# work around problem in gnulib on OSX Lion and Mountain Lion
	if [[ ${CHOST} == *-darwin1[12] ]] ; then
		sed -i -e '/^#ifndef weak_alias$/a\# undef __stpncpy' \
			gettext-tools/gnulib-lib/stpncpy.c || die
		sed -i -e '/^# undef __stpncpy$/a\# undef stpncpy' \
			gettext-tools/gnulib-lib/stpncpy.c || die
	fi

	epunt_cxx

	if [[ ${CHOST} == *-cygwin* ]] ; then
		epatch "${FILESDIR}"/${PN}-${PV}-cygport.patch
		epatch "${FILESDIR}"/${PN}-${PV}-cygport-00-reloc.patch
		epatch "${FILESDIR}"/${PN}-${PV}-cygport-01-reloc.patch
		epatch "${FILESDIR}"/${PN}-${PV}-cygport-02-locale.patch
		epatch "${FILESDIR}"/${PN}-${PV}-cygport-03-locale-tests.patch
		epatch "${FILESDIR}"/${PN}-${PV}-woe-is-us.patch
		epatch "${FILESDIR}"/${PN}-${PV}-cygwin1.7-hostglob.patch
		epatch "${FILESDIR}"/${PN}-${PV}-cygwin-am_gnu_gettext_version.patch

		einfo "=-=-=-=-= Welcome to GNU autohell...  TIP: a watched ebuild never merges =-=-=-=-="
		# TODO: audit to ensure that all files are being regenerated that
		# should be from the cygport patches, which is the point, after all.
		AT_NO_RECURSIVE=yes
		cd "${S}"/gettext-runtime/libasprintf || die
		eautoreconf
		cd "${S}"/gettext-runtime || die
		eautoreconf
		cd "${S}"/gettext-tools/examples || die
		AT_NOELIBTOOLIZE=yes eautoreconf
		cd "${S}"/gettext-tools || die
		eautoreconf
		cd "${S}" || die
		AT_NOELIBTOOLIZE=yes eautoreconf
		cd "${S}"/build-aux || die
		elibtoolize
		cd "${S}" || die
		ebegin "Touching generated files (avoid maintainer-mode)"
		for f in gettext-runtime/{,libasprintf/}config.h.in ; do
			einfo "  ${f}"
			touch ./${f} || die
		done
		eend 0
		einfo "=-=-=-=-= Now resuming your regularly scheduled ebuild.  Sorry for the delay! =-=-=-=-="
	else
		elibtoolize
	fi
	epatch "${FILESDIR}"/${P}-uclibc-sched_param-def.patch
	epatch "${FILESDIR}"/${P}-no-gets.patch
}

src_configure() {
	local myconf=""
	# Build with --without-included-gettext (on glibc systems)
	if use elibc_glibc ; then
		myconf="${myconf} --without-included-gettext $(use_enable nls)"
	else
		myconf="${myconf} --with-included-gettext --enable-nls"
	fi
	use cxx || export CXX=$(tc-getCC)

	if [[ ${CHOST} == *-cygwin* ]] ; then
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
		--cache-file="${S}"/config.cache \
		--docdir="${EPREFIX}/usr/share/doc/${PF}" \
		--without-emacs \
		--without-lispdir \
		$(use_enable java) \
		--with-included-glib \
		--with-included-libcroco \
		--with-included-libunistring \
		$(use_enable acl) \
		$(use_enable openmp) \
		$(use_enable static-libs static) \
		$(use_with git) \
		$(usex git --without-cvs $(use_with cvs))
}

src_install() {
	emake install DESTDIR="${D}" || die "install failed"
	use nls || rm -r "${ED}"/usr/share/locale
	use static-libs || rm -f "${ED}"/usr/lib*/*.la
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
