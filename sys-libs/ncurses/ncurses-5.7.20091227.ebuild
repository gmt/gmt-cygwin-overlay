# Copyright 1999-2012 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI="1"
AUTOTOOLS_AUTO_DEPEND="no"
inherit eutils flag-o-matic toolchain-funcs multilib autotools

MY_PV=${PV:0:3}
PV_SNAP=${PV:4}
MY_P=${PN}-${MY_PV}
DESCRIPTION="console display library"
HOMEPAGE="http://www.gnu.org/software/ncurses/ http://dickey.his.com/ncurses/"
SRC_URI="mirror://gnu/ncurses/${MY_P}.tar.gz"

LICENSE="MIT"
SLOT="5"
KEYWORDS="~ppc-aix ~x64-freebsd ~x86-freebsd ~hppa-hpux ~ia64-hpux ~x86-interix ~amd64-linux ~ia64-linux ~x86-linux ~ppc-macos ~x64-macos ~x86-macos ~m68k-mint ~sparc-solaris ~sparc64-solaris ~x64-solaris ~x86-solaris"
IUSE="ada +cxx debug doc gpm minimal profile static-libs trace unicode"

DEPEND="gpm? ( sys-libs/gpm )
	kernel_AIX? ( ${AUTOTOOLS_DEPEND} )
	kernel_HPUX? ( ${AUTOTOOLS_DEPEND} )"
#	berkdb? ( sys-libs/db )"
RDEPEND="!<x11-terms/rxvt-unicode-9.06-r3"

S=${WORKDIR}/${MY_P}

need-libtool() {
	# need libtool to build aix-style shared objects inside archive libs, but
	# cannot depend on libtool, as this would create circular dependencies...
	# And libtool-1.5.26 needs (a similar) patch for AIX (DESTDIR) as found in
	# http://lists.gnu.org/archive/html/bug-libtool/2008-03/msg00124.html
	# Use libtool on hpux too to get some soname.
	# and cygwin to avoid BROKEN_LINKER
	[[ ${CHOST} == *'-aix'* || ${CHOST} == *'-hpux'* || ${CHOST} == *'-cygwin'* ]]
}

src_unpack() {
	unpack ${A}
	cd "${S}"
	if [[ -n ${PV_SNAP} ]] ; then
		if [[ -e "${WORKDIR}"/${MY_P}-${PV_SNAP}-patch.sh ]] ; then
			epatch "${WORKDIR}"/${MY_P}-${PV_SNAP}-patch.sh
		# gmt_cygwin_overlay hack: if the official .sh script 
		# is not found, look for a regular patch (FIXME: any reason
		# I didn't just use the real deal instead?  IIRC it's 
		# avail. in the cygport)
		elif [[ -e "${FILESDIR}"/${MY_P}-${PV_SNAP}.patch ]] ; then
			epatch "${FILESDIR}"/${MY_P}-${PV_SNAP}.patch
		else
			die snapshot "${PV_SNAP}" not found
		fi
	fi
	epatch "${FILESDIR}"/${PN}-5.6-gfbsd.patch
	epatch "${FILESDIR}"/${PN}-5.7-nongnu.patch
	sed -i '/with_no_leaks=yes/s:=.*:=$enableval:' configure #305889

	epatch "${FILESDIR}"/${PN}-5.7-mint-refresh.patch
	epatch "${FILESDIR}"/${PN}-5.7-mint-terminfo.patch
	epatch "${FILESDIR}"/${PN}-5.5-aix-shared.patch
	epatch "${FILESDIR}"/${PN}-5.6-interix.patch
	epatch "${FILESDIR}"/${PN}-5.6-netbsd.patch
#	epatch "${FILESDIR}"/${PN}-5.6-libtool.patch # used on aix
	epatch "${FILESDIR}"/${PN}-5.7-x64-freebsd.patch
	epatch "${FILESDIR}"/${PN}-5.7-ldflags-with-libtool-refresh.patch

	if [[ ${CHOST} == *-cygwin* ]] ; then
		epatch "${FILESDIR}"/${PN}-5.7-cygwin-pthreads.patch
		epatch "${FILESDIR}"/${PN}-5.7-pc-files-dep.patch
		epatch "${FILESDIR}"/${PN}-5.7-widec-wchar_h.patch
		epatch "${FILESDIR}"/${PN}-5.7-cygwin-misc.patch
	fi

	# irix /bin/sh is no good
	find . -name "*.sh" | xargs sed -i -e '1c\#!/usr/bin/env sh'

	if need-libtool; then
		mkdir "${WORKDIR}"/local-libtool || die
		cd "${WORKDIR}"/local-libtool || die
		cat >configure.ac<<-EOF
			AC_INIT(local-libtool, 0)
			AC_PROG_CC
			AC_PROG_CXX
			AC_PROG_LIBTOOL
			AC_OUTPUT
		EOF
		eautoreconf
	fi
}

