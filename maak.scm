;; modusregel

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

(define-module (maak)
  #:declarative? #t
  #:use-module (maak maak)
  ;; The container helpers are imported under a prefix because the tasks below
  ;; are named the way maak exposes them on the command line -- `maak
  ;; container-build' -- and a task may not shadow the helper it calls.
  #:use-module ((maak container) #:prefix ct:))

;; ====== Maak constants ======

;; The Emacs the package is compiled and tested with, overridable with the
;; EMACS environment variable, exactly as one would expect.
(define emacs-command
  (or (getenv "EMACS") "emacs"))

;; The package itself.
(define source-file
  "modusregel.el")

;; The ERT suite.
(define test-file
  "test/modusregel-test.el")

;; What byte-compilation leaves behind.
(define compiled-files
  '("modusregel.elc" "test/modusregel-test.elc"))

;; ====== Maak tasks ======

(define (compile)
  "Byte-compile the package and its test suite."
  (run (list emacs-command "-Q" "--batch" "-L" "." "-L" "test"
             "-f" "batch-byte-compile" source-file test-file)
       #:verbose? #t))

(define (test)
  "Run the ERT suite.

Most of the suite runs here, in a batch Emacs.  The tests that draw a
whole mode line cannot: `format-mode-line' returns an empty string when
Emacs is not interactive, so they skip here and are run for real, by
this same suite, in a second Emacs given a terminal of its own.  A
failure there is a failure of this task."
  (run (list emacs-command "-Q" "--batch" "-L" "." "-L" "test" "-l" test-file
             "-f" "ert-run-tests-batch-and-exit")
       #:verbose? #t))

(define (lint)
  "Compile with warnings turned into errors, then enforce checkdoc."
  (run (list emacs-command "-Q" "--batch" "-L" "." "-L" "test"
             "--eval" "(setq byte-compile-error-on-warn t)"
             "-f" "batch-byte-compile" source-file test-file)
       #:verbose? #t)
  (run (list emacs-command "-Q" "--batch" "-L" "."
             "-l" "test/modusregel-checkdoc.el")
       #:verbose? #t))

(define (clean)
  "Remove the byte-compiled files."
  (for-each (lambda (file)
              (when (file-exists? file) (delete-file file)))
            compiled-files))

(define (check)
  "The whole quality gate, from a clean tree: lint, then test."
  (clean)
  (lint)
  (test))

(define (repl)
  "Open an Emacs with modusregel loaded and its mode line in place."
  (run (list emacs-command "-Q" "-L" "."
             "--eval" "(progn (require (quote modusregel)) (modusregel-mode 1))")))

(define (tasks)
  "List the available tasks."
  (list-tasks))

;; `maak' on its own runs `check', that is: the whole gate in one command.
(define (default)
  "Run the full quality gate (lint and tests)."
  (check))

;; ====== Container tasks ======

(define (container-build)
  "Build the container image for modusregel."
  (ct:container-build "." #:tag "modusregel" #:verbose? #t))

(define (container-run)
  "Run the container image for modusregel."
  (ct:container-run "modusregel:latest"
                    #:interactive? #t
                    #:tty? #t))

(define (package-docker)
  "Build the container image for modusregel."
  (container-build))

;; Local Variables:
;; mode: scheme
;; End:
