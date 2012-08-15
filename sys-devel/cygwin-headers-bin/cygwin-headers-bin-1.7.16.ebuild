# Copyright 1999-2012 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI="4"

inherit versionator

DESCRIPTION="Standard cygwin header files"
HOMEPAGE="http://cygwin.org"
LICENSE="GPL-3"

KEYWORDS="-* ~x86-cygwin"
IUSE=""

SLOT="$(get_version_component_range 1-2)"
DEPEND=""
RDEPEND=""

MYREV="${PR#r}"
# prefix subrev compatibility
[[ $MYREV == 0*.* ]] && { MYREV="${MYREV#0}" ; MYREV="${MYREV%%.*}" ; }
# add one to the revision level since AFAICS cygwin has no -0's
# to be clear, my intention is to map foo-1.0-r3 to "4" and
# foo-1.0 to "1" (implicit -r0); foo-1.0-r03.8 would map to "4"
(( MYREV++ ))
MYPV="${PV}-${MYREV}"
S=${WORKDIR}/${PN}-${MYPV}
SRC_URI="mirror://cygwin/release/cygwin/cygwin-${MYPV}.tar.bz2"

src_unpack() {
	mkdir -p "${S}"
	cd "${S}"
	unpack "${A}"
}

src_compile() { 
    :;
}

src_install() {
    dodir /usr/include
    cp -R "${S}/usr/include" "${ED}"usr
    cd "${S}"/usr/share/doc/Cygwin
    dodoc COPYING CYGWIN_LICENSE
}

