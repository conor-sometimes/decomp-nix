# decomp-where: where a matching build stopped matching (moved symbols, differing bytes by function).
{ pkgs }:

pkgs.runCommand "decomp-where" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
  install -Dm644 ${./decomp-where.py} $out/share/decomp-where/decomp-where.py
  makeWrapper ${pkgs.python3}/bin/python3 $out/bin/decomp-where --add-flags $out/share/decomp-where/decomp-where.py
''
