# Copyright 1999-2008 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

inherit eutils

DESCRIPTION="Used to create autoconfiguration files"
HOMEPAGE="http://www.gnu.org/software/autoconf/autoconf.html"
SRC_URI="mirror://gnu/${PN}/${P}.tar.gz"

LICENSE="GPL-2"
SLOT="2.5"
KEYWORDS="~ppc-aix ~x86-freebsd ~ia64-hpux ~x86-interix ~amd64-linux ~x86-linux ~ppc-macos ~x64-macos ~x86-macos ~sparc-solaris ~sparc64-solaris ~x64-solaris ~x86-solaris"
IUSE="emacs"

DEPEND=">=sys-apps/texinfo-4.3
	>=sys-devel/m4-1.4.6
	dev-lang/perl"
RDEPEND="${DEPEND}
	>=sys-devel/autoconf-wrapper-5"
PDEPEND="emacs? ( app-emacs/autoconf-mode )"

src_unpack() {
	unpack ${A}
	cd "${S}"
	epatch "${FILESDIR}"/${P}-revert-AC_C_BIGENDIAN.patch #228825
	epatch "${FILESDIR}"/${P}-at-keywords.patch
	epatch "${FILESDIR}"/${P}-fix-multiline-string.patch #217976
	epatch "${FILESDIR}"/${PN}-2.68-config-guess-cygwin1.7-support.patch

	# usr/bin/libtool is provided by binutils-apple
	[[ ${CHOST} == *-darwin* ]] && epatch "${FILESDIR}"/${PN}-2.61-darwin.patch
}

src_compile() {
	# Disable Emacs in the build system since it is in a separate package.
	export EMACS=no
	econf --program-suffix="-${PV}" || die
	# econf updates config.{sub,guess} which forces the manpages
	# to be regenerated which we dont want to do #146621
	touch man/*.1
	# From configure output:
	# Parallel builds via `make -jN' do not work.
	emake -j1 || die
}

src_install() {
	emake DESTDIR="${D}" install || die
	dodoc AUTHORS BUGS NEWS README TODO THANKS \
		ChangeLog ChangeLog.0 ChangeLog.1 ChangeLog.2
}
