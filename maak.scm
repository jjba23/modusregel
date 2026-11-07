;; modusregel

;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;; SPDX-License-Identifier: MIT

(define-module (maak)
  #:declarative? #t
  ;; Only these are tasks: with an export list maak lists and runs exactly these,
  ;; so the helpers below stay procedures rather than appearing on the command
  ;; line as if they were runnable.
  #:export (compile test lint clean check repl tasks default
                   version version-check sync-version
                   agents
                   container-build container-run package-docker)
  #:use-module (maak maak)
  #:use-module ((ice-9 rdelim) #:select (read-line))
  #:use-module (ice-9 format)
  #:use-module (ice-9 regex)
  #:use-module (ice-9 textual-ports)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-13)
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

;; ====== The version's copies ======
;;
;; The version is written by hand once, in the package header: Emacs reads it
;; there, and so does default.nix.  The spec, the PKGBUILD, the README and the
;; Debian changelog cannot read that header, so they carry copies;
;; `sync-version' writes them and `version-check' holds them to it.  A copy is
;; found by a regular expression rather than by its line number, and only the
;; captured span is ever rewritten, so each file keeps its own wording and
;; alignment.  A pattern that stops matching is reported instead of silently
;; checking nothing.

(define version-source
  "modusregel.el")

(define readme-file
  "README.org")

(define spec-file
  "packaging/opensuse/emacs-modusregel.spec")

(define pkgbuild-file
  "packaging/arch/PKGBUILD")

(define changelog-file
  "packaging/debian/changelog")

(define control-file
  "packaging/debian/control")

(define version-regexp
  "([0-9]+\\.[0-9]+\\.[0-9]+)")

;; The header's own copy, which is the one written by hand.  The semicolons are
;; matched loosely: how many of them lead a comment is the file's formatting,
;; not a fact this task should break on.
(define header-pattern
  (string-append ";;+[ \t]*Version:[ \t]+" version-regexp))

;; The newest changelog entry, and only that one: older entries are history and
;; keep their own version.
(define changelog-pattern
  "elpa-modusregel \\(([0-9]+\\.[0-9]+\\.[0-9]+)-[0-9]+\\)")

(define version-sites
  `((,spec-file . ,(string-append "Version:[ \t]+" version-regexp))
    (,pkgbuild-file . ,(string-append "pkgver=" version-regexp))
    (,readme-file . ,(string-append "the same " version-regexp
                                    ", from the most automated"))))

(define (read-text file)
  "Return the whole of FILE as a string, or a task error when it is not there.

A file that cannot be read is an error rather than the empty string: a check
that reads nothing would pass."
  (if (file-exists? file)
      (call-with-input-file file get-string-all)
      (task-error "no ~a in the working tree" #:args (list file)
                  #:hint "Run the task from the repository root.")))

(define (write-text file text)
  "Write TEXT into FILE, replacing what was there."
  (call-with-output-file file
    (lambda (port) (display text port))))

(define (captures-in text pattern)
  "Return what the first group of every PATTERN match captures in TEXT."
  (let loop ((start 0) (found '()))
    (let ((match (string-match pattern text start)))
      (if (not match)
          (reverse found)
          (loop (match:end match)
                (cons (match:substring match 1) found))))))

(define (rewrite-captures text pattern replacement)
  "Return TEXT with what PATTERN's first group matches replaced.

Only the captured span changes, once per match, so everything around it --
the spec's alignment, the PKGBUILD's quoting, the README's prose -- is left
exactly as it was."
  (let loop ((start 0) (last 0) (pieces '()))
    (let ((match (string-match pattern text start)))
      (if (not match)
          (apply string-append (reverse (cons (substring text last) pieces)))
          (loop (match:end match)
                (match:end match 1)
                (cons replacement
                      (cons (substring text last (match:start match 1)) pieces)))))))

(define (header-version)
  "Return the version the package header declares.

That header is the one copy written by hand: Emacs reads it, and so does
default.nix."
  (let ((found (captures-in (read-text version-source) header-pattern)))
    (unless (pair? found)
      (task-error "~a has no `Version:' header" #:args (list version-source)
                  #:hint "That header is where the version is written by hand."))
    (car found)))

(define (changelog-version)
  "Return the version of the newest Debian changelog entry, or #f."
  (let ((found (captures-in (read-text changelog-file) changelog-pattern)))
    (and (pair? found) (car found))))

