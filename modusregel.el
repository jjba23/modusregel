;;; modusregel.el --- Mode line customizations -*- lexical-binding: t -*-

;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;; SPDX-License-Identifier: MIT

;; Version: 0.9.0
;; Author: Josep Bigorra <jjbigorra@gmail.com>
;; Maintainer: Josep Bigorra <jjbigorra@gmail.com>
;; URL: https://github.com/jjba23/modusregel
;; Keywords: faces
;; Package: modusregel
;; Package-Requires: ((emacs "29.1"))

;;; Commentary:

;; modusregel draws the Emacs mode line (the bottom bar) out of the
;; elements defined below.  Each element is a variable of this package,
;; so you can change it, reorder it or leave it out.
;;
;; Install it either way:
;;
;;   ;; 1. Let the mode do it: `mode-line-format' is a per-window
;;   ;;    variable, and this sets its default, which every window that
;;   ;;    does not override it follows.
;;   (modusregel-mode 1)
;;
;;   ;; 2. Or by hand, which is the same thing spelled out.
;;   (setq-default mode-line-format modusregel-format)
;;
;; `modusregel-format' is a list of the symbols of the element
;; variables, exactly as the mode line Emacs starts with is a list of
;; symbols like `mode-line-buffer-identification'.  The mode line
;; resolves them when it draws, so setting one of them -- from Lisp or
;; from Customize -- is visible at the next redisplay, with no need to
;; reload anything.
;;
;; Two rules of `mode-line-format' are worth knowing before editing the
;; list, because both fail quietly:
;;
;; - A list whose car is a *symbol* is not a list of things to draw; it
;;   is the conditional form (SYMBOL THEN ELSE...).  `modusregel-format'
;;   therefore begins with a string, as Emacs's own format begins with
;;   "%e", and it must keep beginning with something that is not a
;;   symbol.
;;
;; - The mode line ignores the `:eval' forms and the text properties
;;   held by a symbol's value unless that symbol is marked as a
;;   `risky-local-variable'.  Every element below is marked, and
;;   `modusregel--format-elements' is what does the marking.
;;
;; Performance: every `:eval' here runs on each redisplay, so each one
;; is kept to a couple of calls, and the ones whose package may be
;; absent -- eglot, flymake, nyan -- check for it rather than signal.

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

(defface modusregel-buffer-position-face
  '((t :height 0.80))
  "Face for the buffer position in the modusregel mode line.

Only the height is set here, so the text keeps the colors of the mode
line it is drawn on, which are those of the selected window's mode line
or of an unselected one."
  :group 'modusregel)

(defcustom modusregel-buffer-position-expr
  '(:eval (list (propertize "%o" 'face 'modusregel-buffer-position-face)))
  "Expression showing how much of the buffer is above the window.

`%o' is the percentage of the buffer the window has travelled through,
or Top, Bot or All."
  :type 'sexp
  :group 'modusregel)

