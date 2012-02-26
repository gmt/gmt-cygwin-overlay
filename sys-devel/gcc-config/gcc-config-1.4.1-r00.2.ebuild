# Copyright 1999-2009 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/sys-devel/gcc-config/gcc-config-1.4.1.ebuild,v 1.9 2009/05/20 17:43:36 armin76 Exp $

inherit eutils flag-o-matic toolchain-funcs multilib prefix

# Version of .c wrapper to use
W_VER="1.5.1"

DESCRIPTION="Utility to change the gcc compiler being used"
HOMEPAGE="http://www.gentoo.org/"
SRC_URI=""

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~ppc-aix ~x64-freebsd ~x86-freebsd ~hppa-hpux ~ia64-hpux ~x86-interix ~amd64-linux ~ia64-linux ~x86-linux ~ppc-macos ~x64-macos ~x86-macos ~m68k-mint ~sparc-solaris ~sparc64-solaris ~x64-solaris ~x86-solaris ~x86-winnt"
IUSE=""

RDEPEND="!app-admin/eselect-compiler
	>=sys-devel/binutils-config-1.9-r04.3"

S=${WORKDIR%/}

src_unpack() {
	cp "${FILESDIR}"/wrapper-${W_VER}.c "${S}"/wrapper.c || die
	echo doing: cp "${FILESDIR}"/wrapper-${W_VER}.c "${S}"/wrapper.c
	cp "${FILESDIR}"/${PN}-${PV}  "${S}/"${PN}-${PV} || die
	eprefixify "${S}"/wrapper.c "${S}"/${PN}-${PV}
}

src_compile() {
	strip-flags

	emake CC="$(tc-getCC)" wrapper || die "compile wrapper"
}

src_install() {
	newbin ${PN}-${PV} ${PN} || die "install gcc-config"

	local libdir
	libdir="$(get_libdir)"
	libdir="${libdir%/}"
	libdir="${libdir#/}"

	sed -i \
		-e "s:@GENTOO_LIBDIR@:/${libdir}:g" \
		"${ED%/}"/usr/bin/${PN}

	exeinto /usr/${libdir}/misc
	newexe wrapper gcc-config || die "install wrapper"
}

pkg_postinst() {
	# Scrub eselect-compiler remains
	if [[ -e ${EROOT}etc/env.d/05compiler ]] ; then
		rm -f "${EROOT}"etc/env.d/05compiler
	fi

	# Make sure old versions dont exist #79062
	rm -f "${EROOT}"usr/sbin/gcc-config

	# Do we have a valid multi ver setup ?
	if gcc-config --get-current-profile &>/dev/null ; then
		# We not longer use the /usr/include/g++-v3 hacks, as
		# it is not needed ...
		[[ -L ${EROOT}usr/include/g++ ]] && rm -f "${EROOT}"usr/include/g++
		[[ -L ${EROOT}usr/include/g++-v3 ]] && rm -f "${EROOT}"usr/include/g++-v3
		gcc-config $(${EPREFIX%/}/usr/bin/gcc-config --get-current-profile)
	fi
}
