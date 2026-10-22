#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  termux-fish-style — one-command Termux makeover
#
#  Install:   curl -fsSL https://raw.githubusercontent.com/YOUR_USER/termux-fish-style/main/install.sh | bash
#  Options:   curl -fsSL <url> | bash -s -- --theme matrix
#
#  Everything this script writes is embedded below in plain text (see
#  write_payload). Your old files are backed up and `tfs uninstall` restores them.
# ─────────────────────────────────────────────────────────────────────────────
set -u

TFS_VERSION="1.0.0"
TFS="$HOME/.config/tfs"
BK="$TFS/backup"
LOGDIR="$HOME/.cache/termux-fish-style"
LOG="$LOGDIR/install.log"

THEME=""
ASSUME_YES=0
MINIMAL=0
NO_FONT=0
NO_UPGRADE=0
NO_SHELL=0
DO_UNINSTALL=0

CORE_PKGS="fish git curl unzip ncurses-utils procps nano"
EXTRA_PKGS="eza bat fzf"

FONT_URLS=(
  "https://raw.githubusercontent.com/ryanoasis/nerd-fonts/master/patched-fonts/JetBrainsMono/Ligatures/JetBrainsMonoNerdFontMono-Regular.ttf"
  "https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/JetBrainsMono/Ligatures/JetBrainsMonoNerdFontMono-Regular.ttf"
  "https://cdn.jsdelivr.net/gh/ryanoasis/nerd-fonts@master/patched-fonts/JetBrainsMono/Ligatures/JetBrainsMonoNerdFontMono-Regular.ttf"
)

# ═════════════════════════ ظاهر نصب‌کننده ═════════════════════════
setup_colors() {
  if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    R=$'\e[0m'; BD=$'\e[1m'; DM=$'\e[2m'
    BLU=$'\e[38;2;137;180;250m'; MAU=$'\e[38;2;203;166;247m'
    GRN=$'\e[38;2;166;227;161m'; RED=$'\e[38;2;243;139;168m'
    YEL=$'\e[38;2;249;226;175m'; MX=$'\e[38;2;0;255;65m'
    FG_DK=$'\e[38;2;17;17;27m'
    BG_MAU=$'\e[48;2;203;166;247m'; BG_BLU=$'\e[48;2;137;180;250m'
    BG_GRN=$'\e[48;2;166;227;161m'
    SPIN=1
  else
    R=""; BD=""; DM=""; BLU=""; MAU=""; GRN=""; RED=""; YEL=""; MX=""
    FG_DK=""; BG_MAU=""; BG_BLU=""; BG_GRN=""; SPIN=0
  fi
}

banner() {
  local -a cols=($'\e[38;2;137;180;250m' $'\e[38;2;152;176;249m' $'\e[38;2;170;171;248m' $'\e[38;2;187;168;248m' $'\e[38;2;203;166;247m')
  [ "$SPIN" = 1 ] || cols=("" "" "" "" "")
  local i=0 line
  echo
  while IFS= read -r line; do
    printf '  %s%s%s\n' "${cols[$i]}" "$line" "$R"
    i=$((i + 1))
  done <<'ART'
 _____ _____ ____  __  __ _   ___  __
|_   _| ____|  _ \|  \/  | | | \ \/ /
  | | |  _| | |_) | |\/| | | | |\  /
  | | | |___|  _ <| |  | | |_| |/  \
  |_| |_____|_| \_\_|  |_|\___//_/\_\
ART
  printf '  %s%sfish · powerline · matrix%s   %sv%s%s\n\n' "$BD" "$MAU" "$R" "$DM" "$TFS_VERSION" "$R"
}

ok()   { printf '  %s✔%s %s\n' "$GRN" "$R" "$*"; }
warn() { printf '  %s!%s %s\n' "$YEL" "$R" "$*"; }
fail() { printf '  %s✘%s %s\n' "$RED" "$R" "$*"; }
info() { printf '  %s•%s %s\n' "$BLU" "$R" "$*"; }
die()  { fail "$*"; printf '    %slog: %s%s\n' "$DM" "$LOG" "$R"; exit 1; }
step() { printf '\n  %s%s%s%s\n' "$BD" "$MAU" "$*" "$R"; }

# اجرای دستور با اسپینر؛ خروجی کامل در فایل لاگ
run() {
  local msg="$1"; shift
  local rc=0
  if [ "$SPIN" = 1 ]; then
    "$@" >>"$LOG" 2>&1 </dev/null &
    local pid=$! i=0
    local -a fr=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
    while kill -0 "$pid" 2>/dev/null; do
      printf '\r\033[2K  %s%s%s %s' "$BLU" "${fr[$((i % 10))]}" "$R" "$msg"
      i=$((i + 1)); sleep 0.1
    done
    wait "$pid" || rc=$?
    printf '\r\033[2K'
  else
    "$@" >>"$LOG" 2>&1 </dev/null || rc=$?
  fi
  if [ "$rc" -eq 0 ]; then ok "$msg"; else fail "$msg"; fi
  return "$rc"
}

retry_cmd() { # retry_cmd N cmd...
  local n="$1" i; shift
  for ((i = 1; i <= n; i++)); do
    "$@" && return 0
    sleep 2
  done
  return 1
}

# ═════════════════════════ پرسش‌ها ═════════════════════════
have_tty() { { : </dev/tty; } 2>/dev/null; }

ask_yn() { # ask_yn "prompt" y|n
  local ans=""
  if [ "$ASSUME_YES" = 1 ] || ! have_tty; then [ "$2" = y ]; return; fi
  read -r -p "$1" ans </dev/tty || ans=""
  ans="${ans:-$2}"
  case "$ans" in y | Y | yes | YES) return 0 ;; *) return 1 ;; esac
}

