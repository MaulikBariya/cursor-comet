;;; cursor-comet.el --- Tapered cursor movement trails -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Maulik Bariya

;; Author: Maulik Bariya <maulikbariya@gmail.com>
;; Maintainer: Maulik Bariya <maulikbariya@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: convenience, faces
;; URL: https://github.com/MaulikBariya/cursor-comet
;; SPDX-License-Identifier: GPL-3.0-or-later

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;;; Commentary:

;; `cursor-comet-mode' draws a short-lived, tapered trail after cursor
;; movements.  It uses ordinary overlays and therefore needs no native
;; module or external dependency.

;;; Code:

(require 'color)
(require 'cl-lib)

(defgroup cursor-comet nil
  "Tapered trails following cursor movement."
  :group 'cursor
  :prefix "cursor-comet-")

(defcustom cursor-comet-minimum-distance 2
  "Minimum movement distance, measured approximately in character cells."
  :type 'number
  :safe #'numberp)

(defcustom cursor-comet-duration 0.18
  "Seconds before a trail disappears."
  :type 'number
  :safe #'numberp)

(defcustom cursor-comet-color nil
  "Trail color, or nil to use the current frame's cursor color."
  :type '(choice (const :tag "Cursor color" nil) color)
  :safe (lambda (value) (or (null value) (stringp value))))

(defcustom cursor-comet-frame-interval 0.025
  "Seconds between trail fade updates."
  :type 'number
  :safe #'numberp)

(defvar cursor-comet--last-marker nil)
(defvar cursor-comet--last-window nil)
(defvar cursor-comet--overlays nil)
(defvar cursor-comet--timer nil)
(defvar cursor-comet--started-at nil)

(defun cursor-comet--interpolate (start end steps)
  "Return evenly spaced points from START toward END.
The result contains STEPS points and excludes END so it cannot cover the cursor."
  (cl-loop for index below steps
           for ratio = (/ (float index) steps)
           collect (cons (round (+ (car start)
                                   (* ratio (- (car end) (car start)))))
                         (round (+ (cdr start)
                                   (* ratio (- (cdr end) (cdr start))))))))

(defun cursor-comet--distance-and-steps (start end frame)
  "Return movement distance and sample count between START and END on FRAME."
  (let* ((cell-width (max 1 (frame-char-width frame)))
         (cell-height (max 1 (frame-char-height frame)))
         (dx (/ (float (- (car end) (car start))) cell-width))
         (dy (/ (float (- (cdr end) (cdr start))) cell-height)))
    (cons (sqrt (+ (* dx dx) (* dy dy)))
          (max 1 (ceiling (max (abs dx) (abs dy)))))))

(defun cursor-comet--blend (foreground background amount)
  "Blend FOREGROUND over BACKGROUND by AMOUNT and return a color string."
  (let ((fg (color-name-to-rgb foreground))
        (bg (color-name-to-rgb background)))
    (if (and fg bg)
        (apply #'color-rgb-to-hex
               (cl-mapcar (lambda (front back)
                            (+ (* amount front) (* (- 1 amount) back)))
                          fg bg))
      foreground)))

(defun cursor-comet--clear ()
  "Remove active trail and its timer."
  (when (timerp cursor-comet--timer)
    (cancel-timer cursor-comet--timer))
  (setq cursor-comet--timer nil
        cursor-comet--started-at nil)
  (mapc (lambda (overlay)
          (when (overlayp overlay)
            (delete-overlay overlay)))
        cursor-comet--overlays)
  (setq cursor-comet--overlays nil))

(defun cursor-comet--tick ()
  "Fade active trail by one animation frame."
  (let ((remaining (- 1.0 (/ (- (float-time) cursor-comet--started-at)
                             (max 0.001 cursor-comet-duration)))))
    (if (<= remaining 0)
        (cursor-comet--clear)
      (dolist (overlay cursor-comet--overlays)
        (when (overlayp overlay)
          (let* ((strength (* remaining
                              (overlay-get overlay 'cursor-comet-strength)))
                 (color (cursor-comet--blend
                         (overlay-get overlay 'cursor-comet-foreground)
                         (overlay-get overlay 'cursor-comet-background)
                         strength)))
            (overlay-put overlay 'face `(:background ,color)))))
      (force-window-update))))

(defun cursor-comet--frame-position (position window)
  "Convert POSITION in WINDOW to frame-relative pixel coordinates."
  (let ((local (posn-x-y position))
        (edges (window-inside-pixel-edges window)))
    (cons (+ (nth 0 edges) (car local))
          (+ (nth 1 edges) (cdr local)))))

