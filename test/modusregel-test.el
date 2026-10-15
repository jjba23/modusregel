;;; modusregel-test.el --- Tests for modusregel  -*- lexical-binding: t; -*-

;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;; modusregel is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; modusregel is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with modusregel.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Run with:
;;
;;   emacs -Q --batch -L . -L test -l test/modusregel-test.el \
;;         -f ert-run-tests-batch-and-exit
;;
;; The suite is in three parts.
;;
;; The first checks the shape of the package: that every element of
;; `modusregel-format' is documented, is marked as the mode line asks a
;; symbol to be marked, and is actually used; that every custom value
;; matches the type it declares; and that every face inherits from faces
;; that exist, which is what the two dangling `:inherit' names this
;; suite was written against were not.
;;
;; The second draws each element on its own, in the buffer conditions it
;; is there for: a modified or read-only or narrowed buffer, a remote
;; directory, a version control branch, Eglot, Flymake, Nyan.
;;
;; The third draws the whole mode line.  That cannot be done here: in a
;; noninteractive Emacs `format-mode-line' returns an empty string, so
;; those tests skip, and `modusregel-test-renders-in-a-terminal' runs
;; them again in a second Emacs given a terminal of its own, and fails
;; if any of them fails there.

;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'modusregel)

(defvar modusregel-test--directory
  (file-name-directory (or load-file-name buffer-file-name))
  "Directory holding this test file.")

(defvar modusregel-test--emacs
  (or (getenv "EMACS") invocation-name "emacs")
  "The Emacs to run the render tests with, overridable with EMACS.")

(defvar modusregel-test--render-timeout 180
  "Seconds to give the terminal Emacs that draws the mode line.")

;; Variables of packages that may not be loaded here.  Declaring them
;; without a value is what makes them dynamic, so that this suite can
;; bind them to stand in for the packages not being there.
(defvar eglot--managed-mode)
(defvar nyan-mode)
(defvar vc-mode)

;;; Helpers

(defun modusregel-test--project-directory ()
  "Return the root of the modusregel checkout these tests come from."
  (file-name-directory (directory-file-name modusregel-test--directory)))

(defun modusregel-test--rendered-p ()
  "Return non-nil when `format-mode-line' can draw in this Emacs."
  (not noninteractive))

(defun modusregel-test--draw (format)
  "Return FORMAT drawn for the buffer that is current, as a window would.

`format-mode-line' draws for the window it is told to, not for the
buffer that is current, so the current buffer is passed as its context."
  (format-mode-line format nil (selected-window) (current-buffer)))

(defun modusregel-test--drawn-value (element)
  "Return what the mode line ELEMENT draws in the current buffer.

For an element whose value is an `:eval' form that is the value of the
form, for any other element it is the value itself, exactly as the mode
line would process it."
  (let ((value (symbol-value element)))
    (if (and (consp value) (eq (car value) :eval))
        (eval (cadr value) t)
      value)))

