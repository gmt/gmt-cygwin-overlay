# Copyright 1999-2012 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

# Unconditional dependency of gcc.  Keep this set to 0.
EAPI="0"

inherit eutils libtool

DESCRIPTION="A library for multiprecision complex arithmetic with exact rounding."
HOMEPAGE="http://mpc.multiprecision.org/"
SRC_URI="http://www.multiprecision.org/mpc/download/${P}.tar.gz
	mirror://gentoo/${P}-configure.patch.bz2"

LICENSE="LGPL-2.1"
SLOT="0"
KEYWORDS="~alpha ~amd64 ~arm ~hppa ~ia64 ~m68k ~mips ~ppc ~ppc64 ~s390 ~sh ~sparc ~x86 ~ppc-aix ~amd64-fbsd ~sparc-fbsd ~x86-fbsd ~x64-freebsd ~x86-freebsd ~ia64-hpux ~x86-interix ~amd64-linux ~ia64-linux ~x86-linux ~ppc-macos ~x86-macos ~m68k-mint ~sparc-solaris ~sparc64-solaris ~x64-solaris ~x86-solaris"
IUSE="static-libs"

DEPEND=">=dev-libs/gmp-4.3.2
	>=dev-libs/mpfr-2.4.2
	elibc_SunOS? ( >=sys-devel/gcc-4.5 )"
RDEPEND="${DEPEND}"

src_unpack() {
	unpack ${A}
	cd "${S}"
	epatch "${WORKDIR}"/${P}-configure.patch
	elibtoolize # for FreeMiNT, bug #347317
}

src_compile() {
	if [[ ${CFLAGS} == *-cygwin* ]] ; then
		econf $(use_enable static-libs static) --enable-shared || die
	else
		econf $(use_enable static-libs static) || die
	fi
	emake || die
}

src_install() {
	emake DESTDIR="${D}" install || die
	use static-libs || rm "${ED:-${D}}"/usr/lib*/libmpc.la
	dodoc ChangeLog NEWS README TODO
}