choose_theme() {
  [ -n "$THEME" ] && return 0
  local cur="modern" ans=""
  [ -f "$TFS/active" ] && cur="$(tr -d '[:space:]' <"$TFS/active" 2>/dev/null)"
  case "$cur" in modern | matrix) ;; *) cur="modern" ;; esac
  if [ "$ASSUME_YES" = 1 ] || ! have_tty; then THEME="$cur"; return 0; fi

  step "Choose your style"
  echo
  printf '   %s1)%s %smodern%s   Catppuccin · powerline · rounded\n' "$BD" "$R" "$BLU" "$R"
  printf '      %s termux %s ~/code %s main +1 %s\n' "${BG_MAU}${FG_DK}" "${BG_BLU}${FG_DK}" "${BG_GRN}${FG_DK}" "$R"
  echo
  printf '   %s2)%s %smatrix%s   hacker green · terminal lines · rain intro\n' "$BD" "$R" "$MX" "$R"
  printf '      %s┌──[%stermux@matrix%s]─[%s~/code%s]─[%smain +1%s]%s\n' "$DM$MX" "$R$MX" "$DM$MX" "$R$MX" "$DM$MX" "$R$YEL" "$DM$MX" "$R"
  echo
  local def=1; [ "$cur" = matrix ] && def=2
  read -r -p "  Enter 1 or 2 [$def]: " ans </dev/tty || ans=""
  ans="${ans:-$def}"
  case "$ans" in 2 | matrix | m) THEME="matrix" ;; *) THEME="modern" ;; esac
}

# ═════════════════════════ بررسی‌ها ═════════════════════════
is_termux() {
  [ -n "${TERMUX_VERSION:-}" ] || [ -d /data/data/com.termux/files/usr ]
}

pkg_installed() { dpkg -s "$1" >/dev/null 2>&1; }

check_env() {
  if ! is_termux && [ "${TFS_FORCE:-0}" != 1 ]; then
    die "This installer is made for Termux (Android). Set TFS_FORCE=1 to override."
  fi
  if [ "$(id -u)" = 0 ] && is_termux; then
    warn "running as root inside Termux — that's unusual, continuing anyway"
  fi
  mkdir -p "$LOGDIR" "$HOME/.cache" "$HOME/.termux" "$HOME/.config/fish"
  : >"$LOG"
  if command -v curl >/dev/null 2>&1; then
    if curl -fsS --max-time 8 -o /dev/null https://github.com 2>>"$LOG"; then
      ok "internet connection"
    else
      warn "can't reach github.com — font download may fail (check your network)"
    fi
  fi
}

# ═════════════════════════ بسته‌ها ═════════════════════════
update_system() {
  export DEBIAN_FRONTEND=noninteractive
  run "Updating package lists" retry_cmd 2 pkg update -y || warn "update failed — if downloads fail run: termux-change-repo"
  if [ "$NO_UPGRADE" != 1 ]; then
    run "Upgrading installed packages" retry_cmd 2 apt-get -y \
      -o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef upgrade \
      || warn "upgrade had problems (continuing)"
  fi
}

install_pkgs() {
  export DEBIAN_FRONTEND=noninteractive
  local p; local -a missing=()
  for p in $CORE_PKGS; do pkg_installed "$p" || missing+=("$p"); done
  if [ "${#missing[@]}" -gt 0 ]; then
    run "Installing ${missing[*]}" retry_cmd 2 pkg install -y "${missing[@]}" \
      || die "could not install required packages"
  else
    ok "required packages already installed"
  fi
  [ "$MINIMAL" = 1 ] && return 0
  for p in $EXTRA_PKGS; do
    if pkg_installed "$p"; then
      ok "$p already installed"
    else
      run "Installing $p" retry_cmd 2 pkg install -y "$p" || warn "$p skipped (optional)"
    fi
  done
}

# ═════════════════════════ بکاپ و فایل‌ها ═════════════════════════
backup_once() { # backup_once <path> <name>
  local path="$1" name="$2"
  mkdir -p "$BK"
  [ -e "$BK/$name" ] || [ -e "$BK/$name.none" ] && return 0
  if [ -e "$path" ]; then cp -p "$path" "$BK/$name"; else : >"$BK/$name.none"; fi
}

fetch_font() {
  local tmp="$HOME/.cache/tfs-font.ttf" u
  if [ -n "${TFS_FONT_URL:-}" ]; then FONT_URLS=("$TFS_FONT_URL" "${FONT_URLS[@]}"); fi
  for u in "${FONT_URLS[@]}"; do
    rm -f "$tmp"
    if curl -fsSL --retry 2 --connect-timeout 10 -o "$tmp" "$u" && [ "$(wc -c <"$tmp")" -gt 1000000 ]; then
      mv -f "$tmp" "$HOME/.termux/font.ttf"
      return 0
    fi
  done
  rm -f "$tmp"
  return 1
}

install_font() {
  [ "$NO_FONT" = 1 ] && { info "font skipped (--no-font)"; return 0; }
  if [ -f "$TFS/.font_ok" ] && [ -s "$HOME/.termux/font.ttf" ]; then
    ok "Nerd Font already installed"; return 0
  fi
  backup_once "$HOME/.termux/font.ttf" font.ttf
  if run "Downloading Nerd Font (JetBrains Mono, 2.5 MB)" fetch_font; then
    touch "$TFS/.font_ok"
  else
    warn "font download failed — icons will show as ?"
    warn "run again later, or use plain icons: tfs icons plain"
  fi
}

apply_properties() {
  [ "$MINIMAL" = 1 ] && return 0
  local f="$HOME/.termux/termux.properties" cursor="bar"
  [ "$THEME" = matrix ] && cursor="block"
  backup_once "$f" termux.properties
  touch "$f"
  sed -i '/^# >>> termux-fish-style >>>/,/^# <<< termux-fish-style <<</d' "$f"
  sed -i -E '/^(terminal-cursor-style|terminal-cursor-blink-rate|bell-character|terminal-transcript-rows|extra-keys)[[:space:]]*=/d' "$f"
  cat >>"$f" <<EOF
# >>> termux-fish-style >>>
terminal-cursor-style = $cursor
terminal-cursor-blink-rate = 600
bell-character = ignore
terminal-transcript-rows = 10000
extra-keys = [['ESC','|','/','-','HOME','UP','END','PGUP'],['TAB','CTRL','ALT','~','LEFT','DOWN','RIGHT','PGDN']]
# <<< termux-fish-style <<<
EOF
  ok "Termux keys & cursor configured"
}

set_default_shell() {
  [ "$NO_SHELL" = 1 ] && return 0
  mkdir -p "$BK"
  local cur
  cur="$(readlink "$HOME/.termux/shell" 2>/dev/null || true)"
  [ -f "$BK/shell.prev" ] || printf '%s\n' "$(basename "${cur:-bash}")" >"$BK/shell.prev"
  case "$cur" in
    */fish) ok "fish is already your default shell"; return 0 ;;
  esac
  if command -v chsh >/dev/null 2>&1; then
    run "Setting fish as default shell" chsh -s fish || warn "chsh failed — run manually: chsh -s fish"
  else
    warn "chsh not found — start fish manually with: fish"
  fi
}

