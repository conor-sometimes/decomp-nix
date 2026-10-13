# objdiff-cli: per-function object diffing and the progress report (`objdiff-cli report`).
# Prebuilt release, pinned to the same version and SHA-256 as Lombyte's setup.sh.
{ pkgs }:

pkgs.stdenvNoCC.mkDerivation rec {
  pname = "objdiff-cli";
  version = "3.8.0";
  src = pkgs.fetchurl {
    url = "https://github.com/encounter/objdiff/releases/download/v${version}/objdiff-cli-linux-x86_64";
    sha256 = "bc1e047126f9c6914bd1695798175234642ab9eaf45e886f841b59a4231e1a81";
  };
  dontUnpack = true;
  nativeBuildInputs = [ pkgs.autoPatchelfHook ];
  buildInputs = [ pkgs.stdenv.cc.cc.lib ];
  installPhase = ''
    install -Dm755 $src $out/bin/objdiff-cli
  '';
  meta.platforms = [ "x86_64-linux" ];
}
