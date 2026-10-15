# compiler-sweep: which EE-GCC build, language and assembler options reproduce a PS2 function.
{ pkgs }:

pkgs.runCommand "compiler-sweep" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
  install -Dm644 ${./compiler-sweep.py} $out/share/compiler-sweep/compiler-sweep.py
  makeWrapper ${pkgs.python3}/bin/python3 $out/bin/compiler-sweep --add-flags $out/share/compiler-sweep/compiler-sweep.py
''
