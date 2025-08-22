# IGEL App Feed (GitHub Actions + Pages)

This repo publishes a **daily snapshot** of the IGEL App Portal feed from:
`https://app.igel.com/api/applications`

Artifacts produced:
- `feed/snapshots/YYYY-MM-DD.json` — daily raw snapshot
- `feed/latest.json` — latest full snapshot
- `feed/latest.min.json` — pruned snapshot: `name, displayName, version, publishedAt`
- `feed/summary_latest.txt` — human-friendly diff vs previous run (new/removed/version changes)

These files are deployed to **GitHub Pages** so you (and GPT) can read them via stable URLs:
- `https://<org>.github.io/<repo>/latest.json`
- `https://<org>.github.io/<repo>/latest.min.json`
- `https://<org>.github.io/<repo>/summary_latest.txt`

> Replace `<org>` and `<repo>` with your GitHub org/user and repo name.

## Local test
```bash
bash scripts/build_feed.sh
cat feed/summary_latest.txt || true
```

## First-time checklist
1. **Create a new public repo** and upload these files.
2. In repository **Settings → Pages**, set **Build and deployment = GitHub Actions**.
3. Go to **Actions** tab, run workflow **manually** once (`Run workflow`).
4. After it finishes, open your Pages URL: `https://<org>.github.io/<repo>/`.

## Caveats
- This is **catalog metadata**, not device/runtime status. For install/running state, use IGEL UMS/IMI and join on `name`/`version`.
- Pages may cache; the workflow overwrites `latest.*` each run.
