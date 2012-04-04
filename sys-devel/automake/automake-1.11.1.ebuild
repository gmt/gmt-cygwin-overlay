# Copyright 1999-2010 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/sys-devel/automake/automake-1.11.1.ebuild,v 1.8 2010/05/31 19:20:31 josejx Exp $

inherit eutils versionator autotools prefix-gmt

if [[ ${PV/_beta} == ${PV} ]]; then
	MY_P=${P}
	SRC_URI="mirror://gnu/${PN}/${P}.tar.bz2"
else
	MY_PV="$(get_major_version).$(($(get_version_component_range 2)-1))b"
	MY_P="${PN}-${MY_PV}"

	# Alpha/beta releases are not distributed on the usual mirrors.
	SRC_URI="ftp://alpha.gnu.org/pub/gnu/${PN}/${MY_P}.tar.bz2"
fi

S="${WORKDIR}/${MY_P}"

# Use Gentoo versioning for slotting.
SLOT="${PV:0:4}"

DESCRIPTION="Used to generate Makefile.in from Makefile.am"
HOMEPAGE="http://sources.redhat.com/automake/"

LICENSE="GPL-2"
KEYWORDS="~ppc-aix ~x64-freebsd ~x86-freebsd ~hppa-hpux ~ia64-hpux ~x86-interix ~amd64-linux ~ia64-linux ~x86-linux ~ppc-macos ~x64-macos ~x86-macos ~m68k-mint ~sparc-solaris ~sparc64-solaris ~x64-solaris ~x86-solaris"
IUSE="ultra-prefixify"

RDEPEND="dev-lang/perl
	>=sys-devel/automake-wrapper-3-r2
	>=sys-devel/autoconf-2.62
	>=sys-apps/texinfo-4.7
	sys-devel/gnuconfig"
DEPEND="${RDEPEND}
	sys-apps/help2man"

src_unpack() {
	unpack ${A}
	cd "${S}"
	epatch "${FILESDIR}"/${PN}-cygwin1.7-config-guess.patch
	chmod a+rx tests/*.test
	export WANT_AUTOCONF=2.5
	if use ultra-prefixify ; then
		bash_shebang_prefixify bootstrap lib/acinstall lib/compile \
			lib/config.{guess,sub} lib/{install,mdate}-sh lib/missing \
			lib/elisp-comp lib/gnupload lib/mkinstalldirs lib/py-compile \
			lib/symlink-tree lib/ylwrap
		bash_shebang_prefixify_dirs tests
		eprefixify_patch "${FILESDIR}"/${PN}-${PV}-ultra-prefixification.patch
		# FIXME: the above is triggering maintainer-mode
		eautoreconf
		bash_shebang_prefixify configure
	fi
	sed -i \
		-e "s|: (automake)| v${SLOT}: (automake${SLOT})|" \
		doc/automake.texi || die "sed failed"
	mv doc/automake{,${SLOT}}.texi
	sed -i \
		-e "s:automake.info:automake${SLOT}.info:" \
		-e "s:automake.texi:automake${SLOT}.texi:" \
		doc/Makefile.in || die "sed on Makefile.in failed"
}

src_compile() {
	econf --docdir="${EPREFIX}"/usr/share/doc/${PF} HELP2MAN=true || die
	emake \
		APIVERSION="${SLOT}" pkgvdatadir="${EPREFIX}/usr/share/${PN}-${SLOT}" || die

	local x
	for x in aclocal automake; do
		help2man "perl -Ilib ${x}" > doc/${x}-${SLOT}.1
	done
}

src_install() {
	emake DESTDIR="${D}" install \
		APIVERSION="${SLOT}" pkgvdatadir="${EPREFIX}/usr/share/${PN}-${SLOT}" || die
	dodoc NEWS README THANKS TODO AUTHORS ChangeLog

	rm \
		"${ED}"/usr/bin/{aclocal,automake} \
		"${ED}"/usr/share/man/man1/{aclocal,automake}.1

	# remove all config.guess and config.sub files replacing them
	# w/a symlink to a specific gnuconfig version
	local x
	for x in guess sub ; do
		dosym ../gnuconfig/config.${x} /usr/share/${PN}-${SLOT}/config.${x}
	done
	use prefix && bash_shebang_prefixify "${ED}"/usr/share/${PN}-${SLOT}/depcomp
}
