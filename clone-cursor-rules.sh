#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./clone-cursor-rules.sh [projects-root]

Find git repos under projects-root and make sure each selected repo has a cloned
Cursor-Rules import at .cursor/rules/imported/Cursor-Rules.

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

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source_repo="$(git -C "$script_dir" rev-parse --show-toplevel)"
source_remote="$(git -C "$source_repo" remote get-url origin)"
projects_root="${1:-$HOME/Code}"
rules_path=".cursor/rules/imported/Cursor-Rules"

if [[ ! -d "$projects_root" ]]; then
  printf 'Projects root not found: %s\n' "$projects_root" >&2
  exit 1
fi

projects_root="$(cd -- "$projects_root" && pwd -P)"

ask_yes_no() {
  local prompt="$1"
  local reply

  read -r -p "$prompt [y/N] " reply || return 1
  [[ "$reply" == "y" || "$reply" == "Y" || "$reply" == "yes" || "$reply" == "YES" ]]
}

find_project_repos() {
  find "$projects_root" \
    \( -type d \( -name .cursor -o -name node_modules \) -prune \) -o \
    \( -name .git \( -type d -o -type f \) -print -prune \)
}

clone_rules() {
  local target_dir="$1"

  mkdir -p -- "$(dirname -- "$target_dir")"
  git clone "$source_remote" "$target_dir"
}

backup_path() {
  local target_dir="$1"
  local backup="${target_dir}.backup-$(date +%Y%m%d%H%M%S)"
  local suffix=1

  while [[ -e "$backup" ]]; do
    backup="${target_dir}.backup-$(date +%Y%m%d%H%M%S)-$suffix"
    ((suffix += 1))
  done

  printf '%s\n' "$backup"
}

convert_copy_to_clone() {
  local target_dir="$1"
  local backup

  backup="$(backup_path "$target_dir")"
  mv -- "$target_dir" "$backup"

  if clone_rules "$target_dir"; then
    printf 'Backup: %s\n' "$backup"
    return 0
  fi

  rm -rf -- "$target_dir"
  mv -- "$backup" "$target_dir"
  return 1
}

mapfile -t project_repos < <(
  while IFS= read -r git_marker; do
    repo="$(dirname -- "$git_marker")"
    repo="$(cd -- "$repo" && pwd -P)"

    if [[ "$repo" != "$source_repo" ]]; then
      printf '%s\n' "$repo"
    fi
  done < <(find_project_repos) | sort -u
)

if ((${#project_repos[@]} == 0)); then
  echo "No project git repos found."
  exit 0
fi

already_cloned=0
cloned=0
converted=0
skipped=0
failed=0

printf 'Project repos (%d):\n' "${#project_repos[@]}"
for repo in "${project_repos[@]}"; do
  printf '  %s\n' "$repo"
done

printf '\nClone results:\n'
for repo in "${project_repos[@]}"; do
  target_dir="$repo/$rules_path"

  if [[ -e "$target_dir/.git" ]]; then
    ((already_cloned += 1))
    continue
  fi

  printf '\n%s\n' "$repo"

  if [[ ! -e "$target_dir" ]]; then
    printf 'State: missing rules import\n'
    if ask_yes_no "Clone Cursor-Rules into this repo?"; then
      if clone_rules "$target_dir"; then
        ((cloned += 1))
        printf 'Result: cloned\n'
      else
        ((failed += 1))
        printf 'Result: failed\n'
      fi
    else
      ((skipped += 1))
      printf 'Result: skipped\n'
    fi
    continue
  fi

  if [[ -d "$target_dir" ]]; then
    printf 'State: copied rules import, not a clone\n'
    if ask_yes_no "Replace copied rules with a cloned repo?"; then
      if convert_copy_to_clone "$target_dir"; then
        ((converted += 1))
        printf 'Result: converted\n'
      else
        ((failed += 1))
        printf 'Result: failed\n'
      fi
    else
      ((skipped += 1))
      printf 'Result: skipped\n'
    fi
    continue
  fi

  ((failed += 1))
  printf 'Result: failed\n'
  printf 'Reason: target path exists but is not a directory\n'
done

printf '\nDone: %d already cloned, %d cloned, %d converted, %d skipped, %d failed.\n' \
  "$already_cloned" "$cloned" "$converted" "$skipped" "$failed"

if ((failed > 0)); then
  exit 1
fi
