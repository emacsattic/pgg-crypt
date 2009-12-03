;;; pgg-crypt.el -- automatic encryption with gpg

;; $Revision:  $
;; $Date:  $

;; This file is not part of Emacs

;; Author: Phillip Lord <phillip.lord@newcastle.ac.uk>
;; Maintainer: Phillip Lord <phillip.lord@newcastle.ac.uk>
;; Website: http://www.russet.org.uk

;; COPYRIGHT NOTICE
;;
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA. 

;;; Commentary
;; 
;; This is a minor mode which will decrypt a file and ensure that it
;; is saved in encrypted form. There is one main entry point,
;; `pgg-crypt-mode'. If you want to encrypt or decrypt the buffer
;; manually, then `pgg-crypt-decrypt' and `pgg-crypt-encrypt' do what
;; you'd expect.
;;
;; You will want to set `pgg-gpg-user-id' `pgg-default-user-id'
;; `pgg-gpg-all-secret-keys'. 
;; 
;; This requires pgg, which is part of Gnus, but only in the
;; pre-release/cvs versions of emacs. You can download the latest
;; version of Gnus, though, and just use the new version of pgg. 
;; 
;; I AM NOT A SECURITY EXPERT. THIS IS PROBABLY FALL OF WHOLES.

;;; Bugs
;; 
;; I don't know how to block auto-save-mode!

;;; Todo
;; 
;; Need a global minor mode, with some sort of file list for storing
;; those files that need to be encrypted. 

(require 'pgg)


(defun pgg-crypt-decrypt-from-self()
  (let* ((start (point-min))
	 (end (point-max))
         (status (pgg-decrypt-region start end)))
    (pgg-display-output-buffer start end status)
    status))

(defun pgg-crypt-encrypt-for-self()
  (let* ((start (point-min))
	 (end (point-max))
         (status (pgg-encrypt-region start end `(,pgg-gpg-user-id) nil)))
    (message "Encrypting Buffer")
    (pgg-display-output-buffer start end status)
    status))


(defmacro pgg-crypt-save-buffer-modified-p(&rest body)
  "Eval BODY without affected buffer modification status"
  `(let ((buffer-modified (buffer-modified-p)))
     ,@body
     (set-buffer-modified-p buffer-modified)))



(defvar pgg-crypt-mode-map (make-keymap)
  "Keymap for pgg-mode")

(define-key pgg-crypt-mode-map "\C-c.d" 'pgg-crypt-decrypt)
(define-key pgg-crypt-mode-map "\C-c.e" 'pgg-crypt-encrypt)


(define-minor-mode pgg-crypt-mode "Toggle pgg-crypt mode.

This mode does automatic encryption decryption"
  nil
  " Pgg"
  pgg-crypt-mode-map
  (pgg-crypt-mode-toggle (interactive-p)))

(defun pgg-crypt-mode-toggle (is-interactive)
  (if pgg-crypt-mode
      (progn 
        ;; autosave nobble?
        (add-hook 'local-write-file-hooks 
                  'pgg-crypt-local-write-hook)
        (make-local-hook 'after-save-hook)
        (add-hook 'after-save-hook
                  'pgg-crypt-restore-buffer t t))
    (remove-hook 'local-write-file-hooks
                 'pgg-crypt-encrypt-maybe)
    (remove-hook 'after-save-hook
                 'pgg-crypt-decrypt-maybe)))


(defvar pgg-crypt-buffer-contents
  nil)

(defun pgg-crypt-local-write-hook ()
  (setq pgg-crypt-buffer-contents nil)
  (unless (pgg-crypt-encrypted-p)
    (setq pgg-crypt-buffer-contents (buffer-string)))
  (if (not (pgg-crypt-encrypt-maybe))
      (error "Encryption Failed, aborting save")
    (message "Encrypted buffer on save")
    ;; return nil or save won't happen!
    nil))


(defun pgg-crypt-restore-buffer ()
  "Restore the buffer without affected modifed state"
  (when pgg-crypt-buffer-contents
    (pgg-crypt-save-buffer-modified-p
     (erase-buffer)
     (insert pgg-crypt-buffer-contents)
     (setq pgg-crypt-buffer-contents nil))))


(defun pgg-crypt-decrypt()
  (interactive)
  (if (pgg-crypt-encrypted-p)
      (pgg-crypt-save-buffer-modified-p
       (pgg-crypt-decrypt-from-self))
    (message "Buffer does not appear to be decrypted")))

(defun pgg-crypt-encrypt()
  (interactive)
  (if (pgg-crypt-encrypted-p)
      (message "Buffer appears to already be encrypted")
    (pgg-crypt-encrypt-for-self)))

(defun pgg-crypt-decrypt-maybe()
  "Decrypt the current buffer if necessary"
  (if (pgg-crypt-encrypted-p)
      (pgg-crypt-decrypt-from-self))) 
  

(defun pgg-crypt-encrypt-maybe()
  "Encrypt the current buffer if necessary. 

Return t if the buffer ends in an encrypted state"
  (if (pgg-crypt-encrypted-p)
      t
    (pgg-crypt-encrypt-for-self)))


(defun pgg-crypt-encrypted-p()
  (save-excursion
    (goto-char (point-min))
    (search-forward "BEGIN PGP MESSAGE" nil t)))


(provide 'pgg-crypt)