install_files() {
  mkdir -p "$TFS/themes" "$BK" "$HOME/.config/fish"
  backup_once "$HOME/.config/fish/config.fish" config.fish
  backup_once "$HOME/.termux/colors.properties" colors.properties
  backup_once "$HOME/.hushlogin" hushlogin
  write_payload
  printf '%s\n' "$THEME" >"$TFS/active"
  cp -f "$TFS/themes/$THEME.colors" "$HOME/.termux/colors.properties"
  touch "$HOME/.hushlogin"
  {
    echo '#!/usr/bin/env bash'
    declare -f tfs_uninstall
    echo 'tfs_uninstall "$@"'
  } >"$TFS/uninstall.sh"
  chmod +x "$TFS/uninstall.sh"
}

validate() {
  command -v fish >/dev/null 2>&1 || { warn "fish not found — skipping validation"; return 0; }
  local f bad=0
  for f in "$TFS/core.fish" "$TFS/themes/modern.fish" "$TFS/themes/matrix.fish" "$HOME/.config/fish/config.fish"; do
    fish -n "$f" >>"$LOG" 2>&1 || { fail "syntax error in $f"; bad=1; }
  done
  [ "$bad" = 1 ] && die "validation failed — restoring is possible via: bash $TFS/uninstall.sh"
  if TERM=xterm-256color timeout 20 fish -i -c 'fish_prompt >/dev/null; exit' >>"$LOG" 2>&1 </dev/null; then
    ok "config validated"
  else
    warn "smoke test reported a problem (see log) — it may still work"
  fi
}

# ═════════════════════════ حذف نصب ═════════════════════════
# توجه: این تابع به‌صورت مستقل در uninstall.sh ذخیره می‌شود؛ فقط از دستورات پایه استفاده کن.
tfs_uninstall() {
  local H="$HOME/.config/tfs" B="$HOME/.config/tfs/backup"
  [ -d "$B" ] || { echo "nothing to uninstall (no backup at $B)"; return 1; }
  restore() { # restore <name> <target>
    if [ -e "$B/$1" ]; then cp -p "$B/$1" "$2"
    elif [ -e "$B/$1.none" ]; then rm -f "$2"; fi
  }
  restore config.fish "$HOME/.config/fish/config.fish"
  restore colors.properties "$HOME/.termux/colors.properties"
  restore font.ttf "$HOME/.termux/font.ttf"
  restore termux.properties "$HOME/.termux/termux.properties"
  restore hushlogin "$HOME/.hushlogin"
  if [ -f "$B/shell.prev" ] && command -v chsh >/dev/null 2>&1; then
    chsh -s "$(cat "$B/shell.prev")" >/dev/null 2>&1 || true
  fi
  rm -rf "$H"
  command -v termux-reload-settings >/dev/null 2>&1 && termux-reload-settings
  echo "✔ termux-fish-style removed — your old setup is restored."
  echo "  Close and reopen Termux."
}

