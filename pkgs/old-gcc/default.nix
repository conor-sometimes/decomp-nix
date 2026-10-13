# Old GCC builds for console decomps, from github.com/decompals/old-gcc (prebuilt release
# tarballs: gcc, cc1, cpp, ...). Each version is a folder, not a PATH entry (it's called `gcc`
# and would shadow the env's gcc): $DECOMP_COMPILERS/<name>/ in envs that include it, the same
# layout as a project's tools/<name>/.
{ pkgs }:

let
  release = { name, tag, sha256 }:
    pkgs.stdenv.mkDerivation {
      pname = name;
      version = tag;
      src = pkgs.fetchurl {
        url = "https://github.com/decompals/old-gcc/releases/download/${tag}/${name}.tar.gz";
        inherit sha256;
      };
      sourceRoot = ".";
      nativeBuildInputs = [ pkgs.autoPatchelfHook ];
      buildInputs = [ pkgs.stdenv.cc.cc.lib ];
      installPhase = ''
        mkdir -p $out/${name}
        cp -r ./* $out/${name}/
      '';
      meta.platforms = [ "x86_64-linux" ];
    };
in
{
  # PS1 (Psy-Q era); crash-bash pins this one (tools/setup.sh)
  gcc-2_8_1-psx = release { name = "gcc-2.8.1-psx"; tag = "0.17"; sha256 = "f6f6e883942d4d3289d048236c672e71ed410e546aaae8ff655952f1567e1be0"; };
}