(defface modusregel-vc-face
  '((t :height 0.80))
  "Face for version control information in the modusregel mode line.

Only the height is set here, so the text keeps the colors of the mode
line it is drawn on, which are those of the selected window's mode line
or of an unselected one."
  :group 'modusregel)

(defun modusregel--vc-name (vc)
  "Return the branch or revision that VC reports in VC.

VC is the value of `vc-mode', which puts the name of the backend in
front of the branch or revision, as in \" Git-master\" or \" SVN:1234\".
A value that carries no branch, such as \"Git\", is returned as it is.

The backend name is matched as a run of letters without hyphens, so
that a branch which has one -- \" Git-feature-x\" -- keeps all of it."
  (if (string-match "^ ?[A-Za-z]+[-:]" vc)
      (substring vc (match-end 0))
    vc))

(defcustom modusregel-vc-expr
  '(:eval (when-let* ((vc (bound-and-true-p vc-mode)))
            (list (propertize (modusregel--vc-name vc)
                              'face 'modusregel-vc-face)
                  modusregel-spacer-str)))
  "Expression showing the version control branch or revision.

Nothing is drawn in a buffer that is not under version control, or in
one where `vc-mode' is nil.  Whether VC has been loaded at all is asked
before its variable is, so that a session that never loads it draws no
version control rather than failing to draw a mode line."
  :type 'sexp
  :group 'modusregel)

(defun modusregel--flymake-status ()
  "Return the Flymake counters for the current buffer, or nil.

Nil also when Flymake is not loaded, or is loaded but offers no
counters to draw, which keeps a mode line out of the internals of a
package that is free to change them."
  (when (fboundp 'flymake--mode-line-counters)
    (ignore-errors (flymake--mode-line-counters))))

(defcustom modusregel-flymake-expr
  '(:eval (modusregel--flymake-status))
  "Expression showing the Flymake counters of the buffer.

Nothing is drawn when Flymake has no diagnostics to report."
  :type 'sexp
  :group 'modusregel)

(defcustom modusregel-buffer-name-expr
  '(:eval (list (propertize "%b" 'face 'bold
                            'help-echo (buffer-file-name))))
  "Expression showing the name of the buffer.

The name is shown in bold, and hovering over it in a graphical Emacs
tells the file it is visiting, for the buffer on screen when it draws."
  :type 'sexp
  :group 'modusregel)

(defcustom modusregel-buffer-modified-str
  '(:eval (when (buffer-modified-p) " ●"))
  "Expression showing that the buffer has been changed and not saved."
  :type 'sexp
  :group 'modusregel)

(defcustom modusregel-buffer-read-only-str
  '(:eval (when buffer-read-only " ☡"))
  "Expression showing that the buffer is read-only."
  :type 'sexp
  :group 'modusregel)

(defcustom modusregel-narrowed-expr
  '(:eval (when (buffer-narrowed-p) " [narrow]"))
  "Expression showing that the buffer is narrowed to a part of itself."
  :type 'sexp
  :group 'modusregel)

(defcustom modusregel-remote-expr
  '(:eval (when (file-remote-p default-directory)
            (list modusregel-spacer-str "☍" modusregel-spacer-str)))
  "Expression showing that the buffer visits a remote file.

The indication is surrounded by the spacer, so that it reads as a word
of its own."
  :type 'sexp
  :group 'modusregel)

(defun modusregel--eglot-active-p ()
  "Return non-nil when Eglot manages the current buffer.

`eglot-managed-p' is asked first, as it is the supported way to know;
older Eglot, which has only the `eglot--managed-mode' variable, is
still understood."
  (or (and (fboundp 'eglot-managed-p) (eglot-managed-p))
      (bound-and-true-p eglot--managed-mode)))

(defcustom modusregel-eglot-expr
  '(:eval (when (modusregel--eglot-active-p)
            (propertize " 𝌤 " 'help-echo "Eglot LSP Active")))
  "Expression showing that an Eglot language server manages the buffer.

Nothing is drawn when Eglot is not loaded, or does not manage the
buffer."
  :type 'sexp
  :group 'modusregel)

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
  "A mapping of major-mode names to more readable versions.

Every key is a symbol of a major mode, and every value is the string to
show in its place."
  :type '(alist :key-type symbol :value-type string)
  :group 'modusregel)

(defun modusregel-major-mode-name (raw-name)
  "Convert a RAW-NAME of a major mode into a prettier more readable version.

A mode that `modusregel-major-mode-alist' speaks for is named as the
alist names it, be it a tree-sitter mode or not.  Any other mode is
named by dropping the \"-mode\" or \"-ts-mode\" it ends with, and
capitalizing what is left, so that `rust-ts-mode' reads as \"Rust\"."
  (let* ((name-str (symbol-name raw-name))
         (base (replace-regexp-in-string "-\\(ts-\\)?mode$" "" name-str))
         (mapped-name (cdr (assoc (intern (concat base "-mode"))
                                  modusregel-major-mode-alist))))
    (or mapped-name
        (capitalize base))))

(defcustom modusregel-major-mode-expr
  '(:eval (modusregel-major-mode-name major-mode))
  "Representation of the major mode in the mode line."
  :type 'sexp
  :group 'modusregel)

(defcustom modusregel-nyan-expr
  '(:eval (when (and (bound-and-true-p nyan-mode)
                     (fboundp 'nyan-create))
            (list (nyan-create))))
  "Nyan Cat indicator (needs nyan mode).

Nothing is drawn unless `nyan-mode' is on, so that a mode line that
does not use it cannot be broken by it."
  :type 'sexp
  :group 'modusregel)

(defvar modusregel--format-elements
  '(modusregel-leading-str
    modusregel-remote-expr
    modusregel-buffer-name-expr
    modusregel-buffer-modified-str
    modusregel-buffer-read-only-str
    modusregel-narrowed-expr
    modusregel-spacer-str
    modusregel-line-number-str
    modusregel-column-number-str
    modusregel-spacer-str
    modusregel-buffer-position-expr
    modusregel-spacer-str
    modusregel-vc-expr
    modusregel-major-mode-expr
    modusregel-eglot-expr
    modusregel-spacer-str
    modusregel-flymake-expr)
  "The elements of `modusregel-format', in the order they are drawn.

Every symbol here names a variable of this package, and every one of
them is marked below as a `risky-local-variable', which is what the
mode line asks of a symbol whose value holds `:eval' forms or text
properties before it will process them.")

(dolist (element modusregel--format-elements)
  (put element 'risky-local-variable t))
(put 'modusregel-format 'risky-local-variable t)

(defcustom modusregel-format
  (append '("") modusregel--format-elements)
  "The list of elements the mode line is drawn from.

The elements are the symbols of the variables defined in this file, so
that changing one of them is visible at the next redisplay.  Add to it,
take from it or reorder it as any other list; a literal construct, such
as the `(\"\" keycast-mode-line)' that `keycast' needs, is understood
here as well.

The list begins with a string because a list whose car is a symbol is
the conditional form of the mode line -- (SYMBOL THEN ELSE...) -- and
not a list of things to draw."
  :type 'sexp
  :group 'modusregel)

(defvar modusregel--saved-mode-line-format nil
  "The value `mode-line-format' had before `modusregel-mode' was enabled.")

(defvar modusregel--mode-line-format-saved nil
  "Non-nil when there is a `mode-line-format' to put back.

A separate flag, rather than the saved value being non-nil, because nil
is a value `mode-line-format' can have: it is how a mode line is asked
not to be drawn at all.")

;;;###autoload
(define-minor-mode modusregel-mode
  "Draw the modusregel mode line in every window.

When the mode is enabled, `mode-line-format' defaults to
`modusregel-format'; when it is disabled, the value it had before is
put back.

This is a global mode because the mode line belongs to a window and not
to any one buffer.  A window that has been given a `mode-line-format'
of its own keeps it, as does a buffer whose value was set with `setq'
rather than `setq-default'."
  :global t
  :lighter nil
  :group 'modusregel
  (if modusregel-mode
      (progn
        ;; What was there is remembered once: enabling a mode that is
        ;; already on must not remember the format it installed itself.
        (unless modusregel--mode-line-format-saved
          (setq modusregel--saved-mode-line-format
                (default-value 'mode-line-format)
                modusregel--mode-line-format-saved t))
        (setq-default mode-line-format modusregel-format))
    (when modusregel--mode-line-format-saved
      (setq-default mode-line-format modusregel--saved-mode-line-format)
      (setq modusregel--mode-line-format-saved nil))))

(provide 'modusregel)

;;; modusregel.el ends here
