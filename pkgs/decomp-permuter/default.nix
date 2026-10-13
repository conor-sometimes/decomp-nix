# decomp-permuter (simonlindholm/decomp-permuter): the permuter source, placed at /opt/permuter so
# a decomp image can run `python3 /opt/permuter/permuter.py`. The Python deps (pycparser, toml,
# levenshtein) come from the env's python, not from here.
{ pkgs }:

let
  src = pkgs.fetchFromGitHub {
    owner = "simonlindholm";
    repo = "decomp-permuter";
    rev = "8556c81d80d1c1af98a858c8f4dc951357f29139";   # 2026-10-06
    sha256 = "0kwxc8m1ass96qfr0bgavs8bwmv6hg85zzjfffzd6chnpd1k377f";
  };
in
pkgs.runCommand "decomp-permuter" { passthru = { inherit src; }; } ''
  mkdir -p $out/opt/permuter
  cp -r ${src}/. $out/opt/permuter/
''