(defun modusregel-test--invalid (construct)
  "Return a description when CONSTRUCT is not a valid mode line construct.

The mode line draws strings, symbols, and lists thereof; a `:eval' is
drawn by evaluating its form and drawing the result, and a `:propertize'
by drawing its first argument.  Anything else -- a number, say -- is
not drawn at all, and is what this looks for."
  (cond
   ((null construct) nil)
   ((stringp construct) nil)
   ((symbolp construct) nil)
   ((consp construct)
    (cond
     ((eq (car construct) :eval)
      (modusregel-test--invalid (eval (cadr construct) t)))
     ((eq (car construct) :propertize)
      (modusregel-test--invalid (cadr construct)))
     (t (seq-some #'modusregel-test--invalid construct))))
   (t (format "not a mode line construct: %S" construct))))

(defun modusregel-test--invalid-element (element)
  "Return a description when the mode line ELEMENT does not draw properly."
  (let ((invalid (modusregel-test--invalid
                  (modusregel-test--drawn-value element))))
    (when invalid (format "%s draws %s" element invalid))))

(defun modusregel-test--has-face-p (string face)
  "Return non-nil when some character of STRING carries FACE."
  (seq-some (lambda (index)
              (memq face (ensure-list (get-text-property index 'face string))))
            (number-sequence 0 (1- (length string)))))

(defun modusregel-test--at-face (string face)
  "Return the text of STRING that carries FACE, or nil."
  (let ((start nil) (end nil))
    (dotimes (index (length string))
      (when (memq face (ensure-list (get-text-property index 'face string)))
        (unless start (setq start index))
        (setq end (1+ index))))
    (when start (substring-no-properties string start end))))

(defmacro modusregel-test--in-buffer (name &rest body)
  "Run BODY in a fresh, unmodified buffer called NAME, with no visited file."
  (declare (indent 1) (debug t))
  `(with-temp-buffer
     (rename-buffer ,name t)
     (setq buffer-file-name nil)
     (insert "one\ntwo\nthree\n")
     (set-buffer-modified-p nil)
     ,@body))

(defun modusregel-test--contents (file)
  "Return the contents of FILE, or an empty string when there is none."
  (if (file-exists-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (buffer-string))
    ""))

(defun modusregel-test--tail (text &optional lines)
  "Return the last LINES lines of TEXT."
  (let ((all (split-string text "\n")))
    (string-join (last all (or lines 40)) "\n")))

(defun modusregel-test--customs ()
  "Return every customized variable this package declares.

The hook a minor mode comes with is left out: `define-minor-mode' makes
it itself, and does not put it in the group the mode declares."
  (let (variables)
    (mapatoms
     (lambda (symbol)
       (when (and (string-prefix-p "modusregel-" (symbol-name symbol))
                  (not (string-suffix-p "-hook" (symbol-name symbol)))
                  (not (facep symbol))
                  (custom-variable-p symbol)
                  (boundp symbol))
         (push symbol variables))))
    (nreverse variables)))

(defun modusregel-test--faces ()
  "Return every face this package defines."
  (seq-filter (lambda (symbol)
                (and (string-prefix-p "modusregel-" (symbol-name symbol))
                     (facep symbol)))
              (face-list)))

;;; The name a major mode goes by

(ert-deftest modusregel-test-major-mode-alist-is-well-formed ()
  "Every entry of the alist names a mode and a string to show."
  (dolist (entry modusregel-major-mode-alist)
    (should (symbolp (car entry)))
    (should (string-suffix-p "-mode" (symbol-name (car entry))))
    (should (stringp (cdr entry)))
    (should-not (string-empty-p (cdr entry)))))

(ert-deftest modusregel-test-major-mode-alist-is-honoured ()
  "Every entry of the alist names the mode it speaks for, tree-sitter or not."
  (dolist (entry modusregel-major-mode-alist)
    (let* ((mode (car entry))
           (tree-sitter (intern (replace-regexp-in-string
                                 "-mode$" "-ts-mode" (symbol-name mode)))))
      (should (equal (cdr entry) (modusregel-major-mode-name mode)))
      (should (equal (cdr entry) (modusregel-major-mode-name tree-sitter))))))

(ert-deftest modusregel-test-major-mode-name-falls-back ()
  "A mode the alist does not speak for is named after itself."
  (should (equal "Rust" (modusregel-major-mode-name 'rust-mode)))
  (should (equal "Rust" (modusregel-major-mode-name 'rust-ts-mode)))
  (should (equal "Python" (modusregel-major-mode-name 'python-mode)))
  (should (equal "Dired" (modusregel-major-mode-name 'dired-mode)))
  (should (equal "Fundamental" (modusregel-major-mode-name 'fundamental-mode)))
  ;; The tree-sitter suffix goes with the mode suffix, not instead of it.
  (should (equal "Go" (modusregel-major-mode-name 'go-ts-mode))))

(ert-deftest modusregel-test-major-mode-name-beats-the-tree-sitter-suffix ()
  "A tree-sitter mode is named as the alist names the mode it comes from."
  (should (equal "ELisp" (modusregel-major-mode-name 'emacs-lisp-ts-mode)))
  (should (equal "TypeScript" (modusregel-major-mode-name 'typescript-ts-mode)))
  (should (equal "Shell" (modusregel-major-mode-name 'bash-ts-mode)))
  (should (equal "C++" (modusregel-major-mode-name 'c++-ts-mode))))

;;; The shape of the package

(ert-deftest modusregel-test-every-element-is-defined-and-documented ()
  "Every element of the format is a variable, and says what it is for."
  (dolist (element modusregel--format-elements)
    (should (boundp element))
    (should (stringp (documentation-property element 'variable-documentation)))
    (should-not (string-empty-p
                 (documentation-property element 'variable-documentation)))))

(ert-deftest modusregel-test-every-element-is-used ()
  "Every element of the package is drawn by the format, so none is dead."
  (dolist (element modusregel--format-elements)
    (should (memq element modusregel-format))))

(ert-deftest modusregel-test-every-element-is-marked-risky ()
  "Every element is marked as the mode line asks before it draws `:eval'.

A symbol whose value holds `:eval' forms or text properties is drawn as
an empty string unless the symbol is marked, and nothing says so."
  (dolist (element modusregel--format-elements)
    (should (get element 'risky-local-variable))))

(ert-deftest modusregel-test-format-does-not-begin-with-a-symbol ()
  "The format begins with a string, so that it is drawn as a list.

A list whose car is a symbol is the conditional form (SYMBOL THEN
ELSE...), and would draw one element instead of all of them."
  (should (stringp (car modusregel-format)))
  (should (equal (cdr modusregel-format) modusregel--format-elements)))

(ert-deftest modusregel-test-elements-draw-valid-constructs ()
  "Every element draws something the mode line knows what to do with."
  (with-temp-buffer
    (dolist (element modusregel--format-elements)
      (should-not (modusregel-test--invalid-element element)))))

(defun modusregel-test--type (custom)
  "Return the type CUSTOM declares, as this Emacs records it."
  (or (get custom 'custom-type)
      (and (fboundp 'custom-variable-type) (custom-variable-type custom))))

(ert-deftest modusregel-test-elements-draw-nothing-when-there-is-nothing ()
  "A clean, local, unmanaged buffer draws only the elements that always show."
  (modusregel-test--in-buffer "modusregel-test-clean"
    (should-not (modusregel-test--drawn-value 'modusregel-remote-expr))
    (should-not (modusregel-test--drawn-value 'modusregel-eglot-expr))
    (should-not (modusregel-test--drawn-value 'modusregel-nyan-expr))
    (should (equal "Fundamental"
                   (modusregel-test--drawn-value 'modusregel-major-mode-expr)))))

(ert-deftest modusregel-test-custom-types-match-their-values ()
  "No custom is declared with a type its value does not have.

This is what the two indications of a modified and of a read-only buffer
were not: each held an `:eval' form while declaring itself a string,
which Customize reads as a value it does not know how to show."
  (require 'wid-edit)
  (dolist (custom (modusregel-test--customs))
    (let* ((type (modusregel-test--type custom))
           (value (symbol-value custom))
           (widget (widget-convert type)))
      (should (widget-apply widget :match value)))))

(ert-deftest modusregel-test-everything-is-in-the-group ()
  "Every custom and every face of the package is in its own group."
  (let ((members (get 'modusregel 'custom-group)))
    (should members)
    (dolist (custom (modusregel-test--customs))
      (should (assq custom members)))
    (dolist (face (modusregel-test--faces))
      (should (assq face members)))))

(ert-deftest modusregel-test-faces-inherit-from-faces-that-exist ()
  "Every face a modusregel face inherits is a face Emacs knows."
  (dolist (face (modusregel-test--faces))
    (let* ((spec (get face 'face-defface-spec))
           (attributes (cdr (assq t spec)))
           (parents (plist-get attributes :inherit)))
      (dolist (parent (ensure-list parents))
        (should (facep parent))))))

(ert-deftest modusregel-test-faces-are-documented ()
  "Every face says what it is for."
  (dolist (face (modusregel-test--faces))
    (should (stringp (face-documentation face)))))

;;; The elements that depend on the buffer

(ert-deftest modusregel-test-modified-and-read-only ()
  "The unsaved and read-only indications appear only when they are true."
  (modusregel-test--in-buffer "modusregel-test-modified"
    (should-not (modusregel-test--drawn-value 'modusregel-buffer-modified-str))
    (should-not (modusregel-test--drawn-value 'modusregel-buffer-read-only-str))
    (set-buffer-modified-p t)
    (should (equal " ●"
                   (modusregel-test--drawn-value
                    'modusregel-buffer-modified-str)))
    (setq buffer-read-only t)
    (should (equal " ☡"
                   (modusregel-test--drawn-value
                    'modusregel-buffer-read-only-str)))))

(ert-deftest modusregel-test-narrowed ()
  "The narrowing indication appears only while the buffer is narrowed."
  (modusregel-test--in-buffer "modusregel-test-narrowed"
    (should-not (modusregel-test--drawn-value 'modusregel-narrowed-expr))
    (narrow-to-region (point-min) 4)
    (should (equal " [narrow]"
                   (modusregel-test--drawn-value 'modusregel-narrowed-expr)))))

(ert-deftest modusregel-test-remote ()
  "The remote indication appears only for a remote directory."
  (modusregel-test--in-buffer "modusregel-test-remote"
    (should-not (modusregel-test--drawn-value 'modusregel-remote-expr))
    (let ((default-directory "/ssh:someone@example.org:/tmp/"))
      (should (member "☍" (modusregel-test--drawn-value
                           'modusregel-remote-expr))))))

(ert-deftest modusregel-test-buffer-name ()
  "The name is drawn bold, and points at the file the buffer visits."
  (modusregel-test--in-buffer "modusregel-test-name"
    (let ((drawn (modusregel-test--drawn-value 'modusregel-buffer-name-expr)))
      (should (equal 'bold (get-text-property 0 'face (car drawn))))
      (should-not (get-text-property 0 'help-echo (car drawn))))
    (let ((buffer-file-name "/tmp/modusregel-some-file.el"))
      (let ((drawn (modusregel-test--drawn-value
                    'modusregel-buffer-name-expr)))
        (should (equal "/tmp/modusregel-some-file.el"
                       (get-text-property 0 'help-echo (car drawn))))))))

(ert-deftest modusregel-test-buffer-position ()
  "The position is drawn in its own face."
  (modusregel-test--in-buffer "modusregel-test-position"
    (let ((drawn (modusregel-test--drawn-value
                  'modusregel-buffer-position-expr)))
      (should (equal 'modusregel-buffer-position-face
                     (get-text-property 0 'face (car drawn))))
      (should (stringp (car drawn))))))

(ert-deftest modusregel-test-vc-name ()
  "The branch or revision is read out of what VC reports."
  (should (equal "master" (modusregel--vc-name " Git-master")))
  (should (equal "main" (modusregel--vc-name "Git:main")))
  (should (equal "1234" (modusregel--vc-name " SVN:1234")))
  (should (equal "1.2" (modusregel--vc-name "RCS-1.2")))
  ;; A branch with a hyphen in it keeps all of it: the backend name is
  ;; matched as a run of letters, so only the first hyphen is a separator.
  (should (equal "feature-x" (modusregel--vc-name " Git-feature-x")))
  (should (equal "feature/first" (modusregel--vc-name " Git-feature/first")))
  ;; Nothing to say about a directory that is only under version control
  ;; as a whole, or a name with no separator in it.
  (should (equal "Git" (modusregel--vc-name "Git")))
  (should (equal "" (modusregel--vc-name ""))))

(ert-deftest modusregel-test-vc-expr ()
  "The branch is drawn in its own face, and only under version control."
  (modusregel-test--in-buffer "modusregel-test-vc"
    (let ((vc-mode nil))
      (should-not (modusregel-test--drawn-value 'modusregel-vc-expr)))
    (let ((vc-mode " Git-master"))
      (let ((drawn (modusregel-test--drawn-value 'modusregel-vc-expr)))
        (should (equal "master" (substring-no-properties (car drawn))))
        (should (equal 'modusregel-vc-face (get-text-property 0 'face (car drawn))))
        (should (equal modusregel-spacer-str (cadr drawn)))))))

(ert-deftest modusregel-test-eglot ()
  "Eglot is asked the supported question, and the old variable is honoured."
  (modusregel-test--in-buffer "modusregel-test-eglot"
    (should-not (modusregel--eglot-active-p))
    (cl-letf (((symbol-function 'eglot-managed-p) (lambda () t)))
      (should (modusregel--eglot-active-p))
      (should (string-match-p "𝌤"
                              (modusregel-test--drawn-value
                               'modusregel-eglot-expr))))
    (cl-letf (((symbol-function 'eglot-managed-p) (lambda () nil)))
      (should-not (modusregel--eglot-active-p)))
    ;; An Eglot old enough to have only the variable is still understood.
    (let ((eglot--managed-mode t))
      (cl-letf (((symbol-function 'eglot-managed-p) (lambda () nil)))
        (should (modusregel--eglot-active-p))))))

(ert-deftest modusregel-test-flymake ()
  "Flymake's counters are drawn, and its absence or its faults are not fatal."
  (modusregel-test--in-buffer "modusregel-test-flymake"
    ;; No diagnostics to report, so nothing is drawn.
    (should-not (modusregel-test--drawn-value 'modusregel-flymake-expr))
    (cl-letf (((symbol-function 'flymake--mode-line-counters)
               (lambda () "3:1")))
      (should (equal "3:1" (modusregel-test--drawn-value
                            'modusregel-flymake-expr))))
    ;; Flymake is free to change an internal function: that is not a
    ;; reason for the mode line to break.
    (cl-letf (((symbol-function 'flymake--mode-line-counters)
               (lambda () (error "changed underneath us"))))
      (should-not (modusregel-test--drawn-value 'modusregel-flymake-expr)))))

(ert-deftest modusregel-test-nyan ()
  "Nyan is drawn only when Nyan is on, and never breaks the mode line."
  (modusregel-test--in-buffer "modusregel-test-nyan"
    (should-not (modusregel-test--drawn-value 'modusregel-nyan-expr))
    (let ((nyan-mode nil))
      (should-not (modusregel-test--drawn-value 'modusregel-nyan-expr)))
    (let ((nyan-mode t))
      (cl-letf (((symbol-function 'nyan-create) (lambda () "(>^.^<)")))
        (should (equal '("(>^.^<)")
                       (modusregel-test--drawn-value 'modusregel-nyan-expr)))))))

;;; Turning the mode line on

(defmacro modusregel-test--with-the-mode-reset (&rest body)
  "Run BODY with the mode, and what it saved, put back afterwards.

BODY sees `original', the value `mode-line-format' had when it started."
  (declare (indent 0) (debug t))
  `(let ((original (default-value 'mode-line-format))
         (modusregel--saved-mode-line-format nil)
         (modusregel--mode-line-format-saved nil))
     (unwind-protect
         (progn ,@body)
       (setq-default mode-line-format original)
       (setq modusregel-mode nil))))

(ert-deftest modusregel-test-mode-installs-and-restores ()
  "Enabling the mode installs the format, and disabling puts back what was."
  (modusregel-test--with-the-mode-reset
    (modusregel-mode 1)
    (should (equal modusregel-format (default-value 'mode-line-format)))
    (modusregel-mode -1)
    (should (equal original (default-value 'mode-line-format)))
    (should-not modusregel--mode-line-format-saved)))

(ert-deftest modusregel-test-mode-remembers-what-was-there ()
  "Enabling twice does not remember the modusregel format as the old one."
  (modusregel-test--with-the-mode-reset
    (modusregel-mode 1)
    (modusregel-mode 1)
    (should (equal original modusregel--saved-mode-line-format))
    (modusregel-mode -1)
    (should (equal original (default-value 'mode-line-format)))))

(ert-deftest modusregel-test-mode-restores-a-mode-line-that-was-off ()
  "A mode line asked not to be drawn at all is put back as it was."
  (modusregel-test--with-the-mode-reset
    (setq-default mode-line-format nil)
    (modusregel-mode 1)
    (should (equal modusregel-format (default-value 'mode-line-format)))
    (modusregel-mode -1)
    (should (null (default-value 'mode-line-format)))))

(ert-deftest modusregel-test-mode-is-global ()
  "Enabling the mode in one buffer enables it in every other."
  (modusregel-test--with-the-mode-reset
    (with-temp-buffer (modusregel-mode 1))
    (should (with-temp-buffer modusregel-mode))
    (should (equal (default-value 'mode-line-format) modusregel-format))))

;;; Drawing the whole mode line, which needs a terminal

(ert-deftest modusregel-test-render-mode-line ()
  "A whole mode line is drawn, with the elements of the package in it."
  :tags '(render)
  (skip-when (not (modusregel-test--rendered-p)))
  (modusregel-test--in-buffer "modusregel-test-render"
    (let ((drawn (modusregel-test--draw modusregel-format)))
      (should (string-match-p (regexp-quote modusregel-leading-str) drawn))
      (should (string-match-p "modusregel-test-render" drawn))
      (should (string-match-p "Fundamental" drawn))
      ;; The line and column, and how far through the buffer the window
      ;; has travelled, are all drawn.
      (should (string-match-p "4:0" drawn))
      (should (string-match-p "All" drawn))
      (should (modusregel-test--has-face-p drawn 'bold))
      (should (modusregel-test--has-face-p drawn
                                            'modusregel-buffer-position-face))
      (should (equal "All" (modusregel-test--at-face
                            drawn 'modusregel-buffer-position-face))))))

(ert-deftest modusregel-test-render-buffer-states ()
  "The whole mode line shows the state the buffer is really in."
  :tags '(render)
  (skip-when (not (modusregel-test--rendered-p)))
  (modusregel-test--in-buffer "modusregel-test-render-states"
    ;; Clean, unrestricted, whole: none of the state glyphs are drawn.
    (let ((drawn (modusregel-test--draw modusregel-format)))
      (should-not (string-match-p "●" drawn))
      (should-not (string-match-p "☡" drawn))
      (should-not (string-match-p "narrow" drawn)))
    ;; Modified and read-only, and saying so.
    (set-buffer-modified-p t)
    (setq buffer-read-only t)
    (let ((drawn (modusregel-test--draw modusregel-format)))
      (should (string-match-p "●" drawn))
      (should (string-match-p "☡" drawn)))
    ;; Narrowed, and saying so.
    (setq buffer-read-only nil)
    (save-restriction
      (narrow-to-region (point-min) 4)
      (should (string-match-p "\\[narrow\\]"
                              (modusregel-test--draw modusregel-format))))))

(ert-deftest modusregel-test-render-without-the-mode ()
  "The format is a mode line format whether the mode installed it or not."
  :tags '(render)
  (skip-when (not (modusregel-test--rendered-p)))
  (modusregel-test--in-buffer "modusregel-test-render-plain"
    (let ((mode-line-format modusregel-format))
      (should (string-match-p "modusregel-test-render-plain"
                              (modusregel-test--draw mode-line-format))))))

;;; Running the render tests for real

(defun modusregel-test--terminal-emacs-p ()
  "Return non-nil when a terminal Emacs can be started to draw a mode line."
  (and (memq system-type '(gnu gnu/linux))
       (executable-find "script")
       (executable-find modusregel-test--emacs)))

(defun modusregel-test--finished-p (file)
  "Return non-nil when the render run has written all of FILE."
  (and (file-exists-p file)
       (with-temp-buffer
         (insert-file-contents file)
         (string-match-p "DONE" (buffer-string)))))

(defun modusregel-test--render-run ()
  "Run the render tests in a terminal Emacs and return what it reported.

`format-mode-line' returns an empty string in a noninteractive Emacs, so
the tests that draw a mode line cannot run here.  They are run in a
second Emacs of the same build, given a terminal of its own by `script',
and what it writes -- how many tests ran and how many did not go as
expected -- is returned as a property list.

The report is a property list holding how many tests ran, how many
went as expected, how many did not, and the :log of the run.

The exit status of `script' is not trusted: it is known to linger after
the Emacs it runs has gone, so what is read is the report the Emacs
wrote, and the run is killed once that report is there.  Nil means the
report never arrived."
  (let* ((directory (make-temp-file "modusregel-render-" t))
         (report (expand-file-name "report.el" directory))
         (log (expand-file-name "log.txt" directory))
         (program (expand-file-name "render.el" directory))
         (root (modusregel-test--project-directory))
         (this (expand-file-name "modusregel-test.el"
                                 modusregel-test--directory))
         (process nil))
    (unwind-protect
        (progn
          (with-temp-file program
            (insert ";;; -*- lexical-binding: t; -*-\n")
            (insert "(let ((stats (ert-run-tests-batch '(tag render))))\n")
            (insert "  (with-temp-file " (prin1-to-string report) "\n")
            (insert "    (prin1 (list :rendered\n")
            (insert "                 (not (string-empty-p (format-mode-line \"modusregel\")))\n")
            (insert "                 :ran (ert-stats-total stats)\n")
            (insert "                 :expected (ert-stats-completed-expected stats)\n")
            (insert "                 :unexpected (ert-stats-completed-unexpected stats))\n")
            (insert "           (current-buffer))\n")
            (insert "    (insert \"\\nDONE\\n\"))\n")
            ;; ERT reports through `message' outside batch mode, so where
            ;; a failure of a render test is written down is the message
            ;; log, which is carried back in the report's :log.
            (insert "  (with-temp-file " (prin1-to-string log) "\n")
            (insert "    (insert (with-current-buffer \"*Messages*\" (buffer-string)))))\n")
            (insert "(kill-emacs)\n"))
          (setq process
                (make-process
                 :name "modusregel-render"
                 :buffer nil
                 :noquery t
                 :command
                 (list "script" "-qec"
                       (format "%s -Q -nw -L %s -L %s -l %s -l %s > %s 2>&1"
                               (shell-quote-argument modusregel-test--emacs)
                               (shell-quote-argument root)
                               (shell-quote-argument modusregel-test--directory)
                               (shell-quote-argument this)
                               (shell-quote-argument program)
                               (shell-quote-argument log))
                       "/dev/null")))
          (let ((deadline (+ (float-time) modusregel-test--render-timeout)))
            (while (and (< (float-time) deadline)
                        (not (modusregel-test--finished-p report)))
              (accept-process-output process 0.2)
              (sleep-for 0.05)))
          ;; The Emacs writes its report and then goes away; it is given a
          ;; moment to do so, and to flush what it printed, before being
          ;; killed for lingering, which `script' is known to do.
          (let ((deadline (+ (float-time) 15)))
            (while (and (process-live-p process) (< (float-time) deadline))
              (accept-process-output process 0.2)))
          (when (and process (process-live-p process))
            (kill-process process)
            (accept-process-output process 0.2))
          ;; The report is read whether or not the run got as far as
          ;; writing it, and the log of what it printed comes with it,
          ;; because that is where a failure of a render test is written
          ;; down.  Nothing here reads the exit status of `script'.
          (when (modusregel-test--finished-p report)
            (append (with-temp-buffer
                      (insert-file-contents report)
                      (read (current-buffer)))
                    (list :log (modusregel-test--contents log)))))
      (delete-directory directory t))))

(ert-deftest modusregel-test-renders-in-a-terminal ()
  "The render tests pass in a terminal Emacs, where drawing really happens."
  (skip-unless (modusregel-test--terminal-emacs-p))
  (let ((report (modusregel-test--render-run)))
    (when (or (null report)
              (not (plist-get report :rendered))
              (zerop (or (plist-get report :ran) 0))
              (not (zerop (or (plist-get report :unexpected) 0))))
      (ert-fail (format "of the render tests: drawn=%s, ran=%s, unexpected=%s\n%s"
                        (plist-get report :rendered)
                        (plist-get report :ran)
                        (plist-get report :unexpected)
                        (modusregel-test--tail (plist-get report :log)))))))

(provide 'modusregel-test)
;;; modusregel-test.el ends here
