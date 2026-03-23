#!/data/data/com.termux/files/usr/bin/bash

set -uo pipefail

#colors and constants
VERSION="3.0"
LOG_FILE="$HOME/pocketdev.log"
STATE_FILE="$HOME/.pocketdev_state"
PROJECTS_DIR="$HOME/projects"
TERM_WIDTH=$(tput cols 2>/dev/null || echo 72)

#ansi colors
R='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
ORANGE='\033[0;33m'

#logging
log()  { printf "[%s] %s\n" "$(date '+%H:%M:%S')" "$*" >> "$LOG_FILE"; }
logn() { printf "[%s] %s" "$(date '+%H:%M:%S')" "$*" >> "$LOG_FILE"; }

#state tracking for resume support
state_set() { grep -qxF "$1" "$STATE_FILE" 2>/dev/null || echo "$1" >> "$STATE_FILE"; }
state_has() { grep -qxF "$1" "$STATE_FILE" 2>/dev/null; }

#ui helpers
hr() {
  local char="${1:--}" color="${2:-$CYAN}"
  printf "${color}${BOLD}"
  printf '%*s\n' "$TERM_WIDTH" '' | tr ' ' "$char"
  printf "${R}"
}

banner() {
  clear
  hr '='
  printf "${WHITE}${BOLD}"
  printf "  >>  PocketDevTermux v%s\n" "$VERSION"
  printf "      %s\n" "$(date '+%d %B %Y')"
  printf "${R}"
  hr '='
  echo ""
}

