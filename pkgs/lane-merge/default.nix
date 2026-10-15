# lane-merge: merge parallel matching lanes in a splat decomp (symbol-file unions, renamed INCLUDE_ASMs, old-name aliases).
{ pkgs }:

pkgs.runCommand "lane-merge" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
  install -Dm644 ${./lane-merge.py} $out/share/lane-merge/lane-merge.py
  makeWrapper ${pkgs.python3}/bin/python3 $out/bin/lane-merge --add-flags $out/share/lane-merge/lane-merge.py
''
