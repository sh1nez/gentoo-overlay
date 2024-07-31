EAPI=8

LLVM_SLOT=17
VERIFY_SIG_METHOD=minisig
VERIFY_SIG_OPENPGP_KEY_PATH=/usr/share/minisig-keys/zig-software-foundation.pub
inherit verify-sig

DESCRIPTION="Best programming language"
HOMEPAGE="https://ziglang.org/"
SRC_URI="
	amd64? ( https://ziglang.org/download/${PV}/zig-linux-x86_64-${PV}.tar.xz )
	arm? ( https://ziglang.org/download/${PV}/zig-linux-armv7a-${PV}.tar.xz ) arm64? ( https://ziglang.org/download/${PV}/zig-linux-aarch64-${PV}.tar.xz )
	ppc64? ( https://ziglang.org/download/${PV}/zig-linux-powerpc64le-${PV}.tar.xz )
	riscv? ( https://ziglang.org/download/${PV}/zig-linux-riscv64-${PV}.tar.xz )
	x86? ( https://ziglang.org/download/${PV}/zig-linux-x86-${PV}.tar.xz )
	verify-sig? (
		amd64? ( https://ziglang.org/download/${PV}/zig-linux-x86_64-${PV}.tar.xz.minisig )
		arm? ( https://ziglang.org/download/${PV}/zig-linux-armv7a-${PV}.tar.xz.minisig )
		arm64? ( https://ziglang.org/download/${PV}/zig-linux-aarch64-${PV}.tar.xz.minisig )
		ppc64? ( https://ziglang.org/download/${PV}/zig-linux-powerpc64le-${PV}.tar.xz.minisig )
		riscv? ( https://ziglang.org/download/${PV}/zig-linux-riscv64-${PV}.tar.xz.minisig )
		x86? ( https://ziglang.org/download/${PV}/zig-linux-x86-${PV}.tar.xz.minisig )
	)
"

LICENSE="MIT Apache-2.0-with-LLVM-exceptions || ( UoI-NCSA MIT ) || ( Apache-2.0-with-LLVM-exceptions Apache-2.0 MIT BSD-2 ) public-domain BSD-2 ZPL ISC HPND BSD inner-net LGPL-2.1+"
SLOT="$(ver_cut 1-2)"
KEYWORDS="-* ~amd64 ~arm ~arm64 ~ppc64 ~riscv ~x86"

BDEPEND="verify-sig? ( sec-keys/minisig-keys-zig-software-foundation )"
IDEPEND="app-eselect/eselect-zig"

#RDEPEND="sys-devel/clang:${LLVM_SLOT}=
#	sys-devel/lld:${LLVM_SLOT}=
#	sys-devel/llvm:${LLVM_SLOT}=[zstd]
#"

DOCS=( "README.md" )
HTML_DOCS=( "doc/langref.html" )


QA_PREBUILT="opt/${P}/zig"

src_unpack() {
	verify-sig_src_unpack

	mv "${WORKDIR}/"* "${S}" || die
}

src_install() {
	insinto /opt/

	einstalldocs
	rm README.md || die
	rm -r ./doc/ || die

	doins -r "${S}"
	fperms 0755 "/opt/${P}/zig"
	dosym -r "/opt/${P}/zig" "/usr/bin/zig-bin-${PV}"
}

pkg_postinst() {
	eselect zig update ifunset
	elog "Starting from 0.12.0, Zig no longer installs"
	elog "precompiled standard library documentation."
	elog "Instead, you can call \`zig std\` to compile it on-the-fly."
	elog "It reflects all edits in standard library automatically."
	elog "See \`zig std --help\` for more information."
	elog "More technical details here: https://github.com/ziglang/zig/pull/19208"
}

pkg_postrm() {
	eselect zig update ifunset
}
