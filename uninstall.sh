#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail

VERSION="1.1"
LOG_FILE="$HOME/pocketdev.log"
STATE_FILE="$HOME/.pocketdev_state"
PROJECTS_DIR="$HOME/projects"
UNINSTALL_LOG="$HOME/pocketdev-uninstall.log"
TERM_WIDTH=$(tput cols 2>/dev/null || echo 72)

R='\033[0m'; BOLD='\033[1m'; DIM='\033[2m'
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
CYAN='\033[0;36m'; WHITE='\033[1;37m'; MAGENTA='\033[0;35m'

ulog() { printf "[%s] %s\n" "$(date '+%H:%M:%S')" "$*" >> "$UNINSTALL_LOG"; }

hr() {
  local char="${1:--}" color="${2:-$CYAN}"
  printf "${color}${BOLD}"; printf '%*s\n' "$TERM_WIDTH" '' | tr ' ' "$char"; printf "${R}"
}
section() {
  echo ""; printf "${MAGENTA}${BOLD}## %s${R}\n" "$1"
  printf "${DIM}"; printf '%*s\n' $(( ${#1}+3 )) '' | tr ' ' '-'; printf "${R}"
}
step()  { printf "  ${CYAN}-->${R}  %-50s" "$1"; }
ok()    { printf " ${GREEN}${BOLD}[  OK  ]${R}\n"; }
skip()  { printf " ${YELLOW}${BOLD}[ SKIP ]${R}\n"; }
fail()  { printf " ${RED}${BOLD}[ FAIL ]${R}\n"; printf "        ${RED}%s${R}\n" "$1"; ulog "FAIL: $1"; }
info()  { printf "  ${CYAN}(i)${R}  %s\n" "$1"; }
confirm() {
  local a; printf "  ${YELLOW}?${R}  %s ${DIM}(y/N)${R}  " "$1"; read -r a; [[ "$a" =~ ^[Yy]$ ]]
}
press_enter() { printf "\n  ${DIM}[ Press Enter to continue ]${R}  "; read -r; }

banner() {
  clear; hr '='
  printf "${WHITE}${BOLD}  >>  PocketDevTermux Uninstaller v%s\n" "$VERSION"
  printf "      Removes only what pocketdev.sh installed\n${R}"
  hr '='; echo ""
}

get_state_entries() {
  local prefix="$1"
  [[ -f "$STATE_FILE" ]] && grep "^${prefix}:" "$STATE_FILE" 2>/dev/null | sed "s/^${prefix}://" || true
}


ESSENTIAL_PKGS="bash busybox coreutils dash termux-am termux-am-socket
                termux-exec termux-tools termux-auth login curl openssh
                git nano tar unzip grep sed gawk ca-certificates"

is_essential() {
  local pkg="$1"
  for e in $ESSENTIAL_PKGS; do [[ "$pkg" == "$e" ]] && return 0; done
  return 1
}

#remove pkg packages
remove_pkgs() {
  section "pkg packages"
  local pkgs; pkgs=$(get_state_entries "pkg")

  if [[ -z "$pkgs" ]]; then
    info "No pkg entries in state file -- using fallback list."
    
    pkgs="python python-pip nodejs nodejs-lts
          clang binutils make cmake gdb
          openjdk-17 gradle maven kotlin golang rust
          zsh tmux jq shellcheck ripgrep fd bat lsd
          fzf gh nnn micro helix neovim vim
          proot-distro tur-repo
          build-essential pkg-config patchelf libzmq
          aichat tgpt
          python-numpy python-scipy matplotlib python-pandas
          python-psutil python-ipykernel
          x11-repo termux-x11-nightly opencv-python
          libffi libbz2 zlib libjpeg-turbo"
  fi

  for pkg in $pkgs; do
    if is_essential "$pkg"; then
      step "$pkg (essential)"; skip; continue
    fi
    step "pkg uninstall $pkg"
    if ! dpkg -l "$pkg" &>/dev/null 2>&1; then
      skip
    elif pkg uninstall -y "$pkg" >> "$UNINSTALL_LOG" 2>&1; then
      ok; ulog "removed pkg: $pkg"
    else
      fail "could not remove $pkg"
    fi
  done
}

#remove pip packages
remove_pip_pkgs() {
  section "pip packages"
  if ! command -v pip &>/dev/null; then info "pip not found."; return; fi

  local pkgs; pkgs=$(get_state_entries "pip")
  if [[ -z "$pkgs" ]]; then
    info "No pip entries in state file -- using fallback list."
    pkgs="ipython black pylint requests rich httpx virtualenv python-dotenv
          seaborn openpyxl flask pyzmq meson meson-python ninja Cython cffi"
  fi

  for pkg in $pkgs; do
    step "pip uninstall $pkg"
    if pip show "$pkg" &>/dev/null 2>&1; then
      if pip uninstall -y --break-system-packages "$pkg" >> "$UNINSTALL_LOG" 2>&1; then
        ok; ulog "removed pip: $pkg"
      else
        fail "pip uninstall $pkg failed"
      fi
    else
      skip
    fi
  done
}

#remove npm global packages
remove_npm_pkgs() {
  section "npm global packages"
  if ! command -v npm &>/dev/null; then info "npm not found."; return; fi

  local pkgs; pkgs=$(get_state_entries "npm")
  if [[ -z "$pkgs" ]]; then
    info "No npm entries in state file -- using fallback list."
    pkgs="live-server prettier eslint http-server nodemon typescript ts-node
          expo-cli react-native-cli eas-cli"
  fi

  for pkg in $pkgs; do
    step "npm uninstall -g $pkg"
    if npm list -g "$pkg" &>/dev/null 2>&1; then
      if npm uninstall -g "$pkg" >> "$UNINSTALL_LOG" 2>&1; then
        ok; ulog "removed npm: $pkg"
      else
        fail "npm uninstall $pkg failed"
      fi
    else
      skip
    fi
  done
}

#remove rust (installed via pkg install rust, not rustup)
remove_rust() {
  section "Rust toolchain"
  step "pkg uninstall rust"
  if dpkg -l rust &>/dev/null 2>&1; then
    pkg uninstall -y rust >> "$UNINSTALL_LOG" 2>&1 && ok && ulog "removed rust" || fail "could not remove rust"
  else
    skip
  fi
  step "~/.cargo"; [[ -d "$HOME/.cargo" ]] && rm -rf "$HOME/.cargo" && ok && ulog "removed ~/.cargo" || skip
  step "~/.rustup"; [[ -d "$HOME/.rustup" ]] && rm -rf "$HOME/.rustup" && ok && ulog "removed ~/.rustup" || skip
}

#remove go binaries
remove_go() {
  section "Go binaries"
  step "~/go"
  [[ -d "$HOME/go" ]] && rm -rf "$HOME/go" && ok && ulog "removed ~/go" || skip
}


remove_ohmyzsh() {
  section "Oh-My-Zsh"
  step "~/.oh-my-zsh"
  [[ -d "$HOME/.oh-my-zsh" ]] && rm -rf "$HOME/.oh-my-zsh" && ok && ulog "removed oh-my-zsh" || skip
}


remove_proot_distros() {
  section "proot-distro containers"
  local distros; distros=$(get_state_entries "proot")
  if [[ -z "$distros" ]]; then
    info "No proot entries in state file -- skipping (safe default)."; return
  fi
  for d in $distros; do
    step "proot-distro remove $d"
    if command -v proot-distro &>/dev/null; then
      proot-distro remove "$d" >> "$UNINSTALL_LOG" 2>&1 && ok && ulog "removed $d" || fail "could not remove $d"
    else
      skip
    fi
  done
}

#remove config files written by pocketdev
remove_configs() {
  section "Config files and binaries"
  local configs=(
    "$HOME/.vimrc"
    "$HOME/.tmux.conf"
    "$HOME/linux.sh"
    "$HOME/start-x11.sh"
    "$HOME/start-jupyter.sh"
    "$HOME/.hushlogin"
  )
  for f in "${configs[@]}"; do
    step "${f/$HOME/~}"
    [[ -f "$f" ]] && rm -f "$f" && ok && ulog "removed $f" || skip
  done

  for bin in newproject tgpt; do
    step "$PREFIX/bin/$bin"
    [[ -f "$PREFIX/bin/$bin" ]] && rm -f "$PREFIX/bin/$bin" && ok && ulog "removed $bin" || skip
  done
}

#strip pocketdev lines from .bashrc
clean_bashrc() {
  section "~/.bashrc cleanup"
  [[ ! -f "$HOME/.bashrc" ]] && info "~/.bashrc not found." && return

  cp "$HOME/.bashrc" "$HOME/.bashrc.pocketdev-backup"
  step "backup -> ~/.bashrc.pocketdev-backup"; ok; ulog "backed up .bashrc"

  local patterns=(
    "# PocketDev:"
    "alias mkenv=" "alias activate=" "alias py=" "alias pip="
    "export GOPATH=" "export PATH.*GOPATH"
    "\.fzf\.bash" "FZF_DEFAULT_OPTS"
    "alias ll=" "alias la=" "alias \.\." "alias \.\.\."
    "alias cls=" "alias h='history" "alias reload=" "alias myip="
    "alias linux=" "alias x11=" "alias jup=" "alias n='nnn"
    "\.cargo/bin" "\.cargo/env"
    "export EDITOR=" "alias vim=nvim"
    "export DISPLAY=:0"
  )

  local tmp; tmp=$(mktemp)
  cp "$HOME/.bashrc" "$tmp"
  for pattern in "${patterns[@]}"; do
    sed -i "/${pattern}/d" "$tmp"
  done
  awk '/^$/{blank++; if(blank<=1) print; next} {blank=0; print}' "$tmp" > "$HOME/.bashrc"
  rm -f "$tmp"
  step "~/.bashrc cleaned"; ok; ulog "cleaned .bashrc"
}


#remove pocketdev state and log
remove_pocketdev_files() {
  section "PocketDevTermux files"
  for f in "$STATE_FILE" "$HOME/pocketdev.log"; do
    step "${f/$HOME/~}"
    [[ -f "$f" ]] && rm -f "$f" && ok && ulog "removed $f" || skip
  done
}

print_summary() {
  echo ""; hr '='
  printf "${GREEN}${BOLD}  Uninstall complete.${R}\n"; hr '='; echo ""
  printf "  ${BOLD}Kept:${R}\n\n"
  printf "  ${CYAN}*${R}  ~/.bashrc.pocketdev-backup\n"
  printf "  ${CYAN}*${R}  ~/pocketdev-uninstall.log\n"
  [[ -d "$PROJECTS_DIR" ]] && printf "  ${CYAN}*${R}  ~/projects/\n"
  echo ""
  printf "  ${DIM}Run: source ~/.bashrc${R}\n\n"
  hr '='
}

main() {
  { echo "========================================"; echo " PocketDevTermux Uninstaller v${VERSION} -- $(date)"; echo "========================================"; } > "$UNINSTALL_LOG"

  banner
  printf "  ${DIM}Essential Termux packages are never removed.${R}\n\n"

  if [[ -f "$STATE_FILE" ]]; then
    printf "  ${DIM}State file found (%s entries)${R}\n\n" "$(wc -l < "$STATE_FILE")"
  else
    printf "  ${YELLOW}No state file -- using fallback lists.${R}\n\n"
  fi

  confirm "  Proceed?" || { printf "\n  ${YELLOW}Aborted.${R}\n\n"; exit 0; }
  press_enter

  remove_pkgs;        press_enter
  remove_pip_pkgs;    press_enter
  remove_npm_pkgs;    press_enter
  remove_rust
  remove_go
  remove_ohmyzsh
  remove_proot_distros
  press_enter
  remove_configs;     press_enter
  clean_bashrc;       press_enter
  remove_projects;    press_enter
  remove_pocketdev_files

  print_summary
  ulog "Uninstaller finished"
}

main "$@"
