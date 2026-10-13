# rank-functions: unmatched functions (still INCLUDE_ASM) ranked easiest first from their assembly.
{ pkgs }:

pkgs.runCommand "rank-functions" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
  install -Dm644 ${./rank-functions.py} $out/share/rank-functions/rank-functions.py
  makeWrapper ${pkgs.python3}/bin/python3 $out/bin/rank-functions --add-flags $out/share/rank-functions/rank-functions.py
''
