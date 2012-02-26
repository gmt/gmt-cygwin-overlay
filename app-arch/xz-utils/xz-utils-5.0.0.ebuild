# Copyright 1999-2010 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/app-arch/xz-utils/xz-utils-5.0.0.ebuild,v 1.2 2010/10/26 14:43:14 vapier Exp $

# Remember: we cannot leverage autotools in this ebuild in order
#           to avoid circular deps with autotools

EAPI="2"

if [[ ${PV} == "9999" ]] ; then
	EGIT_REPO_URI="git://ctrl.tukaani.org/xz.git"
	inherit git autotools
	SRC_URI=""
	EXTRA_DEPEND="sys-devel/gettext dev-vcs/cvs >=sys-devel/libtool-2" #272880 286068
else
	MY_P="${PN/-utils}-${PV/_}"
	SRC_URI="http://tukaani.org/xz/${MY_P}.tar.gz"
	KEYWORDS="~ppc-aix ~x64-freebsd ~x86-freebsd ~hppa-hpux ~ia64-hpux ~x86-interix ~amd64-linux ~ia64-linux ~x86-linux ~ppc-macos ~x64-macos ~x86-macos ~m68k-mint ~sparc-solaris ~sparc64-solaris ~x64-solaris ~x86-solaris"
	S=${WORKDIR}/${MY_P}
	EXTRA_DEPEND=
fi

inherit eutils multilib libtool

DESCRIPTION="utils for managing LZMA compressed files"
HOMEPAGE="http://tukaani.org/xz/"

LICENSE="LGPL-2.1"
SLOT="0"
IUSE="nls static-libs +threads"

RDEPEND="!app-arch/lzma
	!app-arch/lzma-utils
	!<app-arch/p7zip-4.57"
DEPEND="${RDEPEND}
	${EXTRA_DEPEND}"

if [[ ${PV} == "9999" ]] ; then
src_prepare() {
	eautopoint
	eautoreconf
}
else
src_prepare() {
	# interix system headers are missing PRI* defines (no inttypes.h).
	epatch "${FILESDIR}"/${P}-interix.patch
	elibtoolize
}
fi

src_configure() {
	local myconf=
	if [[ ${CHOST} == *-interix* ]]; then
		# assembler code contains a reference to _GLOBAL_OFFSET_TABLE_, which 
		# does not exist when building with interix GCC (all code is PIC here).
		myconf="${myconf} --disable-assembler"

		# actually a gcc bug: it complains about not supporting visibility
		# and ignoring it, but generates different code somehow, which doesn't
		# link correctly.
		export gl_cv_cc_visibility=no
	fi

	[[ ${CHOST} == *-cygwin* ]] &&  \
		myconf="${myconf} --disable-rpath"

	econf \
		${myconf} \
		$(use_enable nls) \
		$(use_enable threads) \
		$(use_enable static-libs static)
}

src_install() {
	emake install DESTDIR="${D}" || die
	rm "${ED}"/usr/share/doc/xz/COPYING* || die
	mv "${ED}"/usr/share/doc/{xz,${PF}} || die
	prepalldocs
	dodoc AUTHORS ChangeLog NEWS README THANKS
}

pkg_preinst() {
	preserve_old_lib /usr/$(get_libdir)/liblzma.so.0
}

pkg_postinst() {
	preserve_old_lib_notify /usr/$(get_libdir)/liblzma.so.0
}
