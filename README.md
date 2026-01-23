# cursor-agent.el

Enhanced Cursor CLI Agent integration for Emacs. This package provides a comprehensive interface to interact with the [Cursor CLI Agent](https://cursor.com/docs/cli/overview) directly from Emacs.

> **Note:** This plugin was created using [Cursor](https://cursor.com) - an AI-powered code editor that helped accelerate development.

## Features

- **Self-contained installation** - Install Cursor CLI directly from Emacs
- **Installation & authentication verification** - Check setup status
- **Interactive and non-interactive modes** - Flexible usage patterns
- **Session management** - Resume previous conversations
- **Model selection** - Choose your preferred AI model
- **Output format options** - Text, JSON, or stream-JSON formats
- **Shell mode support** - Quick command execution
- **MCP server management** - Manage Model Context Protocol servers
- **ANSI color support** - Automatic color handling in output buffers
- **Terminal compatibility** - Works in both GUI and terminal Emacs

## Requirements

- Emacs 27.1 or higher
- Cursor CLI Agent (can be installed via the package)
- Optional: `vterm` package for better terminal emulation (falls back to `shell-mode` if not available)

## Installation

### Method 1: Manual Installation

1. Clone this repository or download `cursor-agent.el`
2. Add to your Emacs configuration:

```elisp
(add-to-list 'load-path "/path/to/cursor-agent.el")
(require 'cursor-agent)
```

### Method 2: Package Installation

```elisp
M-x package-install-file RET /path/to/cursor-agent.el RET
```

### Method 3: Use-package (if installed)

```elisp
(use-package cursor-agent
  :load-path "/path/to/cursor-agent"
  :config
  (setq cursor-agent-default-model "gpt-5"))
```

## Quick Start

1. **Install Cursor CLI** (if not already installed):
   ```
   M-x cursor-agent-install
   ```

2. **Authenticate**:
   ```
   M-x cursor-agent-login
   ```

3. **Verify setup**:
   ```
   M-x cursor-agent-verify-setup
   ```

4. **Start using**:
   ```
   M-x cursor-agent-prompt
   ```

## Usage

### Basic Commands

| Command | Description |
|---------|-------------|
| `cursor-agent-install` | Install Cursor CLI Agent |
| `cursor-agent-prompt` | Run agent with a prompt |
| `cursor-agent-interactive` | Start interactive session |
| `cursor-agent-region` | Process selected region |
| `cursor-agent-resume` | Resume previous conversation |
| `cursor-agent-login` | Authenticate with Cursor |
| `cursor-agent-status` | Show authentication status |
| `cursor-agent-verify-setup` | Verify installation and auth |

### Advanced Commands

| Command | Description |
|---------|-------------|
| `cursor-agent-list-sessions` | List all previous sessions |
| `cursor-agent-list-models` | List available models |
| `cursor-agent-mcp-list` | List MCP servers |
| `cursor-agent-shell-mode` | Start shell mode |
| `cursor-agent-update` | Update Cursor CLI |
| `cursor-agent-readme` | Display the README file |

### Example: Processing a Code Region

1. Select a region of code
2. Run `M-x cursor-agent-region`
3. The agent will process the code and display results

### Example: Interactive Session

1. Run `M-x cursor-agent-interactive`
2. Type your prompts directly in the terminal
3. Use standard terminal navigation

## Configuration

Customize the package behavior:

```elisp
;; Set default model
(setq cursor-agent-default-model "gpt-5")

;; Set default output format
(setq cursor-agent-default-output-format "json")  ; or "text", "stream-json"

;; Enable --force flag for file modifications
(setq cursor-agent-use-force t)

;; Change the command name (if different)
(setq cursor-agent-command "my-agent")
```

## Keybindings

The package does not define keybindings by default. Add your own:

```elisp
;; Example keybindings
(global-set-key (kbd "C-c a a") 'cursor-agent-prompt)
(global-set-key (kbd "C-c a i") 'cursor-agent-interactive)
(global-set-key (kbd "C-c a r") 'cursor-agent-region)
(global-set-key (kbd "C-c a I") 'cursor-agent-install)
(global-set-key (kbd "C-c a L") 'cursor-agent-login)
(global-set-key (kbd "C-c a s") 'cursor-agent-status)
```

Or with `use-package`:

```elisp
(use-package cursor-agent
  :bind (("C-c a a" . cursor-agent-prompt)
         ("C-c a i" . cursor-agent-interactive)
         ("C-c a r" . cursor-agent-region)
         ("C-c a I" . cursor-agent-install)
         ("C-c a L" . cursor-agent-login)
         ("C-c a s" . cursor-agent-status)))
```

## Optional Dependencies

### vterm (Recommended for GUI Emacs)

For better terminal emulation in interactive mode (GUI Emacs only):

```elisp
M-x package-install RET vterm RET
```

**Important Notes:**
- vterm requires GUI Emacs and will not work in terminal mode
- In terminal mode, the package automatically uses `shell-mode` (built-in)
- The fallback is seamless - no configuration needed
- All functions work identically with or without vterm

**Doom Emacs users:** If you have the `:term vterm` module enabled, vterm is already available.

## Doom Emacs Integration

This package works seamlessly with Doom Emacs. Here are recommended integration methods:

### Method 1: Local Package (Recommended)

Place `cursor-agent.el` in your Doom config directory and load it:

1. **Copy the file to your Doom config:**
   ```bash
   cp cursor-agent.el ~/.config/doom/
   ```

2. **Add to `~/.config/doom/config.el`:**
   ```elisp
   ;; Load cursor-agent
   (load! "cursor-agent")

   ;; Optional: Configuration
   (setq cursor-agent-default-model "gpt-5")

   ;; Keybindings using Doom's map! macro
   (map! :leader
         (:prefix "c"  ; Code prefix
          (:prefix ("A" . "cursor-agent")
           :desc "Cursor Agent Install" "I" #'cursor-agent-install
           :desc "Cursor Agent Prompt" "a" #'cursor-agent-prompt
           :desc "Cursor Agent Interactive" "i" #'cursor-agent-interactive
           :desc "Cursor Agent Region" "r" #'cursor-agent-region
           :desc "Cursor Agent Resume" "R" #'cursor-agent-resume
           :desc "Cursor Agent List Sessions" "l" #'cursor-agent-list-sessions
           :desc "Cursor Agent Status" "s" #'cursor-agent-status
           :desc "Cursor Agent Login" "L" #'cursor-agent-login
           :desc "Cursor Agent List Models" "m" #'cursor-agent-list-models
           :desc "Cursor Agent MCP List" "M" #'cursor-agent-mcp-list
           :desc "Cursor Agent Shell Mode" "S" #'cursor-agent-shell-mode
           :desc "Cursor Agent Update" "u" #'cursor-agent-update
           :desc "Cursor Agent Verify Setup" "v" #'cursor-agent-verify-setup)))
   ```

3. **Restart Emacs** - No `doom sync` needed for local files!

### Method 2: Git Repository (For Updates)

If you want to track the package via Git and get updates:

1. **Add to `~/.config/doom/packages.el`:**
   ```elisp
   (package! cursor-agent
     :recipe (:host github
              :repo "chocoelho/cursor-agent.el"
              :files ("cursor-agent.el")))
   ```

2. **Run `doom sync`** to install

3. **Add configuration to `~/.config/doom/config.el`** — use `after! cursor-agent` only for `setq` and keybindings. **Do not** `unload-feature` or `load` the package in `after!`; that causes recursive load errors (see [Known issues](#known-issues)):
   ```elisp
   (after! cursor-agent
     (setq cursor-agent-default-model "gpt-5")
     
     ;; Keybindings
     (map! :leader
           (:prefix "c"
            (:prefix ("A" . "cursor-agent")
             "a" #'cursor-agent-prompt
             "i" #'cursor-agent-interactive
             "r" #'cursor-agent-region
             "I" #'cursor-agent-install
             "L" #'cursor-agent-login
             "s" #'cursor-agent-status)))
   ```

### Method 3: Local Directory (For Development)

If you're developing or want to keep it in a separate directory:

1. **Add to `~/.config/doom/packages.el`:**
   ```elisp
   (package! cursor-agent
     :recipe (:local-repo "/path/to/cursor-agent.el"   ; or "~/workspaces/personal/cursor-agent.el"
              :files ("cursor-agent.el")
              :build (:not compile)))   ; optional: faster iteration when not byte-compiling
   ```

2. **Run `doom sync`**

3. **Configure in `~/.config/doom/config.el`** as in Method 2. **Do not** `unload-feature` or `load` cursor-agent in `after!` — it causes recursive load errors.

With `:local-repo`, Doom/Straight may only autoload a few commands at startup. Run `M-x cursor-agent-install` (or any autoloaded command) once to load the full file; after that, all commands are available. See [Known issues](#known-issues).

### Doom Emacs Keybindings

The recommended keybinding layout for Doom Emacs:

- `SPC c A I` - Install Cursor CLI
- `SPC c A a` - Prompt
- `SPC c A i` - Interactive session
- `SPC c A r` - Process region
- `SPC c A R` - Resume session
- `SPC c A l` - List sessions
- `SPC c A s` - Status
- `SPC c A L` - Login
- `SPC c A m` - List models
- `SPC c A M` - MCP servers
- `SPC c A S` - Shell mode
- `SPC c A u` - Update CLI
- `SPC c A v` - Verify setup

**Why `SPC c A`?**
- `SPC c` is Doom's code prefix (already used for code actions)
- `A` (capital) keeps AI-related commands organized
- Nested within code prefix for logical grouping

### Doom Emacs Tips

- **No `doom sync` needed** for Method 1 (local file) - just restart Emacs
- **Use `after!` macro** for package configuration when using `package!` — only for `setq` and keybindings, **not** for `unload-feature` or `load` of cursor-agent (causes recursive load)
- **Use `map!` macro** for keybindings (Doom's DSL)
- **vterm module**: If you have Doom's `:term vterm` module enabled, vterm will be available automatically

## Known issues

### Doom Emacs / Straight: commands unavailable until first use

With Doom and Straight (`package!` with `:local-repo` or `:host github`), only a subset of commands may appear in `M-x` at startup. **Run `M-x cursor-agent-install`** (or any other autoloaded command) **once** to load the full package; after that, all commands are available. This comes from how Doom/Straight generate and apply autoloads; the package itself has `;;;###autoload` on all commands.

### Doom Emacs: do not unload/reload in config

**Do not** use `unload-feature` and `load` (or `load-file`) of `cursor-agent.el` inside an `after! cursor-agent` block. That causes a **recursive load** between the Straight build path and your source path (e.g. workspace or `:local-repo`). Use `after! cursor-agent` only for configuration (`setq`, keybindings). The package is already loaded by Doom/Straight.

## Compatibility

This package is **designed and tested primarily for vanilla Emacs**. It uses only standard Emacs features and has no distribution-specific dependencies.

### Supported Environments

- **Vanilla Emacs 27.1+** (primary target)
  - GUI Emacs (X11, macOS, Windows)
  - Terminal Emacs (interactive and non-interactive sessions)
- **Emacs distributions** (compatible but not specifically targeted)
  - Doom Emacs (see Doom Emacs Integration section above)
  - Spacemacs
  - Any other Emacs distribution

### Design Principles

- **Vanilla-first**: All code is written and tested against vanilla Emacs
- **Standard features only**: Uses only built-in Emacs functionality
- **No distribution assumptions**: Does not rely on features from Doom Emacs, Spacemacs, or other distributions
- **Universal compatibility**: Works in both GUI and terminal Emacs environments
- **Graceful fallbacks**: Automatically falls back to standard Emacs features when optional packages (like `vterm`) are unavailable

## Documentation

Based on official Cursor CLI documentation:
- [Cursor CLI Overview](https://cursor.com/docs/cli/overview)
- [Installation Guide](https://cursor.com/docs/cli/installation)
- [Usage Guide](https://cursor.com/docs/cli/using)

## Troubleshooting

### Agent command not found

1. Run `M-x cursor-agent-install` to install
2. Ensure `~/.local/bin` is in your PATH
3. Restart Emacs after installation

### Authentication issues

1. Run `M-x cursor-agent-login` to authenticate
2. Check status with `M-x cursor-agent-status`
3. Verify setup with `M-x cursor-agent-verify-setup`

### vterm not available

The package will automatically fall back to `shell-mode`. For better experience, install vterm:

```elisp
M-x package-install RET vterm RET
```

## Testing

Tests are included in `cursor-agent-test.el` using ERT (Emacs Lisp Regression Testing). Run tests locally:

```elisp
M-x load-file RET cursor-agent-test.el RET
M-x ert RET cursor-agent-test-.* RET
```

Or from the command line:

```bash
emacs --batch -l ert -l cursor-agent.el -l cursor-agent-test.el \
  --eval "(ert-run-tests-batch-and-exit 'cursor-agent-test-.* t)"
```

Tests run automatically on GitHub Actions for all pushes and pull requests.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

See [LICENSE](LICENSE) file for details.

## Author

- **chocoelho** - [GitHub](https://github.com/chocoelho)

## Acknowledgments

- Based on [Cursor CLI](https://cursor.com/docs/cli) documentation
- Inspired by the need for better Emacs integration with AI tools
- This plugin was created using [Cursor](https://cursor.com) - an AI-powered code editor
