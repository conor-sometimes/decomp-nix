# Ghidra per console: ghidra-ps2, ghidra-ps1, ... (nixpkgs Ghidra + that platform's extension).
#
#   ghidra-ps2                          # the GUI
#   ghidra-ps2 analyze BINARY OUTDIR    # headless: import, auto-analyse, export
#
# `analyze` leaves OUTDIR/functions.json (every function: name, address, size, signature,
# where the name came from), OUTDIR/symbol_addrs.txt (splat format, named functions only) and
# the Ghidra project itself (open it later with the GUI).
#
# Extensions are prebuilt release zips and must match nixpkgs' Ghidra version exactly; a
# platform whose extension has no build for it stays commented out below.
{ pkgs }:

let
  inherit (pkgs) lib ghidra;

  # writable: the extension writes next to its own data at run time (lock files for its .gdt
  # type archives), so it can't load from the read-only store; the wrapper installs a copy
  # into Ghidra's per-user extensions folder instead.
  # Each extension zip is built for one exact Ghidra release; a mismatch otherwise shows up only as
  # an obscure "Missing SLA format header" at run time.
  prebuilt = { name, url, sha256, writable ? false, forGhidra }:
    assert pkgs.lib.assertMsg (ghidra.version == forGhidra)
      "decomp-nix: ${name} is pinned for Ghidra ${forGhidra}, but this nixpkgs has Ghidra ${ghidra.version}; update its url/sha256 (and forGhidra) in pkgs/ghidra/default.nix, or the nixpkgs pin";
    pkgs.stdenvNoCC.mkDerivation {
      pname = name;
      version = ghidra.version;
      src = pkgs.fetchurl { inherit url sha256; };
      nativeBuildInputs = [ pkgs.unzip ];
      unpackPhase = "unzip -q $src";
      # Compile the processor specs (.slaspec -> .sla) for this exact Ghidra now: Ghidra would
      # otherwise try at first use and fail on the read-only store (zips ship them uncompiled
      # or in an older format).
      buildPhase = ''
        export HOME=$TMPDIR
        ${ghidra}/lib/ghidra/support/sleigh -a ${name}/data/languages
      '';
      installPhase = ''
        mkdir -p $out/lib/ghidra/Ghidra/Extensions
        cp -r ${name} $out/lib/ghidra/Ghidra/Extensions/
      '';
      passthru = { extName = name; inherit writable; };
    };

  extensions = {
    # PS2: Emotion Engine processor (MMI, VU0 macro mode) + STABS .mdebug analyzer
    ps2 = prebuilt {
      name = "ghidra-emotionengine-reloaded";
      url = "https://github.com/chaoticgd/ghidra-emotionengine-reloaded/releases/download/v2.1.38/ghidra_12.0.4_PUBLIC_20261004_ghidra-emotionengine-reloaded.zip";
      sha256 = "16as8z9c9snyrp2kkir5rmvk9r2w1pwii35jzafhnjsggppmkw8j";
      forGhidra = "12.0.4";
    };
    # PS1: PS-X EXE loader, GTE instructions, Psy-Q signatures
    ps1 = prebuilt {
      name = "ghidra_psx_ldr";
      url = "https://github.com/lab313ru/ghidra_psx_ldr/releases/download/2026.10.03/ghidra_12.0.4_PUBLIC_20261004_ghidra_psx_ldr.zip";
      sha256 = "1war7y16w659n6vi93v0zp0rqgp0xpnhqf54j9lslg3b6zsvnkgv";
      forGhidra = "12.0.4";
      writable = true;   # Psy-Q .gdt archives need lock files beside them
    };
    # Waiting for nixpkgs Ghidra 12.1 (their releases target 12.1.x) or a source build:
    #   n64: zeroKilo/N64LoaderWV        gc/wii: Cuyler36/Ghidra-GameCube-Loader
    #   nds: pedro-javierf/NTRGhidra     gba: SiD3W4y/GhidraGBA (last built for 10.1)
  };

  mkGhidra = { name, platforms }:
    let
      exts = map (p: extensions.${p}) platforms;
      inStore = builtins.filter (e: !e.writable) exts;
      perUser = builtins.filter (e: e.writable) exts;
      g = if inStore == [ ] then ghidra else ghidra.withExtensions (_: inStore);  # withExtensions [] fails
      userExtDir = "\${XDG_CONFIG_HOME:-$HOME/.config}/ghidra/ghidra_${ghidra.version}_${ghidra.releaseName}/Extensions";
      installPerUser = lib.concatMapStrings (e: ''
        d="${userExtDir}/${e.extName}"
        if [ "$(cat "$d/.nix-src" 2>/dev/null)" != "${e}" ]; then
          rm -rf "$d"; mkdir -p "$d"
          cp -r ${e}/lib/ghidra/Ghidra/Extensions/${e.extName}/. "$d"/; chmod -R u+w "$d"
          echo "${e}" > "$d/.nix-src"
        fi
      '') perUser;
    in
    pkgs.writeShellApplication {
      name = "ghidra-${name}";
      runtimeInputs = [ g ];
      text = ''
        ${installPerUser}
        if [ "''${1:-}" = analyze ]; then
          [ $# -ge 3 ] || { echo "usage: ghidra-${name} analyze BINARY OUTDIR [analyzeHeadless options]" >&2; exit 2; }
          bin=$(realpath "$2"); out=$(realpath -m "$3"); shift 3
          mkdir -p "$out"
          ghidra-analyzeHeadless "$out" "$(basename "$bin")" -import "$bin" -overwrite \
            -scriptPath ${./scripts} -postScript ExportFunctions.java "$out" "$@"
        else
          exec ghidra "$@"
        fi
      '';
    };
in
{
  inherit extensions mkGhidra;
  ps2 = mkGhidra { name = "ps2"; platforms = [ "ps2" ]; };
  ps1 = mkGhidra { name = "ps1"; platforms = [ "ps1" ]; };
}
