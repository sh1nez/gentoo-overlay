EAPI=8

LLVM_MAX_SLOT=17
inherit edo cmake llvm check-reqs toolchain-funcs

DESCRIPTION="Best programming language"
HOMEPAGE="https://ziglang.org/"

if [[ ${PV} == 9999 ]]; then
	EGIT_REPO_URI="https://github.com/ziglang/zig.git"
	inherit git-r3
else
	VERIFY_SIG_METHOD=minisig
	VERIFY_SIG_OPENPGP_KEY_PATH=/usr/share/minisig-keys/zig-software-foundation.pub
	inherit verify-sig

	SRC_URI="
		https://ziglang.org/download/${PV}/${P}.tar.xz
		verify-sig? ( https://ziglang.org/download/${PV}/${P}.tar.xz.minisig )
	"
	KEYWORDS="~amd64 ~arm ~arm64"

	BDEPEND="verify-sig? ( sec-keys/minisig-keys-zig-software-foundation )"
fi

LICENSE="MIT Apache-2.0-with-LLVM-exceptions || ( UoI-NCSA MIT ) || ( Apache-2.0-with-LLVM-exceptions Apache-2.0 MIT BSD-2 ) public-domain BSD-2 ZPL ISC HPND BSD inner-net LGPL-2.1+"
SLOT="$(ver_cut 1-2)"
IUSE="doc"

BUILD_DIR="${S}/build"

DEPEND="
	sys-devel/clang:${LLVM_MAX_SLOT}=
	sys-devel/lld:${LLVM_MAX_SLOT}=
	sys-devel/llvm:${LLVM_MAX_SLOT}=[zstd]
"

RDEPEND="
	${DEPEND}
"

IDEPEND="app-eselect/eselect-zig"

QA_FLAGS_IGNORED="usr/.*/zig/${PV}/bin/zig"

CHECKREQS_MEMORY="4G"

llvm_check_deps() {
	has_version "sys-devel/clang:${LLVM_SLOT}"
}

ctarget_to_zigtarget() {
	# Zig's Target Format: arch-os-abi
	local CTARGET="${CTARGET:-${CHOST}}"

	local ZIG_ARCH
	case "${CTARGET%%-*}" in
		i?86)		ZIG_ARCH=x86;;
		sparcv9)	ZIG_ARCH=sparc64;;
		*)		ZIG_ARCH="${CTARGET%%-*}";; # Same as in CHOST
	esac

	local ZIG_OS
	case "${CTARGET}" in
		*linux*)	ZIG_OS=linux;;
		*apple*)	ZIG_OS=macos;;
	esac

	local ZIG_ABI
	case "${CTARGET##*-}" in
		gnu)		ZIG_ABI=gnu;;
		solaris*)	ZIG_OS=solaris ZIG_ABI=none;;
		darwin*)	ZIG_ABI=none;;
		*)		ZIG_ABI="${CTARGET##*-}";; # Same as in CHOST
	esac

	echo "${ZIG_ARCH}-${ZIG_OS}-${ZIG_ABI}"
}

get_zig_mcpu() {
	local ZIG_DEFAULT_MCPU=native
	tc-is-cross-compiler && ZIG_DEFAULT_MCPU=baseline
	echo "${ZIG_MCPU:-${ZIG_DEFAULT_MCPU}}"
}

get_zig_target() {
	local ZIG_DEFAULT_TARGET=native
	tc-is-cross-compiler && ZIG_DEFAULT_TARGET="$(ctarget_to_zigtarget)"
	echo "${ZIG_TARGET:-${ZIG_DEFAULT_TARGET}}"
}

pkg_setup() {
	llvm_pkg_setup
	check-reqs_pkg_setup
}

src_configure() {
	export ZIG_LOCAL_CACHE_DIR="${T}/zig-local-cache"
	export ZIG_GLOBAL_CACHE_DIR="${T}/zig-global-cache"

	local mycmakeargs=(
		-DZIG_USE_CCACHE=OFF
		-DZIG_SHARED_LLVM=ON
		-DZIG_TARGET_TRIPLE="$(get_zig_target)"
		-DZIG_TARGET_MCPU="$(get_zig_mcpu)"
		-DZIG_USE_LLVM_CONFIG=ON
		-DCMAKE_PREFIX_PATH="$(get_llvm_prefix ${LLVM_MAX_SLOT})"
		-DCMAKE_INSTALL_PREFIX="${EPREFIX}/usr/$(get_libdir)/zig/${PV}"
	)

	cmake_src_configure
}

src_compile() {
	cmake_src_compile

	"${BUILD_DIR}/stage3/bin/zig" env || die "Zig compilation failed"

	if use doc; then
		cd "${BUILD_DIR}" || die
		edo ./stage3/bin/zig build std-docs --prefix "${S}/docgen/"
		edo ./stage3/bin/zig build langref --prefix "${S}/docgen/"
	fi
}

src_test() {
	cd "${BUILD_DIR}" || die
	local ZIG_TEST_ARGS="-Dstatic-llvm=false -Denable-llvm -Dskip-non-native \
		-Doptimize=ReleaseSafe -Dtarget=$(get_zig_target) -Dcpu=$(get_zig_mcpu)"
	local ZIG_TEST_STEPS=(
		test-cases test-fmt test-behavior test-compiler-rt test-universal-libc test-compare-output
		test-standalone test-c-abi test-link test-stack-traces test-cli test-asm-link test-translate-c
		test-run-translated-c test-std
	)

	local step
	for step in "${ZIG_TEST_STEPS[@]}" ; do
		edob ./stage3/bin/zig build ${step} ${ZIG_TEST_ARGS}
	done
}

src_install() {
	use doc && local HTML_DOCS=( "docgen/doc/langref.html" "docgen/doc/std" )
	cmake_src_install

	cd "${ED}/usr/$(get_libdir)/zig/${PV}/" || die
	mv lib/zig/ lib2/ || die
	rm -rf lib/ || die
	mv lib2/ lib/ || die
	dosym -r "/usr/$(get_libdir)/zig/${PV}/bin/zig" "/usr/bin/zig-${PV}"
}

pkg_postinst() {
	eselect zig update ifunset
}

pkg_postrm() {
	eselect zig update ifunset
}
