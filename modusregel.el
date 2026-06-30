;;; modusregel.el --- Mode line customizations -*- lexical-binding: t -*-

;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;; Version: 0.3.6
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

(defcustom modusregel-line-number-str "%l"
  "String to use as expression to show current line number."
  :type 'string
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
  '(:eval (when (buffer-modified-p) "++"))
  "String to use to show that a buffer is modified and unsaved."
  :type 'string
  :group 'modusregel)

(defcustom modusregel-major-mode-alist
  '((bash-ts-mode . "Shell")
    (bibtex-mode . "BibTeX")
    (c-mode . "C")
    (c-ts-mode . "C")
    (c++-mode . "C++")
    (c++-ts-mode . "C++")
    (cmake-mode . "CMake")
    (comint-mode . "Comint")
    (compilation-mode . "Compile")
    (conf-javaprop-mode . "Props (Java)")
    (conf-mode . "Conf")
    (conf-space-mode . "Conf")
    (conf-unix-mode . "Conf")
    (css-mode . "CSS")
    (css-ts-mode . "CSS")
    (custom-mode . "Customize")
    (deadgrep-mode . "Grep")
    (diff-mode . "Diff")
    (dired-mode . "Dired")
    (doc-view-mode . "Document")
    (dockerfile-mode . "Containerfile")
    (dockerfile-ts-mode . "Containerfile")
    (editorconfig-conf-mode . "EditorConfig")
    (elpaca-log-mode . "Elpaca")
    (emacs-lisp-mode . "ELisp")
    (eshell-mode . "EShell")
    (fundamental-mode . "Fundamental")
    (gitattributes-mode . "Git Attributes")
    (gitconfig-mode . "Git Config")
    (gitignore-mode . "Git Ignore")
    (go-mode . "Go")
    (go-ts-mode . "Go")
    (graphql-mode . "GraphQL")
    (grep-mode . "Grep")
    (haskell-mode . "Haskell")
    (help-mode . "Help")
    (html-mode . "HTML")
    (ielm-mode . "IELM")
    (image-mode . "Image")
    (info-mode . "Info")
    (java-mode . "Java")
    (js-json-mode . "JSON")
    (json-mode . "JSON")
    (json-ts-mode . "JSON")
    (just-mode . "Just")
    (kotlin-mode . "Kotlin")
    (kotlin-ts-mode . "Kotlin")
    (kubernetes-display-thing-mode . "K8s")
    (kubernetes-logs-mode . "K8s logs")
    (kubernetes-overview-mode . "K8s overview")
    (latex-mode . "LaTeX")
    (lisp-interaction-mode . "ELisp")
    (lua-mode . "Lua")
    (magit-diff-mode . "Git Diff")
    (magit-log-mode . "Git Log")
    (magit-status-mode . "Git Status")
    (makefile-gmake-mode . "Make")
    (markdown-mode . "Markdown")
    (messages-buffer-mode . "Messages")
    (nix-ts-mode . "Nix")
    (occur-mode . "Occur")
    (org-agenda-mode . "Org Agenda")
    (org-mode . "Org")
    (package-menu-mode . "Packages")
    (pdf-view-mode . "PDF")
    (php-mode . "PHP")
    (po-mode . "PO")
    (python-mode . "Python")
    (python-ts-mode . "Python")
    (ruby-mode . "Ruby")
    (ruby-ts-mode . "Ruby")
    (rust-mode . "Rust")
    (rust-ts-mode . "Rust")
    (scala-mode . "Scala")
    (scala-ts-mode . "Scala")
    (scheme-mode . "Scheme")
    (scss-mode . "SCSS")
    (sh-mode . "Shell")
    (shell-command-mode . "Shell")
    (shell-mode . "Shell")
    (sql-mode . "SQL")
    (term-mode . "Terminal")
    (text-mode . "Text")
    (toml-mode . "TOML")
    (toml-ts-mode . "TOML")
    (typescript-mode . "TypeScript")
    (typescript-ts-mode . "TypeScript")
    (vterm-mode . "VTerm")
    (wdired-mode . "WDired")
    (yaml-mode . "YAML")
    (yaml-ts-mode . "YAML"))
  "A mapping of major-mode names to more readable versions."
  :type 'alist
  :group 'modusregel)

(defun modusregel-major-mode-name (raw-name)
  "Convert a RAW-NAME of a major mode into a prettier more readable version."
  (let* ((mapped-name (cdr (assoc raw-name modusregel-major-mode-alist)))
         (resulting-mapped-name (or mapped-name (format "%s" raw-name))))
    resulting-mapped-name))

(defvar modusregel-major-mode-expr
  '(:eval (modusregel-major-mode-name major-mode))
  "Representation of the major mode in the mode line.")

(defvar modusregel-nyan-expr
  '(:eval (list (nyan-create)))
  "Nyan indicator")

(defvar modusregel-format
  (list
   modusregel-leading-str
   modusregel-buffer-name-expr
   modusregel-buffer-modified-str
   modusregel-spacer-str
   modusregel-line-number-str
   modusregel-spacer-str
   modusregel-buffer-position-str
   modusregel-spacer-str
   modusregel-vc-expr
   modusregel-major-mode-expr
   modusregel-spacer-str
   modusregel-flymake-expr)
  "The mode-line format to be used.")


(provide 'modusregel)

;;; modusregel.el ends here
