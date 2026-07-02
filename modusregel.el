;;; modusregel.el --- Mode line customizations -*- lexical-binding: t -*-

;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;; Version: 0.4.2
;; Author: Josep Bigorra <jjbigorra@gmail.com>
;; Maintainer: Josep Bigorra <jjbigorra@gmail.com>
;; URL: https://codeberg.org/jjba23/modusregel
;; Keywords: faces
;; Package: modusregel
;; Package-Requires: ((emacs "28.1"))

;; This file is part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; remember that mode-line-format is window-local
;; this means that to persist changes and set it globally
;; one must use setq-default
;; and for tweaking change it temporarily to setq
;;
;; (setq mode-line-format modusregel-format)
;; (setq-default mode-line-format modusregel-format)

;;; Code:

(defgroup modusregel ()
  "Simple and effective mode line customizations for your Emacs."
  :group 'tools)

(defcustom modusregel-leading-str " 𝝺  "
  "String to use at the very start of the mode line."
  :type 'string
  :group 'modusregel)

(defcustom modusregel-spacer-str "  "
  "String to use as spacer between mode line items."
  :type 'string
  :group 'modusregel)

(defcustom modusregel-line-number-str '("%l")
  "List containing the line number format construct."
  :type 'sexp
  :group 'modusregel)

(defcustom modusregel-column-number-str '(":%c")
  "List containing the column number format construct."
  :type 'sexp
  :group 'modusregel)

(defcustom modusregel-buffer-position-str "%o"
  "String to use as expression to show current position in buffer."
  :type 'string
  :group 'modusregel)

(defvar modusregel-vc-expr
  '(:eval (when-let (vc vc-mode)
            (list
             (substring vc 5)
             modusregel-spacer-str))))

(defvar modusregel-flymake-expr
  '(:eval (ignore-errors (flymake--mode-line-counters))))

(defvar modusregel-buffer-name-expr
  (propertize "%b" 'face 'bold 'help-echo (buffer-file-name)))

(defcustom modusregel-buffer-modified-str
  '(:eval (when (buffer-modified-p) "●"))
  "String to use to show that a buffer is modified and unsaved."
  :type 'string
  :group 'modusregel)

(defcustom modusregel-buffer-read-only-str
  '(:eval (when buffer-read-only " ☡"))
  "String to show when the buffer is read-only."
  :type 'string
  :group 'modusregel)

(defvar modusregel-narrowed-expr
  '(:eval (when (buffer-narrowed-p) " [Narrow]")))

(defvar modusregel-remote-expr
  '(:eval (when (file-remote-p default-directory) " ☍ ")))

(defvar modusregel-eglot-expr
  '(:eval (when (bound-and-true-p eglot--managed-mode)
            (propertize " 𝌤 " 'help-echo "Eglot LSP Active"))))

(defcustom modusregel-major-mode-alist
  '((bash-mode . "Shell")
    (sh-mode . "Shell")
    (shell-mode . "Shell")
    (shell-command-mode . "Shell")
    (bibtex-mode . "BibTeX")
    (c++-mode . "C++")
    (cmake-mode . "CMake")
    (compilation-mode . "Compile")
    (conf-javaprop-mode . "Props (Java)")
    (css-mode . "CSS")
    (custom-mode . "Customize")
    (deadgrep-mode . "Grep")
    (doc-view-mode . "Document")
    (dockerfile-mode . "Containerfile")
    (emacs-lisp-mode . "ELisp")
    (elpaca-log-mode . "Elpaca")
    (eshell-mode . "EShell")
    (gitattributes-mode . "Git Attributes")
    (gitconfig-mode . "Git Config")
    (gitignore-mode . "Git Ignore")
    (graphql-mode . "GraphQL")
    (html-mode . "HTML")
    (ielm-mode . "IELM")
    (js-json-mode . "JSON")
    (json-mode . "JSON")
    (kubernetes-display-thing-mode . "K8s")
    (kubernetes-logs-mode . "K8s logs")
    (kubernetes-overview-mode . "K8s overview")
    (latex-mode . "LaTeX")
    (lisp-interaction-mode . "ELisp")
    (magit-diff-mode . "Git Diff")
    (magit-log-mode . "Git Log")
    (magit-status-mode . "Git Status")
    (makefile-gmake-mode . "Make")
    (org-agenda-mode . "Org Agenda")
    (package-menu-mode . "Packages")
    (pdf-view-mode . "PDF")
    (php-mode . "PHP")
    (po-mode . "PO")
    (sql-mode . "SQL")
    (term-mode . "Terminal")
    (toml-mode . "TOML")
    (typescript-mode . "TypeScript")
    (vterm-mode . "VTerm")
    (wdired-mode . "WDired")
    (yaml-mode . "YAML"))
  "A mapping of major-mode names to more readable versions."
  :type 'alist
  :group 'modusregel)

(defun modusregel-major-mode-name (raw-name)
  "Convert a RAW-NAME of a major mode into a prettier more readable version."
  (let* ((name-str (symbol-name raw-name))
         ;; Map tree-sitter modes to standard modes for alist matching
         (clean-sym (intern (replace-regexp-in-string "-ts-mode$" "-mode" name-str)))
         (mapped-name (cdr (assoc clean-sym modusregel-major-mode-alist))))
    (or mapped-name
        ;; Fallback: Strip suffix and capitalize (e.g., rust-mode -> Rust)
        (let ((base (replace-regexp-in-string "-\\(ts-\\)?mode$" "" name-str)))
          (capitalize base)))))

(defvar modusregel-major-mode-expr
  '(:eval (modusregel-major-mode-name major-mode))
  "Representation of the major mode in the mode line.")

(defvar modusregel-nyan-expr
  '(:eval (list (nyan-create)))
  "Nyan Cat indicator (needs nyan cat package).")

(defvar modusregel-format
  (list
   modusregel-leading-str
   modusregel-remote-expr
   modusregel-buffer-name-expr
   modusregel-buffer-modified-str
   modusregel-buffer-read-only-str
   modusregel-spacer-str
   modusregel-line-number-str
   modusregel-column-number-str
   modusregel-spacer-str
   modusregel-buffer-position-str
   modusregel-spacer-str
   modusregel-vc-expr
   modusregel-major-mode-expr
   modusregel-eglot-expr
   modusregel-spacer-str
   modusregel-flymake-expr)
  "The mode-line format to be used.")


(provide 'modusregel)

;;; modusregel.el ends here
