# PocketDevTermux

![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)
![Platform: Termux](https://img.shields.io/badge/Platform-Termux-black.svg)
![Shell: Bash](https://img.shields.io/badge/Shell-Bash-blue.svg)
![Version](https://img.shields.io/badge/Version-3.0-cyan.svg)
![No Root](https://img.shields.io/badge/Root-Not%20Required-brightgreen.svg)
![Maintained](https://img.shields.io/badge/Maintained-Yes-success.svg)

A fully interactive, TUI-based coding environment installer for [Termux](https://termux.dev). Pick your developer profile, install languages and tools, set up an editor, and optionally spin up VS Code Server, a local AI coding model, or a proot based full Linux container.

---

## Requirements

- Android 7.0 or higher
- [Termux](https://f-droid.org/packages/com.termux/) installed from F-Droid (recommended) or Play Store
- Internet connection during setup
- ~500MB free storage minimum (more for Linux containers and LLM models)

---

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/debojitsantra/PocketDevTermux/refs/heads/main/pocketdev.sh -o pocketdev.sh
chmod +x pocketdev.sh
bash pocketdev.sh
```

Or clone the repo:

```bash
pkg install git
git clone https://github.com/debojitsantra/PocketDevTermux.git
cd PocketDevTermux
bash pocketdev.sh
```

---


## Developer Profiles

Run the script and pick one or more profiles. You can combine them freely.

| # | Profile | What gets installed |
|---|---------|---------------------|
| 1 | Python | Python 3, pip, ipython, black, pylint, rich, requests, httpx, virtualenv |
| 2 | Web | Node.js, live-server, eslint, prettier, nodemon, TypeScript, ts-node |
| 3 | C / C++ | Clang, GCC, Make, CMake, GDB, binutils |
| 4 | Java | OpenJDK 17, Gradle, Maven |
| 5 | Kotlin | OpenJDK 17, Kotlin compiler |
| 6 | Rust | rustup, rustc, cargo |
| 7 | Data Science | Python + numpy, pandas, matplotlib, seaborn, scikit-learn, jupyter |
| 8 | DevOps / Shell | zsh, tmux, jq, shellcheck, ripgrep, fd, bat, lsd |
| 9 | Go | Go toolchain, air (hot reload) |
| 10 | Polyglot | All of the above |

Multiple profiles can be selected at once:

```
Enter profile number(s): 1 3 7
```

---

## Optional Features

After the base profile setup, the installer offers five optional power features.

### VS Code Server

Installs [code-server](https://github.com/coder/code-server) and runs VS Code in your phone's browser at `http://localhost:8080`. Full editor with syntax highlighting, file tree, terminal, and extension support.

Start it after install:

```bash
vscode
```

### AI Coding Assistant

Choose from three CLI AI tools:

- **aichat** — supports GPT, Claude, Gemini, and Ollama backends
- **shell-gpt** — Python-based, works with OpenAI or local models
- **tgpt** — no API key required, uses free public backends

### Local LLM

Installs [Ollama](https://ollama.com) and pulls a coding model of your choice. Runs fully offline after the initial download.

Models that work on my devices:

| Model | Size | Notes |
|-------|------|-------|
| qwen2.5-coder:1.5b | ~1GB | Fast, recommended for most devices |
| qwen2.5-coder:7b | ~4GB | More capable, needs more RAM |
| codellama:7b | ~4GB | Meta's coding model |
| deepseek-coder:1.3b | ~800MB | Smallest, surprisingly capable |

Start Ollama after install:

```bash
llm
```

### Linux Container

Installs [proot-distro](https://github.com/termux/proot-distro) and sets up a full Linux rootfs. 


Enter the container:

```bash
linux
```

Optional bootstrap installs `build-essential`, git, python, and Node.js inside the container automatically.

### Project Templates

Installs a `newproject` command that scaffolds complete project structures with config files, `.gitignore`, build files, and a working example. Each project is auto-initialized as a git repository.

```bash
newproject python   my-app
newproject flask    my-website
newproject express  my-api
newproject c        my-tool
newproject rust     my-crate
newproject go       my-service
newproject datasci  my-analysis
```

Run `newproject` with no arguments to see all available templates.

---

## Terminal Editors

| Option | Notes |
|--------|-------|
| micro | Ctrl+S save, Ctrl+Q quit. Closest to a normal editor. |
| nano | Simple, minimal learning curve. |
| helix | Modal editor with built-in LSP support. |
| vim | Classic. Fast once learned. |
| neovim | Modern vim with Lua configuration. |

---

## Resumable

The installer tracks every installed package in `~/.pocketdev_state`. Re-running the script skips everything already installed, so it is safe to run again to add more profiles.

---

## Uninstalling

removes exactly what was installed.

```bash
curl -fsSL https://github.com/debojitsantra/PocketDevTermux/blob/main/uninstall.sh -o uninstall.sh
bash uninstall.sh
```

The uninstaller:

- Reads `~/.pocketdev_state` to identify installed packages
- Falls back to a known package list if the state file is missing
- Removes pkg, pip, and npm packages
- Removes Rust, Go, Ollama, Oh-My-Zsh, and proot containers
- Strips all PocketDevTermux blocks from `~/.bashrc`
- Backs up `~/.bashrc` before modifying it
- Asks before deleting `~/projects`
- Writes a full removal log to `~/pocketdev-uninstall.log`



After running, the installer creates:

```
~/
├── projects/                 # starter projects, one per profile
├── start-vscode.sh           # launch code-server
├── start-ollama.sh           # start Ollama and list models
├── linux.sh                  # enter proot container
├── .pocketdev_state          # install tracking
└── pocketdev.log             # install log
```

---

## Logs

| File | Contents |
|------|----------|
| `~/pocketdev.log` | Full install log with timestamps |
| `~/pocketdev-uninstall.log` | Full uninstall log |
| `~/.pocketdev_state` | Tracked installed packages |

---

## License

MIT License. See [LICENSE](LICENSE)

---

## Recommended Android Apps

Code editors:

- **Acode** — [F-Droid](https://f-droid.org/packages/com.foxdebug.acode/) / [GitHub](https://github.com/deadlyjack/Acode)
- **Xed Editor** — [F-Droid](https://f-droid.org/packages/com.rk.xededitor/) / [Github](https://github.com/Xed-Editor/Xed-Editor)

## Learning Resources

- [freeCodeCamp](https://freecodecamp.org)
- [The Odin Project](https://theodinproject.com)
- [CS50 by Harvard](https://cs50.harvard.edu/x)
- [roadmap.sh](https://roadmap.sh)
- [Exercism](https://exercism.org)
- [SoloLearn](https://sololearn.com)
