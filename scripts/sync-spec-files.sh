#!/bin/bash
# Discover files a new upstream release installs and add any that are
# missing from the spec's %files section.
#
# The daily update job previously only bumped Version / sources /
# changelog. New plugins, commands, and man-page sections then failed
# RPM packaging ("Installed (but unpackaged) file(s) found") — the
# same gap that needed a follow-up for flux-account-fairshare-emulate
# in 0.60.0 and that broke the 0.61.0 accounting bump.
#
# Usage: sync-spec-files.sh SPEC SRC_TREE [NOTES_FILE]
#
# NOTES_FILE (default: /tmp/added_files.txt) receives changelog bullets
# for whatever was added. The script is idempotent: a second run on the
# same spec/tree is a no-op.
set -euo pipefail

usage() {
    echo "Usage: $0 SPEC SRC_TREE [NOTES_FILE]" >&2
    exit 2
}

# Join automake / cmake backslash continuations so each assignment or
# install() call is a single line.
flatten_continuations() {
    awk '
        {
            line = $0
            sub(/[[:space:]]+$/, "", line)
            if (cont) {
                sub(/^[[:space:]]+/, "", line)
                buf = buf " " line
            } else {
                buf = line
            }
            if (buf ~ /\\$/) {
                sub(/\\$/, "", buf)
                sub(/[[:space:]]+$/, "", buf)
                cont = 1
                next
            }
            print buf
            buf = ""
            cont = 0
        }
        END { if (cont && buf != "") print buf }
    '
}