src_compile() {
	if need-libtool; then
		cd "${WORKDIR}"/local-libtool || die
		econf
		export PATH="${WORKDIR}"/local-libtool:${PATH}
		cd "${S}" || die
	fi

	unset TERMINFO #115036
	tc-export BUILD_CC
	export BUILD_CPPFLAGS+=" -D_GNU_SOURCE" #214642

	# when cross-compiling, we need to build up our own tic
	# because people often don't keep matching host/target
	# ncurses versions #249363
	if tc-is-cross-compiler && ! ROOT=/ has_version ~sys-libs/${P} ; then
		make_flags="-C progs tic"
		CHOST=${CBUILD} \
		CFLAGS=${BUILD_CFLAGS} \
		CXXFLAGS=${BUILD_CXXFLAGS} \
		CPPFLAGS=${BUILD_CPPFLAGS} \
		LDFLAGS="${BUILD_LDFLAGS} -static" \
		do_compile cross --without-shared --with-normal
	fi

	make_flags=""
	do_compile narrowc
	use unicode && do_compile widec --enable-widec --includedir="${EPREFIX}"/usr/include/ncursesw

}
do_compile() {
	ECONF_SOURCE=${S}

	mkdir "${WORKDIR}"/$1
	cd "${WORKDIR}"/$1
	shift

	# The chtype/mmask-t settings below are to retain ABI compat
	# with ncurses-5.4 so dont change em !
	local conf_abi="
		--with-chtype=long \
		--with-mmask-t=long \
		--disable-ext-colors \
		--disable-ext-mouse \
		--without-pthread \
		--without-reentrant \
	"

	local myconf=""
	if need-libtool; then
		myconf="${myconf} --with-libtool"
		[[ ${CHOST} == *-cygwin* ]] && \
			# FIXME: what's up with 'normal' here?  Specifically, why would
			# cross-compiles and cygwin need it, but not the general case?
			myconf="${myconf} --with-shared $(use_enable static-libs normal)"
	elif [[ ${CHOST} == *-mint* ]]; then
		:
	else
		myconf="--with-shared"
	fi

	if [[ ${CHOST} == *-interix* ]]; then
		myconf="--without-leaks"
	fi

	if [[ ${CHOST} == *-cygwin* ]] ; then
		# FIXME: we override most of the conf_abi defaults... any
		# way we can pare this list of changes down and integrate
		# more with the general flow of the rest of the ebuild here?
		conf_abi="--with-mmask-t=long --without-pthread"
		myconf="${myconf} --disable-relink"
		myconf="${myconf} --disable-rpath"
		myconf="${myconf} --without-ticlib"
		myconf="${myconf} --without-termlib"
		if [[ $charmode == widec ]] ; then
			myconf="${myconf} --enable-ext-colors"
		else
			conf_abi="${conf_abi} --disable-ext-colors "
		fi
		myconf="${myconf} --enable-ext-mouse"
		myconf="${myconf} --enable-sp-funcs"
		myconf="${myconf} --with-wrap-prefix=ncwrap_"
		myconf="${myconf} --enable-sigwinch"
		myconf="${myconf} --enable-tcap-names"
		myconf="${myconf} --disable-mixed-case"
		myconf="${myconf} --with-pkg-config"
		myconf="${myconf} --enable-pc-files"
		myconf="${myconf} --enable-reentrant"
		# don't understand this hack but the cygport does this
		# so we do too.  FIXME: what purpose does this serve?
		myconf="${myconf} --with-abi-version=10"
	fi

	# We need the basic terminfo files in /etc, bug #37026.  We will
	# add '--with-terminfo-dirs' and then populate /etc/terminfo in
	# src_install() ...
#		$(use_with berkdb hashed-db) \
	econf \
		--libdir="${EPREFIX}/usr/$(get_libdir)" \
		--with-terminfo-dirs="${EPREFIX}/etc/terminfo:${EPREFIX}/usr/share/terminfo" \
		${myconf} \
		--without-hashed-db \
		--enable-overwrite \
		$(use_with ada) \
		$(use_with cxx) \
		$(use_with cxx cxx-binding) \
		$(use_with debug) \
		$(use_with profile) \
		$(use_with gpm) \
		--disable-termcap \
		--enable-symlinks \
		--with-rcs-ids \
		--with-manpage-format=normal \
		--enable-const \
		--enable-colorfgbg \
		--enable-echo \
		$(use_enable !ada warnings) \
		$(use_with debug assertions) \
		$(use_enable debug leaks) \
		$(use_with debug expanded) \
		$(use_with !debug macros) \
		$(use_with trace) \
		${conf_abi} \
		"$@"

	[[ ${CHOST} == *-solaris* ]] && \
		sed -i -e 's/-D_XOPEN_SOURCE_EXTENDED//g' c++/Makefile

	# Fix for install location of the lib{,n}curses{,w} libs as in Gentoo we
	# want those in lib not usr/lib.  We cannot move them lateron after
	# installing, because that will result in broken install_names for
	# platforms that store pointers to the libs instead of directories.
	# But this only is true when building without libtool.
	need-libtool ||
	sed -i -e '/^libdir/s:/usr/lib\(64\|\)$:/lib\1:' ncurses/Makefile || die "nlibdir"

	# for IRIX to get tests compiling
	epatch "${FILESDIR}"/${PN}-5.7-irix.patch

	# A little hack to fix parallel builds ... they break when
	# generating sources so if we generate the sources first (in
	# non-parallel), we can then build the rest of the package
	# in parallel.  This is not really a perf hit since the source
	# generation is quite small.
	emake -j1 sources || die
	emake ${make_flags} || die
}

