# binutils-mips-ps2-decompals: R5900-aware GNU binutils (as, ld, objdump, objcopy, nm, ...) as
# mips-ps2-decompals-*. Prebuilt release, pinned to the same version and SHA-256 as Lombyte's setup.sh.
{ pkgs }:

pkgs.stdenv.mkDerivation rec {
  pname = "binutils-mips-ps2-decompals";
  version = "0.10";
  src = pkgs.fetchurl {
    url = "https://github.com/decompals/binutils-mips-ps2-decompals/releases/download/v${version}/binutils-mips-ps2-decompals-linux-x86-64.tar.gz";
    sha256 = "9fe31ea3ee1a37536f9f0e2e12c668e7c3cb99e59f5154bd2f1fc4762473094c";
  };
  sourceRoot = ".";
  nativeBuildInputs = [ pkgs.autoPatchelfHook ];
  buildInputs = [ pkgs.zstd pkgs.zlib ];
  installPhase = ''
    mkdir -p $out/bin
    install -m755 mips-ps2-decompals-* $out/bin/
  '';
  meta.platforms = [ "x86_64-linux" ];
}
