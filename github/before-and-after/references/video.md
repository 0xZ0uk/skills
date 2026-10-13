# Before/after video

Read this only when the evidence is a screen recording rather than screenshots.

## Recording

- `agent-browser record start` opens a fresh browser context. Cookies and local storage carry over, but an origin-scoped header used to open a protected Vercel Preview may not. Start the recording on a blank page, apply the auth from `agent-browser skills get protected-vercel-deployments --full` inside it, then navigate.
- agent-browser `0.35.2` and `0.36.0` record at a fixed 10 fps. Check the installed version's recording reference before assuming that still holds. Don't transcode to 30/60 fps — it only duplicates frames. Say so beside the video when motion smoothness matters.

## Publishing a video table

`gh --attach` does not rewrite local paths inside `<video src>`, so a side-by-side video table goes through a temporary comment:

1. Upload the videos in a temporary PR comment: `gh pr comment <pr> --body "uploading" --attach .artifacts/<task>/before.webm --attach .artifacts/<task>/after.webm`.
2. `gh pr comment` prints the comment URL ending in `#issuecomment-<id>`. Read that comment back with `gh api 'repos/{owner}/{repo}/issues/comments/<id>' --jq .body` and take the `https://github.com/user-attachments/assets/...` URLs, in before/after order.
3. Build the table from those URLs and replace the marked block:

   ```bash
   gh pr view <pr> --json body --jq .body > <tmp>/pr-body.md
   node <skill-dir>/scripts/format.mjs --body-file <tmp>/pr-body.md \
     --before-video-url <before-url> --after-video-url <after-url> --label "<label>" > <tmp>/pr-body-next.md
   gh pr edit <pr> --body-file <tmp>/pr-body-next.md
   ```

   `<tmp>` is a fresh directory from `mktemp -d`, so parallel agents don't overwrite each other's files.

4. Re-read the PR body and confirm both URLs are there before deleting the temporary comment (`gh api -X DELETE 'repos/{owner}/{repo}/issues/comments/<id>'`). If anything failed, keep the comment — it holds the only copy of the uploads.

Fallback: plain own-line videos (`--before .artifacts/<task>/before.webm --after .artifacts/<task>/after.webm` through `publish.sh`), which `gh --attach` does rewrite.