section() {
  echo ""
  printf "${MAGENTA}${BOLD}## %s${R}\n" "$1"
  printf "${DIM}"
  printf '%*s\n' $(( ${#1} + 3 )) '' | tr ' ' '-'
  printf "${R}"
}

step() {
  printf "  ${CYAN}-->${R}  %-50s" "$1"
}

ok()      { printf " ${GREEN}${BOLD}[  OK  ]${R}\n"; }
skip()    { printf " ${YELLOW}${BOLD}[ SKIP ]${R}\n"; }
warn()    { printf " ${YELLOW}${BOLD}[ WARN ]${R}\n"; log "WARN: $1"; }
fail()    {
  printf " ${RED}${BOLD}[ FAIL ]${R}\n"
  printf "        ${RED}%s${R}\n" "$1"
  log "FAIL: $1"
}
info()    { printf "  ${BLUE}(i)${R}  %s\n" "$1"; }
success() { printf "  ${GREEN}${BOLD}(+)${R}  %s\n" "$1"; }

ask() {
  local _var="$1" _prompt="$2" _default="${3:-}"
  local _hint=""
  [[ -n "$_default" ]] && _hint=" ${DIM}[${_default}]${R}"
  printf "\n  ${YELLOW}?${R}  %s%b  " "$_prompt" "$_hint"
  local _input
  read -r _input
  if [[ -z "$_input" && -n "$_default" ]]; then
    printf -v "$_var" '%s' "$_default"
  else
    printf -v "$_var" '%s' "$_input"
  fi
}

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

spinner() {
  local pid=$1 msg=$2
  local frames=('.' '..' '...' '    ')
  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r  ${CYAN}-->${R}  %-50s${YELLOW}%s${R}" "$msg" "${frames[$((i % 4))]}"
    sleep 0.4
    (( i++ )) || true
  done
  printf "\r  ${CYAN}-->${R}  %-50s" "$msg"
}

#package helpers
has_cmd() { command -v "$1" &>/dev/null; }

pkg_exists() { dpkg -l "$1" &>/dev/null 2>&1; }

pkg_install() {
  local pkg="$1"
  local skip_check="${2:-}"  # pass "force" to skip existence check

  if [[ "$skip_check" != "force" ]] && pkg_exists "$pkg"; then
    step "pkg: $pkg (already installed)"; skip
    return 0
  fi

  step "pkg install $pkg"
  if DEBIAN_FRONTEND=noninteractive pkg install -y "$pkg" >> "$LOG_FILE" 2>&1; then
    ok
    state_set "pkg:$pkg"
  else
    fail "pkg install $pkg -- see $LOG_FILE"
  fi
}

pip_install() {
  local pkg="$1"
  local import_name="${2:-$pkg}"

  step "pip: $pkg"
  if python -c "import $import_name" &>/dev/null 2>&1; then
    skip; return 0
  fi
  if pip install --quiet --break-system-packages "$pkg" >> "$LOG_FILE" 2>&1; then
    ok
    state_set "pip:$pkg"
  else
    fail "pip install $pkg"
  fi
}

npm_global() {
  local pkg="$1"
  local cmd="${2:-$pkg}"

  step "npm -g: $pkg"
  if has_cmd "$cmd"; then
    skip; return 0
  fi
  if npm install -g "$pkg" >> "$LOG_FILE" 2>&1; then
    ok
    state_set "npm:$pkg"
  else
    fail "npm install -g $pkg"
  fi
}

cargo_install() {
  local pkg="$1"
  local cmd="${2:-$pkg}"

  step "cargo install: $pkg"
  if has_cmd "$cmd"; then
    skip; return 0
  fi
  if cargo install "$pkg" >> "$LOG_FILE" 2>&1; then
    ok
  else
    fail "cargo install $pkg"
  fi
}

#profile menu
show_profiles() {
  banner
  section "Pick Your Developer Profile"
  echo ""
  printf "  ${DIM}Pick one or more. Example: 1 3 7${R}\n\n"

  printf "  ${CYAN}${BOLD}[ 1]${R}  ${WHITE}Python Developer${R}\n"
  printf "       ${DIM}Python 3, pip, venv, ipython, black, pylint, rich, requests${R}\n\n"

  printf "  ${CYAN}${BOLD}[ 2]${R}  ${WHITE}Web Developer${R}\n"
  printf "       ${DIM}Node.js, npm, live-server, eslint, prettier, nodemon, http-server${R}\n\n"

  printf "  ${CYAN}${BOLD}[ 3]${R}  ${WHITE}C / C++ Developer${R}\n"
  printf "       ${DIM}Clang, GCC, Make, CMake, GDB, valgrind, binutils${R}\n\n"

  printf "  ${CYAN}${BOLD}[ 4]${R}  ${WHITE}Java Developer${R}\n"
  printf "       ${DIM}OpenJDK 17, Gradle, Maven${R}\n\n"

  printf "  ${CYAN}${BOLD}[ 5]${R}  ${WHITE}Kotlin Developer${R}\n"
  printf "       ${DIM}OpenJDK 17, Kotlin compiler${R}\n\n"

  printf "  ${CYAN}${BOLD}[ 6]${R}  ${WHITE}Rust Developer${R}\n"
  printf "       ${DIM}rustup, rustc, cargo, rust-analyzer${R}\n\n"

  printf "  ${CYAN}${BOLD}[ 7]${R}  ${WHITE}DevOps / Shell Scripting${R}\n"
  printf "       ${DIM}zsh, tmux, jq, bc, shellcheck, bat, lsd, fd, ripgrep${R}\n\n"

  printf "  ${CYAN}${BOLD}[ 8]${R}  ${WHITE}Go Developer${R}\n"
  printf "       ${DIM}Go toolchain, gofmt, gopls, air (hot reload)${R}\n\n"

  printf "  ${CYAN}${BOLD}[ 9]${R}  ${WHITE}Polyglot (Everything)${R}\n"
  printf "       ${DIM}All profiles above combined${R}\n\n"

  hr '-' "$DIM"
}

#base tools always installed
install_base() {
  section "Base Tools"
  
  local base_pkgs=()
  for pkg in git curl wget tar zip unzip tree htop bc openssh; do
    pkg_exists "$pkg" || base_pkgs+=("$pkg")
  done

  if [[ ${#base_pkgs[@]} -gt 0 ]]; then
    step "pkg install ${base_pkgs[*]}"
    if DEBIAN_FRONTEND=noninteractive pkg install -y "${base_pkgs[@]}" >> "$LOG_FILE" 2>&1; then
      ok
      for pkg in "${base_pkgs[@]}"; do state_set "pkg:$pkg"; done
    else
      fail "base pkg install failed -- check $LOG_FILE"
    fi
  else
    step "base packages (all already installed)"; skip
  fi

  local gname gemail
  gname=$(git config --global user.name 2>/dev/null || true)
  gemail=$(git config --global user.email 2>/dev/null || true)
  
  if [[ -z "$gname" || "$gname" == "Coder" || "$gemail" == "coder@example.com" ]]; then
    echo ""
    info "Set your Git name and email (used in commits)."
    ask gname  "Your name"  "${gname:-}"
    ask gemail "Your email" "${gemail:-}"
    git config --global user.name  "$gname"
    git config --global user.email "$gemail"
    git config --global init.defaultBranch main
    git config --global core.editor "nano"
    git config --global pull.rebase false
    git config --global color.ui auto
    step "Git global config"; ok
  else
    step "Git config (already set as '$gname')"; skip
  fi
}

#profile: python
install_python() {
  section "Python Developer"
  pkg_install python
  pkg_install python-pip

  pip_install "ipython"
  pip_install "black"
  pip_install "pylint"
  pip_install "requests"
  pip_install "rich"
  pip_install "httpx"
  pip_install "virtualenv"
  pip_install "python-dotenv" "dotenv"

  local bashrc="$HOME/.bashrc"
  grep -q 'mkenv' "$bashrc" 2>/dev/null || cat >> "$bashrc" << 'ALIASES'

# PocketDev: Python aliases
alias mkenv='python -m venv .venv && source .venv/bin/activate && echo "venv activated"'
alias activate='source .venv/bin/activate'
alias py='python'
alias pip='pip --break-system-packages'
ALIASES
  step "Python shell aliases"; ok

  if [[ ! -d "$PROJECTS_DIR/python-starter" ]]; then
    mkdir -p "$PROJECTS_DIR/python-starter"
    cat > "$PROJECTS_DIR/python-starter/main.py" << 'EOF'
#!/usr/bin/env python3
"""
Python Starter Project
Run: python main.py
"""
from rich.console import Console
from rich.panel import Panel

console = Console()

def greet(name: str) -> str:
    return f"Hello, {name}! Your Python environment works."

if __name__ == "__main__":
    msg = greet("World")
    console.print(Panel(msg, title="[bold green]Python Starter[/]", border_style="cyan"))
EOF
    cat > "$PROJECTS_DIR/python-starter/README.md" << 'EOF'
# Python Starter

Run:
```
python main.py
```

Create a virtual environment:
```
mkenv
```
EOF
    step "Python starter project"; ok
  fi
}

#profile: web
install_web() {
  section "Web Developer"
  pkg_install nodejs
 
  if ! has_cmd npm; then
    pkg_install "nodejs-lts"
  fi
 
  export PATH="$PREFIX/bin:$PATH"

  npm_global "live-server"
  npm_global "prettier"
  npm_global "eslint"
  npm_global "http-server"
  npm_global "nodemon"
  npm_global "typescript" "tsc"
  npm_global "ts-node"

  if [[ ! -d "$PROJECTS_DIR/web-starter" ]]; then
    mkdir -p "$PROJECTS_DIR/web-starter"
    cat > "$PROJECTS_DIR/web-starter/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Web Starter</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: system-ui, sans-serif; display: grid;
           place-items: center; min-height: 100vh; background: #0f172a; }
    h1   { color: #38bdf8; font-size: 2rem; }
    p    { color: #94a3b8; margin-top: 0.5rem; }
  </style>
</head>
<body>
  <div>
    <h1>Web Starter</h1>
    <p>Edit index.html and run: live-server</p>
  </div>
  <script src="main.js"></script>
</body>
</html>
EOF
    cat > "$PROJECTS_DIR/web-starter/main.js" << 'EOF'
// Your JavaScript goes here
console.log("Web environment ready!");
EOF
    cat > "$PROJECTS_DIR/web-starter/README.md" << 'EOF'
# Web Starter

Start dev server:
```
live-server
```

Or serve statically:
```
http-server -p 3000
```
EOF
    step "Web starter project"; ok
  fi
}

#profile: c/c++
install_c_cpp() {
  section "C / C++ Developer"
  for pkg in clang binutils make cmake; do
    pkg_install "$pkg"
  done

  pkg_install "gdb" || warn "gdb unavailable on this device"

  if [[ ! -d "$PROJECTS_DIR/c-starter" ]]; then
    mkdir -p "$PROJECTS_DIR/c-starter"
    cat > "$PROJECTS_DIR/c-starter/main.c" << 'EOF'
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char *argv[]) {
    const char *name = argc > 1 ? argv[1] : "World";
    printf("Hello, %s! C environment is ready.\n", name);
    return EXIT_SUCCESS;
}
EOF
    cat > "$PROJECTS_DIR/c-starter/Makefile" << 'EOF'
CC      = clang
CFLAGS  = -Wall -Wextra -std=c17 -g
TARGET  = hello

all: $(TARGET)

$(TARGET): main.c
	$(CC) $(CFLAGS) -o $@ $<

clean:
	rm -f $(TARGET)

run: all
	./$(TARGET)
EOF
    cat > "$PROJECTS_DIR/c-starter/README.md" << 'EOF'
# C Starter

Build and run:
```
make run
```

Clean:
```
make clean
```
EOF
    step "C starter project"; ok
  fi
}

#profile: java
install_java() {
  section "Java Developer"
  pkg_install "openjdk-17"
  pkg_install "gradle"
  pkg_install "maven" || warn "maven unavailable, use gradle"

  if [[ ! -d "$PROJECTS_DIR/java-starter" ]]; then
    mkdir -p "$PROJECTS_DIR/java-starter/src"
    cat > "$PROJECTS_DIR/java-starter/src/Main.java" << 'EOF'
public class Main {
    public static void main(String[] args) {
        String name = args.length > 0 ? args[0] : "World";
        System.out.printf("Hello, %s! Java environment is ready.%n", name);
    }
}
EOF
    cat > "$PROJECTS_DIR/java-starter/README.md" << 'EOF'
# Java Starter

Compile and run:
```
cd src
javac Main.java
java Main
```
EOF
    step "Java starter project"; ok
  fi
}

#profile: kotlin
install_kotlin() {
  section "Kotlin Developer"
  pkg_install "openjdk-17"
  pkg_install "kotlin"

  if [[ ! -d "$PROJECTS_DIR/kotlin-starter" ]]; then
    mkdir -p "$PROJECTS_DIR/kotlin-starter"
    cat > "$PROJECTS_DIR/kotlin-starter/main.kt" << 'EOF'
fun main(args: Array<String>) {
    val name = if (args.isNotEmpty()) args[0] else "World"
    println("Hello, $name! Kotlin environment is ready.")
}
EOF
    cat > "$PROJECTS_DIR/kotlin-starter/README.md" << 'EOF'
# Kotlin Starter

Compile and run:
```
kotlinc main.kt -include-runtime -d hello.jar
java -jar hello.jar
```
EOF
    step "Kotlin starter project"; ok
  fi
}

#profile: rust
install_rust() {
  section "Rust Developer"

  if has_cmd rustc; then
    step "rustc (already installed)"; skip
  else
    
    step "rust"
    if DEBIAN_FRONTEND=noninteractive pkg install -y rust >> "$LOG_FILE" 2>&1; then
      ok
      state_set "pkg:rust"
      
      
      grep -q '.cargo/bin' "$HOME/.bashrc" || \
        echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> "$HOME/.bashrc"
      export PATH="$HOME/.cargo/bin:$PATH"
    else
      fail "pkg install rust failed -- check $LOG_FILE"
      return
    fi
  fi

  if [[ ! -d "$PROJECTS_DIR/rust-starter" ]]; then
    if has_cmd cargo; then
      step "rust starter project"
      cargo new "$PROJECTS_DIR/rust-starter" --name hello >> "$LOG_FILE" 2>&1 && ok || fail "cargo new failed"
    fi
  else
    step "rust starter project"; skip
  fi
}

#profile: devops/shell
install_devops() {
  section "DevOps / Shell Scripting"
  for pkg in zsh tmux jq bc shellcheck ripgrep fd bat lsd; do
    pkg_install "$pkg"
  done

  # tmux config
  if [[ ! -f "$HOME/.tmux.conf" ]]; then
    cat > "$HOME/.tmux.conf" << 'EOF'
# PocketDev tmux config
set -g mouse on
set -g history-limit 10000
set -g base-index 1
set -g default-terminal "screen-256color"
bind r source-file ~/.tmux.conf \; display "Config reloaded"
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
EOF
    step "tmux config"; ok
  else
    step "tmux config (exists)"; skip
  fi

  # zsh setup
  if has_cmd zsh && [[ "$SHELL" != *zsh* ]]; then
    info "To use zsh as default: chsh -s zsh"
  fi

  if confirm "  Install Oh-My-Zsh (nicer zsh prompt)?"; then
    if [[ -d "$HOME/.oh-my-zsh" ]]; then
      step "Oh-My-Zsh (already installed)"; skip
    else
      step "Oh-My-Zsh"
      if sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
           "" --unattended >> "$LOG_FILE" 2>&1; then
        ok
      else
        fail "oh-my-zsh -- check $LOG_FILE"
      fi
    fi
  fi
}


#profile: go
install_go() {
  section "Go Developer"
  pkg_install "golang"

  local bashrc="$HOME/.bashrc"
  grep -q 'GOPATH' "$bashrc" || cat >> "$bashrc" << 'GOENV'

# PocketDev: Go environment
export GOPATH="$HOME/go"
export PATH="$PATH:$GOPATH/bin"
GOENV
  step "Go PATH config"; ok
  export GOPATH="$HOME/go"
  export PATH="$PATH:$GOPATH/bin"

  if has_cmd go; then
    step "air (hot reload)"
    go install github.com/air-verse/air@latest >> "$LOG_FILE" 2>&1 && ok || warn "air install failed"
  fi

  if [[ ! -d "$PROJECTS_DIR/go-starter" ]]; then
    mkdir -p "$PROJECTS_DIR/go-starter"
    cat > "$PROJECTS_DIR/go-starter/main.go" << 'EOF'
package main

import (
	"fmt"
	"os"
)

func main() {
	name := "World"
	if len(os.Args) > 1 {
		name = os.Args[1]
	}
	fmt.Printf("Hello, %s! Go environment is ready.\n", name)
}
EOF
    cat > "$PROJECTS_DIR/go-starter/go.mod" << 'EOF'
module hello

go 1.21
EOF
    cat > "$PROJECTS_DIR/go-starter/README.md" << 'EOF'
# Go Starter

Run:
```
go run main.go
```

Build:
```
go build -o hello .
./hello
```
EOF
    step "Go starter project"; ok
  fi
}


#profile: polyglot - runs all profiles
install_polyglot() {
  install_python
  install_web
  install_c_cpp
  install_rust
  install_java
  install_devops
  install_go
}


#editor selection
setup_editor() {
  section "Code Editor"
  echo ""
  printf "  ${CYAN}[1]${R}  micro   ${DIM}-- Ctrl+S save, Ctrl+Q quit${R}\n"
  printf "  ${CYAN}[2]${R}  nano    ${DIM}-- simple, no config needed${R}\n"
  printf "  ${CYAN}[3]${R}  helix   ${DIM}-- modern modal editor, built-in LSP${R}\n"
  printf "  ${CYAN}[4]${R}  vim     ${DIM}-- classic, fast, powerful${R}\n"
  printf "  ${CYAN}[5]${R}  neovim  ${DIM}-- modern vim (Lua config)${R}\n"
  printf "  ${CYAN}[6]${R}  skip\n"
  echo ""
  ask editor_choice "Your choice" "1"

  local bashrc="$HOME/.bashrc"

  case "$editor_choice" in
    1)
      pkg_install "micro"
      grep -q 'EDITOR=micro' "$bashrc" || echo 'export EDITOR=micro' >> "$bashrc"
      ;;
    2)
      pkg_install "nano"
      grep -q 'EDITOR=nano' "$bashrc" || echo 'export EDITOR=nano' >> "$bashrc"
      ;;
    3)
      pkg_install "helix"
      grep -q 'EDITOR=hx' "$bashrc" || echo 'export EDITOR=hx' >> "$bashrc"
      ;;
    4)
      pkg_install "vim"
      grep -q 'EDITOR=vim' "$bashrc" || echo 'export EDITOR=vim' >> "$bashrc"
      # Minimal .vimrc
      [[ -f "$HOME/.vimrc" ]] || cat > "$HOME/.vimrc" << 'EOF'
syntax on
set number
set tabstop=4
set shiftwidth=4
set expandtab
set autoindent
set mouse=a
set clipboard=unnamedplus
EOF
      step ".vimrc created"; ok
      ;;
    5)
      pkg_install "neovim"
      grep -q 'EDITOR=nvim' "$bashrc" || echo 'export EDITOR=nvim' >> "$bashrc"
      grep -q 'alias vim=nvim' "$bashrc" || echo 'alias vim=nvim' >> "$bashrc"
      ;;
    6|*)
      step "editor"; skip
      ;;
  esac
}


#optional extras
setup_extras() {
  section "Optional Extras"
  echo ""

  if confirm "  Install fzf (fuzzy history search / file finder)?"; then
    pkg_install "fzf"
    grep -q 'fzf' "$HOME/.bashrc" || cat >> "$HOME/.bashrc" << 'EOF'

# PocketDev: fzf
[ -f ~/.fzf.bash ] && source ~/.fzf.bash
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
EOF
    step "fzf shell integration"; ok
  fi

  if confirm "  Install GitHub CLI (gh)?"; then
    pkg_install "gh"
  fi

  if confirm "  Install nnn (terminal file manager)?"; then
    pkg_install "nnn"
    grep -q 'alias n=' "$HOME/.bashrc" || echo "alias n='nnn -de'" >> "$HOME/.bashrc"
  fi

  # Shell polish
  local bashrc="$HOME/.bashrc"
  grep -q '# PocketDev: QoL aliases' "$bashrc" || cat >> "$bashrc" << 'QOLALIASES'

# PocketDev: QoL aliases
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias cls='clear'
alias h='history | tail -20'
alias reload='source ~/.bashrc && echo "bashrc reloaded"'
alias myip='curl -s ifconfig.me && echo'
QOLALIASES
  step "QoL shell aliases"; ok

  # hushlogin to suppress Termux motd
  touch "$HOME/.hushlogin" 2>/dev/null || true
}


#version check table
print_version_table() {
  section "Installed Versions"
  echo ""

  local tools=(
    "python:python --version"
    "pip:pip --version"
    "node:node --version"
    "npm:npm --version"
    "git:git --version"
    "rustc:rustc --version"
    "go:go version"
    "java:java -version"
    "gcc:gcc --version"
    "clang:clang --version"
  )

  for entry in "${tools[@]}"; do
    local name="${entry%%:*}"
    local cmd="${entry#*:}"

    if has_cmd "${cmd%% *}"; then
      local ver
      ver=$(eval "$cmd" 2>&1 | head -1 | sed 's/version //' | cut -c1-50)
      printf "  ${GREEN}+${R}  %-10s  ${DIM}%s${R}\n" "$name" "$ver"
    else
      printf "  ${DIM}-  %-10s  not installed${R}\n" "$name"
    fi
  done
  echo ""
}


#optional: ai coding assistant
setup_ai_assistant() {
  section "AI Coding Assistant"
  echo ""
  printf "  ${CYAN}[1]${R}  aichat \n" 
  printf "  ${CYAN}[2]${R}  tgpt \n"   
  printf "  ${CYAN}[3]${R}  both \n"
  printf "  ${CYAN}[4]${R}  skip\n"
  echo ""
  ask ai_choice "Your choice" "4"

  case "$ai_choice" in
    1|3)
      step "aichat"
      if has_cmd aichat; then skip
      else
        pkg_install "aichat" || fail "aichat unavailable"
      fi
      ;;&
    2|3)
      step "tgpt"
      if has_cmd tgpt; then skip
      else
        pkg_install "tgpt" || fail "tgpt install failed"
      fi
      ;;
    4|*)
      step "AI assistant"; skip; return
      ;;
  esac

  echo ""
  info "Usage:"
  printf "  ${DIM}tgpt 'explain what a for loop is'${R}\n"
  printf "  ${DIM}aichat 'fix this error: ...'${R}\n"
}


