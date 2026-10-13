#!/usr/bin/env bash
# decomp-guard: keep game data out of a decomp repo's git history.
#   decomp-guard check [FILE...]   check FILEs, or (no args) everything staged for commit
#   decomp-guard install           install as this repo's pre-commit hook (self-contained copy;
#                                  an existing hook is kept and still runs, as pre-commit.local)
# Refuses: game-data extensions; boot-executable names (SCPS_150.88, SLUS_123.45, ...); files whose
# bytes look like an ELF, a PS-X EXE, an ISO 9660 image or an N64 ROM; anything under asm/ disc/
# build/ assets/ dumps/ iso/ (README.md excepted); binaries over 5 MB. Exceptions: one glob per
# line in .decomp-guard-allow at the repo root.
# Plain bash 3.2 + git + coreutils/BSD tools, so it also runs on macOS without Nix.
set -u

die_usage() { echo "usage: decomp-guard check [FILE...] | decomp-guard install" >&2; exit 2; }

allowed() { # path
    local f="$1" pat
    [ -f .decomp-guard-allow ] || return 1
    while IFS= read -r pat || [ -n "$pat" ]; do
        case "$pat" in ''|'#'*) continue ;; esac
        # shellcheck disable=SC2254
        case "$f" in $pat) return 0 ;; esac
    done < .decomp-guard-allow
    return 1
}

read_head() { # path staged? -> first 36 KB on stdout
    if [ "$2" = staged ]; then git show ":$1" 2>/dev/null | head -c 36864; else head -c 36864 "$1" 2>/dev/null; fi
}

size_of() { # path staged?
    if [ "$2" = staged ]; then git cat-file -s ":$1" 2>/dev/null || echo 0; else wc -c < "$1" | tr -d ' '; fi
}

why_bad() { # path staged? -> prints a reason if the file is game data
    local f="$1" mode="$2" base lower hex size
    base=$(basename "$f"); lower=$(printf '%s' "$f" | tr 'A-Z' 'a-z')
    case "$lower" in
        *.iso|*.bin|*.cue|*.chd|*.img|*.mdf|*.nrg|*.cso|*.zso|*.elf|*.z64|*.n64|*.v64|*.gba|*.nds|*.gcm|*.wbfs|*.rvz|*.xex|*.7z)
            echo "game-data file type"; return ;;
    esac
    if printf '%s' "$base" | grep -Eq '^S[CL][A-Z]{2}_[0-9]{3}\.[0-9]{2}$'; then echo "boot executable name"; return; fi
    case "/$f" in
        */asm/*|*/disc/*|*/build/*|*/assets/*|*/dumps/*|*/iso/*)
            [ "$base" = README.md ] || { echo "generated or extracted path"; return; } ;;
    esac
    hex=$(read_head "$f" "$mode" | od -An -tx1 -v | tr -d ' \n')
    case "$hex" in
        7f454c46*) echo "ELF binary"; return ;;
        50532d5820455845*) echo "PS-X EXE"; return ;;
        80371240*|37804012*|40123780*) echo "N64 ROM"; return ;;
    esac
    # ISO 9660: "CD001" at byte 0x8001 (hex offset 0x10002)
    [ "${hex:65538:10}" = 4344303031 ] && { echo "ISO 9660 image"; return; }
    size=$(size_of "$f" "$mode")
    if [ "${size:-0}" -gt 5242880 ] && read_head "$f" "$mode" | LC_ALL=C grep -q "$(printf '\000')" 2>/dev/null; then
        echo "binary over 5 MB"; return
    fi
}

cmd_check() {
    local mode=file bad=0 f reason
    if [ $# -eq 0 ]; then
        mode=staged
        set -- $(git diff --cached --name-only --diff-filter=ACMR)
    fi
    for f in "$@"; do
        allowed "$f" && continue
        reason=$(why_bad "$f" "$mode")
        if [ -n "$reason" ]; then echo "decomp-guard: refusing $f ($reason)" >&2; bad=1; fi
    done
    if [ $bad = 1 ]; then
        echo "decomp-guard: game data never goes in git. Unstage it (git restore --staged FILE), or list a deliberate exception in .decomp-guard-allow." >&2
        return 1
    fi
}

cmd_install() {
    local hooks hook self
    hooks=$(git rev-parse --git-path hooks) || exit 1
    mkdir -p "$hooks"; hook="$hooks/pre-commit"; self=${BASH_SOURCE[0]}
    if [ -f "$hook" ] && ! grep -q 'decomp-guard' "$hook"; then mv "$hook" "$hook.local"; fi
    {
        echo '#!/usr/bin/env bash'
        echo '# installed by decomp-guard; the previous hook (if any) runs afterwards as pre-commit.local'
        echo 'decomp_guard() {'
        sed -e '1,/^set -u$/d' -e '/^case "\${1:-}" in$/,$d' "$self"
        echo 'cmd_check || exit 1'
        echo '}'
        echo 'decomp_guard'
        echo 'here=$(dirname "$0"); [ -x "$here/pre-commit.local" ] && exec "$here/pre-commit.local" "$@"'
        echo 'exit 0'
    } > "$hook"
    chmod +x "$hook"
    echo "decomp-guard: installed $hook"
}

case "${1:-}" in
    check) shift; cmd_check "$@" ;;
    install) cmd_install ;;
    *) die_usage ;;
esac
