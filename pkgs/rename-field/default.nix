# rename-field STRUCT OLD NEW [PATH...]: rename one field of one struct across C sources, the way
# IDA's rename does: only where the expression's type really is that struct (s.OLD, p->OLD, and
# the declaration inside the struct), never a same-named field of another struct. Coccinelle
# (spatch) does the type-aware matching. In a matching decomp a pure rename cannot change the
# bytes, so the project's gates (make elf etc.) must still pass afterwards.
{ pkgs }:

pkgs.writeShellApplication {
  name = "rename-field";
  runtimeInputs = [ pkgs.coccinelle pkgs.coreutils pkgs.gnugrep pkgs.git ];
  text = ''
    if [ $# -lt 3 ]; then
      echo "usage: rename-field STRUCT OLD NEW [PATH...]   (default PATH: src include)" >&2
      echo "       TYPEDEF=Name if the struct's typedef is not also called STRUCT" >&2
      exit 2
    fi
    s=$1 old=$2 new=$3; shift 3
    td=''${TYPEDEF:-$s}
    [ $# -gt 0 ] || set -- src include
    rule=$(mktemp --suffix=.cocci)
    macros=$(mktemp --suffix=.h)
    trap 'rm -f "$rule" "$macros"' EXIT
    # Decomp C is full of GCC-isms spatch can't parse (symbol labels on declarations, section and
    # sda attributes, INCLUDE_ASM lines); an unparsed declaration hides the variable's type, so
    # its uses would be missed. Treat them as nothing.
    cat > "$macros" <<'H'
    #define __asm__(x)
    #define asm(x)
    #define __attribute__(x)
    #define INCLUDE_ASM(a, b)
    #define INCLUDE_RODATA(a, b)
    H
    cat > "$rule" <<COCCI
    @ rename_decl @
    type T;
    @@
    struct $s {
      ...
    - T $old;
    + T $new;
      ...
    };

    @ rename_use @
    typedef $td;
    struct $s *p;
    struct $s v;
    $td *tp;
    $td tv;
    @@
    (
    - p->$old
    + p->$new
    |
    - v.$old
    + v.$new
    |
    - tp->$old
    + tp->$new
    |
    - tv.$old
    + tv.$new
    )
    COCCI
    inc=()
    for d in include src; do [ -d "$d" ] && inc+=(-I "$d"); done
    for target in "$@"; do   # spatch walks a folder only with --dir
      if [ -d "$target" ]; then where=(--dir "$target"); else where=("$target"); fi
      spatch --sp-file "$rule" --macro-file "$macros" --in-place --include-headers \
        --include-headers-for-types --recursive-includes --relax-include-path \
        "''${inc[@]}" --very-quiet --timeout 120 "''${where[@]}"
    done
    echo "== left over (a cast, a macro, or code spatch could not parse; check by hand):"
    grep -rn --include='*.c' --include='*.h' --include='*.cpp' --include='*.hpp' -w "$old" "$@" || echo "   none"
    if git rev-parse --git-dir >/dev/null 2>&1; then git diff --stat -- "$@" | tail -1; fi
    echo "Now run the project's gates: a pure rename must leave every byte identical."
  '';
}