#optional: full linux container via proot-distro
setup_linux_container() {
  section "Full Linux Dev Container (proot-distro)"
  echo ""
  printf "  ${DIM}Full Linux rootfs inside Termux via proot-distro. No root needed.${R}\n\n"

  step "proot-distro"
  if pkg_exists "proot-distro"; then skip
  else
    pkg_install "proot-distro"
  fi

  #hardcoded distro list matching current proot-distro supported distros
  local names=(
    "Adélie Linux"
    "AlmaLinux"
    "Alpine Linux"
    "Arch Linux"
    "Artix Linux"
    "Chimera Linux"
    "Debian (trixie)"
    "Deepin"
    "Fedora"
    "Manjaro"
    "OpenSUSE"
    "Oracle Linux"
    "Pardus"
    "Rocky Linux"
    "Termux"
    "Trisquel GNU/Linux"
    "Ubuntu (25.10)"
    "Void Linux"
  )
  local slugs=(
    "adelie"
    "almalinux"
    "alpine"
    "archlinux"
    "artix"
    "chimera"
    "debian"
    "deepin"
    "fedora"
    "manjaro"
    "opensuse"
    "oracle"
    "pardus"
    "rockylinux"
    "termux"
    "trisquel"
    "ubuntu"
    "void"
  )

  section "Available Distros"
  echo ""
  local i
  for i in "${!names[@]}"; do
    printf "  ${CYAN}[%2d]${R}  %-30s ${DIM}%s${R}\n" "$((i+1))" "${names[$i]}" "${slugs[$i]}"
  done
  echo ""
  printf "  ${CYAN}[ 0]${R}  skip\n"
  echo ""
  ask distro_choice "Your choice" "0"

  if [[ "$distro_choice" == "0" ]] || [[ -z "$distro_choice" ]]; then
    step "Linux container"; skip; return
  fi

  local idx=$(( distro_choice - 1 ))
  if [[ $idx -lt 0 || $idx -ge ${#names[@]} ]]; then
    printf "  ${RED}Invalid choice.${R}\n"; return
  fi

  local distro_name="${names[$idx]}"
  local distro_slug="${slugs[$idx]}"

  printf "\n  ${DIM}Installing %s -- downloading rootfs, may take a few minutes...${R}\n\n" "$distro_name"
  step "proot-distro install $distro_slug"
  if proot-distro install "$distro_slug" >> "$LOG_FILE" 2>&1; then
    ok
    state_set "proot:$distro_slug"
  else
    #already installed counts as success
    if proot-distro list 2>/dev/null | grep -q "$distro_slug"; then
      skip
    else
      fail "proot-distro install $distro_slug failed"
      return
    fi
  fi

  local login_script="$HOME/linux.sh"
  cat > "$login_script" << LOGINSCRIPT
#!/data/data/com.termux/files/usr/bin/bash
echo ""
echo "  Entering $distro_name container..."
echo "  Type 'exit' to return to Termux."
echo ""
proot-distro login $distro_slug --shared-tmp
LOGINSCRIPT
  chmod +x "$login_script"

  grep -q 'alias linux=' "$HOME/.bashrc" || \
    echo "alias linux='bash ~/linux.sh'" >> "$HOME/.bashrc"
  step "Login alias: linux"; ok

  echo ""
  info "Enter the container: linux"
  printf "  ${DIM}Your Termux home is shared inside the container.${R}\n"

  echo ""
  if confirm "  Auto-install build tools inside $distro_name right now?"; then
    echo ""
    case "$distro_slug" in
      ubuntu|debian|deepin|pardus|trisquel)
        proot-distro login "$distro_slug" -- bash -c \
          "apt-get update -qq && apt-get install -y build-essential git curl wget python3 python3-pip nodejs npm 2>&1" \
          | tee -a "$LOG_FILE" | tail -5
        ;;
      alpine|adelie|chimera)
        proot-distro login "$distro_slug" -- sh -c \
          "apk update && apk add build-base git curl wget python3 py3-pip nodejs npm 2>&1" \
          | tee -a "$LOG_FILE" | tail -5
        ;;
      archlinux|manjaro|artix)
        proot-distro login "$distro_slug" -- bash -c \
          "pacman -Syu --noconfirm && pacman -S --noconfirm base-devel git curl wget python python-pip nodejs npm 2>&1" \
          | tee -a "$LOG_FILE" | tail -5
        ;;
      fedora|almalinux|rockylinux|oracle)
        proot-distro login "$distro_slug" -- bash -c \
          "dnf install -y gcc gcc-c++ make git curl wget python3 python3-pip nodejs npm 2>&1" \
          | tee -a "$LOG_FILE" | tail -5
        ;;
      opensuse)
        proot-distro login "$distro_slug" -- bash -c \
          "zypper install -y gcc gcc-c++ make git curl wget python3 python3-pip nodejs npm 2>&1" \
          | tee -a "$LOG_FILE" | tail -5
        ;;
      void)
        proot-distro login "$distro_slug" -- bash -c \
          "xbps-install -Sy base-devel git curl wget python3 python3-pip nodejs npm 2>&1" \
          | tee -a "$LOG_FILE" | tail -5
        ;;
      termux)
        proot-distro login "$distro_slug" -- bash -c \
          "pkg install -y git curl wget python nodejs 2>&1" \
          | tee -a "$LOG_FILE" | tail -5
        ;;
      *)
        info "Unknown package manager for $distro_slug -- skipping bootstrap"
        ;;
    esac
    step "Container dev tools bootstrap"; ok
  fi
}