(defun cursor-comet--window-position (pixel frame)
  "Return window and buffer position at frame-relative PIXEL on FRAME."
  (cl-loop for window in (window-list frame t)
           for edges = (window-inside-pixel-edges window)
           when (and (<= (nth 0 edges) (car pixel))
                     (< (car pixel) (nth 2 edges))
                     (<= (nth 1 edges) (cdr pixel))
                     (< (cdr pixel) (nth 3 edges)))
           for position = (posn-point
                           (posn-at-x-y (- (car pixel) (nth 0 edges))
                                        (- (cdr pixel) (nth 1 edges))
                                        window))
           when (integer-or-marker-p position)
           return (cons window position)))

(defun cursor-comet--draw (start end frame steps)
  "Render cursor trail from START toward END on FRAME.
Use STEPS samples."
  (cursor-comet--clear)
  (let* ((foreground (or cursor-comet-color
                         (frame-parameter frame 'cursor-color)
                         "#4f7cff"))
         (background (or (face-background 'default frame t) "#000000"))
         positions)
    (dolist (pixel (cursor-comet--interpolate start end steps))
      (let ((position (cursor-comet--window-position pixel frame)))
        (when (and position
                   (not (equal position (car positions))))
          (push position positions))))
    (setq positions (nreverse positions))
    (cl-loop with count = (length positions)
             for position in positions
             for index from 1
             for strength = (expt (/ (float index) (max 1 count)) 0.65)
             for window = (car position)
             for buffer-position = (cdr position)
             for buffer = (window-buffer window)
             do (with-current-buffer buffer
                  (let ((overlay (make-overlay buffer-position
                                               (min (1+ buffer-position)
                                                    (point-max))
                                               buffer nil t)))
                    (overlay-put overlay 'window window)
                    (overlay-put overlay 'priority 1001)
                    (overlay-put overlay 'evaporate t)
                    (overlay-put overlay 'cursor-comet-strength strength)
                    (overlay-put overlay 'cursor-comet-foreground foreground)
                    (overlay-put overlay 'cursor-comet-background background)
                    (overlay-put overlay 'face
                                 `(:background
                                   ,(cursor-comet--blend foreground background
                                                         strength)))
                    (push overlay cursor-comet--overlays))))
    (when cursor-comet--overlays
      (setq cursor-comet--started-at (float-time)
            cursor-comet--timer
            (run-at-time cursor-comet-frame-interval
                         cursor-comet-frame-interval
                         #'cursor-comet--tick)))))

(defun cursor-comet--track ()
  "Record point and animate qualifying cursor movement."
  (condition-case nil
      (let* ((window (selected-window))
             (frame (window-frame window))
             (buffer (window-buffer window))
             (current (posn-at-point (window-point window) window))
             (previous (and (window-live-p cursor-comet--last-window)
                            (eq frame
                                (window-frame cursor-comet--last-window))
                            (markerp cursor-comet--last-marker)
                            (eq (window-buffer cursor-comet--last-window)
                                (marker-buffer cursor-comet--last-marker))
                            (posn-at-point cursor-comet--last-marker
                                           cursor-comet--last-window))))
        (when (and current previous)
          (let* ((start (cursor-comet--frame-position
                         previous cursor-comet--last-window))
                 (end (cursor-comet--frame-position current window))
                 (measure (cursor-comet--distance-and-steps
                           start end frame)))
            (when (>= (car measure) cursor-comet-minimum-distance)
              (cursor-comet--draw start end frame (cdr measure)))))
        (unless (markerp cursor-comet--last-marker)
          (setq cursor-comet--last-marker (make-marker)))
        (set-marker cursor-comet--last-marker (window-point window) buffer)
        (setq cursor-comet--last-window window))
    (error (cursor-comet--clear))))

(defun cursor-comet--reset ()
  "Reset cursor tracking state."
  (cursor-comet--clear)
  (when (markerp cursor-comet--last-marker)
    (set-marker cursor-comet--last-marker nil))
  (setq cursor-comet--last-marker nil
        cursor-comet--last-window nil))

;;;###autoload
(define-minor-mode cursor-comet-mode
  "Toggle tapered cursor movement trails globally."
  :global t
  :group 'cursor-comet
  (if cursor-comet-mode
      (progn
        (cursor-comet--reset)
        (add-hook 'post-command-hook #'cursor-comet--track)
        (add-hook 'minibuffer-setup-hook #'cursor-comet--track))
    (remove-hook 'post-command-hook #'cursor-comet--track)
    (remove-hook 'minibuffer-setup-hook #'cursor-comet--track)
    (cursor-comet--reset)))

(provide 'cursor-comet)

;;; cursor-comet.el ends here
