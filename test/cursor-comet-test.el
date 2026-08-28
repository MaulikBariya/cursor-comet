;;; cursor-comet-test.el --- Tests for cursor-comet -*- lexical-binding: t; -*-

(require 'ert)
(require 'cursor-comet)

(ert-deftest cursor-comet-interpolation-is-taper-safe ()
  (should (equal (cursor-comet--interpolate '(0 . 0) '(8 . 4) 4)
                 '((0 . 0) (2 . 1) (4 . 2) (6 . 3))))
  (should-not (member '(8 . 4)
                      (cursor-comet--interpolate '(0 . 0) '(8 . 4) 4))))

(ert-deftest cursor-comet-mode-tracks-minibuffer-entry ()
  (unwind-protect
      (progn
        (cursor-comet-mode 1)
        (should (memq #'cursor-comet--track
                      (default-value 'minibuffer-setup-hook))))
    (cursor-comet-mode -1))
  (should-not (memq #'cursor-comet--track
                    (default-value 'minibuffer-setup-hook))))

(provide 'cursor-comet-test)

;;; cursor-comet-test.el ends here
