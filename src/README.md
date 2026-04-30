# fishtools source layout

`fishtools.sh` is the single-file release artifact users run on VPS hosts.
Edit files under `src/` during development, then rebuild the release file:

```bash
bash scripts/build-release.sh
```

On Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build-release.ps1
```

Layout:

- `00_globals.sh`: script metadata, colors, cleanup trap.
- `core/`: package manager helpers, dependency checks, CLI args, logging, validation.
- `ui/`: menu drawing and common interactive UI helpers.
- `modules/`: VPS management features grouped by domain.
- `99_main.sh`: main menu and startup sequence.

Before publishing, run:

```bash
bash -n fishtools.sh scripts/*.sh
shellcheck fishtools.sh src/**/*.sh scripts/*.sh
```