(define (version-disagreements wanted)
  "Return a line for every copy of the version that does not say WANTED."
  (let ((site-lines
         (fold (lambda (site lines)
                 (let* ((file (car site))
                        (pattern (cdr site))
                        (found (captures-in (read-text file) pattern)))
                   (cond
                    ((null? found)
                     (append lines
                             (list (~ "~a: `~a' matches nothing any more"
                                      file pattern))))
                    ((every (lambda (copy) (string=? copy wanted)) found)
                     lines)
                    (else
                     (append lines
                             (list (~ "~a: ~a" file (string-join found ", "))))))))
               '()
               version-sites))
        (newest (changelog-version)))
    (cond
     ((string=? (or newest "") wanted) site-lines)
     (newest (append site-lines
                     (list (~ "~a: the newest entry is ~a"
                              changelog-file newest))))
     (else (append site-lines
                   (list (~ "~a: no entry names a version" changelog-file)))))))

(define (patterns-of file)
  "Return every version pattern that names a place in FILE."
  (if (string=? file version-source)
      (list header-pattern)
      (map cdr (filter (lambda (site) (string=? (car site) file))
                       version-sites))))

(define (sync-file file version)
  "Write VERSION into every place FILE names the version.

Return whether the file had to change."
  (let ((text (read-text file)))
    (let ((rewritten (fold (lambda (pattern text)
                             (rewrite-captures text pattern version))
                           text
                           (patterns-of file))))
      (if (string=? text rewritten)
          #f
          (begin (write-text file rewritten) #t)))))

(define (debian-maintainer)
  "Return the maintainer the Debian control file names."
  (let ((found (string-match "Maintainer:[ \t]+([^\n]+)"
                             (read-text control-file))))
    (unless found
      (task-error "no `Maintainer:' line in ~a" #:args (list control-file)))
    (string-trim-both (match:substring found 1))))

(define debian-days
  #("Sun" "Mon" "Tue" "Wed" "Thu" "Fri" "Sat"))

(define debian-months
  #("Jan" "Feb" "Mar" "Apr" "May" "Jun" "Jul" "Aug" "Sep" "Oct" "Nov" "Dec"))

(define (debian-date)
  "Return the current time the way a Debian changelog spells it.

The day and the month come from the vectors above rather than from
`strftime', whose names follow the locale: a changelog entry is read by
machines and wants the English names whichever language the release was cut
in."
  (let ((now (localtime (current-time))))
    (format #f "~a, ~2,'0d ~a ~4,'0d ~2,'0d:~2,'0d:~2,'0d ~a"
            (vector-ref debian-days (vector-ref now 6))
            (vector-ref now 3)
            (vector-ref debian-months (vector-ref now 4))
            (+ 1900 (vector-ref now 5))
            (vector-ref now 2)
            (vector-ref now 1)
            (vector-ref now 0)
            (strftime "%z" now))))

(define (ensure-changelog-entry version)
  "Prepend a dated changelog entry for VERSION, unless it is the newest one.

A changelog is history, so an old entry is never rewritten.  The new entry
says `Sync with upstream', which the release that cuts it makes specific."
  (if (string=? (or (changelog-version) "") version)
      (log-info "~a already has an entry for ~a." changelog-file version)
      (begin
        (write-text changelog-file
                    (string-append
                     (format #f "elpa-modusregel (~a-1) unstable; urgency=medium~%~%"
                             version)
                     (format #f "  * Sync with upstream ~a.~%~%" version)
                     (format #f " -- ~a  ~a~%~%" (debian-maintainer) (debian-date))
                     (read-text changelog-file)))
        (log-info "Added a ~a entry to ~a." version changelog-file))))

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

;; ====== Version tasks ======

(define (version)
  "Print the version the package header declares."
  (display (header-version))
  (newline))

(define (version-check)
  "Fail unless every copy of the version agrees with the package header."
  (let* ((current (header-version))
         (disagreements (version-disagreements current)))
    (if (null? disagreements)
        (log-info "Every copy of the version says ~a." current)
        (task-error "the version is ~a in ~a, but not in every copy"
                    #:args (list current version-source)
                    #:hint (string-join disagreements "\n       ")))))

(define* (sync-version #:optional version)
  "Write the version into the package header and into every copy of it.

VERSION defaults to the one the header already declares, which only re-syncs
the copies.  The Debian changelog gets a new dated entry rather than a
rewritten one."
  (let* ((wanted (or version (header-version)))
         (files (delete-duplicates (cons version-source (map car version-sites))))
         (rewritten (filter (lambda (file) (sync-file file wanted)) files)))
    (if (null? rewritten)
        (log-info "Every copy of the version already says ~a." wanted)
        (for-each (lambda (file)
                    (log-info "Wrote ~a into ~a." wanted file))
                  rewritten))
    (ensure-changelog-entry wanted)
    (version-check)
    (log-info "Left to you: the release notes in NEWS.org and the v~a tag." wanted)))

(define (check)
  "The whole quality gate, from a clean tree: version, lint, then test."
  (clean)
  (version-check)
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
  "Run the full quality gate (version, lint and tests)."
  (check))

;; ====== Agent skills ======

;; AGENTS.md is generated, never edited by hand.  The section has two halves:
;; the data below, which is this project's, and the task itself, which is not.
;; Another repository copies the whole section and replaces the data - the
;; header, the pinned skills (repository, commit, path, licence) and the
;; practices - and `maak agents' writes its own AGENTS.md.  Regeneration is
;; deterministic: the same pins and the same text produce the same file, byte
;; for byte, and it needs nothing but curl.  The skill URLs assume GitHub, so a
;; skill hosted elsewhere needs a URL of its own.

(define ponytail-commit
  "96608e078b2d5ea607c5c3b8b5a54d1c1fba6846")

(define tdd-commit
  "22f0b463e7a5e579904dd6211a520321035526f7")

;; Name, repository, commit, the path the repository keeps the skill at and the
;; licence.  A skill arrives whole: trimming it means scanning for headings, and
;; such a scan cannot tell a heading from a `##' line inside a code fence.
(define agent-skills
  (list (list "ponytail"
              "DietrichGebert/ponytail"
              ponytail-commit
              "skills/ponytail/SKILL.md"
              "MIT")
        (list "test-driven-development"
              "obra/superpowers"
              tdd-commit
              "skills/test-driven-development/SKILL.md"
              "MIT")))

(define agent-skills-dir
  "reports/agent-skills")

(define agents-header
  "# AGENTS.md

Generated by `maak agents` from the pinned skills and the practices in
`maak.scm`; edit that task, never this file.  The pins and the text are the whole
input, so regenerating gives the same document.  The repository's own rules win
over general advice, and the narrowest rule here wins over the broadest.
")

;; Practices this project keeps.  They are short on purpose: a rule a reader
;; checks in a second is a rule that gets followed.  The pinned skills are the
;; long form of the same habits.
(define agent-practices
  (list
   "## Documentation

- Every user-visible change reaches the documentation: the page that owns the
  feature, the manual page for a flag or an environment variable, and the
  release notes under the unreleased heading.
- Keep the table of contents in step with the headings.  A section with no entry
  is a section nobody finds.
- The guide is Org: one `*` heading per page, `**` for sections, `#+TITLE` and
  `#+EMAIL` at the top, a `CUSTOM_ID` on anything linked from elsewhere, and
  `file:` links between pages.
- Explain why and when, never what: the code already says what.  A docstring's
  first line works as a summary on its own.
- Spell an identifier the way the code spells it - the exact name, not a
  description of it.
- An example must run as written, copied from a real invocation.
- No promises about the future and no changelog in the guide; history lives in
  the release notes.
"
   "## Security

- No secrets in the tree.  Tokens, keys and passwords arrive through the
  environment, and no recipe, workflow or example embeds one.
- Validate at the edge: anything from a file, a report, a path or a subprocess
  is untrusted until it has been checked.
- Never build a shell string out of data.  Tasks pass argument lists, and Guile
  calls `(system \"program\" \"arg\")` or `open-pipe*`, never a command
  assembled with `string-append`.
- Do not `eval` or `read` input you did not write; parse with `(json)` or a
  reader built for the format.
- Escape what leaves the process: a name that came from input is escaped when
  it is written to XML, HTML or a data file.
- Fail closed.  A file that cannot be read is an error, not an empty result.
- Input never chooses the path of a written file; writes stay inside the
  directory reserved for them.
- A dependency is a security decision: it must be needed, MIT compatible and
  pinned.
- Report a vulnerability privately, not in a public issue.
"
   "## Performance

- Measure first.  A before and after belongs in the benchmark, and a speedup
  claimed without a number is not a speedup.
- Prefer not doing the work: cache it, skip it, batch it, or delete the call,
  before making the call faster.
- Then the algorithm, then the data structure (hash table, vector), then the
  micro-optimisation.  In that order, for that reason.
- Guile specifics: keep module resolution and long `assoc` chains out of loops,
  use `#:declarative?` modules and compiled `.go` files at startup, and reach
  for `statprof` instead of guessing where the time goes.
- A shortcut that buys speed costs clarity; it gets a measurement and a
  `shortcut:` comment saying what it costs and when to revisit it.
- Coverage instrumentation is slow by design: iterate without it, and measure
  before finishing.
"
   "## Architecture decisions

- A decision that is expensive to reverse gets a short record: the context, the
  decision, the consequences, and the alternatives that lost.  A small decision
  belongs in the commit body instead.
- Two paragraphs beat a design document; record the choice while it is still a
  choice, not after it has become a fact.
- An accepted record is not rewritten.  Supersede it with a new one and link the
  two directions.
- The record lives next to its subject: the documentation for anything a user
  would notice, the release notes for the release-level result.
- Changes to the public API, a file format, the pipeline or the licence get this
  treatment at a minimum in the commit body.
"
   "## Semantic versioning

- The project follows SemVer 2.0.0 for its public API: the exported functions,
  the CLI flags and environment variables, and the shape of its file formats.
- A breaking change bumps MAJOR, a new feature MINOR, a fix PATCH.  A new export
  is MINOR; removing or changing one is MAJOR.
- One version string, named everywhere it appears: the source, the build
  recipes, the manual page and the packaging.
- A release is a dated release-notes section, an annotated `vX.Y.Z` tag on the
  release commit, and a packaging checksum updated afterwards from the published
  archive.
"
   "## Conventional commits

- `type(scope): summary`, imperative, lower case, no full stop, about seventy
  characters.
- Types in use: `feat`, `fix`, `perf`, `refactor`, `test`, `docs`, `build`, `ci`,
  `chore`.  A `!` after the type or a `BREAKING CHANGE:` footer marks a MAJOR
  change, and says what breaks.
- The subject says what changed.  The body says why, and what was rejected.
- One logical change per commit: a refactor and a fix travel apart, so either
  can be reverted alone.
- Run the full validation task before committing, and never commit a red suite
  without saying so in the message.
- Reference the issue in the footer - `Closes #12` - not in the subject.
"
   "## Functional programming and immutability

- Pure functions in the core, effects at the edges.  Whatever touches the file
  system or the clock sits at the edge; the core does not.
- Prefer `let` and new values to `set!`.  Build results with `map`, `filter`,
  `fold` and named `let`, not with index loops that push into a list.
- A record is a value: construct a new one instead of mutating a shared one, and
  pass configuration as arguments or parameters rather than as globals.
- Handle an exception at the boundary: catch it there, turn it into a result
  record, and let the caller decide what it means.
- A function that both computes and prints is two functions.
- Temporary effects - a changed directory, a bound environment variable - go
  through `dynamic-wind`.
- Prefer the expression style: `if` and `cond` that return a value, not a branch
  that assigns one.
"
   "## Do not reinvent the wheel

- Guile's standard library first: `(ice-9 ...)` for the runtime, `(srfi srfi-1)`
  for lists, `(srfi srfi-9)` for records, `(srfi srfi-13)` for strings, `(json)`
  for JSON.  The project already depends on all of them.
- Then this codebase: read the existing modules before writing a helper, and use
  the one that is nearly right instead of adding a second one.
- A new dependency needs a reason the standard library cannot meet, a licence
  the project can carry, and a paragraph in the commit body.
- Prefer deleting a special case to writing code that handles it.
- The best diff removes lines and keeps the behaviour; the second best is a
  small diff that is obvious a year later.
"))

(define (slurp path)
  "Return the whole of @var{path} as a string."
  (call-with-input-file path
    (lambda (port)
      (let loop ((lines '())
                 (line (read-line port)))
        (if (eof-object? line)
            (string-concatenate-reverse lines)
            (loop (cons (string-append line "\n") lines)
                  (read-line port)))))))

(define (fetch-skill name repository commit path)
  "Download one skill pinned at @var{commit}, into the reports tree.

  Returns the skill's text."
  (let ((target (~ "~a/~a.md" agent-skills-dir name))
        (url (~ "https://raw.githubusercontent.com/~a/~a/~a"
                repository commit path)))
    (run (list "curl" "--fail" "--silent" "--show-error" "--location"
               "--output" target url)
         #:verbose? #t)
    (slurp target)))

(define (agents)
  "Regenerate AGENTS.md from the pinned skills and the practices."
  (run (list "mkdir" "-p" agent-skills-dir))
  ;; Every download happens before the file is opened, so a fetch that fails
  ;; leaves the previous AGENTS.md in place rather than a half-written one.
  (let ((skills (map (lambda (skill)
                       (append skill
                               (list (fetch-skill (list-ref skill 0)
                                                  (list-ref skill 1)
                                                  (list-ref skill 2)
                                                  (list-ref skill 3)))))
                     agent-skills)))
    (call-with-output-file "AGENTS.md"
      (lambda (port)
        (display agents-header port)
        (for-each (lambda (skill)
                    (format port
                            "~%## ~a~%~%`~a` at `~a`, `~a`, ~a licensed.~%~%"
                            (list-ref skill 0)
                            (list-ref skill 1)
                            (list-ref skill 2)
                            (list-ref skill 3)
                            (list-ref skill 4))
                    (display (list-ref skill 5) port))
                  skills)
        (for-each (lambda (practice)
                    (newline port)
                    (display practice port))
                  agent-practices)))))
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
