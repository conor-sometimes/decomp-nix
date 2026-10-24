# GNU binutils with the PSP's VFPU (pspdev's fork, branch allegrex-v2.44, as the pspdev
# toolchain builds it). Mainline binutils knows the Allegrex since 2.42 but not its vector unit:
# lv.q, sv.q, vidt.q, vflush, ... fail there. Commands: psp-as, psp-ld, psp-objdump, ...
{ pkgs }:

pkgs.stdenv.mkDerivation {
  pname = "binutils-allegrex";
  version = "2.44-unstable-2025-06-24";
  src = pkgs.fetchFromGitHub {
    owner = "pspdev";
    repo = "binutils-gdb";
    rev = "a8b53fe2b5825fa86337623c743d21a19aeb0daf";
    hash = "sha256-uUJS1USIsgbsmbkMOCF/+UqTWdXaLeAXF8lmFcI411w=";
  };
  nativeBuildInputs = with pkgs; [ bison flex texinfo perl ];
  buildInputs = with pkgs; [ zlib gmp mpfr ];
  configureFlags = [
    "--target=mipsallegrexel-psp-elf"
    "--disable-gdb" "--disable-gdbserver" "--disable-sim" "--disable-gprofng"
    "--disable-nls" "--disable-werror" "--disable-initfini-array" "--with-system-zlib"
  ];
  # short names, as pspdev installs them: psp-as, psp-ld, psp-objdump, ...
  postInstall = ''
    for f in $out/bin/mipsallegrexel-psp-elf-*; do
      ln -s $(basename $f) $out/bin/psp-''${f##*/mipsallegrexel-psp-elf-}
    done
  '';
  # 2.44-era C (the bundled readline's `tputs ()` prototypes) predates GCC 15's C23 default
  env.NIX_CFLAGS_COMPILE = "-std=gnu17";
  enableParallelBuilding = true;
  doCheck = false;
  meta = {
    license = pkgs.lib.licenses.gpl3Plus;
    platforms = pkgs.lib.platforms.linux;
  };
}
