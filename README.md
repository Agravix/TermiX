# TermiX

One command turns a fresh Termux into a beautiful fish-powered terminal.

## Themes

Two built-in themes:

- **modern** — Catppuccin Mocha · rounded powerline · gradient banner
- **matrix** — hacker green · terminal lines · matrix rain intro

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/Agravix/TermiX/main/install.sh | bash
```

The installer asks which theme you want. To skip all prompts:

```bash
curl -fsSL https://raw.githubusercontent.com/Agravix/TermiX/main/install.sh | bash -s -- --theme matrix --yes
```

## Options

| Option | Description |
|---|---|
| `-t, --theme modern\|matrix` | Choose theme |
| `-y, --yes` | No prompts |
| `--minimal` | Skip eza/bat/fzf and Termux extra-keys config |
| `--no-font` | Do not download the font |
| `--no-upgrade` | Skip `pkg upgrade` (faster) |
| `--no-shell` | Do not change the default shell |
| `--uninstall` | Restore everything |

## What the installer does

- Runs `pkg update` and `pkg upgrade`, installs `fish git curl unzip ncurses-utils procps nano` plus optional tools `eza bat fzf`
- Downloads JetBrainsMono Nerd Font Mono (~2.5 MB) for icons
- Installs the fish config and chosen theme into `~/.config/tfs/`
- Sets Termux colors, prompt, and the extra-keys row (`ESC | / - TAB CTRL ALT ~ ...`)
- Disables the default Termux welcome message and sets fish as the default shell
- Backs up your existing files before changing anything

Everything is plain text inside `install.sh` (see the `write_payload` function). Read it before running.

## The `tfs` command

```bash
tfs theme modern|matrix     # switch theme (Termux colors change too)
tfs icons nerd|plain        # plain = no Nerd Font required
tfs intro auto|always|never # matrix rain intro (auto = once every 6h)
tfs rain                    # matrix rain now
tfs doctor                  # diagnose fonts and icons
tfs uninstall               # remove and restore previous settings
```

## Features

- Two-line prompt with full git info: branch, ⇡⇣ ahead/behind, staged `+`, modified `!`, untracked `?`, conflict `✖`
- Duration for slow commands, exit code with name (`127 NOTFOUND`, `130 SIGINT`), background jobs, virtualenv, SSH and root
- Collapsible prompt: after Enter the previous prompt shrinks to a single line
- Empty Enter and Ctrl-C do not repeat the last exit code; Ctrl+L adds no extra blank line
- Automatically compacts on narrow mobile screens
- Colored command highlighting, fzf colors (Ctrl+R / Ctrl+T / Alt+C), and eza with theme
- Ready-made shortcuts: `gs ga gc gp gl pu pi`, `.. ... ....`, `!!`, and functions `mkcd extract myip weather`

## Personal config

Anything you want goes in `~/.config/tfs/user.fish`; the installer never overwrites it.

```fish
set -g prompt_show_clock 0
set -g prompt_min_duration 5000
abbr -a gs 'git status'
```

## FAQ

**Icons show as `?` or boxes.** Fully close Termux (remove it from the app list) and reopen it, then run `tfs doctor`. If you have Termux:Styling, its font may override ours. To skip the font: `tfs icons plain`.

**Persian text is broken in Termux.** Terminals do not shape or RTL-render Persian text correctly; the installer output is English for this reason.

**fish did not start after install.** Run `chsh -s fish` manually, or just run `fish`. Install log: `~/.cache/termux-fish-style/install.log`.

**Package repo errors.** Run `termux-change-repo` and re-run the installer; re-installing is safe and does not overwrite the original backup.

## Uninstall

```bash
tfs uninstall
```

Or:

```bash
curl -fsSL https://raw.githubusercontent.com/Agravix/TermiX/main/install.sh | bash -s -- --uninstall
```

Your config, colors, font, and previous `termux.properties` are restored, and the default shell goes back to what it was.

## Credits & License

MIT. Colors from [Catppuccin](https://github.com/catppuccin/catppuccin) (MIT). Font: [JetBrains Mono](https://github.com/JetBrains/JetBrainsMono) (OFL) patched by [Nerd Fonts](https://github.com/ryanoasis/nerd-fonts); downloaded directly from the Nerd Fonts release during install and not bundled in this repo.
