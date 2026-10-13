# maspsx (github.com/mkst/maspsx): makes GNU as reproduce Psy-Q's assembler for PS1 decomps.
# Pinned to crash-bash's revision. `maspsx` on PATH; the source tree in $out/share/maspsx.
{ pkgs }:

let
  rev = "e85ecb373828aabea96d7e6400974d4f91ce8c74";
  src = pkgs.fetchzip {
    url = "https://github.com/mkst/maspsx/archive/${rev}.tar.gz";
    sha256 = "0kbayzy66chrljnw8s222v9nk39qy0avagpmf6a81zm317sd9kv2";
  };
in
pkgs.runCommand "maspsx-${builtins.substring 0 7 rev}" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
  mkdir -p $out/share $out/bin
  cp -r ${src} $out/share/maspsx
  makeWrapper ${pkgs.python3}/bin/python3 $out/bin/maspsx --add-flags $out/share/maspsx/maspsx.py
''