# ═════════════════════════ محتوای نصب (متن ساده) ═════════════════════════
write_payload() {
cat > "$HOME/.config/fish/config.fish" <<'TFS_EOF_LOADER'
# termux-fish-style loader — اینجا چیزی ننویس؛ تنظیمات شخصی → ~/.config/tfs/user.fish
set -q TFS_HOME; or set -g TFS_HOME $HOME/.config/tfs
test -f $TFS_HOME/core.fish; and source $TFS_HOME/core.fish
TFS_EOF_LOADER

cat > "$TFS/core.fish" <<'TFS_EOF_CORE'
# ╭──────────────────────────────────────────────╮
# │  termux-fish-style · core                    │
# │  این فایل توسط نصب‌کننده مدیریت می‌شود       │
# │  تنظیمات شخصی خودت → ~/.config/tfs/user.fish │
# ╰──────────────────────────────────────────────╯
status is-interactive; or return

set -g TFS_HOME $HOME/.config/tfs
set -g TFS_VERSION 1.0.0

# ═════════ پیش‌فرض‌ها ═════════
set -g tfs_theme modern          # modern | matrix
set -g prompt_icons nerd         # nerd | plain
set -g prompt_transient 1        # جمع‌کردن پرامپت قدیمی بعد از Enter
set -g prompt_show_clock 1
set -g prompt_min_duration 2000  # میلی‌ثانیه
set -g tfs_intro auto            # auto | always | never  (انیمیشن تم ماتریکس)

# تنظیمات ذخیره‌شده با دستور tfs
test -f $TFS_HOME/settings.fish; and source $TFS_HOME/settings.fish
test -f $TFS_HOME/active; and set -g tfs_theme (string trim < $TFS_HOME/active)

# ═════════ محیط ═════════
set -gx LANG en_US.UTF-8
set -g fish_term24bit 1
set -gx EDITOR nano
fish_add_path -g $HOME/.local/bin

# مقادیری که فقط یک بار محاسبه می‌شن (سرعت پرامپت در ترموکس)
set -g __user_name (whoami)
string match -qr '^u\d+_a\d+$' -- $__user_name; and set -g __user_name termux
set -g __is_root 0
test (id -u) = 0; and set -g __is_root 1

# ═════════ تم ═════════
function __tfs_load_theme
    set -l f $TFS_HOME/themes/$tfs_theme.fish
    test -f $f; or set f $TFS_HOME/themes/modern.fish
    source $f
end
__tfs_load_theme

# ═════════ آیکون‌ها ═════════
function __setup_icons
    if test "$prompt_icons" = plain
        for v in sep cap user home dir lock git time err jobs venv root ssh cal term up mem disk dur
            set -g __i_$v ''
        end
    else
        set -g __i_sep \ue0b0
        set -g __i_cap \ue0b6
        set -g __i_user \uf007
        set -g __i_home \uf015
        set -g __i_dir \uf07c
        set -g __i_lock \uf023
        set -g __i_git \ue0a0
        set -g __i_time \uf017
        set -g __i_err \uf00d
        set -g __i_jobs \uf013
        set -g __i_venv \ue73c
        set -g __i_root \uf0e7
        set -g __i_ssh \uf0ac
        set -g __i_cal \uf073
        set -g __i_term \uf120
        set -g __i_up \uf1da
        set -g __i_mem \uf2db
        set -g __i_disk \uf0a0
        set -g __i_dur \uf252
    end
end
__setup_icons

# ═════════ رویدادها (حل مشکل Enter خالی / کد خطای تکراری) ═════════
function __on_postexec --on-event fish_postexec
    set -l s $status
    set -g __last_status $s
    set -g __last_duration $CMD_DURATION
    set -g __ran 1
    set -e __transient
    set -l first (string split ' ' -- $argv[1])[1]
    if contains -- $first vim nvim vi nano less man htop top btop ssh tmux mosh python python3 node fish
        set -g __last_duration 0
    end
end

function __on_preexec --on-event fish_preexec
    set -e __transient
end

function __on_prompt --on-event fish_prompt
    set -e __transient
    if set -q __ran
        set -e __ran
    else
        set -g __last_status 0
        set -g __last_duration 0
    end
    if set -q __skip_nl
        set -g __print_nl 0
        set -e __skip_nl
    else
        set -g __print_nl 1
    end
end

# ═════════ Enter هوشمند + پرامپت جمع‌شونده ═════════
function __enter_key
    if commandline --paging-mode
        commandline -f execute
        return
    end
    if test "$prompt_transient" = 1
        set -l cmd (commandline | string collect)
        if test -z "$cmd"; or commandline --is-valid
            set -g __transient 1
            commandline -f repaint
        end
    end
    commandline -f execute
end
bind \r __enter_key
bind \n __enter_key

function __clear_screen
    set -g __print_nl 0
    commandline -f clear-screen
end
bind \cl __clear_screen

function clear --wraps clear
    command clear $argv
    set -g __skip_nl 1
end

# ═════════ سگمنت‌ها: Powerline و Lines ═════════
function __pl_seg --argument-names bg fg text
    if set -q __pl_prev
        set_color -b $bg
        set_color $__pl_prev
        echo -n $__i_sep
    else if test -n "$__i_cap"
        set_color normal
        set_color $bg
        echo -n $__i_cap
    end
    set_color -b $bg
    set_color --bold $fg
    echo -n " $text "
    set -g __pl_prev $bg
end

function __pl_end
    set_color normal
    set_color $__pl_prev
    echo -n $__i_sep
    set_color normal
    set -e __pl_prev
end

function __ln_seg --argument-names color text
    set_color $t_frame
    set -q __pl_prev; and echo -n "─"
    echo -n "["
    set_color --bold $color
    echo -n $text
    set_color normal
    set_color $t_frame
    echo -n "]"
    set -g __pl_prev $color
end

function __seg --argument-names color text
    if test "$t_style" = powerline
        __pl_seg $color $t_fg_seg $text
    else
        __ln_seg $color $text
    end
end

function __seg_end
    if test "$t_style" = powerline
        __pl_end
    else
        set_color normal
        set -e __pl_prev
    end
end

function __fmt_duration --argument-names ms
    set -l s (math -s0 "floor($ms / 1000)")
    if test $s -ge 3600
        printf '%dh %dm %ds' (math -s0 "floor($s / 3600)") (math -s0 "floor(($s % 3600) / 60)") (math -s0 "$s % 60")
    else if test $s -ge 60
        printf '%dm %ds' (math -s0 "floor($s / 60)") (math -s0 "$s % 60")
    else
        printf '%.1fs' (math "$ms / 1000")
    end
end

function __status_label --argument-names code compact
    if test "$compact" = 1
        echo $code
        return
    end
    switch $code
        case 126; echo "$code NOEXEC"
        case 127; echo "$code NOTFOUND"
        case 130; echo "$code SIGINT"
        case 137; echo "$code KILL"
        case 139; echo "$code SEGV"
        case 143; echo "$code TERM"
        case '*'; echo $code
    end
end

function __user_segment
    set -l color $c_user
    set -l icon $__i_user
    set -l name $__user_name
    if test "$t_style" = lines
        set icon ''
        test -n "$t_host"; and set name "$name@$t_host"
    end
    if test "$__is_root" = 1
        set color $c_root
        set icon $__i_root
    end
    if set -q SSH_CONNECTION
        set color $c_ssh
        set icon $__i_ssh
        set name "$__user_name@$hostname"
    end
    __seg $color (string trim -- "$icon $name")
end

function __path_segment --argument-names compact
    set -l dl 2
    test "$compact" = 1; and set dl 1
    set -l p (prompt_pwd --dir-length $dl --full-length-dirs 1)
    set -l icon $__i_dir
    test "$PWD" = "$HOME"; and set icon $__i_home
    test "$t_style" = lines; and set icon ''
    set -l lock ''
    test -w "$PWD"; or set lock " $__i_lock"
    __seg $c_path (string trim -- "$icon $p$lock")
end

function __git_segment
    set -l out (command git --no-optional-locks status --porcelain=v2 --branch 2>/dev/null)
    test (count $out) -gt 0; or return

    set -l branch ''
    set -l oid ''
    set -l ahead 0
    set -l behind 0
    set -l staged 0
    set -l unstaged 0
    set -l untracked 0
    set -l conflict 0

    for line in $out
        set -l t (string sub -l 1 -- $line)
        if test "$t" = '#'
            set -l m (string match -r '^# branch\.(oid|head|ab) (.*)$' -- $line)
            if set -q m[2]
                switch $m[2]
                    case oid
                        set oid (string sub -l 7 -- $m[3])
                    case head
                        set branch $m[3]
                    case ab
                        set -l ab (string match -r '\+(\d+) -(\d+)' -- $m[3])
                        if set -q ab[3]
                            set ahead $ab[2]
                            set behind $ab[3]
                        end
                end
            end
        else if test "$t" = 1 -o "$t" = 2
            set -l xy (string sub -s 3 -l 2 -- $line)
            test (string sub -l 1 -- $xy) != '.'; and set staged (math $staged + 1)
            test (string sub -s 2 -l 1 -- $xy) != '.'; and set unstaged (math $unstaged + 1)
        else if test "$t" = u
            set conflict (math $conflict + 1)
        else if test "$t" = '?'
            set untracked (math $untracked + 1)
        end
    end

    test "$branch" = '(detached)'; and set branch "@$oid"
    set branch (string shorten -m 22 -- $branch)

    set -l txt "$__i_git $branch"
    test $ahead -gt 0; and set txt "$txt ⇡$ahead"
    test $behind -gt 0; and set txt "$txt ⇣$behind"
    test $staged -gt 0; and set txt "$txt +$staged"
    test $unstaged -gt 0; and set txt "$txt !$unstaged"
    test $untracked -gt 0; and set txt "$txt ?$untracked"
    test $conflict -gt 0; and set txt "$txt ✖$conflict"

    set -l color $c_git_ok
    if test $conflict -gt 0
        set color $c_git_bad
    else if test (math $staged + $unstaged + $untracked) -gt 0
        set color $c_git_dirty
    end
    __seg $color (string trim -- $txt)
end

# ═════════ پرامپت ═════════
function fish_prompt
    if set -q __transient
        __transient_prompt
        return
    end

    set -l compact 0
    test "$COLUMNS" -lt 56 2>/dev/null; and set compact 1
    set -e __pl_prev

    test "$__print_nl" != 0; and echo
    set_color $t_frame
    echo -n $t_top

    test $compact -eq 0; and __user_segment
    __path_segment $compact
    __git_segment

    if test $compact -eq 0; and set -q VIRTUAL_ENV
        set -l v (string split -r -m1 / -- $VIRTUAL_ENV)[-1]
        __seg $c_venv (string trim -- "$__i_venv $v")
    end

    set -l nj (count (jobs -p 2>/dev/null))
    if test $nj -gt 0
        __seg $c_jobs (string trim -- "$__i_jobs $nj")
    end

    if test "$__last_duration" -ge "$prompt_min_duration" 2>/dev/null
        __seg $c_dur (string trim -- "$__i_dur "(__fmt_duration $__last_duration))
    end

    if test "$__last_status" -ne 0 2>/dev/null
        set -l color $c_err
        test "$__last_status" = 130; and set color $c_sigint
        __seg $color (string trim -- "$__i_err "(__status_label $__last_status $compact))
    end

    set -q __pl_prev; and __seg_end
    echo

    set_color $t_frame
    echo -n $t_bot
    __prompt_char
end

function __prompt_char
    if test "$__last_status" -ne 0 2>/dev/null
        set_color $t_err
    else
        set_color $t_ok
    end
    if test "$__is_root" = 1
        echo -n "# "
    else
        echo -n "$t_char "
    end
    set_color normal
end

function __transient_prompt
    test "$__print_nl" != 0; and echo
    __prompt_char
end

function fish_right_prompt
    set -q __transient; and return
    test "$prompt_show_clock" = 1; or return
    set_color $t_dim
    echo -n (string trim -- "$__i_time "(date +%H:%M))
    set_color normal
end

# ═════════ بنرها ═════════
function __collect_info
    set -g __info_up (uptime -p 2>/dev/null | string replace -r '^up ' '')
    set -g __info_mem ''
    set -l m (free -m 2>/dev/null | string match -r '^Mem:\s+(\d+)\s+(\d+)')
    set -q m[3]; and set -g __info_mem "$m[3] / $m[2] MB"
    set -g __info_disk ''
    set -l d (df -h $HOME 2>/dev/null | tail -n1 | string match -ra '\S+')
    set -q d[5]; and set -g __info_disk "$d[3] / $d[2] ($d[5])"
end

function __gradient --argument-names text from to
    set -l chars (string split '' -- $text)
    set -l n (count $chars)
    set -l r1 (math "0x"(string sub -s 1 -l 2 -- $from))
    set -l g1 (math "0x"(string sub -s 3 -l 2 -- $from))
    set -l b1 (math "0x"(string sub -s 5 -l 2 -- $from))
    set -l r2 (math "0x"(string sub -s 1 -l 2 -- $to))
    set -l g2 (math "0x"(string sub -s 3 -l 2 -- $to))
    set -l b2 (math "0x"(string sub -s 5 -l 2 -- $to))
    set -l i 0
    for ch in $chars
        set -l t 0
        test $n -gt 1; and set t (math "$i / ($n - 1)")
        set -l r (math -s0 "round($r1 + ($r2 - $r1) * $t)")
        set -l g (math -s0 "round($g1 + ($g2 - $g1) * $t)")
        set -l b (math -s0 "round($b1 + ($b2 - $b1) * $t)")
        set_color (printf '%02x%02x%02x' $r $g $b)
        printf '%s' $ch
        set i (math $i + 1)
    end
    set_color normal
end

function __greet_row --argument-names color icon text
    set -l w 33
    test -z "$icon"; and set icon '•'
    set_color $t_frame
    echo -n "  │ "
    set_color $color
    echo -n "$icon "
    set_color $t_text
    printf '%s' (string pad -r -w $w -- (string shorten -m $w -- $text))
    set_color $t_frame
    echo " │"
    set_color normal
end

function __greeting_modern
    set -l w 33
    set -l line (string repeat -n (math $w + 4) ─)
    set -l title "Welcome back, $__user_name"
    set -l gap (math "max(0, $w - "(string length -- $title)")")
    set -l ico $__i_term
    test -z "$ico"; and set ico '•'

    set_color $t_frame
    echo "  ╭$line╮"
    echo -n "  │ "
    set_color $t_g1
    echo -n "$ico "
    __gradient $title $t_g1 $t_g2
    echo -n (string repeat -n $gap ' ')
    set_color $t_frame
    echo " │"

    __greet_row $t_row1 $__i_cal (date "+%a %d %b %Y · %H:%M")
    __greet_row $t_row2 $__i_term "fish $version · "(uname -m)
    test -n "$__info_up"; and __greet_row $t_row3 $__i_up "$__info_up"
    test -n "$__info_mem"; and __greet_row $t_row4 $__i_mem "$__info_mem"
    test -n "$__info_disk"; and __greet_row $t_row5 $__i_disk "$__info_disk"

    set_color $t_frame
    echo "  ╰$line╯"
    set_color normal
end

function __matrix_rain --argument-names rows
    set -l cols (math "min(60, max(10, $COLUMNS - 2))")
    set -l pal 0a3d14 006b0d 00a82d 00ff41 b6ffc8
    set -l glyphs 0 1 0 1 2 3 4 5 6 7 8 9 A B C D E F '<' '>' '/' '|' '+' '=' '*' '#' '%' '&' '@' ':' ';' '$'
    for r in (seq $rows)
        set -l base (math -s0 "ceil($r * 5 / $rows)")
        echo -n " "
        for c in (seq $cols)
            if test (random 1 100) -le 40
                echo -n " "
                continue
            end
            set -l lv (math "$base + "(random 0 1)" - "(random 0 1))
            test $lv -lt 1; and set lv 1
            test $lv -gt 5; and set lv 5
            set_color $pal[$lv]
            printf '%s' (random choice $glyphs)
        end
        set_color normal
        echo
        sleep 0.04
    end
end

function __typewriter --argument-names text color delay
    set_color $color
    for ch in (string split '' -- $text)
        printf '%s' $ch
        sleep $delay
    end
    set_color normal
    echo
end

function __mx_row --argument-names label value
    set_color $t_frame
    echo -n "  ["
    set_color --bold $t_ok
    printf '%s' (string pad -r -w 4 -- $label)
    set_color normal
    set_color $t_frame
    echo -n "] "
    set_color $t_text
    echo $value
    set_color normal
end

function __greeting_matrix
    set -l animate 0
    switch $tfs_intro
        case always
            set animate 1
        case auto
            set -l stamp $TFS_HOME/.last_intro
            if not test -f $stamp
                set animate 1
            else if test (math (date +%s) - (stat -c %Y $stamp)) -gt 21600
                set animate 1
            end
    end
    if test $animate -eq 1
        touch $TFS_HOME/.last_intro
        __matrix_rain 7
        __typewriter "Wake up, $__user_name..." $t_ok 0.035
        sleep 0.25
        __typewriter "The Matrix has you." $t_ok 0.035
        sleep 0.2
        echo
    end
    __mx_row SYS "$__user_name@"(uname -m)" · fish $version"
    __mx_row TIME (date "+%a %d %b %Y · %H:%M")
    test -n "$__info_up"; and __mx_row UP "$__info_up"
    test -n "$__info_mem"; and __mx_row MEM "$__info_mem"
    test -n "$__info_disk"; and __mx_row DISK "$__info_disk"
    set_color $t_frame
    echo -n "  ["
    set_color --bold $t_ok
    printf '%s' (string pad -r -w 4 -- AUTH)
    set_color normal
    set_color $t_frame
    echo -n "] "
    set_color --bold $t_ok
    echo "ACCESS GRANTED"
    set_color normal
end

function fish_greeting
    __collect_info
    if test "$t_greeting" = matrix
        __greeting_matrix
    else
        __greeting_modern
    end
    set -e __info_up __info_mem __info_disk
end

# ═════════ دستور مدیریت: tfs ═════════
function __tfs_save --argument-names key value
    mkdir -p $TFS_HOME
    set -l f $TFS_HOME/settings.fish
    set -l keep
    test -f $f; and set keep (string match -v -r "^set -g $key " < $f)
    printf '%s\n' $keep "set -g $key $value" > $f
end

function __tfs_set_cursor --argument-names style
    set -l p $HOME/.termux/termux.properties
    test -f $p; and sed -i "s/^terminal-cursor-style *=.*/terminal-cursor-style = $style/" $p
end

function __tfs_cmd_theme --argument-names name
    if not contains -- "$name" modern matrix
        echo "usage: tfs theme modern|matrix"
        return 1
    end
    test -f $TFS_HOME/themes/$name.fish; or begin
        echo "theme files missing — re-run the installer"
        return 1
    end
    echo $name > $TFS_HOME/active
    set -g tfs_theme $name
    __tfs_load_theme
    test -f $TFS_HOME/themes/$name.colors; and cp $TFS_HOME/themes/$name.colors $HOME/.termux/colors.properties
    if test "$name" = matrix
        __tfs_set_cursor block
    else
        __tfs_set_cursor bar
    end
    type -q termux-reload-settings; and termux-reload-settings
    set_color $t_ok
    echo "✔ theme: $name"
    set_color normal
end

function __tfs_doctor
    set_color --bold $t_ok
    echo "termux-fish-style v$TFS_VERSION"
    set_color normal
    echo "theme: $tfs_theme · icons: $prompt_icons · intro: $tfs_intro"
    echo "fish $version · $COLUMNS cols · COLORTERM=$COLORTERM"
    if test -f $HOME/.termux/font.ttf
        echo "font.ttf: "(stat -c %s $HOME/.termux/font.ttf)" bytes"
    else
        echo "font.ttf: MISSING (icons will show as ?)"
    end
    echo -n "icons: "
    echo \ue0b0 \uf07c \ue0a0 \uf007
    echo "(if you see boxes or ?, fully close Termux and reopen it)"
end

function __tfs_help
    echo "tfs — termux-fish-style v$TFS_VERSION"
    echo
    echo "  tfs theme modern|matrix   switch look"
    echo "  tfs icons nerd|plain      icon set (plain = no Nerd Font needed)"
    echo "  tfs intro auto|always|never   matrix intro animation"
    echo "  tfs rain                  matrix rain"
    echo "  tfs doctor                diagnose icons/font"
    echo "  tfs uninstall             restore your old setup"
end

function tfs --description 'termux-fish-style manager'
    switch "$argv[1]"
        case theme
            __tfs_cmd_theme $argv[2]
        case icons
            if contains -- "$argv[2]" nerd plain
                set -g prompt_icons $argv[2]
                __setup_icons
                __tfs_save prompt_icons $argv[2]
            else
                echo "usage: tfs icons nerd|plain"
            end
        case intro
            if contains -- "$argv[2]" auto always never
                set -g tfs_intro $argv[2]
                __tfs_save tfs_intro $argv[2]
            else
                echo "usage: tfs intro auto|always|never"
            end
        case rain
            __matrix_rain 14
        case doctor
            __tfs_doctor
        case uninstall
            bash $TFS_HOME/uninstall.sh
        case version
            echo $TFS_VERSION
        case '*'
            __tfs_help
    end
end

# ═════════ اختصارها ═════════
if type -q eza
    abbr -a ls 'eza --icons --group-directories-first'
    abbr -a ll 'eza -lah --icons --group-directories-first --git'
    abbr -a lt 'eza --tree --level=2 --icons'
else
    abbr -a ll 'ls -lah --color=auto'
    abbr -a la 'ls -A --color=auto'
end
type -q bat; and abbr -a b 'bat --paging=never'
abbr -a pu 'pkg update && pkg upgrade -y'
abbr -a pi 'pkg install'
abbr -a gs 'git status -sb'
abbr -a ga 'git add .'
abbr -a gc 'git commit -m'
abbr -a gp 'git push'
abbr -a gl 'git log --oneline --graph --decorate -15'
abbr -a py python
abbr -a cls clear

function __multicd
    echo cd (string repeat -n (math (string length -- $argv[1]) - 1) ../)
end
abbr -a dotdot --regex '^\.\.+$' --function __multicd

function __last_cmd
    echo $history[1]
end
abbr -a '!!' --position anywhere --function __last_cmd

# ═════════ ابزارها ═════════
function mkcd --description 'mkdir + cd'
    mkdir -p $argv[1]; and cd $argv[1]
end

function reload --description 'reload config'
    source ~/.config/fish/config.fish
end

function myip --description 'public IP'
    curl -s ifconfig.me; echo
end

function weather --description 'weather [city]'
    curl -s "wttr.in/$argv[1]?m&format=3"
end

function extract --description 'extract any archive'
    if test (count $argv) -eq 0
        echo "usage: extract <file>"
        return 1
    end
    switch $argv[1]
        case '*.tar.gz' '*.tgz'; tar xzf $argv[1]
        case '*.tar.bz2'; tar xjf $argv[1]
        case '*.tar.xz'; tar xJf $argv[1]
        case '*.tar'; tar xf $argv[1]
        case '*.zip'; unzip $argv[1]
        case '*.7z'; 7z x $argv[1]
        case '*.gz'; gunzip $argv[1]
        case '*'; echo "unsupported format"
    end
end

# fzf: Ctrl+R تاریخچه، Ctrl+T فایل، Alt+C پوشه
if type -q fzf
    fzf --fish 2>/dev/null | source
end

# تنظیمات شخصی (هیچ‌وقت توسط نصب‌کننده بازنویسی نمی‌شود)
test -f $TFS_HOME/user.fish; and source $TFS_HOME/user.fish
TFS_EOF_CORE

cat > "$TFS/themes/modern.fish" <<'TFS_EOF_MODERN'
# theme: modern — Catppuccin Mocha · powerline · rounded
set -g t_name modern
set -g t_style powerline
set -g t_greeting modern
set -g t_top '╭─'
set -g t_bot '╰─'
set -g t_char '❯'
set -g t_host ''

set -g t_fg_seg 11111b
set -g t_frame 89b4fa
set -g t_text cdd6f4
set -g t_dim 6c7086
set -g t_ok a6e3a1
set -g t_err f38ba8

set -g c_user cba6f7
set -g c_path 89b4fa
set -g c_git_ok a6e3a1
set -g c_git_dirty f9e2af
set -g c_git_bad f38ba8
set -g c_venv f5c2e7
set -g c_jobs 94e2d5
set -g c_dur fab387
set -g c_err f38ba8
set -g c_sigint fab387
set -g c_ssh f9e2af
set -g c_root f38ba8

set -g t_g1 89dceb
set -g t_g2 f5c2e7
set -g t_row1 a6e3a1
set -g t_row2 f9e2af
set -g t_row3 89dceb
set -g t_row4 f5c2e7
set -g t_row5 fab387

set -g fish_color_normal cdd6f4
set -g fish_color_command 89b4fa
set -g fish_color_param f5c2e7
set -g fish_color_keyword cba6f7
set -g fish_color_quote a6e3a1
set -g fish_color_redirection f5e0dc
set -g fish_color_end fab387
set -g fish_color_error f38ba8
set -g fish_color_comment 6c7086
set -g fish_color_operator 94e2d5
set -g fish_color_escape f2cdcd
set -g fish_color_option 94e2d5
set -g fish_color_cancel 6c7086
set -g fish_color_autosuggestion 585b70
set -g fish_color_valid_path --underline
set -g fish_color_selection --background=313244
set -g fish_color_search_match --background=313244
set -g fish_color_history_current --bold
set -g fish_color_cwd f9e2af
set -g fish_color_cwd_root f38ba8
set -g fish_color_user a6e3a1
set -g fish_color_host 89dceb
set -g fish_color_host_remote f9e2af
set -g fish_pager_color_prefix cba6f7 --bold
set -g fish_pager_color_completion cdd6f4
set -g fish_pager_color_description 6c7086
set -g fish_pager_color_progress 89b4fa
set -g fish_pager_color_selected_background --background=313244

set -gx FZF_DEFAULT_OPTS "--height=40% --layout=reverse --border=rounded --prompt='❯ ' --pointer='▶' --marker='✓' --color=bg+:#313244,fg:#cdd6f4,hl:#f38ba8,fg+:#cdd6f4,hl+:#f38ba8,info:#cba6f7,prompt:#cba6f7,pointer:#f5e0dc,marker:#a6e3a1,spinner:#f5e0dc,header:#f38ba8,border:#6c7086"
set -e EZA_COLORS
TFS_EOF_MODERN

cat > "$TFS/themes/matrix.fish" <<'TFS_EOF_MATRIX'
# theme: matrix — hacker green · terminal lines · rain intro
set -g t_name matrix
set -g t_style lines
set -g t_greeting matrix
set -g t_top '┌──'
set -g t_bot '└─'
set -g t_char '❯'
set -g t_host matrix

set -g t_fg_seg 000000
set -g t_frame 00a82d
set -g t_text b6ffc8
set -g t_dim 1f7a35
set -g t_ok 00ff41
set -g t_err ff0033

set -g c_user 00ff41
set -g c_path b6ffc8
set -g c_git_ok 00ff41
set -g c_git_dirty ffb000
set -g c_git_bad ff0033
set -g c_venv 00e5a0
set -g c_jobs 00ffd5
set -g c_dur d7ff3a
set -g c_err ff0033
set -g c_sigint ffb000
set -g c_ssh ffb000
set -g c_root ff0033

set -g t_g1 00ff41
set -g t_g2 b6ffc8
set -g t_row1 00ff41
set -g t_row2 00ff41
set -g t_row3 00ff41
set -g t_row4 00ff41
set -g t_row5 00ff41

set -g fish_color_normal b6ffc8
set -g fish_color_command 00ff41 --bold
set -g fish_color_param 7dffa1
set -g fish_color_keyword d7ff3a
set -g fish_color_quote 00e5a0
set -g fish_color_redirection ffb000
set -g fish_color_end ffb000
set -g fish_color_error ff0033
set -g fish_color_comment 1d6b2e
set -g fish_color_operator 00ffd5
set -g fish_color_escape d7ff3a
set -g fish_color_option 00ffd5
set -g fish_color_cancel 1d6b2e
set -g fish_color_autosuggestion 1f5e2c
set -g fish_color_valid_path --underline
set -g fish_color_selection --background=0a3d14
set -g fish_color_search_match --background=0a3d14
set -g fish_color_history_current --bold
set -g fish_color_cwd 00ff41
set -g fish_color_cwd_root ff0033
set -g fish_color_user 00ff41
set -g fish_color_host 00a82d
set -g fish_color_host_remote ffb000
set -g fish_pager_color_prefix 00ff41 --bold
set -g fish_pager_color_completion b6ffc8
set -g fish_pager_color_description 1f7a35
set -g fish_pager_color_progress 00ff41
set -g fish_pager_color_selected_background --background=0a3d14

set -gx FZF_DEFAULT_OPTS "--height=40% --layout=reverse --border=sharp --prompt='❯ ' --pointer='▶' --marker='✓' --color=bg+:#0a3d14,fg:#00a82d,hl:#b6ffc8,fg+:#00ff41,hl+:#b6ffc8,info:#00a82d,prompt:#00ff41,pointer:#00ff41,marker:#ffb000,spinner:#00ff41,header:#00a82d,border:#006b0d"
set -gx EZA_COLORS "di=1;32:ln=1;36:ex=1;92:fi=32:da=2;32:sn=32:sb=32:uu=32:gu=32:un=33:gn=33"
TFS_EOF_MATRIX

cat > "$TFS/themes/modern.colors" <<'TFS_EOF_MODERN_COLORS'
# termux-fish-style · modern · Catppuccin Mocha
background=#1e1e2e
foreground=#cdd6f4
cursor=#f5e0dc

color0=#45475a
color1=#f38ba8
color2=#a6e3a1
color3=#f9e2af
color4=#89b4fa
color5=#f5c2e7
color6=#94e2d5
color7=#bac2de

color8=#585b70
color9=#f38ba8
color10=#a6e3a1
color11=#f9e2af
color12=#89b4fa
color13=#f5c2e7
color14=#94e2d5
color15=#a6adc8
TFS_EOF_MODERN_COLORS

cat > "$TFS/themes/matrix.colors" <<'TFS_EOF_MATRIX_COLORS'
# termux-fish-style · matrix · hacker green
background=#0d0208
foreground=#00ff41
cursor=#00ff41

color0=#0d0208
color1=#ff0033
color2=#00ff41
color3=#d7ff3a
color4=#00b36b
color5=#00ffa3
color6=#00ffd5
color7=#b6ffc8

color8=#1d4d2a
color9=#ff5577
color10=#39ff14
color11=#ffe066
color12=#2bd68a
color13=#7dffcf
color14=#7dffe8
color15=#e6fff0
TFS_EOF_MATRIX_COLORS

if [ ! -f "$TFS/user.fish" ]; then
cat > "$TFS/user.fish" <<'TFS_EOF_USER'
# تنظیمات شخصی تو — این فایل هیچ‌وقت توسط نصب‌کننده بازنویسی نمی‌شود
# your own settings — never overwritten by the installer
#
# مثال‌ها / examples:
# set -g prompt_show_clock 0
# set -g prompt_min_duration 5000
# abbr -a gs 'git status'
# set -gx EDITOR vim
TFS_EOF_USER
fi
}

