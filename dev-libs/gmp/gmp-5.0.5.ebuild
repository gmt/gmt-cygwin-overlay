# Copyright 1999-2012 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

inherit flag-o-matic eutils libtool unpacker toolchain-funcs

MY_PV=${PV/_p*}
MY_P=${PN}-${MY_PV}
PLEVEL=${PV/*p}
DESCRIPTION="Library for arithmetic on arbitrary precision integers, rational numbers, and floating-point numbers"
HOMEPAGE="http://gmplib.org/"
SRC_URI="mirror://gnu/${PN}/${MY_P}.tar.xz
	doc? ( http://gmplib.org/${PN}-man-${MY_PV}.pdf )"

LICENSE="LGPL-3"
SLOT="0"

KEYWORDS="~ppc-aix ~x64-freebsd ~x86-freebsd ~hppa-hpux ~ia64-hpux ~x86-interix ~amd64-linux ~ia64-linux ~x86-linux ~ppc-macos ~x64-macos ~x86-macos ~m68k-mint ~sparc-solaris ~sparc64-solaris ~x64-solaris ~x86-solaris"
IUSE="doc cxx static-libs"

DEPEND="sys-devel/m4
	app-arch/xz-utils"
RDEPEND=""

S=${WORKDIR}/${MY_P}

src_unpack() {
	unpacker_src_unpack
	cd "${S}"
	[[ -d ${FILESDIR}/${PV} ]] && EPATCH_SUFFIX="diff" EPATCH_FORCE="yes" epatch "${FILESDIR}"/${PV}
 	epatch "${FILESDIR}"/${PN}-4.1.4-noexecstack.patch
	epatch "${FILESDIR}"/${PN}-5.0.5-x32-support.patch
	epatch "${FILESDIR}"/${PN}-5.0.2-cygwin-declspec.patch

	# disable -fPIE -pie in the tests for x86  #236054
	if use x86 && gcc-specs-pie ; then
		epatch "${FILESDIR}"/${PN}-5.0.1-x86-nopie-tests.patch
	fi

	# note: we cannot run autotools here as gcc depends on this package
	elibtoolize

	# GMP uses the "ABI" env var during configure as does Gentoo (econf).
	# So, to avoid patching the source constantly, wrap things up.
	mv configure configure.wrapped || die
	echo "#!${EPREFIX}/bin/sh" > configure
	echo 'exec env ABI="$GMPABI" "${0}.wrapped" "$@"' >> configure
	chmod a+rx configure
}

src_compile() {
	local myconf

	# Because of our 32-bit userland, 1.0 is the only HPPA ABI that works
	# http://gmplib.org/manual/ABI-and-ISA.html#ABI-and-ISA (bug #344613)
	if [[ ${CHOST} == hppa2.0-* ]] ; then
		export GMPABI="1.0"
	fi

	# ABI mappings (needs all architectures supported)
	case ${ABI} in
		32|x86)       GMPABI=32;;
		64|amd64|n64) GMPABI=64;;
		[onx]32)      GMPABI=${ABI};;
	esac
	export GMPABI

	#367719
	if [[ ${CHOST} == *-mint* ]]; then
		filter-flags -O?
	fi

	if [[ ${CHOST} == *-cygwin* ]] ; then
		# libmpc issue?
		myconf="${myconf} --enable-mpbsd"
		myconf="${myconf} --enable-fat"
		myconf="${myconf} --enable-shared" # otherwise only static is built!
		GMPABI=32
	else
		myconf="${myconf} --disable-mpbsd"
	fi

	tc-export CC
	econf \
		--localstatedir="${EPREFIX}"/var/state/gmp \
		$(use_enable !nocxx cxx) \
		${myconf} \
		$(use_enable static-libs static) \
		|| die

	emake || die
}

src_install() {
	emake DESTDIR="${D}" install || die

	# should be a standalone lib
	rm -f "${ED}"/usr/$(get_libdir)/libgmp.la
	# this requires libgmp
	local la="${ED}/usr/$(get_libdir)/libgmpxx.la"
	use static-libs \
		&& sed -i 's:/[^ ]*/libgmp.la:-lgmp:' "${la}" \
		|| rm -f "${la}"

	dodoc AUTHORS ChangeLog NEWS README
	dodoc doc/configuration doc/isa_abi_headache
	dohtml -r doc

	use doc && cp "${DISTDIR}"/gmp-man-${MY_PV}.pdf "${ED}"/usr/share/doc/${PF}/
}

pkg_preinst() {
	preserve_old_lib /usr/$(get_libdir)/libgmp.so.3
}

pkg_postinst() {
	preserve_old_lib_notify /usr/$(get_libdir)/libgmp.so.3
}