# Resolve a Makefile.am directory value to an RPM %files path.
resolve_am_dir() {
    local raw=$1
    raw=${raw//\$\(fluxlibdir\)/%{_libdir\}\/flux}
    raw=${raw//\$\(fluxcmddir\)/%{_libexecdir\}\/flux\/cmd}
    raw=${raw//\$\(fluxrc1dir\)/%{_sysconfdir\}\/flux\/rc1.d}
    raw=${raw//\$\(fluxrc3dir\)/%{_sysconfdir\}\/flux\/rc3.d}
    raw=${raw//\$\(fluxmoddir\)/%{_libdir\}\/flux\/modules}
    raw=${raw//\$\(libexecdir\)/%{_libexecdir\}}
    raw=${raw//\$\(libdir\)/%{_libdir\}}
    raw=${raw//\$\(sysconfdir\)/%{_sysconfdir\}}
    raw=${raw//\$\(prefix\)\/libexec/%{_libexecdir\}}
    raw=${raw//\$\(prefix\)\/lib/%{_libdir\}}
    raw=${raw//\$\(prefix\)\/etc/%{_sysconfdir\}}
    raw=${raw%/}
    # Refuse anything we could not fully expand.
    if [[ "$raw" == *'$('* ]]; then
        echo ""
        return 1
    fi
    echo "$raw"
}

# Collect "path<TAB>kind" candidates from an extracted source tree.
# kind is plugin|command|rc|unit|manN — used for insertion + changelog.
discover_candidates() {
    local src=$1
    local am vars prefix dir_val item base dest section

    while IFS= read -r -d '' am; do
        vars=$(flatten_continuations < "$am")

        # *_LTLIBRARIES that actually get installed (not noinst_/check_).
        while IFS= read -r line; do
            [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)_LTLIBRARIES[[:space:]]*=[[:space:]]*(.*)$ ]] || continue
            prefix="${BASH_REMATCH[1]}"
            case "$prefix" in
                noinst|check|EXTRA) continue ;;
            esac
            dir_val=$(echo "$vars" | sed -n "s/^${prefix}dir[[:space:]]*=[[:space:]]*//p" | tail -n1)
            [[ -n "$dir_val" ]] || continue
            dest=$(resolve_am_dir "$dir_val") || continue
            [[ -n "$dest" ]] || continue
            for item in ${BASH_REMATCH[2]}; do
                [[ "$item" == *.la ]] || continue
                base="${item##*/}"
                base="${base%.la}"
                if [[ "$dest" == *job-manager/plugins* ]]; then
                    printf '%s\t%s\n' "${dest}/${base}.so" plugin
                elif [[ "$dest" == *flux/modules* ]]; then
                    printf '%s\t%s\n' "${dest}/${base}.so" plugin
                else
                    printf '%s\t%s\n' "${dest}/${base}.so" plugin
                fi
            done
        done <<< "$vars"

        # flux cmd scripts / programs.
        # Optional automake `dist_` prefix is not a capturing group so
        # BASH_REMATCH indices stay stable under `set -u`.
        while IFS= read -r line; do
            [[ "$line" =~ fluxcmd_(SCRIPTS|PROGRAMS)[[:space:]]*=[[:space:]]*(.*)$ ]] || continue
            for item in ${BASH_REMATCH[2]}; do
                [[ "$item" == *'$( '* ]] && continue
                base="${item##*/}"
                [[ -n "$base" && "$base" != *'$'* ]] || continue
                printf '%s\t%s\n' "%{_libexecdir}/flux/cmd/${base}" command
            done
        done <<< "$vars"

        # rc1 / rc3 hooks.
        while IFS= read -r line; do
            [[ "$line" =~ fluxrc([13])_SCRIPTS[[:space:]]*=[[:space:]]*(.*)$ ]] || continue
            section="${BASH_REMATCH[1]}"
            for item in ${BASH_REMATCH[2]}; do
                base="${item##*/}"
                [[ -n "$base" && "$base" != *'$'* ]] || continue
                printf '%s\t%s\n' "%{_sysconfdir}/flux/rc${section}.d/${base}" rc
            done
        done <<< "$vars"

        # systemd units (strip .in).
        while IFS= read -r line; do
            [[ "$line" =~ systemdsystemunit_DATA[[:space:]]*=[[:space:]]*(.*)$ ]] || continue
            for item in ${BASH_REMATCH[1]}; do
                base="${item##*/}"
                base="${base%.in}"
                [[ -n "$base" && "$base" != *'$'* ]] || continue
                printf '%s\t%s\n' "%{_unitdir}/${base}" unit
            done
        done <<< "$vars"

        # man page sections from automake variables (man_MANS, MAN5_FILES, ...).
        while IFS= read -r line; do
            [[ "$line" =~ (man_MANS|MAN[0-9]_FILES_PRIMARY|MAN[0-9]_FILES)[[:space:]]*=[[:space:]]*(.*)$ ]] || continue
            for item in ${BASH_REMATCH[2]}; do
                section=""
                if [[ "$item" =~ \.([0-9])$ ]]; then
                    section="${BASH_REMATCH[1]}"
                elif [[ "$item" =~ man([0-9])/ ]]; then
                    section="${BASH_REMATCH[1]}"
                fi
                [[ -n "$section" ]] || continue
                printf '%s\t%s\n' "%{_mandir}/man${section}/*.${section}*" "man${section}"
            done
        done <<< "$vars"
    done < <(find "$src" -name Makefile.am -print0)

    # Source-tree manN directories (covers cmake / sphinx layouts that
    # don't list every page in an automake variable we parsed).
    while IFS= read -r -d '' dir; do
        section="${dir##*/man}"
        [[ "$section" =~ ^[0-9]$ ]] || continue
        printf '%s\t%s\n' "%{_mandir}/man${section}/*.${section}*" "man${section}"
    done < <(find "$src" -type d -name 'man[0-9]' -print0)

    # CMake install destinations (flux-sched).
    if find "$src" -name CMakeLists.txt -print -quit | grep -q .; then
        while IFS= read -r -d '' cmake; do
            flatten_continuations < "$cmake" | grep -E 'install\s*\(' | while IFS= read -r line; do
                if [[ "$line" =~ DESTINATION[[:space:]]+[^[:space:]]*man([0-9]) ]]; then
                    printf '%s\t%s\n' "%{_mandir}/man${BASH_REMATCH[1]}/*.${BASH_REMATCH[1]}*" "man${BASH_REMATCH[1]}"
                fi
                if [[ "$line" =~ DESTINATION[[:space:]]+[^[:space:]]*flux/cmd ]] && \
                   [[ "$line" =~ (FILES|PROGRAMS|TARGETS)[[:space:]]+([^[:space:]]+) ]]; then
                    base="${BASH_REMATCH[2]##*/}"
                    [[ -n "$base" && "$base" != *'$'* && "$base" != *'{'* ]] || continue
                    printf '%s\t%s\n' "%{_libexecdir}/flux/cmd/${base}" command
                fi
                if [[ "$line" =~ DESTINATION[[:space:]]+[^[:space:]]*flux/modules ]] && \
                   [[ "$line" =~ (TARGETS|FILES)[[:space:]]+([^[:space:]]+) ]]; then
                    base="${BASH_REMATCH[2]##*/}"
                    [[ -n "$base" && "$base" != *'$'* && "$base" != *'{'* ]] || continue
                    printf '%s\t%s\n' "%{_libdir}/flux/modules/${base}.so" plugin
                fi
            done
        done < <(find "$src" -name CMakeLists.txt -print0)
    fi
}

# Strip %files decorations so we can compare paths.
# %dir lines are kept (they own everything underneath).
normalize_files_entry() {
    local line=$1
    # Drop comments
    line="${line%%#*}"
    # Drop leading RPM directives / attributes
    line=$(echo "$line" | sed -E \
        -e 's/^[[:space:]]+//' \
        -e 's/[[:space:]]+$//' \
        -e 's/^%dir[[:space:]]+//' \
        -e 's/^%ghost[[:space:]]+//' \
        -e 's/^%config(\([^)]*\))?[[:space:]]+//' \
        -e 's/^%attr\([^)]*\)[[:space:]]+//' \
        -e 's/^%verify\([^)]*\)[[:space:]]+//')
    echo "$line"
}

# Every path listed in any %files section (main + subpackages).
collect_spec_paths() {
    local spec=$1
    awk '
        BEGIN { in_files = 0 }
        /^%files([[:space:]]|$)/ { in_files = 1; next }
        /^%changelog/ { in_files = 0 }
        /^%(prep|build|install|check|pre|post|preun|postun|trigger|transfiletrigger|package|description|prep)/ {
            if ($0 !~ /^%files/) in_files = 0
        }
        in_files { print }
    ' "$spec"
}

# Return 0 if candidate is already owned by an existing %files entry.
# Reads the global spec_lines array — never stdin, so a caller can
# safely invoke this from inside a pipeline.
spec_covers() {
    local candidate=$1
    local raw entry
    for raw in "${spec_lines[@]}"; do
        [[ -z "$raw" || "$raw" =~ ^[[:space:]]*# ]] && continue
        case "$raw" in
            %license*|%doc*|%defattr*) continue ;;
        esac
        entry=$(normalize_files_entry "$raw")
        [[ -n "$entry" ]] || continue

        # Exact path
        [[ "$entry" == "$candidate" ]] && return 0
        # Directory ownership: listing a dir owns everything under it
        [[ "$candidate" == "$entry"/* ]] && return 0
        # Glob on the spec side (e.g. %{_mandir}/man1/*.1*).
        # The unquoted RHS is the point: bash [[ == ]] glob-matches.
        # shellcheck disable=SC2053
        if [[ "$candidate" == $entry ]]; then
            return 0
        fi
        # Two globs in the same directory (man5/* covers man5/*.5*)
        if [[ "$entry" == *"*"* && "$candidate" == *"*"* ]]; then
            [[ "${entry%/*}" == "${candidate%/*}" ]] && return 0
        fi
    done
    return 1
}

# Insert a new %files line next to related entries in the *main*
# %files section (not %files devel). Falls back to the end of that
# section — just before the next %files or %changelog.
insert_files_entry() {
    local spec=$1
    local path=$2
    local kind=$3
    local tmp
    tmp=$(mktemp)

    awk -v path="$path" -v kind="$kind" '
        BEGIN {
            inserted = 0
            files_count = 0
            last_related = 0
            if (kind == "plugin") {
                needle = "job-manager/plugins/|flux/modules/.*\\.so"
            } else if (kind == "command") {
                needle = "libexecdir\\}/flux/cmd/"
            } else if (kind ~ /^man[0-9]$/) {
                needle = "\\{_mandir\\}/"
            } else if (kind == "rc") {
                needle = "sysconfdir\\}/flux/rc"
            } else if (kind == "unit") {
                needle = "\\{_unitdir\\}/"
            } else {
                needle = ""
            }
        }
        /^%files([[:space:]]|$)/ {
            files_count++
            # Leaving the main package: insert at the end of it.
            if (files_count == 2 && !inserted) {
                print path
                inserted = 1
            }
            print
            next
        }
        {
            if (inserted) { print; next }
            if (files_count == 1 && needle != "" && $0 ~ needle) {
                last_related = 1
                print
                next
            }
            # First non-related line after a match: insert so the new
            # entry sits with the others of its kind.
            if (files_count == 1 && last_related && !inserted) {
                print path
                inserted = 1
                print
                next
            }
            if (files_count == 1 && !inserted && $0 ~ /^%changelog/) {
                print path
                inserted = 1
                print
                next
            }
            print
        }
        END {
            if (!inserted) {
                print "ERROR: could not find insertion point for " path > "/dev/stderr"
                exit 1
            }
        }
    ' "$spec" > "$tmp"
    mv "$tmp" "$spec"
}

changelog_note() {
    local path=$1
    local kind=$2
    local name=${path##*/}
    case "$kind" in
        plugin)  echo "- Package ${name} (new upstream plugin)" ;;
        command) echo "- Package ${name} (new upstream command)" ;;
        rc)      echo "- Package ${name} rc hook" ;;
        unit)    echo "- Package ${name} systemd unit" ;;
        man*)    echo "- Package ${kind} pages" ;;
        *)       echo "- Package ${name}" ;;
    esac
}

# ---------------------------------------------------------------------------
# self-test: the 0.61.0-shaped gap (new plugin + new man section) and
# the 0.60.0-shaped gap (new command), plus directory/glob coverage.
# ---------------------------------------------------------------------------
self_test() {
    local tmp spec src notes
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' RETURN

    spec="$tmp/test.spec"
    src="$tmp/src"
    notes="$tmp/notes.txt"
    mkdir -p "$src/src/plugins" "$src/doc/man5" "$src/src/cmd"

    cat > "$src/src/plugins/Makefile.am" <<'EOF'
jobtapdir = \
  $(fluxlibdir)/job-manager/plugins/

jobtap_LTLIBRARIES = mf_priority.la resource_quotas.la
EOF
    cat > "$src/src/Makefile.am" <<'EOF'
dist_fluxcmd_SCRIPTS = \
	cmd/flux-account.py \
	cmd/flux-account-fairshare-emulate.py
EOF
    cat > "$src/doc/Makefile.am" <<'EOF'
MAN5_FILES_PRIMARY = \
	man5/flux-config-accounting.5
man_MANS = $(MAN1_FILES) $(MAN5_FILES)
EOF
    : > "$src/doc/man5/flux-config-accounting.rst"

    # Starting spec: one plugin, one command, man1 only — the 0.60.0
    # packaged set before the 0.61.0 artifacts existed.
    cat > "$spec" <<'EOF'
Name: test
%files
%{_libdir}/flux/job-manager/plugins/mf_priority.so
%{_libexecdir}/flux/cmd/flux-account.py
%{_mandir}/man1/*.1*
%changelog
* Wed Sep 02 2026 test - 1-1
- initial
EOF

    "$0" "$spec" "$src" "$notes"

    grep -q '%{_libdir}/flux/job-manager/plugins/resource_quotas.so' "$spec" \
        || { echo "FAIL: plugin not added" >&2; return 1; }
    grep -q '%{_libexecdir}/flux/cmd/flux-account-fairshare-emulate.py' "$spec" \
        || { echo "FAIL: command not added" >&2; return 1; }
    grep -q '%{_mandir}/man5/\*\.5\*' "$spec" \
        || { echo "FAIL: man5 glob not added" >&2; return 1; }
    grep -q 'resource_quotas.so (new upstream plugin)' "$notes" \
        || { echo "FAIL: plugin changelog note missing" >&2; return 1; }

    # Idempotent.
    "$0" "$spec" "$src" "$notes"
    [[ ! -s "$notes" ]] || { echo "FAIL: second run was not a no-op" >&2; return 1; }

    # Directory ownership covers a new plugin.
    cat > "$spec" <<'EOF'
Name: test
%files
%{_libdir}/flux/job-manager
%{_libexecdir}/flux
%{_mandir}/man1/*.1*
%{_mandir}/man5/*.5*
%changelog
* Wed Sep 02 2026 test - 1-1
- initial
EOF
    "$0" "$spec" "$src" "$notes"
    [[ ! -s "$notes" ]] || { echo "FAIL: directory ownership not honored" >&2; return 1; }

    echo "self-test passed"
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
[[ ${1:-} == "-h" || ${1:-} == "--help" ]] && usage
[[ ${1:-} == "--self-test" ]] && { self_test; exit $?; }
[[ $# -ge 2 ]] || usage

SPEC=$1
SRC=$2
NOTES=${3:-/tmp/added_files.txt}

[[ -f "$SPEC" ]] || { echo "ERROR: spec not found: $SPEC" >&2; exit 1; }
[[ -d "$SRC" ]] || { echo "ERROR: source tree not found: $SRC" >&2; exit 1; }

: > "$NOTES"

mapfile -t spec_lines < <(collect_spec_paths "$SPEC")

# Deduplicate candidates (man sections especially show up many times).
declare -A seen=()
added=0

while IFS=$'\t' read -r path kind; do
    [[ -n "$path" ]] || continue
    [[ -z "${seen[$path]:-}" ]] || continue
    seen[$path]=1

    if spec_covers "$path"; then
        echo "Already packaged: $path"
        continue
    fi

    echo "Adding to %files: $path ($kind)"
    insert_files_entry "$SPEC" "$path" "$kind"
    changelog_note "$path" "$kind" >> "$NOTES"
    added=$((added + 1))

    # Re-read %files so a just-added man5 glob covers later man5 hits.
    mapfile -t spec_lines < <(collect_spec_paths "$SPEC")
done < <(discover_candidates "$SRC" | sort -u)

if [[ "$added" -eq 0 ]]; then
    echo "No new %files entries needed"
else
    echo "Added ${added} %files entr$( [[ "$added" -eq 1 ]] && echo y || echo ies )"
    echo "Changelog notes:"
    cat "$NOTES"
fi