# ═════════════════════════ آرگومان‌ها ═════════════════════════
usage() {
  cat <<EOF
termux-fish-style v$TFS_VERSION

Usage: bash install.sh [options]

  -t, --theme <modern|matrix>   choose the look (default: ask)
  -y, --yes                     no questions, accept defaults
      --minimal                 skip extras (eza/bat/fzf) and Termux key tweaks
      --no-font                 don't download the Nerd Font
      --no-upgrade              skip 'pkg upgrade' (faster)
      --no-shell                don't change the default shell
      --uninstall               restore your old setup
  -h, --help                    this help

Piped:  curl -fsSL <url> | bash -s -- --theme matrix --yes
EOF
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      -t | --theme) THEME="${2:-}"; shift ;;
      --theme=*) THEME="${1#--theme=}" ;;
      -y | --yes) ASSUME_YES=1 ;;
      --minimal) MINIMAL=1 ;;
      --no-font) NO_FONT=1 ;;
      --no-upgrade) NO_UPGRADE=1 ;;
      --no-shell) NO_SHELL=1 ;;
      --uninstall) DO_UNINSTALL=1 ;;
      -h | --help) usage; exit 0 ;;
      *) echo "unknown option: $1"; usage; exit 1 ;;
    esac
    shift
  done
  case "$THEME" in "" | modern | matrix) ;; *) echo "theme must be modern or matrix"; exit 1 ;; esac
}

