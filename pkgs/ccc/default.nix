# ccc (github.com/chaoticgd/ccc): PS2 symbol table tools. stdump reads STABS .mdebug, ELF and
# SNDLL symbols (types, function signatures, globals) as C++ or JSON; uncc lays them out as
# skeleton source files; demangle handles GCC 2.x mangled names. Prebuilt static (musl) release.
# Its objdump is installed as ccc-objdump so it never shadows binutils.
{ pkgs }:

pkgs.stdenvNoCC.mkDerivation rec {
  pname = "ccc";
  version = "2.1";
  src = pkgs.fetchurl {
    url = "https://github.com/chaoticgd/ccc/releases/download/v${version}/ccc_v${version}_linux-musl.zip";
    sha256 = "1w4f75jmqm07rfc286q6g2ilkn75zrgyx6gnh6r03zx8kbq4r5zf";
  };
  nativeBuildInputs = [ pkgs.unzip ];
  installPhase = ''
    install -Dm755 stdump $out/bin/stdump
    install -Dm755 uncc $out/bin/uncc
    install -Dm755 demangle $out/bin/demangle
    install -Dm755 objdump $out/bin/ccc-objdump
    install -Dm644 -t $out/share/doc/ccc README.md License.txt
  '';
  meta.platforms = [ "x86_64-linux" ];
}
