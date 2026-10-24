# PSP compilers from decomp.me's compiler mirror (github.com/decompme/compilers, release
# "compilers"). Each is a folder, not a PATH entry: $DECOMP_COMPILERS/<name>/ in PSP envs
# (platforms.psp), the same layout as a project's tools/compilers/<name>/. SNC and mwccpsp are
# Windows executables (run them with wine, so the project env needs `wine = true`); psp-gcc is
# the pspdev homebrew GCC (Linux).
{ pkgs }:

let
  release = { name, sha256 }:
    pkgs.stdenvNoCC.mkDerivation {
      pname = name;
      version = "decompme";
      src = pkgs.fetchurl {
        url = "https://github.com/decompme/compilers/releases/download/compilers/${name}.tar.gz";
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
  mwccpsp = build: sha256: release { name = "mwccpsp_3.0.1_${build}"; inherit sha256; };
in
{
  # SN Systems ProDG for PSP: pspsnc (EDG C/C++ front end), pspas, pspld, pspprxgen
  pspsnc1_2_7503_0 = release { name = "pspsnc_1.2.7503.0"; sha256 = "0d10a4b387e45b62369eea21b6693fc5517335033bf65e65aa7b543a916f4d6d"; };
  # Metrowerks CodeWarrior for PSP
  mwccpsp3_0_1_121 = mwccpsp "121" "44836bb4d19fbe216b55fbd638420c000f7dd373c84493de0e732e85f81656af";
  mwccpsp3_0_1_134 = mwccpsp "134" "a4a00c2450ee2b6f7be29fc73470446994fcf2b1b1003b8ac34568f3358e1c99";
  mwccpsp3_0_1_139 = mwccpsp "139" "932bae1cdd95df8e1c593af14c19c90c21ad8e2662d6cc5e537269543d8bdd8f";
  mwccpsp3_0_1_147 = mwccpsp "147" "7b9c917d50f804617eb50897cb5b68e1f287f6f676f28078c04a9054b2e4586e";
  mwccpsp3_0_1_151 = mwccpsp "151" "168ee268ebd9a9dc756886c90b4fdd577b13b57ecad025c8b7d98acf47d3f76f";
  mwccpsp3_0_1_180 = mwccpsp "180" "2d4ff76e4e5c9bd938dbc627e4219583d6119bc4af30548df43e06221ab7b32b";
  mwccpsp3_0_1_192 = mwccpsp "192" "e68e0a281f90e0c5a96cd04defe01eabfad4b5592807bba983495fa07c1d55b3";
  mwccpsp3_0_1_201 = mwccpsp "201" "1bf4b06615f56e6ca5b78287e8fab5c7737f5cd5766d1df052829d737928dbc8";
  mwccpsp3_0_1_205 = mwccpsp "205" "ace61d4641fcdff55c08b7560c95915b20243f0f18023c3d4ce99fe37c5cdb00";
  mwccpsp3_0_1_210 = mwccpsp "210" "a8a0bf3a0ec3545f6578717516aad0f262a40dd1538a6e462b77efc29e79a969";
  mwccpsp3_0_1_219 = mwccpsp "219" "81a2a8664d779901f6fa2f298b663b4b0feeb1d7f6613fd14531f51e66926d78";
  # pspdev GCC (homebrew toolchain). As decomp.me ships them: psp/bin/as is a 0-byte file in its
  # tarballs (the gcc driver and cc1 are fine), so assemble with binutils-allegrex (psp-as).
  psp-gcc1_3_1 = release { name = "psp-gcc-1.3.1"; sha256 = "788b6d2c0ed920da6b1e5a350d23dd7ea05820526e23f9b5b967b3b238ea2e2e"; };
  psp-gcc1_7_1 = release { name = "psp-gcc-1.7.1"; sha256 = "55d4267b1d74855157501d5fd61ed31b68d961a737306b5831b582a2d58f3484"; };
}