# ═════════════════════════ اجرا ═════════════════════════
main() {
  parse_args "$@"
  setup_colors
  banner

  if [ "$DO_UNINSTALL" = 1 ]; then
    tfs_uninstall
    exit $?
  fi

  check_env
  choose_theme

  if [ "${TFS_SKIP_PKG:-0}" != 1 ]; then
    step "System"
    update_system
    step "Packages"
    install_pkgs
  fi

  step "Setting up ($THEME)"
  install_files
  ok "config & theme files installed"
  install_font
  apply_properties
  set_default_shell
  validate
  command -v termux-reload-settings >/dev/null 2>&1 && termux-reload-settings

  local accent="$BLU"; [ "$THEME" = matrix ] && accent="$MX"
  printf '\n  %s%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n' "$BD" "$accent" "$R"
  printf '  %s✔ Done!%s  theme: %s%s%s\n' "$GRN$BD" "$R" "$accent$BD" "$THEME" "$R"
  printf '  %s%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n\n' "$BD" "$accent" "$R"
  info "switch look:   ${BD}tfs theme modern${R}  /  ${BD}tfs theme matrix${R}"
  info "icons are ?:   fully close Termux & reopen, then ${BD}tfs doctor${R}"
  info "no Nerd Font:  ${BD}tfs icons plain${R}"
  info "remove:        ${BD}tfs uninstall${R}"
  info "your settings: ${BD}~/.config/tfs/user.fish${R}"
  echo

  if command -v fish >/dev/null 2>&1 && have_tty; then
    if ask_yn "  Start fish now? [Y/n] " y; then
      exec fish </dev/tty
    fi
  fi
}

main "$@"
