# decomp-guard: keeps game data out of a decomp repo's git history (see decomp-guard.sh).
#   decomp-guard install     # in a repo: becomes its pre-commit hook (a self-contained copy)
#   decomp-guard check [F]   # check files, or what's staged
{ pkgs }:

pkgs.stdenvNoCC.mkDerivation {
  pname = "decomp-guard";
  version = "1";
  src = ./decomp-guard.sh;
  dontUnpack = true;
  nativeBuildInputs = [ pkgs.makeWrapper ];
  installPhase = ''
    install -Dm755 $src $out/libexec/decomp-guard.sh
    patchShebangs $out/libexec/decomp-guard.sh
    makeWrapper $out/libexec/decomp-guard.sh $out/bin/decomp-guard \
      --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.git pkgs.coreutils pkgs.gnugrep pkgs.gnused ]}
  '';
}
