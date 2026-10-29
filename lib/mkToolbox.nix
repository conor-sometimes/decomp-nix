# mkToolbox: a per-project, on-demand container toolbox. Nix builds a small OCI image (the durable,
# deduplicated artifact — it lives in the store, no container runs until a job does); `.run` spins a
# throwaway `podman run --rm` container with CPU/memory caps, the project bind-mounted at /work, runs
# one command, and tears the container down. Many toolboxes = many cheap images, zero idle containers.
#
# This is a different lifecycle from the always-on podman boxes (agent containment): those are
# long-lived and ssh-in; these exist only while a command runs. For a trusted project the container
# is for reproducibility + resource caps, not isolation.
#
#   tb = mkToolbox { name = "pktlib"; packages = p: [ p.uv p.python313 ]; };
#   nix run <repo>#pktlib -- just test                 # in the repo, on-demand container
#   nix run <repo>#pktlib -- --cpus 4 --memory 8g -- just soak 1
{ pkgs }:

spec@{
  name,
  packages ? (_: [ ]),          # project tools in the image (a function of nixpkgs)
  resources ? { },              # { cpus = 4; memory = "8g"; } defaults for the run
  env ? { },                    # extra container environment (NAME = "value")
  tag ? "latest",
}:

let
  cpus = toString (resources.cpus or 4);
  memory = resources.memory or "8g";

  # The image: a minimal userland (bash/coreutils/git + TLS roots) plus the project's tools.
  image = pkgs.dockerTools.buildLayeredImage {
    name = "toolbox-${name}";
    inherit tag;
    contents = (with pkgs; [ bashInteractive coreutils gitMinimal cacert ]) ++ packages pkgs;
    config.WorkingDir = "/work";
  };

  # Extra `-e NAME=value` flags for podman, from `env`.
  envFlags = pkgs.lib.concatStringsSep " "
    (pkgs.lib.mapAttrsToList (k: v: "-e ${pkgs.lib.escapeShellArg "${k}=${v}"}") env);

  run = pkgs.writeShellApplication {
    name = "toolbox-${name}";
    runtimeInputs = [ pkgs.podman ];
    text = ''
      img="toolbox-${name}:${tag}"
      cpus="${cpus}"; memory="${memory}"; repo="$PWD"
      # options before `--`: --cpus N | --memory M | --repo DIR
      while [ $# -gt 0 ] && [ "$1" != "--" ]; do
        case "$1" in
          --cpus)   cpus="$2";   shift 2 ;;
          --memory) memory="$2"; shift 2 ;;
          --repo)   repo="$2";   shift 2 ;;
          *) break ;;
        esac
      done
      [ "''${1:-}" = "--" ] && shift
      [ "''${1:-}" = "-c" ] && shift   # accept the decomp envs' `-- -c 'cmd'` form too, so both read alike
      [ $# -gt 0 ] || { echo "usage: toolbox-${name} [--cpus N --memory M --repo DIR] -- [-c] <cmd...>" >&2; exit 2; }

      # load the nix-built image into podman once (idempotent)
      podman image exists "$img" || podman load -i ${image}

      # a persistent per-toolbox cache (uv/pip downloads survive between runs); /work is the project, rw
      cache="''${XDG_CACHE_HOME:-$HOME/.cache}/toolbox-${name}"; mkdir -p "$cache" "$repo/out"

      exec podman run --rm \
        --cpus="$cpus" --memory="$memory" \
        -v "$repo":/work -v "$cache":/cache -w /work \
        -e HOME=/tmp -e XDG_CACHE_HOME=/cache -e UV_CACHE_DIR=/cache/uv \
        -e SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt \
        ${envFlags} \
        "$img" bash -lc "$*"
    '';
  };
in
# the common project shape (same as a decomp env from mkDecompEnv): a runnable `run`, an optional
# interactive `shell`, an optional `image`, and the `runtime` tag. The flake treats every project
# alike by this shape — a decomp env and a container toolbox are just two runtimes.
{
  inherit name image run resources;
  runtime = "container";
  shell = null;   # `nix develop` into a container isn't offered; use the FHS envs for that
}
