# perm-lines: statement-order brute force for MIPS matching decomps (C or C++), parallel.
{ pkgs }:

pkgs.runCommand "perm-lines" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
  install -Dm644 ${./perm-lines.py} $out/share/perm-lines/perm-lines.py
  makeWrapper ${pkgs.python3}/bin/python3 $out/bin/perm-lines --add-flags $out/share/perm-lines/perm-lines.py
''
