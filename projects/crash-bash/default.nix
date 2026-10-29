# Crash Bash (PS1, USA, SCUS-94570). Psy-Q GCC 2.8.1 + maspsx (tools/setup.sh pins, mirrored in
# platforms.ps1). Its Python tooling is uv-managed (uv.lock) and its front door is just.
#
#   crash-bash-env -c 'just build'
{ pkgs, lib, tools }:

lib.platforms.ps1.mkEnv {
  name = "crash-bash";
}
