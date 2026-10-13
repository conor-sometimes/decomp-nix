# Sony EE-GCC builds (PS2), from decomp.me's compiler mirror (github.com/decompme/compilers,
# release "compilers"), pinned to the SHA-256s bokura-no-kazoku-decomp verified. Each is a
# folder, not a PATH entry: $DECOMP_COMPILERS/<name>/ in PS2 envs (platforms.ps2), the same
# layout as a project's tools/compilers/<name>/. They're Linux i386 binaries and run inside a
# decomp-nix env (which provides the 32-bit loader and libraries), so they're not patched.
{ pkgs }:

let
  release = { name, sha256 }:
    pkgs.stdenvNoCC.mkDerivation {
      pname = name;
      version = "decompme";
      src = pkgs.fetchurl {
        url = "https://github.com/decompme/compilers/releases/download/compilers/${name}.tar.xz";
        inherit sha256;
      };
      sourceRoot = ".";
      dontPatchELF = true;
      dontStrip = true;
      dontFixup = true;
      installPhase = ''
        mkdir -p $out/${name}
        cp -r ./* $out/${name}/
        echo ${sha256} > $out/${name}/.sha256
      '';
      meta.platforms = [ "x86_64-linux" ];
    };
in
{
  # Bokura no Kazoku's compiler: confirmed on eight functions, -O2 -G0 (docs/compiler.md there)
  ee-gcc2_96 = release { name = "ee-gcc2.96"; sha256 = "0590d2ca9da8f5903889d66761220d14b47a8d14ba987ca53db84a1650a1fd0a"; };
  # Other candidates, for the next PS2 game's compiler hunt
  ee-gcc2_9-991111 = release { name = "ee-gcc2.9-991111"; sha256 = "99cb5db603cd985b50fc6851157020ad69489f2227309ccf825bd43ac7bc19dd"; };
  ee-gcc2_9-991111a = release { name = "ee-gcc2.9-991111a"; sha256 = "f07d1f38afa847197fb816237dbce64e79b2d37b738cb93fa4df3ac7aa1d16f3"; };
  ee-gcc2_9-991111-01 = release { name = "ee-gcc2.9-991111-01"; sha256 = "ed684fd98f89d36b0121caab311052089103e3b36241fcef4338cc9ea41c75b8"; };
  ee-gcc2_9-990721 = release { name = "ee-gcc2.9-990721"; sha256 = "ad2ea68afff2be25d21a1d51a75e8a0eea8f259018e6580622355cd01b95676b"; };
  ee-gcc3_2-040921 = release { name = "ee-gcc3.2-040921"; sha256 = "8c60ca7482523190e999524a7e4de2379dcf7ffee543c1b5663bfdf6a80ebf0f"; };
}