#optional: project scaffolding command
setup_project_templates() {
  section "Automatic Project Templates"
  echo ""
  printf "  ${DIM}Installs a newproject command to scaffold projects from templates.${R}\n\n"

  if ! confirm "  Install the 'newproject' template command?"; then
    step "project templates"; skip; return
  fi

  local bin_path="$PREFIX/bin/newproject"

  cat > "$bin_path" << 'NEWPROJECT'
#!/data/data/com.termux/files/usr/bin/bash
# newproject -- scaffold a new project from a template
# Usage: newproject <template> <name>
#   or:  newproject   (interactive)

R='\033[0m'; BOLD='\033[1m'; CYAN='\033[0;36m'
GREEN='\033[0;32m'; YELLOW='\033[0;33m'; WHITE='\033[1;37m'; DIM='\033[2m'

PROJECTS_DIR="$HOME/projects"

usage() {
  echo ""
  printf "  ${WHITE}${BOLD}newproject${R} -- project scaffolding tool\n\n"
  printf "  ${CYAN}Usage:${R}  newproject [template] [project-name]\n\n"
  printf "  ${CYAN}Templates available:${R}\n\n"
  printf "  ${CYAN}python${R}      Python app with venv, main.py, .env, .gitignore\n"
  printf "  ${CYAN}flask${R}       Flask web app with routes, templates, static\n"
  printf "  ${CYAN}node${R}        Node.js app with package.json, index.js, ESLint\n"
  printf "  ${CYAN}react${R}       React app (via create-react-app)\n"
  printf "  ${CYAN}express${R}     Express.js REST API with routes + middleware\n"
  printf "  ${CYAN}c${R}           C project with Makefile, src/, include/\n"
  printf "  ${CYAN}cpp${R}         C++ project with CMakeLists.txt, src/, include/\n"
  printf "  ${CYAN}rust${R}        Rust binary crate (cargo new)\n"
  printf "  ${CYAN}go${R}          Go module with main.go + go.mod\n"
  printf "  ${CYAN}bash${R}        Shell script project with main.sh + lib/\n"
  printf "  ${CYAN}java${R}        Java project with src/main/java structure\n"
  printf "  ${CYAN}datasci${R}     Data science project with notebooks/, data/, src/\n"
  echo ""
}

scaffold_python() {
  local name="$1" dir="$PROJECTS_DIR/$name"
  mkdir -p "$dir"
  cat > "$dir/main.py" << 'EOF'
#!/usr/bin/env python3
"""
Project: PROJECT_NAME
"""

def main():
    print("Hello from PROJECT_NAME!")

if __name__ == "__main__":
    main()
EOF
  sed -i "s/PROJECT_NAME/$name/g" "$dir/main.py"
  cat > "$dir/requirements.txt" << 'EOF'
# Add your dependencies here
# e.g. requests==2.31.0
EOF
  cat > "$dir/.env.example" << 'EOF'
# Copy this to .env and fill in your values
APP_DEBUG=true
SECRET_KEY=changeme
EOF
  cat > "$dir/.gitignore" << 'EOF'
.venv/
__pycache__/
*.pyc
.env
*.egg-info/
dist/
EOF
  cat > "$dir/README.md" << EOF
# $name

## Setup
\`\`\`
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
\`\`\`

## Run
\`\`\`
python main.py
\`\`\`
EOF
}

scaffold_flask() {
  local name="$1" dir="$PROJECTS_DIR/$name"
  mkdir -p "$dir/templates" "$dir/static/css" "$dir/static/js"
  cat > "$dir/app.py" << 'EOF'
from flask import Flask, render_template

app = Flask(__name__)

@app.route("/")
def index():
    return render_template("index.html", title="Home")

if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=5000)
EOF
  cat > "$dir/templates/index.html" << 'EOF'
<!DOCTYPE html>
<html><head><title>{{ title }}</title></head>
<body><h1>Flask app is running!</h1></body></html>
EOF
  cat > "$dir/requirements.txt" << 'EOF'
flask>=3.0.0
python-dotenv>=1.0.0
EOF
  cat > "$dir/.gitignore" << 'EOF'
.venv/
__pycache__/
*.pyc
.env
instance/
EOF
  cat > "$dir/README.md" << EOF
# $name (Flask)

\`\`\`
pip install -r requirements.txt
python app.py
\`\`\`
Open: http://localhost:5000
EOF
}

scaffold_node() {
  local name="$1" dir="$PROJECTS_DIR/$name"
  mkdir -p "$dir/src"
  cat > "$dir/src/index.js" << 'EOF'
'use strict';

function main() {
  console.log('Hello from Node.js!');
}

main();
EOF
  cat > "$dir/package.json" << EOF
{
  "name": "$name",
  "version": "1.0.0",
  "description": "",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "dev": "nodemon src/index.js"
  },
  "license": "MIT"
}
EOF
  cat > "$dir/.gitignore" << 'EOF'
node_modules/
.env
dist/
EOF
  cat > "$dir/README.md" << EOF
# $name

\`\`\`
npm install
npm start
\`\`\`
EOF
}

scaffold_express() {
  local name="$1" dir="$PROJECTS_DIR/$name"
  mkdir -p "$dir/src/routes" "$dir/src/middleware"
  cat > "$dir/src/index.js" << 'EOF'
const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

app.get('/', (req, res) => {
  res.json({ message: 'API is running', status: 'ok' });
});

app.get('/health', (req, res) => {
  res.json({ status: 'healthy', uptime: process.uptime() });
});

app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});
EOF
  cat > "$dir/package.json" << EOF
{
  "name": "$name",
  "version": "1.0.0",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "dev": "nodemon src/index.js"
  },
  "dependencies": {
    "express": "^4.18.0"
  },
  "license": "MIT"
}
EOF
  cat > "$dir/.gitignore" << 'EOF'
node_modules/
.env
EOF
  cat > "$dir/README.md" << EOF
# $name (Express API)

\`\`\`
npm install
npm run dev
\`\`\`
GET http://localhost:3000/
EOF
}

scaffold_c() {
  local name="$1" dir="$PROJECTS_DIR/$name"
  mkdir -p "$dir/src" "$dir/include"
  cat > "$dir/src/main.c" << 'EOF'
#include <stdio.h>
#include "app.h"

int main(void) {
    greet("World");
    return 0;
}
EOF
  cat > "$dir/include/app.h" << 'EOF'
#ifndef APP_H
#define APP_H
void greet(const char *name);
#endif
EOF
  cat > "$dir/src/app.c" << 'EOF'
#include <stdio.h>
#include "app.h"

void greet(const char *name) {
    printf("Hello, %s!\n", name);
}
EOF
  cat > "$dir/Makefile" << 'EOF'
CC      = clang
CFLAGS  = -Wall -Wextra -std=c17 -Iinclude -g
SRCS    = src/main.c src/app.c
TARGET  = app

all: $(TARGET)
$(TARGET): $(SRCS)
	$(CC) $(CFLAGS) -o $@ $^
clean:
	rm -f $(TARGET)
run: all
	./$(TARGET)
EOF
}

scaffold_cpp() {
  local name="$1" dir="$PROJECTS_DIR/$name"
  mkdir -p "$dir/src" "$dir/include"
  cat > "$dir/src/main.cpp" << 'EOF'
#include <iostream>
#include "app.hpp"

int main() {
    greet("World");
    return 0;
}
EOF
  cat > "$dir/include/app.hpp" << 'EOF'
#pragma once
#include <string>
void greet(const std::string& name);
EOF
  cat > "$dir/src/app.cpp" << 'EOF'
#include <iostream>
#include "app.hpp"

void greet(const std::string& name) {
    std::cout << "Hello, " << name << "!\n";
}
EOF
  cat > "$dir/CMakeLists.txt" << EOF
cmake_minimum_required(VERSION 3.16)
project($name CXX)
set(CMAKE_CXX_STANDARD 17)
include_directories(include)
add_executable(app src/main.cpp src/app.cpp)
EOF
  cat > "$dir/README.md" << EOF
# $name (C++)

\`\`\`
mkdir build && cd build
cmake ..
make
./app
\`\`\`
EOF
}

scaffold_rust() {
  local name="$1"
  if command -v cargo &>/dev/null; then
    cargo new "$PROJECTS_DIR/$name" --name "$name"
  else
    printf "  cargo not found. Install Rust first: bash pocketdev.sh\n" >&2
    return 1
  fi
}

scaffold_go() {
  local name="$1" dir="$PROJECTS_DIR/$name"
  mkdir -p "$dir"
  cat > "$dir/main.go" << EOF
package main

import "fmt"

func main() {
	fmt.Println("Hello from $name!")
}
EOF
  cat > "$dir/go.mod" << EOF
module $name

go 1.21
EOF
  cat > "$dir/README.md" << EOF
# $name (Go)

\`\`\`
go run main.go
go build -o $name .
\`\`\`
EOF
}

scaffold_bash() {
  local name="$1" dir="$PROJECTS_DIR/$name"
  mkdir -p "$dir/lib"
  cat > "$dir/main.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"


#entry point
main() {
  log "Script started"
  greet "World"
}

main "$@"
EOF
  cat > "$dir/lib/utils.sh" << 'EOF'
log()   { printf "[%s] %s\n" "$(date '+%H:%M:%S')" "$*"; }
greet() { printf "Hello, %s!\n" "$1"; }
EOF
  chmod +x "$dir/main.sh"
  cat > "$dir/.gitignore" << 'EOF'
*.log
tmp/
EOF
  cat > "$dir/README.md" << EOF
# $name

\`\`\`
bash main.sh
\`\`\`
EOF
}

scaffold_java() {
  local name="$1" class_name
  class_name="$(echo "$name" | sed 's/[^a-zA-Z0-9]//g' | sed 's/^\(.\)/\u\1/')"
  local dir="$PROJECTS_DIR/$name/src/main/java"
  mkdir -p "$dir"
  cat > "$dir/Main.java" << EOF
public class Main {
    public static void main(String[] args) {
        System.out.println("Hello from $name!");
    }
}
EOF
  cat > "$PROJECTS_DIR/$name/README.md" << EOF
# $name (Java)

\`\`\`
cd src/main/java
javac Main.java
java Main
\`\`\`
EOF
}

scaffold_datasci() {
  local name="$1" dir="$PROJECTS_DIR/$name"
  mkdir -p "$dir/notebooks" "$dir/data/raw" "$dir/data/processed" "$dir/src" "$dir/outputs"
  cat > "$dir/src/explore.py" << 'EOF'
"""
Data exploration script.
Run: python src/explore.py
"""
import os
import pandas as pd
import numpy as np

DATA_DIR = os.path.join(os.path.dirname(__file__), "..", "data", "raw")

def load_sample():
    rng = np.random.default_rng(42)
    df = pd.DataFrame({
        "id":    range(50),
        "value": rng.normal(100, 15, 50).round(2),
        "group": np.tile(["A","B","C"], 17)[:50],
    })
    return df

if __name__ == "__main__":
    df = load_sample()
    print(df.head(10))
    print("\nSummary:")
    print(df.describe())
    print("\nGroup means:")
    print(df.groupby("group")["value"].mean())
EOF
  cat > "$dir/requirements.txt" << 'EOF'
numpy
pandas
matplotlib
seaborn
scikit-learn
jupyter
EOF
  cat > "$dir/.gitignore" << 'EOF'
data/raw/*
outputs/*
.venv/
__pycache__/
*.pyc
.ipynb_checkpoints/
EOF
  cat > "$dir/README.md" << EOF
# $name (Data Science)

Structure:
  notebooks/   -- Jupyter notebooks
  data/raw/    -- raw input data (gitignored)
  data/processed/ -- cleaned data
  src/         -- Python scripts
  outputs/     -- plots, reports

\`\`\`
pip install -r requirements.txt
python src/explore.py
jupyter notebook
\`\`\`
EOF
}

# ── Main interactive flow ──────────────────────────────────

template="${1:-}"
proj_name="${2:-}"

if [[ -z "$template" ]]; then
  usage
  printf "  ${YELLOW}?${R}  Template name  " ; read -r template
fi

if [[ -z "$proj_name" ]]; then
  printf "  ${YELLOW}?${R}  Project name   " ; read -r proj_name
fi

# Sanitize name
proj_name="${proj_name// /-}"
proj_name="${proj_name//[^a-zA-Z0-9_-]/}"

if [[ -z "$proj_name" ]]; then
  printf "  Invalid project name.\n" >&2; exit 1
fi

target="$PROJECTS_DIR/$proj_name"

if [[ -d "$target" ]]; then
  printf "  ${YELLOW}Directory %s already exists!${R}\n" "$target" >&2; exit 1
fi

printf "\n  ${CYAN}Creating${R}  ${WHITE}%s${R}  from template  ${CYAN}%s${R}...\n\n" "$proj_name" "$template"

case "$template" in
  python)  scaffold_python  "$proj_name" ;;
  flask)   scaffold_flask   "$proj_name" ;;
  node)    scaffold_node    "$proj_name" ;;
  express) scaffold_express "$proj_name" ;;
  c)       scaffold_c       "$proj_name" ;;
  cpp)     scaffold_cpp     "$proj_name" ;;
  rust)    scaffold_rust    "$proj_name" ;;
  go)      scaffold_go      "$proj_name" ;;
  bash)    scaffold_bash    "$proj_name" ;;
  java)    scaffold_java    "$proj_name" ;;
  datasci) scaffold_datasci "$proj_name" ;;
  react)
    if command -v npx &>/dev/null; then
      npx create-react-app "$target" --template typescript
    else
      printf "  npx not found. Install Node.js first.\n" >&2; exit 1
    fi
    ;;
  *)
    printf "  Unknown template: %s\n" "$template" >&2
    usage; exit 1
    ;;
esac

# Init git repo
if command -v git &>/dev/null && [[ -d "$target" ]]; then
  git -C "$target" init -q
  git -C "$target" add . 2>/dev/null
  git -C "$target" commit -qm "Initial scaffold ($template template)" 2>/dev/null || true
fi

printf "  ${GREEN}${BOLD}Done!${R}  Project created at: ${CYAN}%s${R}\n\n" "$target"
printf "  ${DIM}cd %s${R}\n\n" "$target"
NEWPROJECT

  chmod +x "$bin_path"
  step "newproject command installed"; ok

  echo ""
  info "Usage:  newproject python my-app"
  info "        newproject flask my-website"
  info "        newproject node my-api"
  printf "  ${DIM}Run 'newproject' with no args to see all templates.${R}\n"
}


run_tests() {
  local PASS=0 FAIL=0 SKIP=0
  local TEST_DIR
  TEST_DIR=$(mktemp -d)
  local TEST_LOG="$HOME/pocketdev-test.log"

  {
    echo "========================================"
    echo " PocketDevTermux test run -- $(date)"
    echo "========================================"
  } > "$TEST_LOG"

  tlog() { printf "[%s] %s\n" "$(date '+%H:%M:%S')" "$*" >> "$TEST_LOG"; }

  clear
  hr '='
  printf "${WHITE}${BOLD}  >>  PocketDevTermux -- Test Suite${R}\n"
  printf "      Testing all installed tools and languages\n"
  hr '='
  echo ""
  printf "  ${DIM}Temp dir: %s${R}\n" "$TEST_DIR"
  printf "  ${DIM}Log:      %s${R}\n\n" "$TEST_LOG"

 
  t() {
    local name="$1" cmd="$2"
    printf "  ${CYAN}-->${R}  %-48s" "$name"
    tlog "TEST: $name"
    tlog "CMD:  $cmd"
    if eval "$cmd" >> "$TEST_LOG" 2>&1; then
      printf " ${GREEN}${BOLD}[ PASS ]${R}\n"
      tlog "RESULT: PASS"
      (( PASS++ )) || true
    else
      printf " ${RED}${BOLD}[ FAIL ]${R}\n"
      tlog "RESULT: FAIL"
      (( FAIL++ )) || true
    fi
  }

  ts() {
    local name="$1"
    printf "  ${DIM}--   %-48s [ SKIP ]${R}\n" "$name"
    tlog "SKIP: $name"
    (( SKIP++ )) || true
  }

  
  tc() {
    local cmd_check="$1" name="$2" test_cmd="$3"
    if has_cmd "$cmd_check"; then
      t "$name" "$test_cmd"
    else
      ts "$name"
    fi
  }

  
  section "Base Tools"

  t  "git version"          "git --version"
  t  "curl fetch"           "curl -fsSL --max-time 5 https://example.com -o /dev/null"
  t  "wget fetch"           "wget -q --timeout=5 https://example.com -O /dev/null"
  tc "tmux"  "tmux version"          "tmux -V"
  tc "jq"    "jq parse"              "echo '{\"a\":1}' | jq .a"
  tc "fzf"   "fzf version"           "fzf --version"
  tc "gh"    "gh version"            "gh --version"
  tc "rg"    "ripgrep search"        "echo 'hello world' | rg 'hello'"
  tc "fd"    "fd find"               "fd --version"
  tc "bat"   "bat version"           "bat --version"
  tc "htop"  "htop version"          "htop --version"

  
  section "Python"

  if has_cmd python; then
  
    cat > "$TEST_DIR/test_python.py" << 'PYEOF'
import sys, os, math, json, pathlib
assert sys.version_info >= (3, 8), "Python 3.8+ required"
assert math.sqrt(9) == 3.0
data = json.dumps({"status": "ok"})
assert json.loads(data)["status"] == "ok"
print("python core ok")
PYEOF
    t  "python core"            "python $TEST_DIR/test_python.py"
    t  "pip version"            "pip --version"
    tc "ipython" "ipython version"    "ipython --version"
    tc "black"   "black check"        "black --version"
    tc "pylint"  "pylint version"     "pylint --version"

   
    cat > "$TEST_DIR/test_ds.py" << 'DSEOF'
results = []
def try_import(name, import_as=None):
    try:
        __import__(import_as or name)
        results.append(f"  + {name}")
    except ImportError:
        results.append(f"  - {name} NOT FOUND")

try_import("numpy")
try_import("pandas")
try_import("matplotlib")
try_import("scipy")
try_import("sklearn", "sklearn")
try_import("seaborn")
try_import("jupyter")
try_import("ipykernel")
try_import("openpyxl")
try_import("requests")
try_import("rich")
try_import("flask")
try_import("cv2")

for r in results:
    print(r)

failures = [r for r in results if "NOT FOUND" in r]
if failures:
    print(f"\n{len(failures)} package(s) missing")
    exit(1)
DSEOF
    t  "python packages"        "python $TEST_DIR/test_ds.py"

  
    cat > "$TEST_DIR/test_numpy.py" << 'NPEOF'
import numpy as np
a = np.array([1,2,3,4,5])
assert np.mean(a) == 3.0
assert np.std(a) > 0
b = np.random.default_rng(0).normal(0, 1, 1000)
assert -0.5 < np.mean(b) < 0.5
print("numpy math ok")
NPEOF
    tc "python" "numpy math"         "python $TEST_DIR/test_numpy.py"

   
    cat > "$TEST_DIR/test_pandas.py" << 'PDEOF'
import pandas as pd, numpy as np
df = pd.DataFrame({"x": range(10), "y": np.random.default_rng(1).random(10)})
assert len(df) == 10
assert df["x"].sum() == 45
grouped = df.groupby(df["x"] % 2)["y"].mean()
assert len(grouped) == 2
print("pandas ok")
PDEOF
    tc "python" "pandas dataframe"   "python $TEST_DIR/test_pandas.py"

   
    cat > "$TEST_DIR/test_mpl.py" << 'MPLEOF'
import os
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
fig, ax = plt.subplots()
ax.plot(np.linspace(0, 2*np.pi, 100), np.sin(np.linspace(0, 2*np.pi, 100)))
ax.set_title("sine wave")
out = "/tmp/pocketdev_test_plot.png"
fig.savefig(out)
assert os.path.exists(out) and os.path.getsize(out) > 0
print(f"matplotlib render ok -> {out}")
MPLEOF
    tc "python" "matplotlib render"  "python $TEST_DIR/test_mpl.py"

  else
    ts "python (not installed)"
  fi

  
  section "Node.js / Web"

  if has_cmd node; then
    cat > "$TEST_DIR/test_node.js" << 'JSEOF'
const assert = require('assert');
const http = require('http');
assert.strictEqual(typeof process.version, 'string');
const arr = [1,2,3].map(x => x * 2);
assert.deepStrictEqual(arr, [2,4,6]);
const obj = JSON.parse('{"ok":true}');
assert.strictEqual(obj.ok, true);
console.log('node core ok, version', process.version);
JSEOF
    t  "node core"             "node $TEST_DIR/test_node.js"
    t  "npm version"           "npm --version"
    tc "tsc"        "typescript version"  "tsc --version"
    tc "ts-node"    "ts-node version"     "ts-node --version"
    tc "nodemon"    "nodemon version"     "nodemon --version"
    tc "prettier"   "prettier version"    "prettier --version"
    tc "eslint"     "eslint version"      "eslint --version"
    tc "live-server" "live-server version" "live-server --version"
  else
    ts "node (not installed)"
  fi

  
  section "C / C++"

  if has_cmd clang; then
    cat > "$TEST_DIR/test.c" << 'CEOF'
#include <stdio.h>
#include <assert.h>
#include <math.h>
int add(int a, int b) { return a + b; }
int main(void) {
    assert(add(2, 3) == 5);
    assert((int)sqrt(16.0) == 4);
    printf("C ok\n");
    return 0;
}
CEOF
    t  "clang compile"         "clang -o $TEST_DIR/test_c $TEST_DIR/test.c -lm"
    t  "C binary run"          "$TEST_DIR/test_c"

    cat > "$TEST_DIR/test.cpp" << 'CPPEOF'
#include <iostream>
#include <vector>
#include <numeric>
#include <cassert>
int main() {
    std::vector<int> v = {1,2,3,4,5};
    int sum = std::accumulate(v.begin(), v.end(), 0);
    assert(sum == 15);
    std::cout << "C++ ok" << std::endl;
    return 0;
}
CPPEOF
    t  "clang++ compile"       "clang++ -std=c++17 -o $TEST_DIR/test_cpp $TEST_DIR/test.cpp"
    t  "C++ binary run"        "$TEST_DIR/test_cpp"
    tc "cmake" "cmake version"        "cmake --version"
    tc "make"  "make version"         "make --version"
  else
    ts "clang (not installed)"
  fi

  
  section "Java"

  if has_cmd javac; then
    cat > "$TEST_DIR/TestJava.java" << 'JAVAEOF'
public class TestJava {
    static int factorial(int n) { return n <= 1 ? 1 : n * factorial(n-1); }
    public static void main(String[] args) {
        assert factorial(5) == 120 : "factorial failed";
        System.out.println("Java ok, version " + System.getProperty("java.version"));
    }
}
JAVAEOF
    t  "javac compile"         "javac -d $TEST_DIR $TEST_DIR/TestJava.java"
    t  "java run"              "java -cp $TEST_DIR TestJava"
    tc "gradle" "gradle version"      "gradle --version"
  else
    ts "java (not installed)"
  fi

  
  section "Kotlin"

  if has_cmd kotlinc; then
    cat > "$TEST_DIR/test.kt" << 'KTEOF'
fun main() {
    val nums = listOf(1,2,3,4,5)
    val sum = nums.sum()
    check(sum == 15) { "sum failed: $sum" }
    println("Kotlin ok")
}
KTEOF
    t  "kotlinc compile"       "kotlinc $TEST_DIR/test.kt -include-runtime -d $TEST_DIR/test_kt.jar"
    t  "kotlin jar run"        "java -jar $TEST_DIR/test_kt.jar"
  else
    ts "kotlin (not installed)"
  fi

  
  section "Rust"

  if has_cmd rustc; then
    cat > "$TEST_DIR/test.rs" << 'RSEOF'
fn fibonacci(n: u64) -> u64 {
    match n { 0 => 0, 1 => 1, _ => fibonacci(n-1) + fibonacci(n-2) }
}
fn main() {
    assert_eq!(fibonacci(10), 55);
    println!("Rust ok");
}
RSEOF
    t  "rustc compile"         "rustc $TEST_DIR/test.rs -o $TEST_DIR/test_rs"
    t  "rust binary run"       "$TEST_DIR/test_rs"
    tc "cargo" "cargo version"        "cargo --version"
  else
    ts "rust (not installed)"
  fi

 
  section "Go"

  if has_cmd go; then
    cat > "$TEST_DIR/test.go" << 'GOEOF'
package main

import (
    "fmt"
    "sort"
)

func main() {
    s := []int{5, 2, 4, 1, 3}
    sort.Ints(s)
    if s[0] != 1 || s[4] != 5 {
        panic("sort failed")
    }
    fmt.Println("Go ok")
}
GOEOF
    t  "go run"                "go run $TEST_DIR/test.go"
    t  "go build"              "go build -o $TEST_DIR/test_go $TEST_DIR/test.go"
    t  "go binary run"         "$TEST_DIR/test_go"
  else
    ts "go (not installed)"
  fi

  
  section "Shell / DevOps"

  cat > "$TEST_DIR/test.sh" << 'SHEOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
result=$(echo "hello world" | tr '[:lower:]' '[:upper:]')
[[ "$result" == "HELLO WORLD" ]] || exit 1
nums=(1 2 3 4 5)
total=0
for n in "${nums[@]}"; do (( total += n )); done
[[ $total -eq 15 ]] || exit 1
echo "bash ok"
SHEOF
  chmod +x "$TEST_DIR/test.sh"
  t  "bash script"            "bash $TEST_DIR/test.sh"
  tc "zsh"        "zsh version"         "zsh --version"
  tc "shellcheck" "shellcheck lint"     "shellcheck $TEST_DIR/test.sh"
  tc "jq"         "jq transform"        "echo '[1,2,3]' | jq 'map(. * 2)'"

  
  section "Editors"

  tc "micro"  "micro version"        "micro --version"
  tc "nano"   "nano version"         "nano --version"
  tc "vim"    "vim version"          "vim --version"
  tc "nvim"   "neovim version"       "nvim --version"
  tc "hx"     "helix version"        "hx --version"

  
  section "AI / LLM Tools"

  tc "aichat"   "aichat version"     "aichat --version"
  tc "tgpt"     "tgpt version"       "tgpt --version"
  tc "sgpt"     "sgpt version"       "sgpt --version"

  
  section "Network & System"

  t  "internet (curl)"        "curl -fsSL --max-time 8 https://httpbin.org/get -o /dev/null"
  t  "dns resolution"         "curl -fsSL --max-time 5 https://1.1.1.1 -o /dev/null"
  tc "ssh"    "ssh version"          "ssh -V"

  
  #cleanup
  rm -rf "$TEST_DIR"

  #results
  local total=$(( PASS + FAIL + SKIP ))
  echo ""
  hr '='
  printf "${WHITE}${BOLD}  Test Results${R}\n"
  hr '-' "$DIM"
  printf "  ${GREEN}${BOLD}PASS${R}  %d\n" "$PASS"
  printf "  ${RED}${BOLD}FAIL${R}  %d\n" "$FAIL"
  printf "  ${DIM}SKIP  %d${R}\n" "$SKIP"
  printf "  ${DIM}TOTAL %d${R}\n" "$total"
  hr '-' "$DIM"

  if [[ $FAIL -eq 0 ]]; then
    printf "  ${GREEN}${BOLD}All tests passed.${R}\n"
  else
    printf "  ${YELLOW}%d test(s) failed. Check %s for details.${R}\n" "$FAIL" "$TEST_LOG"
  fi
  hr '='
  echo ""
  printf "  ${DIM}Full test log: %s${R}\n\n" "$TEST_LOG"
}



show_resources() {
  clear
  hr '='
  printf "${WHITE}${BOLD}  >>  Recommended Apps & Learning Resources${R}\n"
  hr '='

  
  section "Code Editor Apps for Android"

  printf "  ${CYAN}${BOLD}Acode${R}  ${DIM}-- powerful code editor, syntax highlight, git, FTP${R}\n"
  printf "  ${YELLOW}  Play Store :${R}  https://play.google.com/store/apps/details?id=com.foxdebug.acodefree\n"
  printf "  ${YELLOW}  F-Droid    :${R}  https://f-droid.org/packages/com.foxdebug.acode/\n"
  printf "  ${YELLOW}  GitHub     :${R}  https://github.com/deadlyjack/Acode\n"
  echo ""

  printf "  ${CYAN}${BOLD}Xed Editor${R}  ${DIM}-- clean, fast, markdown + code support${R}\n"
  printf "  ${YELLOW}  GitHub     :${R}  https://github.com/Xed-Editor/Xed-Editor\n"
  printf "  ${YELLOW}  F-Droid    :${R}  https://f-droid.org/packages/com.rk.xededitor/\n"
  echo ""

  printf "  ${CYAN}${BOLD}QuickEdit Pro${R}  ${DIM}-- fast editor, handles huge files well${R}\n"
  printf "  ${YELLOW}  Play Store :${R}  https://play.google.com/store/apps/details?id=com.rhmsoft.edit.pro\n"
  echo ""

  press_enter

  
  section "Learn to Code -- Free Apps"

  printf "  ${CYAN}${BOLD}SoloLearn${R}  ${DIM}-- free courses: Python, JS, C++, Java, SQL, HTML & more${R}\n"
  printf "  ${YELLOW}  Play Store :${R}  https://play.google.com/store/apps/details?id=com.sololearn\n"
  printf "  ${YELLOW}  Website    :${R}  https://sololearn.com\n"
  echo ""

  printf "  ${CYAN}${BOLD}Mimo${R}  ${DIM}-- bite-sized lessons, daily streaks${R}\n"
  printf "  ${YELLOW}  Play Store :${R}  https://play.google.com/store/apps/details?id=com.getmimo\n"
  printf "  ${YELLOW}  Website    :${R}  https://getmimo.com\n"
  echo ""

  printf "  ${CYAN}${BOLD}Programming Hub${R}  ${DIM}-- 20+ languages, offline support, example programs${R}\n"
  printf "  ${YELLOW}  Play Store :${R}  https://play.google.com/store/apps/details?id=com.freeit.java\n"
  echo ""

  press_enter

  
  section "Free Courses Online"

  printf "  ${CYAN}${BOLD}freeCodeCamp${R}  ${DIM}-- full web dev curriculum, 100%% free, certificates${R}\n"
  printf "  ${YELLOW}  Website    :${R}  https://freecodecamp.org\n"
  printf "  ${YELLOW}  YouTube    :${R}  https://youtube.com/@freecodecamp\n"
  echo ""

  printf "  ${CYAN}${BOLD}The Odin Project${R}  ${DIM}-- best free full-stack web dev course, project-based${R}\n"
  printf "  ${YELLOW}  Website    :${R}  https://theodinproject.com\n"
  echo ""

  printf "  ${CYAN}${BOLD}CS50 by Harvard${R}  ${DIM}-- world-famous intro to CS, totally free on edX${R}\n"
  printf "  ${YELLOW}  Website    :${R}  https://cs50.harvard.edu/x\n"
  echo ""

  printf "  ${CYAN}${BOLD}MIT OpenCourseWare${R}  ${DIM}-- real MIT lecture notes and problem sets, free${R}\n"
  printf "  ${YELLOW}  Website    :${R}  https://ocw.mit.edu\n"
  echo ""

  printf "  ${CYAN}${BOLD}Khan Academy (Computing)${R}  ${DIM}-- visual intro to computing${R}\n"
  printf "  ${YELLOW}  Website    :${R}  https://khanacademy.org/computing\n"
  echo ""

  printf "  ${CYAN}${BOLD}roadmap.sh${R}  ${DIM}-- step-by-step visual roadmaps for every developer path${R}\n"
  printf "  ${YELLOW}  Website    :${R}  https://roadmap.sh\n"
  echo ""

  printf "  ${CYAN}${BOLD}W3Schools${R}  ${DIM}-- quick reference and try-it editor for HTML/CSS/JS/SQL/Python${R}\n"
  printf "  ${YELLOW}  Website    :${R}  https://w3schools.com\n"
  echo ""

  press_enter

  
  section "Practice & Coding Challenges"

  printf "  ${CYAN}${BOLD}LeetCode${R}       ${DIM}https://leetcode.com${R}          ${DIM}-- interview prep, algorithms${R}\n"
  printf "  ${CYAN}${BOLD}HackerRank${R}     ${DIM}https://hackerrank.com${R}        ${DIM}-- structured problem sets by topic${R}\n"
  printf "  ${CYAN}${BOLD}Exercism${R}       ${DIM}https://exercism.org${R}          ${DIM}-- exercises + human mentoring, free${R}\n"
  printf "  ${CYAN}${BOLD}Codewars${R}       ${DIM}https://codewars.com${R}          ${DIM}-- fun kata challenges, levelling system${R}\n"
  printf "  ${CYAN}${BOLD}Project Euler${R}  ${DIM}https://projecteuler.net${R}      ${DIM}-- math + programming problems${R}\n"
  echo ""

  press_enter
}


#final summary
print_summary() {
  echo ""
  hr '='
  printf "${GREEN}${BOLD}  ALL DONE!  Your coding environment is ready.${R}\n"
  hr '='
  echo ""

  print_version_table

  printf "  ${BOLD}Quick start:${R}\n\n"
  printf "  ${CYAN}1.${R}  Reload your shell so PATH changes take effect:\n"
  printf "       ${YELLOW}source ~/.bashrc${R}\n\n"
  printf "  ${CYAN}2.${R}  Open your starter projects and try running them:\n"
  printf "       ${YELLOW}ls ~/projects/${R}\n\n"
  printf "  ${CYAN}3.${R}  Something went wrong? Check the install log:\n"
  printf "       ${YELLOW}cat %s${R}\n\n" "$LOG_FILE"
  printf "  ${CYAN}4.${R}  Want to add more languages later? Just re-run:\n"
  printf "       ${YELLOW}bash pocketdev.sh${R}\n\n"

  hr '-' "$DIM"
  printf "  ${GREEN}${BOLD}Good luck and have fun coding!${R}\n\n"
  hr '='
}


main() {
  
  if [[ "${1:-}" == "--test" ]]; then
    run_tests
    exit $?
  fi

  # Init log
  {
    echo "========================================"
    echo " pocketdev.sh v${VERSION} started at $(date)"
    echo "========================================"
  } >> "$LOG_FILE"

  banner

  
  printf "  ${GREEN}${BOLD}PocketDevTermux${R}\n\n"
  printf "  ${DIM}Pick profiles, re-run anytime. Already-installed tools are skipped.${R}\n"
  printf "  ${DIM}Log: ~/pocketdev.log${R}\n"
  echo ""
  press_enter

  # Update
  section "Updating Termux packages"
  step "pkg update"
  if pkg update -y >> "$LOG_FILE" 2>&1; then ok; else fail "pkg update failed"; fi
  step "pkg upgrade"
  if pkg upgrade -y >> "$LOG_FILE" 2>&1; then ok; else fail "pkg upgrade failed"; fi
  press_enter

  # Base
  install_base
  press_enter

  # Profile selection
  show_profiles
  ask profiles "Enter profile number(s)" "1"

  echo ""

  # Process each chosen profile
  for p in $profiles; do
    case "$p" in
      1)  install_python      ;;
      2)  install_web         ;;
      3)  install_c_cpp       ;;
      4)  install_java        ;;
      5)  install_kotlin      ;;
      6)  install_rust        ;;
      7)  install_devops      ;;
      8)  install_go          ;;
      9)  install_polyglot    ;;
      *)  printf "  ${YELLOW}Unknown profile %s -- skipped${R}\n" "$p" ;;
    esac
  done

  echo ""
  printf "  ${GREEN}Profile installation done!${R}\n"
  press_enter

  setup_editor
  press_enter

  setup_extras
  press_enter

  
  section "Optional Features"
  echo ""
  echo ""
  press_enter

  setup_ai_assistant
  press_enter

  setup_linux_container
  press_enter

  setup_project_templates
  press_enter

  show_resources
  print_summary

  log "PocketDevTermux finished"
}

main "$@"
