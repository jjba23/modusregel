# Vision

modusregel draws the Emacs mode line out of named elements, each of them a
`defcustom` you can set, reorder or leave out, and the direction is to stay the
mode line that is *yours* — no segments to learn, no icon font to install, no
colour the active theme did not choose — while saying the things a mode line
should say and currently does not.

## Where modusregel is today

One file, `modusregel.el`, 380 lines, Emacs 29.1 and later,
`lexical-binding: t`, MIT, no dependencies at all. `modusregel-mode` is a global
minor mode that makes `modusregel-format` the default `mode-line-format` and puts
back the previous value when disabled, remembering it exactly once so that
enabling twice cannot record the package's own format as the thing to restore.

Seventeen elements, each a `defcustom` whose value the mode line resolves at
redisplay: the 𝝺 lead, the remote `☍`, the buffer name, `●` for unsaved and `☡`
for read-only, `[narrow]`, the spacers, line and column, the buffer position as a
percentage or `Top`/`Bot`/`All`, the VC branch with the backend stripped, the
prettified major mode, `𝌤` for Eglot, the Flymake counters, and `nyan-mode`'s cat
as an opt-in. 32 ERT tests, a `checkdoc` gate that turns findings into a non-zero
exit, and a byte-compile of the package *and* its suite with warnings as errors.

Four decisions carry the package, and every idea below must survive all four.

**`modusregel-format` holds symbols, not values.** The list names the element
variables the way Emacs' own `mode-line-format` names
`mode-line-buffer-identification`, so the mode line resolves each one when it
draws and a change is visible at the next redisplay with nothing to reload. It
also means the list must not begin with a symbol: `(SYMBOL THEN ELSE...)` is the
conditional form, which is why it begins with a string, exactly as Emacs' own
format begins with `"%e"` for the same reason.

**Everything is marked `risky-local-variable`.** A symbol whose value holds
`:eval` forms or text properties is drawn as an empty string unless it is marked,
and nothing announces the mistake. `modusregel--format-elements` exists to make
that marking a loop over one list rather than seventeen scattered `put` calls,
and the suite asserts it.

**Faces set height, never colour.** `modusregel-buffer-position-face` and
`modusregel-vc-face` set `:height 0.80` and nothing else, so the text keeps the
colours of the selected or unselected window's mode line. This is why a theme
change needs no cooperation from the package, and it is the constraint that rules
out separator glyphs drawn in their own colour.

**Unicode only, TUI and GUI alike.** The iconography is `𝝺`, `●`, `☡`, `☍`, `𝌤` —
characters a terminal font already has, at one column each, rather than a Nerd
Font private-use range. The suite renders the mode line for real in a second
Emacs given a terminal through `script`, because `format-mode-line` returns an
empty string in a batch Emacs and a mode line taken on trust is a mode line
nobody has seen.

## The vision

1. **The mode line says everything the buffer is doing.** Minor modes, a running
   process, the project a file belongs to and the input method in force are all
   things a user asks the mode line about, and all of them are currently invisible
   here. Today's seventeen elements cover state and position; they do not cover
   *context*.

2. **A buffer can choose its own elements.** The format is one default for every
   window, and the only way to vary it is to `setq` `mode-line-format` per buffer
   by hand. The direction is a supported, documented way to say "no line numbers
   in the terminal buffer, no VC in the agenda".

3. **The package installs like any other.** Not being on MELPA or ELPA is a
   distribution problem, not a technical one, and it costs adoption every day. The
   direction is a recipe upstream and a version-check that already exists here
   holding the result honest.

4. **Emacs' own drawing stays the engine.** No separators, no powerline images, no
   `:box` tricks, no per-frame layout computation: every element is a construct
   the mode line understands natively, which keeps redisplay cheap and the package
   readable. Anything that would need a redisplay hook is out of scope.

