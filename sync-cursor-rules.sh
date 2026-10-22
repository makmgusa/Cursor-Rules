#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./sync-cursor-rules.sh [projects-root]

Find existing imported Cursor-Rules directories under projects-root and run
git pull --ff-only in each one.

If projects-root is omitted, the script scans $HOME/Code.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if (($# > 1)); then
  usage >&2
  exit 2
fi

code_dir="${1:-$HOME/Code}"
rules_path=".cursor/rules/imported/Cursor-Rules"

if [[ ! -d "$code_dir" ]]; then
  printf 'Projects root not found: %s\n' "$code_dir" >&2
  exit 1
fi

code_dir="$(cd -- "$code_dir" && pwd -P)"

mapfile -t rules_dirs < <(
  find "$code_dir" -type d -path "*/$rules_path" -print | sort
)

if ((${#rules_dirs[@]} == 0)); then
  echo "No imported Cursor-Rules directories found."
  exit 0
fi

successes=0
failures=0

printf 'Target directories (%d):\n' "${#rules_dirs[@]}"
for rules_dir in "${rules_dirs[@]}"; do
  printf '  %s\n' "$rules_dir"
done

printf '\nPull results:\n'
for rules_dir in "${rules_dirs[@]}"; do
  printf '\n%s\n' "$rules_dir"

  if [[ ! -e "$rules_dir/.git" ]]; then
    ((failures += 1))
    printf 'Result: failed\n'
    printf 'Reason: imported Cursor-Rules directory is not a git clone. Run clone-cursor-rules.sh to fix it.\n'
    continue
  fi

  if output="$(git -C "$rules_dir" pull --ff-only 2>&1)"; then
    ((successes += 1))
    printf 'Result: success\n'
  else
    ((failures += 1))
    printf 'Result: failed\n'
  fi

  if [[ -n "$output" ]]; then
    printf '%s\n' "$output"
  fi
done

printf '\nDone: %d succeeded, %d failed.\n' "$successes" "$failures"

if ((failures > 0)); then
  exit 1
fi
