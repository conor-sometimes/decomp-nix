# sjis-strings: Shift-JIS (Japanese) strings in an executable or data file, as TSV.
{ pkgs }:

pkgs.runCommand "sjis-strings" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
  install -Dm644 ${./sjis-strings.py} $out/share/sjis-strings/sjis-strings.py
  makeWrapper ${pkgs.python3}/bin/python3 $out/bin/sjis-strings --add-flags $out/share/sjis-strings/sjis-strings.py
''
