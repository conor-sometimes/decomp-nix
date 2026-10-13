# progress-readme: keep a progress section (bar + numbers + date) at the top of a decomp's README.
{ pkgs }:

pkgs.runCommand "progress-readme" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
  install -Dm644 ${./progress-readme.py} $out/share/progress-readme/progress-readme.py
  makeWrapper ${pkgs.python3}/bin/python3 $out/bin/progress-readme --add-flags $out/share/progress-readme/progress-readme.py
''
