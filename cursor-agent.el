;;; cursor-agent.el --- Enhanced Cursor CLI Agent integration for Emacs -*- lexical-binding: t; -*-

;; Author: Carlos Coelho
;; Maintainer: chocoelho
;; Version: 1.1.0
;; Package-Requires: ((emacs "27.1"))
;; Keywords: tools, ai, cursor, agent
;; URL: https://github.com/chocoelho/cursor-agent.el
;;
;; This file is NOT part of GNU Emacs.
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; This package provides integration with Cursor CLI Agent, offering:
;; - Installation and authentication verification
;; - Interactive and non-interactive modes
;; - Session management
;; - Model selection
;; - Output format options
;; - Shell mode support
;; - MCP server management
;;
;; Based on Cursor CLI documentation:
;; - https://cursor.com/docs/cli/overview
;; - https://cursor.com/docs/cli/installation
;; - https://cursor.com/docs/cli/using
;;
;; Note: This plugin was created using Cursor (https://cursor.com),
;; an AI-powered code editor that helped accelerate development.
;;
;; Installation:
;;   Place this file in your load-path and add to your init.el:
;;   (require 'cursor-agent)
;;
;;   Or use package.el:
;;   M-x package-install-file RET cursor-agent.el RET
;;
;; Usage:
;;   M-x cursor-agent-prompt
;;   M-x cursor-agent-interactive
;;   M-x cursor-agent-install
;;
;; Optional dependencies:
;;   - vterm: For better terminal emulation in interactive mode (GUI only)
;;     Install with: M-x package-install RET vterm RET
;;     Note: vterm requires GUI Emacs.  In terminal mode, shell-mode is used automatically.
;;
;; Terminal compatibility:
;;   This package works in both GUI and terminal Emacs.  All functions are compatible
;;   with terminal mode.  Interactive prompts use standard Emacs minibuffer which
;;   works in all environments.  Browser-based authentication (login) will open
;;   your system's default browser even when running in terminal mode.
;;
;; Doom Emacs / Straight:
;;   With Doom and Straight (:local-repo or :host github), only a subset of
;;   commands may appear in M-x until the package is loaded.  Invoke any
;;   autoloaded command (e.g. cursor-agent-install) once to load the file and
;;   expose all commands.  Do not unload and reload this package in config
;;   (e.g. in after! cursor-agent); that causes recursive load errors between
;;   the Straight build path and the source path.

;;; Code:

(defgroup cursor-agent nil
  "Cursor CLI Agent integration for Emacs."
  :group 'tools
  :prefix "cursor-agent-")

(defcustom cursor-agent-command "agent"
  "Command to run cursor-agent CLI."
  :type 'string
  :group 'cursor-agent)

(defcustom cursor-agent-default-model nil
  "Default model to use.  Set to nil to use CLI default.
Available models can be listed with `agent models'."
  :type '(choice (const nil) string)
  :group 'cursor-agent)

(defcustom cursor-agent-default-output-format "text"
  "Default output format for non-interactive commands.
Options: `text', `json', `stream-json'."
  :type '(choice (const "text") (const "json") (const "stream-json"))
  :group 'cursor-agent)

(defcustom cursor-agent-use-force nil
  "Whether to use --force flag by default for file modifications.
When enabled, allows agent to modify files without confirmation in print mode."
  :type 'boolean
  :group 'cursor-agent)

(defvar cursor-agent-installed-p nil
  "Cached status of cursor-agent installation.")

(defvar cursor-agent-authenticated-p nil
  "Cached status of cursor-agent authentication.")

;;;###autoload
(defun cursor-agent-installed-p ()
  "Check if cursor-agent CLI is installed.
Returns t if `agent' command is available, nil otherwise."
  (if (executable-find cursor-agent-command)
      (progn
        (setq cursor-agent-installed-p t)
        t)
    (setq cursor-agent-installed-p nil)
    nil))

;;;###autoload
(defun cursor-agent-check-auth ()
  "Check if cursor-agent is authenticated.
Returns t if authenticated, nil otherwise.
Updates cached status."
  (if (not (cursor-agent-installed-p))
      (progn
        (setq cursor-agent-authenticated-p nil)
        nil)
    (let ((status-output (shell-command-to-string
                          (format "%s status 2>&1" cursor-agent-command))))
      (if (string-match-p "authenticated\\|Authenticated" status-output)
          (progn
            (setq cursor-agent-authenticated-p t)
            t)
      (setq cursor-agent-authenticated-p nil)
      nil))))

(defun cursor-agent--run-command-in-compilation-buffer (command buffer-name header-text)
  "Run COMMAND in a compilation buffer with proper ANSI color handling.
COMMAND is the shell command to execute.
BUFFER-NAME is the name of the buffer to use.
HEADER-TEXT is the text to insert at the start of the buffer.
Sets the process filter to compilation-filter to ensure ANSI colors are handled."
  (let ((buffer (get-buffer-create buffer-name)))
    (with-current-buffer buffer
      (erase-buffer)
      (when header-text
        (insert header-text))
      (compilation-mode))
    ;; Use async-shell-command but set the filter to compilation-filter
    ;; to ensure compilation-filter-hook runs, which handles ANSI color codes
    (let ((process (async-shell-command command buffer-name)))
      (when process
        (set-process-filter process 'compilation-filter)))
    (pop-to-buffer buffer-name)))

(defun cursor-agent--run-list-command (command buffer-name header-text)
  "Helper function to run a list command with installation check.
COMMAND is the shell command to execute.
BUFFER-NAME is the name of the buffer to use.
HEADER-TEXT is the text to insert at the start of the buffer.
Checks if cursor-agent is installed before running the command."
  (unless (cursor-agent-installed-p)
    (if (y-or-n-p "Cursor Agent CLI not found. Would you like to install it now? ")
        (cursor-agent-install)
      (user-error "Cursor Agent CLI not found.  Run 'M-x cursor-agent-install' to install")))
  (cursor-agent--run-command-in-compilation-buffer
   command
   buffer-name
   header-text))

(defun cursor-agent--local-bin-in-path-p ()
  "Check if ~/.local/bin is in PATH.
Returns t if found, nil otherwise."
  (let ((local-bin (expand-file-name "~/.local/bin"))
        (path (getenv "PATH")))
    (or (string-match-p (regexp-quote local-bin) path)
        (string-match-p (regexp-quote (expand-file-name "~/.local/bin")) path))))

(defun cursor-agent--get-path-instruction (shell)
  "Get PATH configuration instruction for SHELL.
Returns a string with instructions for adding ~/.local/bin to PATH."
  (cond
   ((string-match-p "zsh" shell)
    "  echo 'export PATH=\"$HOME/.local/bin:$PATH\"' >> ~/.zshrc\n  source ~/.zshrc\n")
   ((string-match-p "bash" shell)
    "  echo 'export PATH=\"$HOME/.local/bin:$PATH\"' >> ~/.bashrc\n  source ~/.bashrc\n")
   (t
    "  Add ~/.local/bin to your PATH in your shell configuration file\n")))

(defun cursor-agent--prepare-install-buffer (buffer-name shell path-in-shell)
  "Prepare installation buffer with instructions.
BUFFER-NAME is the buffer to prepare.
SHELL is the user's shell.
PATH-IN-SHELL indicates if ~/.local/bin is in PATH."
  (with-current-buffer (get-buffer-create buffer-name)
    (erase-buffer)
    (insert "Installing Cursor CLI Agent...\n")
    (insert "================================\n\n")
    (insert "This will:\n")
    (insert "1. Download the official installation script\n")
    (insert "2. Run the installation script\n")
    (insert "3. Install agent to ~/.local/bin/\n\n")
    
    (unless path-in-shell
      (insert "[WARNING] ~/.local/bin is not in your PATH.\n")
      (insert "After installation, you may need to add it to your shell config:\n")
      (insert (cursor-agent--get-path-instruction shell))
      (insert "\n"))
    
    (insert "Running installation script...\n\n")
    (compilation-mode)))

(defun cursor-agent--handle-install-success (buffer-name)
  "Handle successful installation.
BUFFER-NAME is the installation buffer."
  (with-current-buffer buffer-name
    (goto-char (point-max))
    (insert "\n" (make-string 50 ?=) "\n")
    (insert "Installation completed!\n\n")
    (insert "[OK] Cursor Agent installed successfully!\n\n")
    (insert "Next steps:\n")
    (insert "1. If ~/.local/bin was not in PATH, restart your shell or Emacs\n")
    (insert "2. Run 'M-x cursor-agent-login' to authenticate\n")
    (insert "3. Run 'M-x cursor-agent-verify-setup' to verify everything is working\n")
    (message "[OK] Cursor Agent installed successfully! Run 'M-x cursor-agent-login' to authenticate.")
    
    ;; Offer to verify setup
    (when (y-or-n-p "Verify installation now? ")
      (cursor-agent-verify-setup)
      (when (and (cursor-agent-installed-p)
                 (not (cursor-agent-check-auth)))
        (when (y-or-n-p "Would you like to authenticate now? ")
          (cursor-agent-login))))))

(defun cursor-agent--handle-install-failure (buffer-name)
  "Handle installation failure.
BUFFER-NAME is the installation buffer."
  (with-current-buffer buffer-name
    (goto-char (point-max))
    (insert "\n" (make-string 50 ?=) "\n")
    (insert "Installation completed!\n\n")
    (insert "[WARNING] Installation may have completed, but agent command not found.\n\n")
    (insert "Possible issues:\n")
    (insert "1. ~/.local/bin is not in your PATH\n")
    (insert "2. Installation script failed silently\n\n")
    (insert "Try:\n")
    (insert "- Restart your shell or Emacs\n")
    (insert "- Manually add ~/.local/bin to PATH\n")
    (insert "- Run: curl https://cursor.com/install -fsS | bash\n")
    (message "[WARNING] Installation completed, but agent not found in PATH. You may need to restart Emacs.")))

(defun cursor-agent--install-sentinel (buffer-name)
  "Return a process sentinel for installation.
BUFFER-NAME is the installation buffer."
  (lambda (_proc event)
    (when (string-match-p "finished\\|exited" event)
      ;; Wait a moment for PATH to update, then verify
      (sit-for 1)
      (let ((installed (cursor-agent-installed-p)))
        (if installed
            (cursor-agent--handle-install-success buffer-name)
          (cursor-agent--handle-install-failure buffer-name))))))

;;;###autoload
(defun cursor-agent-install ()
  "Install Cursor CLI Agent.
Downloads and installs the agent using the official installation script.
Checks for prerequisites (curl) and handles PATH configuration.
After installation, prompts to verify setup and optionally authenticate."
  (interactive)
  ;; Check if already installed
  (cond
   ((and (cursor-agent-installed-p)
         (not (y-or-n-p "Cursor Agent appears to be installed. Reinstall anyway? ")))
    (message "Installation cancelled - Cursor Agent is already installed")
    nil)
   (t
    ;; If reinstalling, clear the cache
    (when (cursor-agent-installed-p)
      (setq cursor-agent-installed-p nil))
    
    ;; Check for curl
    (unless (executable-find "curl")
      (user-error "curl is required for installation.  Please install curl first"))
    
    ;; Setup installation
    (let ((shell (or (getenv "SHELL") "/bin/bash"))
          (install-script "curl https://cursor.com/install -fsS | bash")
          (buffer-name "*cursor-agent-install*")
          (path-in-shell (cursor-agent--local-bin-in-path-p)))
      
      ;; Prepare installation buffer
      (cursor-agent--prepare-install-buffer buffer-name shell path-in-shell)
      (pop-to-buffer buffer-name)
      
      ;; Run installation
      (let ((process (start-process
                      "cursor-agent-install"
                      buffer-name
                      shell
                      "-c"
                      install-script)))
        (set-process-sentinel process (cursor-agent--install-sentinel buffer-name)))
      
      ;; Return nil since installation is async
      nil)))

;;;###autoload
(defun cursor-agent-verify-setup ()
  "Verify cursor-agent installation and authentication.
Shows a message with status and returns t if ready, nil otherwise."
  (interactive)
  (let ((installed (cursor-agent-installed-p))
        (authenticated (when (and installed (fboundp 'cursor-agent-check-auth))
                         (cursor-agent-check-auth))))
    (cond
     ((not installed)
      (if (y-or-n-p "Cursor Agent CLI not found. Would you like to install it now? ")
          (cursor-agent-install)
        (message "[ERROR] Cursor Agent CLI not found. Run 'M-x cursor-agent-install' to install."))
      nil)
     ((not authenticated)
      (message "[WARNING] Cursor Agent not authenticated. Run 'M-x cursor-agent-login' to authenticate")
      nil)
     (t
      (message "[OK] Cursor Agent is installed and authenticated")
      t))))

;;;###autoload
(defun cursor-agent-prompt (prompt &optional model output-format)
  "Run cursor-agent with a prompt in a new buffer.
PROMPT is the prompt to send to the agent.
MODEL optionally specifies the model to use (defaults to cursor-agent-default-model).
OUTPUT-FORMAT optionally specifies output format (defaults to cursor-agent-default-output-format).
ANSI color codes are automatically handled by `compilation-mode'."
  (interactive
   (list
    (read-string "Prompt: ")
    (when current-prefix-arg
      (read-string "Model (empty for default): "))
    (when (equal current-prefix-arg '(4))
      (completing-read "Output format: " '("text" "json" "stream-json") nil t))))
  (unless (cursor-agent-verify-setup)
    (user-error "Cursor Agent not properly set up"))
  (let* ((model-arg (if model (format " --model %s" model)
                      (if cursor-agent-default-model
                          (format " --model %s" cursor-agent-default-model)
                        "")))
         (format-arg (if output-format
                         (format " --output-format %s" output-format)
                       (if (not (string= cursor-agent-default-output-format "text"))
                           (format " --output-format %s" cursor-agent-default-output-format)
                         "")))
         (force-arg (if cursor-agent-use-force " --force" ""))
         (buffer-name "*cursor-agent*")
         (command (format "%s -p %s%s%s%s"
                          cursor-agent-command
                          (shell-quote-argument prompt)
                          model-arg
                          format-arg
                          force-arg)))
    (cursor-agent--run-command-in-compilation-buffer
     command
     buffer-name
     (format "Running: %s\n\n" command))))

;;;###autoload
(defun cursor-agent-interactive (&optional initial-prompt)
  "Start an interactive cursor-agent session in a new buffer.
INITIAL-PROMPT optionally provides an initial prompt to send.
Uses vterm if available in GUI mode for better terminal emulation,
otherwise falls back to shell-mode (works in both GUI and terminal Emacs).
vterm automatically handles OSC escape sequences (like window title changes)."
  (interactive "sInitial prompt (optional): ")
  (unless (cursor-agent-installed-p)
    (if (y-or-n-p "Cursor Agent CLI not found. Would you like to install it now? ")
        (cursor-agent-install)
      (user-error "Cursor Agent CLI not found.  Run 'M-x cursor-agent-install' to install")))
  ;; Try to use vterm if available and in GUI mode, otherwise fall back to shell-mode
  ;; vterm may not work well in terminal Emacs, so prefer shell-mode in terminal
  (if (and (display-graphic-p)
           (require 'vterm nil t))
      ;; Use vterm for better terminal emulation
      (let ((buffer-name "*cursor-agent-interactive*"))
        (if (and (get-buffer buffer-name)
                 (buffer-live-p (get-buffer buffer-name))
                 (get-buffer-process buffer-name))
            ;; Buffer exists and is active, switch to it
            (switch-to-buffer buffer-name)
          ;; Create new vterm buffer
          (with-current-buffer (vterm buffer-name)
            ;; Wait a moment for vterm to fully initialize
            (sit-for 0.1)
            ;; Start cursor-agent with optional initial prompt
            (if initial-prompt
                ;; Quote the prompt to handle special characters safely
                (vterm-send-string (format "agent %s\n" (shell-quote-argument initial-prompt)))
              (vterm-send-string "agent\n"))
            (switch-to-buffer buffer-name))))
    ;; Fallback to shell-mode if vterm is not available
    (let ((buffer-name "*cursor-agent-interactive*"))
      (if (and (get-buffer buffer-name)
               (buffer-live-p (get-buffer buffer-name))
               (get-buffer-process buffer-name))
          (switch-to-buffer buffer-name)
        (with-current-buffer (get-buffer-create buffer-name)
          (erase-buffer)
          (shell-mode))
        (switch-to-buffer buffer-name)
        (comint-send-input)
        (insert (if initial-prompt
                    (format "agent %s" (shell-quote-argument initial-prompt))
                  "agent"))
        (comint-send-input)))))

;;;###autoload
(defun cursor-agent-region (start end &optional model)
  "Send selected region to cursor-agent for processing.
START and END are the region boundaries.
MODEL optionally specifies the model to use.
ANSI color codes are automatically handled by compilation-mode."
  (interactive "r\nsModel (optional): ")
  (unless (cursor-agent-verify-setup)
    (user-error "Cursor Agent not properly set up"))
  (let* ((text (buffer-substring-no-properties start end))
         (model-arg (if model (format " --model %s" model)
                      (if cursor-agent-default-model
                          (format " --model %s" cursor-agent-default-model)
                        "")))
         (force-arg (if cursor-agent-use-force " --force" ""))
         (buffer-name "*cursor-agent*")
         (command (format "echo %s | %s -p \"process this code:\"%s%s"
                          (shell-quote-argument text)
                          cursor-agent-command
                          model-arg
                          force-arg)))
    (cursor-agent--run-command-in-compilation-buffer
     command
     buffer-name
     (format "Processing region with cursor-agent:\n\n%s\n\n" text))))

;;;###autoload
(defun cursor-agent-resume (&optional chat-id)
  "Resume a previous cursor-agent conversation.
CHAT-ID optionally specifies which conversation to resume.
If not provided, resumes the most recent conversation."
  (interactive)
  (unless (cursor-agent-installed-p)
    (if (y-or-n-p "Cursor Agent CLI not found. Would you like to install it now? ")
        (cursor-agent-install)
      (user-error "Cursor Agent CLI not found.  Run 'M-x cursor-agent-install' to install")))
  (let ((buffer-name "*cursor-agent-interactive*")
        (resume-arg (if chat-id
                        (format " --resume=%s" chat-id)
                      " resume")))
    (if (and (get-buffer buffer-name)
             (buffer-live-p (get-buffer buffer-name))
             (get-buffer-process buffer-name))
        (switch-to-buffer buffer-name)
      ;; Try vterm first if in GUI mode, fallback to shell-mode
      (if (and (display-graphic-p)
               (require 'vterm nil t))
          (with-current-buffer (vterm buffer-name)
            (sit-for 0.1)
            (vterm-send-string (format "agent%s\n" resume-arg))
            (switch-to-buffer buffer-name))
        (with-current-buffer (get-buffer-create buffer-name)
          (erase-buffer)
          (shell-mode))
        (switch-to-buffer buffer-name)
        (comint-send-input)
        (insert (format "agent%s" resume-arg))
        (comint-send-input)))))

;;;###autoload
(defun cursor-agent-list-sessions ()
  "List all previous cursor-agent conversations.
Opens a buffer showing the list of available sessions.
ANSI color codes are automatically handled by `compilation-mode'."
  (interactive)
  (cursor-agent--run-list-command
   (format "%s ls" cursor-agent-command)
   "*cursor-agent-sessions*"
   "Cursor Agent Sessions:\n\n"))

;;;###autoload
(defun cursor-agent-login ()
  "Authenticate with cursor-agent using browser flow.
Opens browser for authentication.  Works in both GUI and terminal Emacs.
In terminal mode, the browser will open in your system's default browser."
  (interactive)
  (unless (cursor-agent-installed-p)
    (if (y-or-n-p "Cursor Agent CLI not found. Would you like to install it now? ")
        (cursor-agent-install)
      (user-error "Cursor Agent CLI not found.  Run 'M-x cursor-agent-install' to install")))
  (let ((buffer-name "*cursor-agent-login*"))
    (with-current-buffer (get-buffer-create buffer-name)
      (erase-buffer)
      (insert "Authenticating with Cursor Agent...\n\n")
      (compilation-mode))
    ;; Set process filter to compilation-filter to ensure ANSI colors are handled
    (let ((process (async-shell-command
                    (format "%s login" cursor-agent-command)
                    buffer-name)))
      (when process
        (set-process-filter process 'compilation-filter)))
    (pop-to-buffer buffer-name)))

;;;###autoload
(defun cursor-agent-status ()
  "Show cursor-agent authentication status and configuration.
ANSI color codes are automatically handled by `compilation-mode'."
  (interactive)
  (cursor-agent--run-list-command
   (format "%s status" cursor-agent-command)
   "*cursor-agent-status*"
   "Cursor Agent Status:\n\n"))

;;;###autoload
(defun cursor-agent-list-models ()
  "List all available models for cursor-agent.
ANSI color codes are automatically handled by `compilation-mode'."
  (interactive)
  (cursor-agent--run-list-command
   (format "%s models" cursor-agent-command)
   "*cursor-agent-models*"
   "Available Cursor Agent Models:\n\n"))

;;;###autoload
(defun cursor-agent-mcp-list ()
  "List configured MCP servers for cursor-agent.
MCP (Model Context Protocol) servers extend cursor-agent functionality.
ANSI color codes are automatically handled by `compilation-mode'."
  (interactive)
  (cursor-agent--run-list-command
   (format "%s mcp list" cursor-agent-command)
   "*cursor-agent-mcp*"
   "Cursor Agent MCP Servers:\n\n"))

;;;###autoload
(defun cursor-agent-shell-mode ()
  "Start cursor-agent in shell mode for quick command execution.
Shell mode allows running shell commands directly from the CLI.
Commands timeout after 30 seconds and are non-interactive.
Works in both GUI and terminal Emacs."
  (interactive)
  (unless (cursor-agent-installed-p)
    (if (y-or-n-p "Cursor Agent CLI not found. Would you like to install it now? ")
        (cursor-agent-install)
      (user-error "Cursor Agent CLI not found.  Run 'M-x cursor-agent-install' to install")))
  ;; Try vterm first if in GUI mode, fallback to shell-mode (works in terminal)
  (if (and (display-graphic-p)
           (require 'vterm nil t))
      (let ((buffer-name "*cursor-agent-shell*"))
        (if (and (get-buffer buffer-name)
                 (buffer-live-p (get-buffer buffer-name))
                 (get-buffer-process buffer-name))
            (switch-to-buffer buffer-name)
          (with-current-buffer (vterm buffer-name)
            (sit-for 0.1)
            (vterm-send-string "agent\n")
            (vterm-send-string "/shell\n")  ; Enter shell mode
            (switch-to-buffer buffer-name))))
    ;; Fallback to shell-mode
    (let ((buffer-name "*cursor-agent-shell*"))
      (if (and (get-buffer buffer-name)
               (buffer-live-p (get-buffer buffer-name))
               (get-buffer-process buffer-name))
          (switch-to-buffer buffer-name)
        (with-current-buffer (get-buffer-create buffer-name)
          (erase-buffer)
          (shell-mode))
        (switch-to-buffer buffer-name)
        (comint-send-input)
        (insert "agent")
        (comint-send-input)
        (insert "/shell")
        (comint-send-input)))))

;;;###autoload
(defun cursor-agent-update ()
  "Update cursor-agent CLI to the latest version."
  (interactive)
  (unless (cursor-agent-installed-p)
    (if (y-or-n-p "Cursor Agent CLI not found. Would you like to install it now? ")
        (cursor-agent-install)
      (user-error "Cursor Agent CLI not found.  Run 'M-x cursor-agent-install' to install")))
  (let ((buffer-name "*cursor-agent-update*"))
    (with-current-buffer (get-buffer-create buffer-name)
      (erase-buffer)
      (insert "Updating Cursor Agent CLI...\n\n")
      (compilation-mode))
    (async-shell-command
     (format "%s update" cursor-agent-command)
     buffer-name)
    (pop-to-buffer buffer-name)))

;;;###autoload
(defun cursor-agent-readme ()
  "Display the README file for cursor-agent.
Opens the README.md file in a new buffer for viewing."
  (interactive)
  (let ((readme-file (expand-file-name
                      "README.md"
                      (file-name-directory
                       (or (locate-library "cursor-agent" t)
                           (buffer-file-name)
                           default-directory)))))
    (if (file-exists-p readme-file)
        (progn
          (find-file readme-file)
          (view-mode)
          (message "Press 'q' to quit view mode"))
      (user-error "README.md not found.  Please ensure the package is properly installed")))))

(provide 'cursor-agent)

;;; cursor-agent.el ends here
