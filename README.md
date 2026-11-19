# streamdraw-equicord

Upstream [Equicord](https://github.com/Equicord/Equicord) with the StreamDraw plugin built in, rebuilt automatically. Clients installed from here update themselves from this repo's releases, so they get both upstream Equicord changes and plugin changes.

This repo doesn't contain Equicord's source. Every 6 hours, a workflow:

1. checks out the latest upstream Equicord and the private plugin repo
2. records both commits in `streamdraw/versions`
3. if either changed, builds standalone Equicord with the plugin and publishes it as the latest release

The build is stamped with this repo's commit and name, so Equicord's built-in updater looks for new releases here. Nothing gets merged, so there are no merge conflicts. If a build fails, nothing is released and clients stay on the last good version.

| | |
|---|---|
| `.github/workflows/streamdraw.yml` | schedule, manual trigger, steps |
| `streamdraw/sync.sh` | records versions, decides whether to build |
| `streamdraw/build.sh` | copies the plugin into Equicord and builds |
| `streamdraw/release.sh` | publishes the release, keeps the newest 5 |
| `streamdraw/install.ps1`, `install.sh` | friend installers. URLs are filled in per release. |
| `streamdraw/versions` | written by the workflow |

## Setup

1. **Create `miluum-one/streamdraw-equicord` as a public repo** and push this folder:
   ```sh
   git init -b main
   git add -A
   git commit -m "StreamDraw build pipeline"
   git remote add origin https://github.com/miluum-one/streamdraw-equicord.git
   git push -u origin main
   ```
   It has to be public, because clients check for updates without logging in.

2. **Let the workflow read the private plugin repo** with a read-only deploy key:
   ```sh
   ssh-keygen -t ed25519 -N "" -C "streamdraw-equicord CI" -f streamdraw-deploy
   ```
   - On the **plugin repo**: Settings → Deploy keys → Add. Paste `streamdraw-deploy.pub` and leave write access off.
   - On **this repo**: Settings → Secrets and variables → Actions:
     - Secret `STREAMDRAW_DEPLOY_KEY` = the contents of `streamdraw-deploy` (the private half)
     - Variable `STREAMDRAW_PLUGIN_REPO` = `miluum-one/streamdraw`, or whatever the plugin repo is called

   Delete both key files afterwards. The plugin repo's `relay/` and `.github/` folders are left out of the build.

3. **Allow the workflow to push the versions file**: Settings → Actions → General → Workflow permissions → **Read and write permissions**. If `main` has branch protection, let GitHub Actions bypass it.

4. **Run it once**: Actions → *Build Equicord + StreamDraw* → Run workflow. After that it runs every 6 hours on its own.

Optional: the repository variable `STREAMDRAW_KEEP_RELEASES` changes how many releases are kept (default 5). Running the workflow with **force** rebuilds the current versions.

## Installing (send this to friends)

Windows, in PowerShell:
```powershell
irm https://github.com/miluum-one/streamdraw-equicord/releases/latest/download/install.ps1 | iex
```

macOS, in Terminal:
```sh
curl -fsSL https://github.com/miluum-one/streamdraw-equicord/releases/latest/download/install.sh | sh
```

Each script:
1. downloads the build into Equicord's usual folder
2. closes Discord
3. runs the official Equicord installer (Equilotl) in "use this build" mode
4. reopens Discord

Equicord settings are kept. Vencord users get switched over too: the installer removes the Vencord patch first. Their Vencord settings live in a separate folder, so export them in Vencord's Backup & Restore beforehand and import them in Equicord's.

Then enable **StreamDraw** under Settings → Equicord → Plugins and click a relay invite link.

On macOS, the first run may ask to allow Terminal to modify apps (System Settings → Privacy & Security → App Management).

## Things to know

- Running the official Equicord installer's **Repair** or **Update** switches a client back to stock Equicord. Rerun the one-liner to fix it.
- In Equicord's settings, the "source code" links for plugins point at this repo, which has no source, so they 404. It's cosmetic.
- **GPL:** Equicord is GPL-3.0, and the releases here are public. Strictly speaking, anyone who downloads the build can ask for the plugin's source. Fine for a friend group, but worth knowing.
# streamdraw-equicord
