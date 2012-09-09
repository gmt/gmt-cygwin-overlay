# Copyright 1999-2012 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI=4
inherit flag-o-matic multilib libtool autotools

MY_P=pkg-config-${PV}

DESCRIPTION="Package config system that manages compile/link flags"
HOMEPAGE="http://pkgconfig.freedesktop.org/wiki/"
SRC_URI="http://pkgconfig.freedesktop.org/releases/${MY_P}.tar.gz"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="alpha amd64 arm hppa ia64 m68k ~mips ppc ppc64 s390 sh sparc x86 ~ppc-aix ~amd64-fbsd ~sparc-fbsd ~x86-fbsd ~x64-freebsd ~x86-freebsd ~hppa-hpux ~ia64-hpux ~x86-interix ~amd64-linux ~ia64-linux ~x86-linux ~ppc-macos ~x64-macos ~x86-macos ~m68k-mint ~sparc-solaris ~sparc64-solaris ~x64-solaris ~x86-solaris"
IUSE="elibc_FreeBSD hardened"

RDEPEND=">=dev-libs/glib-2.28
	>=dev-libs/popt-1.16
	!dev-util/pkgconf[pkg-config]
	!dev-util/pkg-config-lite
	!dev-util/pkgconfig-openbsd[pkg-config]"
DEPEND="${RDEPEND}"

S=${WORKDIR}/${MY_P}

DOCS=( AUTHORS NEWS README )

src_prepare() {
	if [[ ${CHOST} == *-cygwin* ]] ; then
		epatch "${FILESDIR}"/${PN}-0.23b-cygport.patch
		epatch "${FILESDIR}"/${PN}-fix-const.patch
		eautoreconf
	fi
	elibtoolize # for FreeMiNT, bug #333429
}

src_configure() {
	if ! has_version dev-util/pkgconfig; then
		export GLIB_CFLAGS="-I${EPREFIX}/usr/include/glib-2.0 -I${EPREFIX}/usr/$(get_libdir)/glib-2.0/include"
		export GLIB_LIBS="-lglib-2.0"
	fi

	use ppc64 && use hardened && replace-flags -O[2-3] -O1

	# Force using all the requirements when linking, so that needed -pthread
	# lines are inherited between libraries
	local myconf
	if use elibc_FreeBSD || [[ ${CHOST} == *-cygwin* ]] ; then
		myconf="--enable-indirect-deps"
	fi

	econf \
		--docdir="${EPREFIX}"/usr/share/doc/${PF}/html \
		--with-system-include-path="${EPREFIX}"/usr/include \
		--with-system-library-path="${EPREFIX}"/usr/$(get_libdir) \
		--with-installed-popt \
		${myconf}
}

src_install() {
	default

	if use prefix; then
		# Add an explicit reference to $EPREFIX to PKG_CONFIG_PATH to
		# simplify cross-prefix builds
		echo "PKG_CONFIG_PATH=${EPREFIX}/usr/$(get_libdir)/pkgconfig:${EPREFIX}/usr/share/pkgconfig" >> "${T}"/99${PN}
		doenvd "${T}"/99${PN}
	fi
}
