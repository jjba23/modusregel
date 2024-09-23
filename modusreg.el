;;; modusreg.el --- mode line customizations -*- lexical-binding: t -*-

;; Copyright (C) 2024 Free Software Foundation, Inc.

;; Version: 0.1.0
;; Author: Josep Bigorra <jjbigorra@gmail.com>
;; Maintainer: Josep Bigorra <jjbigorra@gmail.com>
;; Keywords: mode, line, emacs, ui
;; Package: modusregel

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
  :group 'tools
  )

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
                      modusregel-spacer-str)
                     )))

(defvar modusregel-flymake-expr
  '(:eval (flymake--mode-line-counters)))

(defvar modusregel-buffer-name-expr
  (propertize "%b" 'help-echo (buffer-file-name)))

(defcustom modusregel-buffer-modified-str
  (when (buffer-modified-p) "++")
  "String to use to show that a buffer is modified and unsaved."
  :type 'string)

(defvar modusregel-major-mode-expr
  (jjba-major-mode-name (format "%s" major-mode))
  "Representation of the major mode in the mode line.")

(defun jjba-major-mode-name (raw-name)
    "Convert a RAW-NAME of a major mode into a prettier more readable version."
    (interactive)
    (cond
     ((string-equal raw-name "emacs-lisp-mode") "ELisp")
     ((string-equal raw-name "lisp-interaction-mode") "ELisp")
     ((string-equal raw-name "shell-command-mode") "Shell-cmd")
     ((string-equal raw-name "haskell-mode") "Haskell")
     ((string-equal raw-name "scala-ts-mode") "Scala")
     ((string-equal raw-name "nix-ts-mode") "Nix")
     (t raw-name)
     ))

(defvar modusregel-format (list
    '(:eval
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
           modusregel-flymake-expr
       )))
  "The mode-line format to be used.")

(provide 'modusregel)

;;; modusreg.el ends here