src_install() {
	# use the cross-compiled tic (if need be) #249363
	export PATH=${WORKDIR}/cross/progs:${PATH}

	# install unicode version second so that the binaries in /usr/bin
	# support both wide and narrow
	cd "${WORKDIR}"/narrowc
	emake DESTDIR="${D}" install || die
	if use unicode ; then
		cd "${WORKDIR}"/widec
		emake DESTDIR="${D}" install || die
	fi

	# don't bother on cygwin, they are fine in /usr
	# FIXME: but we should move them anyhow; the below needs some changes to do it.
	if need-libtool && [[ ${CHOST} != *-cygwin* ]] ; then
		# Move dynamic ncurses libraries into /lib
		dodir /$(get_libdir)
		local f
		for f in "${ED}"usr/$(get_libdir)/lib{,n}curses{,w}$(get_libname)*; do
			[[ -f ${f} ]] || continue
			mv "${f}" "${ED}"$(get_libdir)/ || die "could not move ${f#${ED}}"
		done
	elif ! need-libtool ; then # keeping intendation to keep diff small
	# Move static and extraneous ncurses static libraries out of /lib
	cd "${ED}"/$(get_libdir)
	mv *.a "${ED}"/usr/$(get_libdir)/
	fi
	gen_usr_ldscript lib{,n}curses$(get_libname)
	if use unicode ; then
		gen_usr_ldscript libncursesw$(get_libname)
	fi
	# no need on cygwin as didn't move to /lib; anyhow even if we had moved them,
	# cygwin shared libs would still need *.dll.a files in libdir!)
	if [[ ${HOST} != *-cygwin* ]] ; then
		ln -sf libncurses$(get_libname) \
			"${ED}"/usr/$(get_libdir)/libcurses$(get_libname) || die
		use static-libs || rm "${ED}"/usr/$(get_libdir)/*.a			
	fi

#	if ! use berkdb ; then
		# We need the basic terminfo files in /etc, bug #37026
		einfo "Installing basic terminfo files in /etc..."
		for x in ansi console dumb linux rxvt rxvt-unicode screen sun vt{52,100,102,200,220} \
				 xterm xterm-color xterm-xfree86
		do
			local termfile=$(find "${ED}"/usr/share/terminfo/ -name "${x}" 2>/dev/null)
			local basedir=$(basename $(dirname "${termfile}"))

			if [[ -n ${termfile} ]] ; then
				dodir /etc/terminfo/${basedir}
				mv ${termfile} "${ED}"/etc/terminfo/${basedir}/
				dosym ../../../../etc/terminfo/${basedir}/${x} \
					/usr/share/terminfo/${basedir}/${x}
			fi
		done

		# Build fails to create this ...
		dosym ../share/terminfo /usr/$(get_libdir)/terminfo
#	fi

	echo "CONFIG_PROTECT_MASK=\"/etc/terminfo\"" > "${T}"/50ncurses
	doenvd "${T}"/50ncurses

	if [[ ${CHOST} == *-cygwin* ]] ; then
		# abi "10" is an artifact of cygwin history
		# As far as external clients are concerned, this is ncurses API 6
		mv "${ED}"/usr/bin/ncurses10-config "${ED}"/usr/bin/ncurses6-config
		mv "${ED}"/usr/bin/ncursesw10-config "${ED}"/usr/bin/ncursesw6-config
		sed -i -e "s/echo \"10\"/echo \"6\"/" "${ED}"/usr/bin/ncurses6-config
		sed -i -e "s/echo \"10\"/echo \"6\"/" "${ED}"/usr/bin/ncursesw6-config
	fi

	use minimal && rm -r "${ED}"/usr/share/terminfo*
	# Because ncurses5-config --terminfo returns the directory we keep it
	keepdir /usr/share/terminfo #245374

	cd "${S}"
	dodoc ANNOUNCE MANIFEST NEWS README* TO-DO doc/*.doc
	use doc && dohtml -r doc/html/
}
