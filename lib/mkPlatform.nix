# mkPlatform: the shared shape of a platform toolbox (PS1, PS2, ...). A platform supplies its
# tools and its compilers; this wraps them into the `{ tools; compilers; mkEnv; }` every platform
# exposes, so the one bit that was copy-pasted in each platform file -- fold the platform tools into
# every project env and point $DECOMP_COMPILERS at the compilers -- lives in one place.
#
#   mkPlatform { inherit tools compilers; }        # -> { tools; compilers; mkEnv; }
#   mkPlatform { inherit tools compilers; platformProfile = "export FOO=1\n"; }   # extra env setup
{ mkDecompEnv }:

{
  tools,                 # the platform's tool packages, added to every project env on this platform
  compilers,             # a symlinkJoin exported as $DECOMP_COMPILERS (projects link tools/<name>)
  platformProfile ? "",  # platform-wide shell setup, before the project's own profile
}:

{
  inherit tools compilers;
  mkEnv = args@{ packages ? (p: [ ]), profile ? "", ... }:
    mkDecompEnv (args // {
      packages = p: tools ++ packages p;
      profile = ''
        export DECOMP_COMPILERS=${compilers}
      '' + platformProfile + profile;
    });
}
