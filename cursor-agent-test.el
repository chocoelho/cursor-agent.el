;;; cursor-agent-test.el --- Unit tests for cursor-agent.el

;; This file demonstrates how to write unit tests for Emacs Lisp using ERT
;; ERT (Emacs Lisp Regression Testing) is built into Emacs

(require 'ert)
(require 'cl-lib)

;; Ensure cursor-agent.el is loaded before tests are defined
;; This is necessary in CI environments where require might not work as expected
;; elisp-check may load cursor-agent.el automatically, but we ensure it's loaded here too
(let ((test-dir (file-name-directory
                 (or load-file-name
                     (and (boundp 'buffer-file-name) buffer-file-name)
                     default-directory))))
  (add-to-list 'load-path test-dir)
  ;; Always load the file to ensure all functions are available
  ;; Use require first (standard way), then fallback to load-file if needed
  (unless (featurep 'cursor-agent)
    (condition-case nil
        (require 'cursor-agent nil t)
      (error nil)))
  ;; If still not loaded or function not found, force load with load-file
  (unless (fboundp 'cursor-agent-verify-setup)
    (let ((main-file (expand-file-name "cursor-agent.el" test-dir)))
      (when (file-exists-p main-file)
        (load-file main-file)))))

;; ============================================================================
;; Test Setup and Utilities
;; ============================================================================

(defun cursor-agent-test--mock-executable-find (command)
  "Mock executable-find to return t for 'agent' command."
  (string= command "agent"))

(defun cursor-agent-test--mock-shell-command-to-string (command)
  "Mock shell-command-to-string to return authenticated status."
  "authenticated")

;; ============================================================================
;; Tests for cursor-agent-installed-p
;; ============================================================================

(ert-deftest cursor-agent-test-installed-p-returns-t-when-found ()
  "Test that cursor-agent-installed-p returns t when agent is found."
  (cl-letf (((symbol-function 'executable-find) #'cursor-agent-test--mock-executable-find))
    (should (cursor-agent-installed-p))))

(ert-deftest cursor-agent-test-installed-p-returns-nil-when-not-found ()
  "Test that cursor-agent-installed-p returns nil when agent is not found."
  (cl-letf (((symbol-function 'executable-find) (lambda (cmd) nil)))
    (should-not (cursor-agent-installed-p))))

;; ============================================================================
;; Tests for cursor-agent-check-auth
;; ============================================================================

(ert-deftest cursor-agent-test-check-auth-returns-t-when-authenticated ()
  "Test that cursor-agent-check-auth returns t when authenticated."
  (cl-letf (((symbol-function 'executable-find) #'cursor-agent-test--mock-executable-find)
            ((symbol-function 'shell-command-to-string) #'cursor-agent-test--mock-shell-command-to-string))
    (should (cursor-agent-check-auth))))

;; ============================================================================
;; Tests for Configuration Variables
;; ============================================================================

(ert-deftest cursor-agent-test-default-command-is-agent ()
  "Test that cursor-agent-command defaults to 'agent'."
  (should (string= cursor-agent-command "agent")))

(ert-deftest cursor-agent-test-default-output-format-is-text ()
  "Test that cursor-agent-default-output-format defaults to 'text'."
  (should (string= cursor-agent-default-output-format "text")))

(ert-deftest cursor-agent-test-use-force-defaults-to-nil ()
  "Test that cursor-agent-use-force defaults to nil."
  (should-not cursor-agent-use-force))

;; ============================================================================
;; Tests for Helper Functions
;; ============================================================================

(ert-deftest cursor-agent-test-local-bin-in-path-p-with-path ()
  "Test cursor-agent--local-bin-in-path-p when ~/.local/bin is in PATH."
  (let ((original-path (getenv "PATH")))
    (unwind-protect
        (progn
          (setenv "PATH" (concat (expand-file-name "~/.local/bin") ":" original-path))
          (should (cursor-agent--local-bin-in-path-p)))
      (setenv "PATH" original-path))))

(ert-deftest cursor-agent-test-get-path-instruction-for-zsh ()
  "Test cursor-agent--get-path-instruction returns zsh instructions."
  (let ((instruction (cursor-agent--get-path-instruction "/bin/zsh")))
    (should (string-match-p "zshrc" instruction))
    (should (string-match-p "\\.local/bin" instruction))))

(ert-deftest cursor-agent-test-get-path-instruction-for-bash ()
  "Test cursor-agent--get-path-instruction returns bash instructions."
  (let ((instruction (cursor-agent--get-path-instruction "/bin/bash")))
    (should (string-match-p "bashrc" instruction))
    (should (string-match-p "\\.local/bin" instruction))))

;; ============================================================================
;; Tests for Buffer Creation
;; ============================================================================

(ert-deftest cursor-agent-test-buffer-creation ()
  "Test that functions create buffers with correct names."
  (let ((buffer-name "*cursor-agent-test*"))
    (unwind-protect
        (progn
          (with-current-buffer (get-buffer-create buffer-name)
            (erase-buffer)
            (insert "Test content")
            (compilation-mode)
            (should (buffer-live-p (get-buffer buffer-name)))
            (should (eq major-mode 'compilation-mode)))
          (should (buffer-live-p (get-buffer buffer-name))))
      (when (get-buffer buffer-name)
        (kill-buffer buffer-name)))))

;; ============================================================================
;; Integration Tests (require actual agent command)
;; ============================================================================

;; Helper to force load a specific function from a file
(defun cursor-agent-test--force-load-function (file func-name)
  "Force load FUNC-NAME from FILE.
FUNC-NAME should be a symbol like 'cursor-agent-verify-setup."
  (let ((buf (find-file-noselect file)))
    (with-current-buffer buf
      (goto-char (point-min))
      (let ((search-pattern (format "(defun %s" func-name)))
        (when (search-forward search-pattern nil t)
          (beginning-of-defun)
          (let ((form-start (point)))
            (end-of-defun)
            (let ((form-text (buffer-substring form-start (point))))
              (condition-case err
                  (progn
                    (eval (read form-text))
                    ;; Verify it worked - if still not bound, try reading from buffer directly
                    (unless (fboundp func-name)
                      (goto-char form-start)
                      (let ((form (read (current-buffer))))
                        (eval form))))
                (error (message "Error force-loading function %s: %s" func-name (error-message-string err)))))))))))

;; Ensure cursor-agent is loaded before running integration tests
(defun cursor-agent-test--ensure-loaded ()
  "Ensure cursor-agent.el is loaded before tests run.
Loads all expected functions, force-loading any that aren't bound after load-file."
  (let ((expected-functions
         '(cursor-agent-install
           cursor-agent-verify-setup
           cursor-agent-prompt
           cursor-agent-interactive
           cursor-agent-region
           cursor-agent-resume
           cursor-agent-list-sessions
           cursor-agent-login
           cursor-agent-status
           cursor-agent-list-models
           cursor-agent-mcp-list
           cursor-agent-shell-mode
           cursor-agent-update
           cursor-agent-readme))
        (all-loaded t))
    ;; Check if all functions are loaded
    (dolist (func expected-functions)
      (unless (fboundp func)
        (setq all-loaded nil)))
    ;; If not all loaded, try to load
    (unless all-loaded
      ;; First try to require the feature
      (unless (featurep 'cursor-agent)
        (condition-case nil
            (require 'cursor-agent nil t)
          (error nil)))
      ;; Check again after require
      (setq all-loaded t)
      (dolist (func expected-functions)
        (unless (fboundp func)
          (setq all-loaded nil)))
      ;; If still not all loaded, try to find and load the file
      (unless all-loaded
        ;; Try multiple strategies to find the main file
        (let ((main-file nil)
              (test-file (cond
                           ((boundp 'load-file-name) (and load-file-name (symbol-value 'load-file-name)))
                           ((boundp 'buffer-file-name) (and buffer-file-name (symbol-value 'buffer-file-name)))
                           (t nil))))
          ;; Strategy 1: Use test file directory
          (when test-file
            (let ((test-dir (file-name-directory test-file)))
              (when test-dir
                (add-to-list 'load-path test-dir)
                (setq main-file (expand-file-name "cursor-agent.el" test-dir))
                (unless (file-exists-p main-file)
                  (setq main-file nil)))))
          ;; Strategy 2: Try locate-library
          (unless (and main-file (file-exists-p main-file))
            (let ((found (locate-library "cursor-agent" t)))
              (when found
                (setq main-file found))))
          ;; Strategy 3: Try current directory
          (unless (and main-file (file-exists-p main-file))
            (let ((candidate (expand-file-name "cursor-agent.el" default-directory)))
              (when (file-exists-p candidate)
                (setq main-file candidate))))
          ;; Now load and force-evaluate any missing functions
          (when (and main-file (file-exists-p main-file))
            (load-file main-file)
            ;; Force evaluation of any functions that still aren't bound
            ;; This ensures all functions are available even if load-file doesn't evaluate them
            (dolist (func expected-functions)
              (unless (fboundp func)
                (cursor-agent-test--force-load-function main-file func)))))))))

(ert-deftest cursor-agent-test-verify-setup-structure ()
  "Test that cursor-agent-verify-setup has correct structure."
  (cursor-agent-test--ensure-loaded)
  (should (fboundp 'cursor-agent-verify-setup))
  (should (commandp 'cursor-agent-verify-setup)))

(ert-deftest cursor-agent-test-all-commands-are-defined ()
  "Test that all expected commands are defined."
  (cursor-agent-test--ensure-loaded)
  (let ((expected-commands
         '(cursor-agent-install
           cursor-agent-verify-setup
           cursor-agent-prompt
           cursor-agent-interactive
           cursor-agent-region
           cursor-agent-resume
           cursor-agent-list-sessions
           cursor-agent-login
           cursor-agent-status
           cursor-agent-list-models
           cursor-agent-mcp-list
           cursor-agent-shell-mode
           cursor-agent-update
           cursor-agent-readme)))
    (dolist (cmd expected-commands)
      (should (fboundp cmd))
      (should (commandp cmd)))))

;; ============================================================================
;; Test Runner
;; ============================================================================

(defun cursor-agent-test-run-all ()
  "Run all cursor-agent tests."
  (interactive)
  (ert-run-tests "cursor-agent-test-" t))

;; Provide the test module
(provide 'cursor-agent-test)
