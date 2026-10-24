# pspdecrypt (github.com/John-K/pspdecrypt): decrypts PSP executables (~PSP-wrapped EBOOT.BIN and
# PRX modules) to plain ELF/PRX, plus firmware updaters. Retail UMDs zero out the plain BOOT.BIN,
# so this is step one of every PSP decomp. Decryption code from PPSSPP (libkirk). GPL-3.0.
{ pkgs }:

pkgs.stdenv.mkDerivation {
  pname = "pspdecrypt";
  version = "1.0-unstable-2024-06-07";
  src = pkgs.fetchFromGitHub {
    owner = "John-K";
    repo = "pspdecrypt";
    rev = "c156627db7634d395c380c0a9589130f603307fc";
    hash = "sha256-OvX1jsOCB9AG9QienbtN7S4YxYEQISHggo49l+ZVbXM=";
  };
  buildInputs = [ pkgs.zlib pkgs.openssl ];
  makeFlags = [ "CC=${pkgs.stdenv.cc.targetPrefix}cc" "CXX=${pkgs.stdenv.cc.targetPrefix}c++" ];
  enableParallelBuilding = true;
  installPhase = ''
    install -Dm755 pspdecrypt $out/bin/pspdecrypt
    install -Dm644 -t $out/share/doc/pspdecrypt Readme.md
  '';
  meta = {
    license = pkgs.lib.licenses.gpl3Only;
    platforms = pkgs.lib.platforms.linux;
    mainProgram = "pspdecrypt";
  };
}