5. **The suite keeps watching what breaks quietly.** Every failure here was
   silent — an unmarked symbol drawn as an empty string, a `:eval` computed once
   at load time, a `vc-mode` read before VC loaded, a Nyan element erroring in a
   session without it. A new element arrives with a test that would have caught
   the last one, and a render test that sees it.

## Features that are in scope and not built yet

- **Minor-mode lighters.** The format has no `mode-line-modes` equivalent, so
  `flymake-mode`, region highlighting or any package's lighter never appears. The
  hard part is drawing `minor-mode-alist` entries — arbitrary strings and lists,
  often already propertised — without breaking the rule that an element says
  nothing when it has nothing to say.
- **A right-aligned tail.** `mode-line-format` can align with a `(space
  :align-to ...)` construct, and this package draws left to right only. The hard
  part is making alignment a placeable element rather than a change to every other
  element's padding.
- **Per-buffer element selection.** The mechanism — a buffer's own
  `mode-line-format` — exists and is documented, but there is no supported way to
  express it as a policy. The hard part is a shape that is not a second
  configuration system.
- **`project.el` in the mode line.** A project's name is one call to
  `project-current` and `project-name`, and the element does not exist. The hard
  part is nothing; it is here to be picked up as a first contribution.
- **A running process, and the input method.** `mode-line-process` and
  `mode-line-input-method` are what the built-in mode line shows and this one does
  not. The hard part is keeping each element to a couple of calls, since every
  `:eval` runs on each redisplay.

## New features that would be worth having

- **A `modusregel-gallery`.** The README shows screenshots; a page listing each
  element, the states it draws in and one line of Lisp to try it would answer the
  question the screenshots raise — the highest adoption value per hour here.
- **A "minimal" preset**, three or four elements for a small terminal frame, as a
  value of `modusregel-format` rather than a second mode. Speculative: it invites
  a preset zoo, which is the failure mode of every mode-line package.
- **`modusregel-major-mode-alist` grown from the modes actually loaded**, so a
  package's own mode name is prettified without waiting for a release here. The
  hard part is doing it without an eager `require` of anything.
- **A `modusregel-debug` command** that prints, for the current buffer, what each
  element resolves to and why — the mode line equivalent of `M-x
  describe-face`, and the answer to "why is this blank".

## Contributions that would move the needle

1. **A minor-mode lighters element with its tests.** It is the one thing the
   package visibly lacks, the design question is genuinely interesting, and the
   existing suite already has the fixture a new element must satisfy.
2. **The MELPA recipe.** A few lines upstream and a `Package-Requires` header that
   is already correct; it removes the "not yet available in popular Emacs
   repositories" sentence, which is the first thing a reader meets.
3. **A `project-name` element plus a render test.** Twenty lines end to end,
   including the test in the terminal-running second Emacs, which is exactly the
   shape of contribution that teaches the suite.
4. **The gallery page.** No Emacs Lisp at all, and it is what converts a reader
   comparing four mode-line packages.
5. **A `modusregel-debug` reporter.** Small, and it answers the support question
   that costs the author the most time: "my mode line is empty".
6. **A version-check test for the new packaging copies** as they appear, since
   `maak version-check` already holds the spec, the PKGBUILD, the README and the
   Debian changelog to the `Version:` header.

## Compared to related projects

