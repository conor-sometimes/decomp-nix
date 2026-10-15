# split-units: cut code without vtables into plausible translation units (splat yaml).
{ pkgs }:

pkgs.runCommand "split-units" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
  install -Dm644 ${./split-units.py} $out/share/split-units/split-units.py
  makeWrapper ${pkgs.python3}/bin/python3 $out/bin/split-units --add-flags $out/share/split-units/split-units.py
''
