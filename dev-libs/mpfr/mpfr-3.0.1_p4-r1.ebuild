# Copyright 1999-2011 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/dev-libs/mpfr/mpfr-3.0.1_p4-r1.ebuild,v 1.1 2011/08/25 19:44:27 vapier Exp $

EAPI="3"

# NOTE: we cannot depend on autotools here starting with gcc-4.3.x
inherit eutils libtool multilib

MY_PV=${PV/_p*}
MY_P=${PN}-${MY_PV}
PLEVEL=${PV/*p}
DESCRIPTION="library for multiple-precision floating-point computations with exact rounding"
HOMEPAGE="http://www.mpfr.org/"
SRC_URI="http://www.mpfr.org/mpfr-${MY_PV}/${MY_P}.tar.bz2"

LICENSE="LGPL-2.1"
SLOT="0"
KEYWORDS="~ppc-aix ~x64-freebsd ~x86-freebsd ~hppa-hpux ~ia64-hpux ~x86-interix ~amd64-linux ~ia64-linux ~x86-linux ~ppc-macos ~x64-macos ~x86-macos ~m68k-mint ~sparc-solaris ~sparc64-solaris ~x64-solaris ~x86-solaris"
IUSE="static-libs"

RDEPEND=">=dev-libs/gmp-4.1.4-r2[static-libs=]"
DEPEND="${RDEPEND}"

S=${WORKDIR}/${MY_P}

src_prepare() {
	[[ -d ${FILESDIR}/${PV} ]] && epatch "${FILESDIR}"/${PV}/*.patch
	[[ ${PLEVEL} == ${PV} ]] && return 0
	for ((i=1; i<=PLEVEL; ++i)) ; do
		patch=patch$(printf '%02d' ${i})
		if [[ -f ${FILESDIR}/${MY_PV}/${patch} ]] ; then
			epatch "${FILESDIR}"/${MY_PV}/${patch}
		elif [[ -f ${DISTDIR}/${PN}-${MY_PV}_p${i} ]] ; then
			epatch "${DISTDIR}"/${PN}-${MY_PV}_p${i}
		else
			ewarn "${DISTDIR}/${PN}-${MY_PV}_p${i}"
			die "patch ${i} missing - please report to bugs.gentoo.org"
		fi
	done
	sed -i '/if test/s:==:=:' configure #261016
	find . -type f -print0 | xargs -0 touch -r configure

	# needed for FreeMiNT
	elibtoolize
}

src_configure() {
	local myconf=""
	[[ ${CHOST} == *-cygwin* ]] && \
		myconf="${myconf} --enable-shared"
	econf \
		--with-gmp-lib="${EPREFIX}"/usr/$(get_libdir) \
		--with-gmp-include="${EPREFIX}"/usr/include \
		$(use_enable static-libs static) \
		${myconf}
}

src_install() {
	emake install DESTDIR="${D}" || die
	use static-libs || rm -f "${ED}"/usr/$(get_libdir)/libmpfr.la
	rm "${ED}"/usr/share/doc/${PN}/*.html || die
	mv "${ED}"/usr/share/doc/{${PN},${PF}} || die
	dodoc AUTHORS BUGS ChangeLog NEWS README TODO
	dohtml *.html
	prepalldocs
}

pkg_preinst() {
	preserve_old_lib /usr/$(get_libdir)/libmpfr$(get_libname 1)
}

pkg_postinst() {
	preserve_old_lib_notify /usr/$(get_libdir)/libmpfr$(get_libname 1)
}