| Project | What it is | Where modusregel differs |
| --- | --- | --- |
| `doom-modeline` | The most widely used mode line in the Doom ecosystem: many segments, Nerd Font icons, per-buffer state, flycheck/Eglot/lsp indicators, and a sizeable configuration surface. | `doom-modeline` draws icon-font glyphs and owns its own colour scheme; modusregel draws Unicode each terminal already has and takes its colours from whatever theme is active. `doom-modeline` has segments and rules for when each shows; modusregel has named variables and a list. |
| `powerline` | The original, and still the reference implementation of separators: curved and slanted images, themes, and the `powerline-*` extension API. | `powerline` is a rendering layer that replaces the mode line's appearance; modusregel is a format that stays inside Emacs' own drawing, so there are no images to scale on a HiDPI frame and no separator theme to choose between. |
| `telephone-line` | A powerline successor with hierarchical segments, subseparators and a `telephone-line-defsegment` macro. | The segment macro is more expressive than a variable when layout itself is the feature; against that, a modusregel element is placeable by name in an ordinary list, and the package is a fifth of the size. |
| `mood-line` | A deliberately minimal mode line: a few segments, Nerd Font icons, Flymake and Eglot support, and a similar "small is good" pitch. | The closest sibling in intent. `mood-line` requires an icon font and hands you a fixed set of segments; modusregel requires no font and hands you the variables, with the `nyan-mode` cat as the only imported novelty. |
| `smart-mode-line`, `sml-modeline` | The first "smart" mode line: hides most minor modes, abbreviates names, and adds a rich minibuffer. | `smart-mode-line`'s headline feature is hiding minor modes; modusregel draws no minor modes at all today, which is the same outcome reached by omission rather than by policy — and the reason lighters rank first below. |
| `moody` | Replaces the mode-line and minibuffer faces wholesale, used by CIDER, so the mode line and the minibuffer read as one surface. | `moody` is about faces; modusregel sets no colour on purpose, so the two could be combined, and a user who wants `moody`'s colour treatment should keep it rather than see it overridden. |
| `minions` | A minor mode that removes lighters from `minor-mode-alist` so the mode line gets shorter. | `minions` is a complement, not a rival: it decides which lighters exist, and a lighters element here would decide how the survivors are drawn. |
| Emacs' built-in `mode-line-format` | The default: buffer identification, minor modes, process, position, and a documented construct language. | modusregel is that language used rather than replaced — the same `%`-constructs and `:eval` forms, with the parts named and made customizable, and no bitmap or separator anywhere. |

What the others do that modusregel could still add: `doom-modeline`'s
conditional-segment discipline is worth stealing as a principle even if the
mechanism is not — an element that draws nothing when there is nothing to say is
already this package's rule. `minions`' insight, that most lighters are noise, is
the argument for a lighters element that shows a chosen few rather than all of
them. `powerline`'s separators are the one thing that genuinely cannot be
borrowed: they cost an image, a colour of their own and a HiDPI bug, which is the
whole reason this package draws without them. `mood-line`'s icon font buys a
visual density Unicode cannot match, and the honest answer is that it is a real
trade — a Nerd Font is a dependency, and this package's zero-dependency story is
worth more than the density.

Where modusregel is ahead and should stay ahead: no dependencies beyond Emacs
29.1 itself; TUI and GUI drawing from the same characters, so a screenshot is
what a terminal shows; no colour of its own, so every theme works without a
`modusregel-theme`; elements that are `defcustom`s with declared types, appearing
in `M-x customize-group RET modusregel RET` in the order they are drawn; and a
test suite that renders the mode line for real in a terminal rather than asserting
that the code around it looks right.

## In the long run

**The mode line belongs to the theme, not to the package.** One `setq-default` and
seventeen variables is the whole surface, and it works with the theme you already
chose. Every package in this space eventually grows a colour scheme; growing one
would be the point at which modusregel stopped being the modest option.

**Unicode-only is a position, not a limitation.** A mode line that renders
correctly over SSH, in a Linux console with a fallback font, in `emacs -nw` inside
a container, and on a graphical frame with no font installed is worth the visual
density it gives up — and the bet is that terminals keep improving faster than a
private-use icon range becomes safe to assume.

**Small and inspected beats large and trusted.** The package's history is a series
of silent failures found by an audit and closed by tests that would have caught
them; the durable asset is not the seventeen elements but the suite that will not
let an eighteenth be wrong.

## Getting involved

`maak` on its own runs the whole gate: version-check, byte-compile with warnings
as errors, `checkdoc`, then the ERT suite including the terminal render test.
`AGENTS.md` is the repository's rulebook and wins over anything argued here.

*This document describes intent, not commitments: it names directions the
project would like to take, and no item in it is promised for any release.*
