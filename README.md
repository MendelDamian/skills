# skills

My Claude Code plugin marketplace (`mendel`): my own plugins plus mirrors of upstream ones, which a daily GitHub Action keeps in sync.

| Plugin | Source |
|---|---|
| `pstack` | [cursor/plugins/pstack](https://github.com/cursor/plugins/tree/main/pstack) (mirrored) |

## Install (Claude Code)

```
/plugin marketplace add MendelDamian/skills
/plugin install pstack@mendel
```

Auto-update is off by default for third-party marketplaces. Enable it in `/plugin` → Marketplaces → mendel, or update manually:

```
/plugin marketplace update mendel
/plugin update pstack@mendel
```

## Without the marketplace (OpenCode, or plain ~/.claude)

```
git clone https://github.com/MendelDamian/skills ~/projects/skills
~/projects/skills/scripts/link.sh opencode   # or: claude
```

This symlinks every plugin's `skills/*` and `agents/*.md` into `~/.config/opencode/` (or `~/.claude/`). Run `git pull` to update. Don't use `link.sh claude` together with the marketplace install, or you'll get duplicates.

## Layout

- `plugins/<name>/`: one plugin per folder. Mirrored ones are overwritten on every sync, so never edit them by hand. Your own plugins are never touched by the sync.
- `sources.json`: which plugins are mirrored. Each entry is `{name, repo, path, exclude?, allowModelInvocation?}`:
  - `exclude`: globs relative to the plugin root (e.g. `skills/recall`, `skills/*-verification-skill`). They aren't synced, and already-synced copies are deleted.
  - `allowModelInvocation`: globs matched against skill directory names (e.g. `principle-*`, or `*` for all). Matching skills lose upstream's `disable-model-invocation: true`, so Claude can load them on its own. The rest stay manual (slash command only).
- `overlay/plugins/<name>/`: files layered on top of a mirrored plugin after each sync. It must contain `.claude-plugin/plugin.json` with a `version`, which sync bumps whenever the plugin changes.
- `upstream-lock.json`: the upstream SHA last synced for each mirrored plugin.
- `scripts/sync.sh`, `scripts/validate.sh`: run by `.github/workflows/sync.yml`, and can be run locally.

## Add a mirrored plugin

1. Add `{ "name": "...", "repo": "owner/repo", "path": "dir" }` to `sources.json`.
2. Add `overlay/plugins/<name>/.claude-plugin/plugin.json` with `"version": "0.0.0"`.
3. Add an entry to `.claude-plugin/marketplace.json` with source `./plugins/<name>`.
4. Run `scripts/sync.sh && scripts/validate.sh`, then commit.

## Add your own plugin

Create `plugins/<name>/.claude-plugin/plugin.json` and `plugins/<name>/skills/<skill>/SKILL.md`, add it to `marketplace.json`, and bump its `version` by hand when you change it.
