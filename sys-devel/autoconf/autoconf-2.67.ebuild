# Copyright 1999-2011 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI="2"

inherit eutils

if [[ ${PV} == "9999" ]] ; then
	EGIT_REPO_URI="git://git.savannah.gnu.org/autoconf.git"
	inherit git
	SRC_URI=""
	#KEYWORDS=""
else
	SRC_URI="mirror://gnu/${PN}/${P}.tar.bz2
		ftp://alpha.gnu.org/pub/gnu/${PN}/${P}.tar.bz2"
	KEYWORDS="~ppc-aix ~x64-freebsd ~x86-freebsd ~hppa-hpux ~ia64-hpux ~x86-interix ~amd64-linux ~ia64-linux ~x86-linux ~ppc-macos ~x64-macos ~x86-macos ~m68k-mint ~sparc-solaris ~sparc64-solaris ~x64-solaris ~x86-solaris"
fi

DESCRIPTION="Used to create autoconfiguration files"
HOMEPAGE="http://www.gnu.org/software/autoconf/autoconf.html"

LICENSE="GPL-3"
SLOT="2.5"
IUSE="emacs"

DEPEND=">=sys-apps/texinfo-4.3
	>=sys-devel/m4-1.4.6
	dev-lang/perl"
RDEPEND="${DEPEND}
	>=sys-devel/autoconf-wrapper-9-r1"
PDEPEND="emacs? ( app-emacs/autoconf-mode )"

src_prepare() {
	# usr/bin/libtool is provided by binutils-apple
	[[ ${CHOST} == *-darwin* ]] && epatch "${FILESDIR}"/${PN}-2.61-darwin.patch
	epatch "${FILESDIR}"/${PN}-2.68-config-guess-cygwin1.7-support.patch

	if [[ ${PV} == "9999" ]] ; then
		autoreconf -f -i || die
	fi
}

src_configure() {
	# Disable Emacs in the build system since it is in a separate package.
	export EMACS=no
	econf --program-suffix="-${PV}" || die
	# econf updates config.{sub,guess} which forces the manpages
	# to be regenerated which we dont want to do #146621
	touch man/*.1
}

src_install() {
	emake DESTDIR="${D}" install || die
	dodoc AUTHORS BUGS NEWS README TODO THANKS \
		ChangeLog ChangeLog.0 ChangeLog.1 ChangeLog.2
}
