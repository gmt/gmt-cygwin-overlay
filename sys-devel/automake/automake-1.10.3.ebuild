# Copyright 1999-2010 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/sys-devel/automake/automake-1.10.3.ebuild,v 1.7 2010/03/13 19:31:12 armin76 Exp $

inherit eutils prefix-gmt

DESCRIPTION="Used to generate Makefile.in from Makefile.am"
HOMEPAGE="http://sources.redhat.com/automake/"
SRC_URI="mirror://gnu/${PN}/${P}.tar.bz2"

LICENSE="GPL-2"
SLOT="${PV:0:4}"
KEYWORDS="~ppc-aix ~x64-freebsd ~x86-freebsd ~hppa-hpux ~ia64-hpux ~x86-interix ~amd64-linux ~ia64-linux ~x86-linux ~ppc-macos ~x64-macos ~x86-macos ~m68k-mint ~sparc-solaris ~sparc64-solaris ~x64-solaris ~x86-solaris"
IUSE=""

RDEPEND="dev-lang/perl
	>=sys-devel/automake-wrapper-2
	>=sys-devel/autoconf-2.60
	>=sys-apps/texinfo-4.7
	sys-devel/gnuconfig"
DEPEND="${RDEPEND}
	sys-apps/help2man"

src_unpack() {
	unpack ${A}
	cd "${S}"
	chmod a+rx tests/*.test
	sed -i \
		-e "s|: (automake)| v${SLOT}: (automake${SLOT})|" \
		doc/automake.texi || die "sed failed"
	mv doc/automake{,${SLOT}}.texi
	sed -i \
		-e "s:automake.info:automake${SLOT}.info:" \
		-e "s:automake.texi:automake${SLOT}.texi:" \
		doc/Makefile.in || die "sed on Makefile.in failed"
	export WANT_AUTOCONF=2.5

	# this fixes --disable-dependency-tracking for all config.status files.
	# the symptom was a "shift: nothing to shift" with ksh and a silent
	# configure failure with bash. the patch has been reported upstream.
	epatch "${FILESDIR}"/${PN}-1.10.2-depout.patch
	epatch "${FILESDIR}"/${PN}-cygwin1.7-config-guess.patch
	if use prefix ; then
		bash_shebang_prefixify bootstrap configure lib/acinstall lib/compile \
		lib/config.guess lib/config.sub lib/elisp-comp lib/install-sh lib/mdate-sh \
		lib/missing lib/mkinstalldirs lib/py-compile lib/symlink-tree lib/ylwrap
		bash_shebang_prefixify_dirs tests
		eprefixify_patch "${FILESDIR}"/${PN}-${PV}-eprefix.patch
	fi
}

src_compile() {
	econf --docdir="${EPREFIX}"/usr/share/doc/${PF} || die
	emake || die
}

src_install() {
	emake DESTDIR="${D}" install || die
	dodoc NEWS README THANKS TODO AUTHORS ChangeLog

	# SLOT the docs and junk
	local x
	for x in aclocal automake ; do
		help2man "perl -Ilib ${x}" > ${x}-${SLOT}.1
		doman ${x}-${SLOT}.1
		rm -f "${ED}"/usr/bin/${x}
	done

	# remove all config.guess and config.sub files replacing them
	# w/a symlink to a specific gnuconfig version
	for x in guess sub ; do
		dosym ../gnuconfig/config.${x} /usr/share/${PN}-${SLOT}/config.${x}
	done
}
