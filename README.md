This is an Agent rules repo based on direction from Cursor employees in these two posts:
https://forum.cursor.com/t/agent-model-change-around-the-weekend-frustration-rising/160562
https://forum.cursor.com/t/how-do-you-import-rules-in-the-latest-rules-settings/170505

The best practice of putting Rules in a git repo and keeping them in sync for each project was deprecated with a patch in September of 2026.

In order to retain this functionality, clone-cursor-rules.sh and sync-cursor-rules.sh were created.

Run clone-cursor-rules.sh first to make sure projects have a cloned copy of this rules repo. The script scans project repos, prompts before making changes, clones missing imports, and converts copied imports into cloned imports.

Any time rules are updated in this repo, commit and push the changes, then run sync-cursor-rules.sh to update all projects using the rules.

Projects import this repo at:
`.cursor/rules/imported/Cursor-Rules`

After updating rules in this repo, commit and push the changes, then run:
`./sync-cursor-rules.sh`

The sync script finds existing cloned imports of this repo under `$HOME/Code` and runs `git pull --ff-only` in each one.

If a project is new or its rules are not syncing, run:
`./clone-cursor-rules.sh`

To scan a different projects directory, pass it as the only argument:
`./sync-cursor-rules.sh /path/to/projects`
`./clone-cursor-rules.sh /path/to/projects`