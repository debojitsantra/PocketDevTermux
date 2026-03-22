#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail

VERSION="1.0"
LOG_FILE="$HOME/pocketdev.log"
STATE_FILE="$HOME/.pocketdev_state"
PROJECTS_DIR="$HOME/projects"
UNINSTALL_LOG="$HOME/pocketdev-uninstall.log"
TERM_WIDTH=$(tput cols 2>/dev/null || echo 72)

R='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
MAGENTA='\033[0;35m'

#logging
ulog() { printf "[%s] %s\n" "$(date '+%H:%M:%S')" "$*" >> "$UNINSTALL_LOG"; }

#ui helpers
hr() {
  local char="${1:--}" color="${2:-$CYAN}"
  printf "${color}${BOLD}"
  printf '%*s\n' "$TERM_WIDTH" '' | tr ' ' "$char"
  printf "${R}"
}

section() {
  echo ""
  printf "${MAGENTA}${BOLD}## %s${R}\n" "$1"
  printf "${DIM}"
  printf '%*s\n' $(( ${#1} + 3 )) '' | tr ' ' '-'
  printf "${R}"
}

step() { printf "  ${CYAN}-->${R}  %-50s" "$1"; }
ok()   { printf " ${GREEN}${BOLD}[  OK  ]${R}\n"; }
skip() { printf " ${YELLOW}${BOLD}[ SKIP ]${R}\n"; }
fail() { printf " ${RED}${BOLD}[ FAIL ]${R}\n"; printf "        ${RED}%s${R}\n" "$1"; ulog "FAIL: $1"; }
info() { printf "  ${CYAN}(i)${R}  %s\n" "$1"; }

confirm() {
  local _ans
  printf "  ${YELLOW}?${R}  %s ${DIM}(y/N)${R}  " "$1"
  read -r _ans
  [[ "$_ans" =~ ^[Yy]$ ]]
}

press_enter() {
  printf "\n  ${DIM}[ Press Enter to continue ]${R}  "
  read -r
}

#banner
banner() {
  clear
  hr '='
  printf "${WHITE}${BOLD}"
  printf "  >>  PocketDevTermux Uninstaller v%s\n" "$VERSION"
  printf "      Removes everything installed by pocketdev.sh\n"
  printf "${R}"
  hr '='
  echo ""
}

#read state file and parse pkg/pip/npm/proot entries
read_state() {
  if [[ ! -f "$STATE_FILE" ]]; then
    printf "  ${YELLOW}State file not found: %s${R}\n" "$STATE_FILE"
    printf "  ${DIM}Will fall back to manual removal of known items.${R}\n"
    return 1
  fi
  return 0
}

get_state_entries() {
  local prefix="$1"
  if [[ -f "$STATE_FILE" ]]; then
    grep "^${prefix}:" "$STATE_FILE" 2>/dev/null | sed "s/^${prefix}://" || true
  fi
}

#remove pkg packages tracked in state file
remove_pkgs() {
  section "Removing pkg packages"
  local pkgs
  pkgs=$(get_state_entries "pkg")

  if [[ -z "$pkgs" ]]; then
    info "No pkg entries in state file."
    #fallback: known packages pocketdev installs
    pkgs="git curl wget tar zip unzip tree htop bc openssh
          python python-pip nodejs clang binutils make cmake gdb
          openjdk-17 gradle maven kotlin golang
          zsh tmux jq shellcheck ripgrep fd bat lsd bottom
          fzf gh nnn micro nano vim neovim helix
          proot-distro aichat"
    info "Using known package list as fallback."
  fi

  for pkg in $pkgs; do
    step "pkg uninstall $pkg"
    if ! dpkg -l "$pkg" &>/dev/null 2>&1; then
      skip
    elif pkg uninstall -y "$pkg" >> "$UNINSTALL_LOG" 2>&1; then
      ok
      ulog "removed pkg: $pkg"
    else
      fail "could not remove $pkg"
    fi
  done
}

#remove pip packages tracked in state file
remove_pip_pkgs() {
  section "Removing pip packages"

  if ! command -v pip &>/dev/null; then
    info "pip not found, skipping."
    return
  fi

  local pkgs
  pkgs=$(get_state_entries "pip")

  if [[ -z "$pkgs" ]]; then
    info "No pip entries in state file."
    pkgs="ipython black pylint requests rich httpx virtualenv python-dotenv
          numpy pandas matplotlib seaborn scikit-learn jupyter notebook
          ipykernel scipy flask shell-gpt"
    info "Using known pip package list as fallback."
  fi

  for pkg in $pkgs; do
    step "pip uninstall $pkg"
    if pip show "$pkg" &>/dev/null 2>&1; then
      if pip uninstall -y --break-system-packages "$pkg" >> "$UNINSTALL_LOG" 2>&1; then
        ok
        ulog "removed pip: $pkg"
      else
        fail "pip uninstall $pkg failed"
      fi
    else
      skip
    fi
  done
}

#remove npm global packages tracked in state file
remove_npm_pkgs() {
  section "Removing npm global packages"

  if ! command -v npm &>/dev/null; then
    info "npm not found, skipping."
    return
  fi

  local pkgs
  pkgs=$(get_state_entries "npm")

  if [[ -z "$pkgs" ]]; then
    info "No npm entries in state file."
    pkgs="live-server prettier eslint http-server nodemon typescript ts-node
          code-server expo-cli react-native-cli eas-cli"
    info "Using known npm package list as fallback."
  fi

  for pkg in $pkgs; do
    step "npm uninstall -g $pkg"
    if npm list -g "$pkg" &>/dev/null 2>&1; then
      if npm uninstall -g "$pkg" >> "$UNINSTALL_LOG" 2>&1; then
        ok
        ulog "removed npm: $pkg"
      else
        fail "npm uninstall $pkg failed"
      fi
    else
      skip
    fi
  done
}

#remove rust / cargo toolchain
remove_rust() {
  section "Removing Rust toolchain"

  step "rustup self uninstall"
  if command -v rustup &>/dev/null; then
    if rustup self uninstall -y >> "$UNINSTALL_LOG" 2>&1; then
      ok
      ulog "removed rustup"
    else
      fail "rustup self uninstall failed"
    fi
  else
    skip
  fi

  step "~/.cargo directory"
  if [[ -d "$HOME/.cargo" ]]; then
    rm -rf "$HOME/.cargo" && ok && ulog "removed ~/.cargo" || fail "could not remove ~/.cargo"
  else
    skip
  fi

  step "~/.rustup directory"
  if [[ -d "$HOME/.rustup" ]]; then
    rm -rf "$HOME/.rustup" && ok && ulog "removed ~/.rustup" || fail "could not remove ~/.rustup"
  else
    skip
  fi
}

#remove ollama and pulled models
remove_ollama() {
  section "Removing Ollama and LLM models"

  step "ollama models"
  if command -v ollama &>/dev/null; then
    local models
    models=$(ollama list 2>/dev/null | tail -n +2 | awk '{print $1}' || true)
    if [[ -n "$models" ]]; then
      for m in $models; do
        step "  ollama rm $m"
        ollama rm "$m" >> "$UNINSTALL_LOG" 2>&1 && ok || fail "could not remove $m"
      done
    else
      step "ollama models (none found)"; skip
    fi
  else
    step "ollama (not installed)"; skip
  fi

  step "ollama binary"
  if [[ -f "$PREFIX/bin/ollama" ]]; then
    rm -f "$PREFIX/bin/ollama" && ok && ulog "removed ollama" || fail "could not remove ollama"
  elif [[ -f "/usr/local/bin/ollama" ]]; then
    rm -f "/usr/local/bin/ollama" 2>/dev/null && ok || fail "could not remove ollama (needs root?)"
  else
    skip
  fi

  step "~/.ollama directory"
  if [[ -d "$HOME/.ollama" ]]; then
    rm -rf "$HOME/.ollama" && ok && ulog "removed ~/.ollama" || fail "could not remove ~/.ollama"
  else
    skip
  fi
}

#remove proot distros
remove_proot_distros() {
  section "Removing proot-distro containers"

  local distros
  distros=$(get_state_entries "proot")

  if [[ -z "$distros" ]]; then
    if command -v proot-distro &>/dev/null; then
      distros=$(proot-distro list 2>/dev/null | grep -E '^\s+\*' | awk '{print $2}' || true)
    fi
  fi

  if [[ -n "$distros" ]]; then
    for d in $distros; do
      step "proot-distro remove $d"
      if proot-distro remove "$d" >> "$UNINSTALL_LOG" 2>&1; then
        ok
        ulog "removed proot distro: $d"
      else
        fail "could not remove $d"
      fi
    done
  else
    info "No proot distros found."
  fi
}

#remove go toolchain and installed binaries
remove_go() {
  section "Removing Go binaries"

  step "~/go directory"
  if [[ -d "$HOME/go" ]]; then
    rm -rf "$HOME/go" && ok && ulog "removed ~/go" || fail "could not remove ~/go"
  else
    skip
  fi
}

#remove oh-my-zsh
remove_ohmyzsh() {
  section "Removing Oh-My-Zsh"

  step "~/.oh-my-zsh"
  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    rm -rf "$HOME/.oh-my-zsh" && ok && ulog "removed oh-my-zsh" || fail "could not remove ~/.oh-my-zsh"
  else
    skip
  fi
}

#remove config files written by pocketdev
remove_configs() {
  section "Removing config files"

  local configs=(
    "$HOME/.vimrc"
    "$HOME/.tmux.conf"
    "$HOME/start-vscode.sh"
    "$HOME/start-ollama.sh"
    "$HOME/linux.sh"
    "$HOME/.hushlogin"
  )

  for f in "${configs[@]}"; do
    step "${f/$HOME/~}"
    if [[ -f "$f" ]]; then
      rm -f "$f" && ok && ulog "removed $f" || fail "could not remove $f"
    else
      skip
    fi
  done

  #remove newproject command
  step "$PREFIX/bin/newproject"
  if [[ -f "$PREFIX/bin/newproject" ]]; then
    rm -f "$PREFIX/bin/newproject" && ok && ulog "removed newproject" || fail "could not remove newproject"
  else
    skip
  fi

  #remove tgpt binary if manually placed
  step "$PREFIX/bin/tgpt"
  if [[ -f "$PREFIX/bin/tgpt" ]]; then
    rm -f "$PREFIX/bin/tgpt" && ok && ulog "removed tgpt" || fail "could not remove tgpt"
  else
    skip
  fi
}

#strip pocketdev blocks from .bashrc
clean_bashrc() {
  section "Cleaning ~/.bashrc"

  if [[ ! -f "$HOME/.bashrc" ]]; then
    info "~/.bashrc not found."
    return
  fi

  #backup first
  cp "$HOME/.bashrc" "$HOME/.bashrc.pocketdev-backup"
  step "~/.bashrc backup -> ~/.bashrc.pocketdev-backup"; ok
  ulog "backed up .bashrc"

  local patterns=(
    "# PocketDev: Python aliases"
    "alias mkenv="
    "alias activate="
    "alias py="
    "alias pip="
    "# PocketDev: Go environment"
    "export GOPATH="
    "export PATH.*GOPATH"
    "# PocketDev: fzf"
    "\.fzf\.bash"
    "FZF_DEFAULT_OPTS"
    "# PocketDev: QoL aliases"
    "alias ll="
    "alias la="
    "alias \.\."
    "alias \.\.\."
    "alias cls="
    "alias h='history"
    "alias reload="
    "alias myip="
    "alias vscode="
    "alias llm="
    "alias linux="
    "alias n='nnn"
    "\.cargo/bin"
    "\.cargo/env"
    "export EDITOR="
    "alias vim=nvim"
  )

  #build sed expression to delete matching lines
  local tmp; tmp=$(mktemp)
  cp "$HOME/.bashrc" "$tmp"

  for pattern in "${patterns[@]}"; do
    sed -i "/${pattern}/d" "$tmp"
  done

  #collapse multiple blank lines
  awk '/^$/{blank++; if(blank<=1) print; next} {blank=0; print}' "$tmp" > "$HOME/.bashrc"
  rm -f "$tmp"

  step "~/.bashrc cleaned"; ok
  ulog "cleaned .bashrc"
}

#remove projects directory
remove_projects() {
  section "Projects directory"

  if [[ ! -d "$PROJECTS_DIR" ]]; then
    info "$PROJECTS_DIR not found."
    return
  fi

  echo ""
  printf "  ${YELLOW}WARNING:${R}  This will delete ${WHITE}%s${R}\n" "$PROJECTS_DIR"
  printf "  ${DIM}Contains all starter projects and any work you put there.${R}\n\n"

  if confirm "  Delete ~/projects? (your own code may be in here)"; then
    step "rm -rf ~/projects"
    rm -rf "$PROJECTS_DIR" && ok && ulog "removed ~/projects" || fail "could not remove ~/projects"
  else
    step "~/projects"; skip
    info "Skipped. Remove manually: rm -rf ~/projects"
  fi
}

#remove pocketdev log and state files
remove_pocketdev_files() {
  section "PocketDevTermux files"

  local files=(
    "$STATE_FILE"
    "$HOME/pocketdev.log"
  )

  for f in "${files[@]}"; do
    step "${f/$HOME/~}"
    if [[ -f "$f" ]]; then
      rm -f "$f" && ok && ulog "removed $f" || fail "could not remove $f"
    else
      skip
    fi
  done
}

#summary
print_summary() {
  echo ""
  hr '='
  printf "${GREEN}${BOLD}  Uninstall complete.${R}\n"
  hr '='
  echo ""
  printf "  ${BOLD}What was kept:${R}\n\n"
  printf "  ${CYAN}*${R}  ~/.bashrc.pocketdev-backup  ${DIM}(original .bashrc backup)${R}\n"
  printf "  ${CYAN}*${R}  ~/pocketdev-uninstall.log   ${DIM}(this run's log)${R}\n"
  if [[ -d "$PROJECTS_DIR" ]]; then
    printf "  ${CYAN}*${R}  ~/projects/                 ${DIM}(you chose to keep it)${R}\n"
  fi
  echo ""
  printf "  ${DIM}Run 'source ~/.bashrc' to apply shell changes.${R}\n"
  printf "  ${DIM}Restart Termux to fully reset the environment.${R}\n\n"
  hr '='
}

#entry point
main() {
  {
    echo "========================================"
    echo " PocketDevTermux Uninstaller v${VERSION} -- $(date)"
    echo "========================================"
  } > "$UNINSTALL_LOG"

  banner

  printf "  ${RED}${BOLD}This will remove everything installed by pocketdev.sh.${R}\n\n"

  read_state || true

  if [[ -f "$STATE_FILE" ]]; then
    echo ""
    printf "  ${DIM}State file found: %s${R}\n" "$STATE_FILE"
    printf "  ${DIM}Tracked entries: %s${R}\n\n" "$(wc -l < "$STATE_FILE")"
    info "Reading install records from state file..."
  else
    echo ""
    printf "  ${YELLOW}No state file found.${R}\n"
    printf "  ${DIM}Will use known package list as fallback.${R}\n"
  fi

  echo ""
  if ! confirm "  Proceed with uninstall?"; then
    printf "\n  ${YELLOW}Aborted.${R}\n\n"
    exit 0
  fi

  press_enter

  remove_pkgs
  press_enter

  remove_pip_pkgs
  press_enter

  remove_npm_pkgs
  press_enter

  remove_rust
  remove_go
  remove_ollama
  remove_ohmyzsh
  remove_proot_distros
  press_enter

  remove_configs
  press_enter

  clean_bashrc
  press_enter

  remove_projects
  press_enter

  remove_pocketdev_files

  print_summary
  ulog "Uninstaller finished"
}

main "$@"
