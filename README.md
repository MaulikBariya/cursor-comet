# cursor-comet

Dependency-free tapered cursor trails for graphical Emacs 29.1+.

`cursor-comet-mode` measures movement across the whole Emacs frame, then draws
a fading trail through ordinary windows and the minibuffer. Large jumps such as
`M-x`, search results, and window switches animate; small movements stay quiet.

## Install

### Emacs 29 package-vc

```elisp
(package-vc-install "https://github.com/MaulikBariya/cursor-comet")
(require 'cursor-comet)
(cursor-comet-mode 1)
```

### Doom Emacs

Add to `$DOOMDIR/packages.el`:

```elisp
(package! cursor-comet
  :recipe (:host github :repo "MaulikBariya/cursor-comet"))
```

Add to `$DOOMDIR/config.el`:

```elisp
(use-package! cursor-comet
  :config
  (setq cursor-comet-minimum-distance 2)
  (cursor-comet-mode 1))
```

Run `doom sync`, then restart Doom Emacs.

### Manual

```sh
git clone https://github.com/MaulikBariya/cursor-comet.git
```

```elisp
(add-to-list 'load-path "/path/to/cursor-comet")
(require 'cursor-comet)
(cursor-comet-mode 1)
```

## Configure

```elisp
(setq cursor-comet-minimum-distance 2 ; approximate character-cell distance
      cursor-comet-duration 0.18       ; seconds
      cursor-comet-color nil)          ; nil follows cursor color
```

Run `M-x customize-group RET cursor-comet` for all options. Toggle with
`M-x cursor-comet-mode`.

## Compatibility

- Requires graphical Emacs 29.1 or newer.
- Uses standard Emacs overlays and pixel-coordinate APIs; no native module.
- Designed for X11 and PGTK/Wayland Linux builds.
- Terminal Emacs and every theme/font/scaling combination are not guaranteed.
- Mode lines, fringes, and other window decorations are intentionally skipped.

## Test

```sh
emacs -Q --batch -L . -L test \
  -l test/cursor-comet-test.el \
  -f ert-run-tests-batch-and-exit
```

Byte-compile with warnings treated as errors:

```sh
emacs -Q --batch -L . \
  --eval '(setq byte-compile-error-on-warn t)' \
  -f batch-byte-compile cursor-comet.el
```

## Contributing

Bug reports should include Emacs version, `window-system`, Linux distribution,
desktop environment, and whether session uses X11 or Wayland.

## License

GPL-3.0-or-later. See [LICENSE](LICENSE).
