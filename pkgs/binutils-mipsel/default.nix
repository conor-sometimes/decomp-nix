# GNU binutils for little-endian MIPS (PS1), from nixpkgs' cross set, plus the
# mipsel-linux-gnu-* names that PS1 decomp Makefiles use (nixpkgs calls them
# mipsel-unknown-linux-gnu-*).
{ pkgs }:

let
  bu = pkgs.pkgsCross.mipsel-linux-gnu.buildPackages.binutils-unwrapped;
in
pkgs.runCommand "binutils-mipsel-${bu.version}" { } ''
  mkdir -p $out/bin
  for f in ${bu}/bin/mipsel-unknown-linux-gnu-*; do
    n=$(basename $f)
    ln -s $f $out/bin/$n
    ln -s $f $out/bin/mipsel-linux-gnu-''${n#mipsel-unknown-linux-gnu-}
  done
''
