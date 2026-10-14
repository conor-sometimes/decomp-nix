# decomp-permuter (simonlindholm/decomp-permuter): the permuter source at /opt/permuter, plus a
# `permuter` command on PATH so every env can run it without a per-project clone. The command execs
# the env's own `python3` (so it picks up the env's pycparser/toml/levenshtein) and finds the
# platform's `mips-linux-gnu-objdump` on PATH (PS2 env provides it). `.src` is still exposed for
# shipping the source elsewhere.
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
  mkdir -p $out/opt/permuter $out/bin
  cp -r ${src}/. $out/opt/permuter/
  cat > $out/bin/permuter <<EOF
  #!/usr/bin/env bash
  # run decomp-permuter with the env's python (holds pycparser/toml/levenshtein) and objdump on PATH
  exec python3 $out/opt/permuter/permuter.py "\$@"
  EOF
  chmod +x $out/bin/permuter
''
