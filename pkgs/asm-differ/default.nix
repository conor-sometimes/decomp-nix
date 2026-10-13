# asm-differ (github.com/simonlindholm/asm-differ): quick per-function terminal diffs (diff.py),
# next to objdiff. Pinned to crash-bash's revision. `asm-differ` on PATH (run from a project
# with a diff_settings.py). ansiwrap left out: nixpkgs removed it (broken); asm-differ runs without.
{ pkgs }:

let
  rev = "0dd09af8f8008f1f880327cf0aca3b26d2562ea2";
  src = pkgs.fetchzip {
    url = "https://github.com/simonlindholm/asm-differ/archive/${rev}.tar.gz";
    sha256 = "00l0s70wx4nq3xnyiav7iflx8lmsayr9qd3d2cf10dc7kfw30w8a";
  };
  py = pkgs.python3.withPackages (ps: with ps; [ colorama watchdog levenshtein cxxfilt ]);
in
pkgs.runCommand "asm-differ-${builtins.substring 0 7 rev}" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
  mkdir -p $out/share $out/bin
  cp -r ${src} $out/share/asm-differ
  makeWrapper ${py}/bin/python3 $out/bin/asm-differ --add-flags $out/share/asm-differ/diff.py
''
