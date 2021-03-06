# Copyright 1999-2012 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI=4
inherit fdo-mime autotools eutils

DESCRIPTION="The Shared MIME-info Database specification"
HOMEPAGE="http://freedesktop.org/wiki/Software/shared-mime-info"
SRC_URI="http://people.freedesktop.org/~hadess/${P}.tar.xz"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="alpha amd64 arm hppa ia64 ~mips ppc ppc64 s390 sh sparc x86 ~amd64-fbsd ~x86-fbsd ~x64-freebsd ~x86-freebsd ~x86-interix ~amd64-linux ~x86-linux ~ppc-macos ~x64-macos ~x86-macos ~m68k-mint ~sparc-solaris ~sparc64-solaris ~x64-solaris ~x86-solaris"
IUSE=""

RDEPEND=">=dev-libs/glib-2
	dev-libs/libxml2"
DEPEND="${RDEPEND}
	app-arch/xz-utils
	dev-util/intltool
	virtual/pkgconfig
	sys-devel/gettext"

DOCS=( ChangeLog HACKING NEWS README )

src_prepare() {
	if [[ ${CHOST} == *-cygwin* ]] ; then
		# backport 1f3c3f46e (https://bugs.freedesktop.org/show_bug.cgi?id=42554)
		epatch "${FILESDIR}"/${P}-fix-exe-platforms.patch
		eautoreconf
	fi
}

src_configure() {
	econf --disable-update-mimedb
}

src_compile() {
	# FIXME: 0.91 fails with -j9 every second time like:
	# update_mime_database-update-mime-database.o: file not recognized: File truncated
	# collect2: ld returned 1 exit status
	emake -j1
}

src_install() {
	default

	# in prefix, install an env.d entry such that prefix patch is used/added
	if use prefix; then
		echo "XDG_DATA_DIRS=\"${EPREFIX}/usr/share\"" > "${T}"/50mimeinfo
		doenvd "${T}"/50mimeinfo
	fi
}

pkg_postinst() {
	use prefix && export XDG_DATA_DIRS="${EPREFIX}"/usr/share
	fdo-mime_mime_database_update
}
