# pktlib (github conor-sometimes/pktlib): a pure-Python, uv-managed library. No runtime deps; the
# heavy work worth offloading is the property-based (Hypothesis), mutation (mutmut) and soak suites.
# uv.lock pins every dev dep deterministically, so the image only needs uv + the interpreters + just;
# uv builds the venv from the lock at run time. Pinned Python is 3.14. (nixpkgs has dropped 3.10, the
# low end of pktlib's CI matrix — to test 3.10 here you'd need uv's own download, i.e. network + lifting
# UV_PYTHON_DOWNLOADS; the nix-provided interpreters are 3.11–3.14.)
#
#   nix run <repo>#pktlib -- just test            # the ~1-min suite, in an on-demand container
#   nix run <repo>#pktlib -- --cpus 4 -- just soak 1
{ pkgs, lib, tools }:

lib.mkToolbox {
  name = "pktlib";
  packages = p: with p; [ uv just python311 python312 python313 python314 ];
  resources = { cpus = 4; memory = "8g"; };
  env = {
    # use the interpreters baked into the image; never try to download a Python at run time
    UV_PYTHON_PREFERENCE = "only-system";
    UV_PYTHON_DOWNLOADS = "never";
  };
}
