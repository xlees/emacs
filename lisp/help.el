;;; help.el --- help commands for Emacs

;; Copyright (C) 1985, 1986, 1993, 1994, 1998, 1999, 2000, 2001
;;   Free Software Foundation, Inc.

;; Maintainer: FSF
;; Keywords: help, internal

;; This file is part of GNU Emacs.

;; GNU Emacs is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:

;; This code implements GNU Emacs' on-line help system, the one invoked by
;; `M-x help-for-help'.

;;; Code:

;; Get the macro make-help-screen when this is compiled,
;; or run interpreted, but not when the compiled code is loaded.
(eval-when-compile (require 'help-macro))
(eval-when-compile (require 'view))

(defvar help-map (make-sparse-keymap)
  "Keymap for characters following the Help key.")

(defvar help-mode-map (make-sparse-keymap)
  "Keymap for help mode.")

(define-key global-map (char-to-string help-char) 'help-command)
(define-key global-map [help] 'help-command)
(define-key global-map [f1] 'help-command)
(fset 'help-command help-map)

(define-key help-map (char-to-string help-char) 'help-for-help)
(define-key help-map [help] 'help-for-help)
(define-key help-map [f1] 'help-for-help)
(define-key help-map "?" 'help-for-help)

(define-key help-map "\C-c" 'describe-copying)
(define-key help-map "\C-d" 'describe-distribution)
(define-key help-map "\C-w" 'describe-no-warranty)
(define-key help-map "\C-p" 'describe-project)
(define-key help-map "a" 'apropos-command)

(define-key help-map "b" 'describe-bindings)

(define-key help-map "c" 'describe-key-briefly)
(define-key help-map "k" 'describe-key)

(define-key help-map "d" 'describe-function)
(define-key help-map "f" 'describe-function)

(define-key help-map "F" 'view-emacs-FAQ)

(define-key help-map "i" 'info)
(define-key help-map "4i" 'info-other-window)
(define-key help-map "\C-f" 'Info-goto-emacs-command-node)
(define-key help-map "\C-k" 'Info-goto-emacs-key-command-node)
(define-key help-map "\C-i" 'info-lookup-symbol)

(define-key help-map "l" 'view-lossage)

(define-key help-map "m" 'describe-mode)
(define-key help-map "\C-m" 'view-order-manuals)

(define-key help-map "\C-n" 'view-emacs-news)
(define-key help-map "n" 'view-emacs-news)

(define-key help-map "p" 'finder-by-keyword)
(autoload 'finder-by-keyword "finder"
  "Find packages matching a given keyword." t)

(define-key help-map "P" 'view-emacs-problems)

(define-key help-map "s" 'describe-syntax)

(define-key help-map "t" 'help-with-tutorial)

(define-key help-map "w" 'where-is)

(define-key help-map "v" 'describe-variable)

(define-key help-map "q" 'help-quit)

(define-key help-mode-map [mouse-2] 'help-follow-mouse)
(define-key help-mode-map "\C-c\C-b" 'help-go-back)
(define-key help-mode-map "\C-c\C-c" 'help-follow)
(define-key help-mode-map "\t" 'help-next-ref)
(define-key help-mode-map [backtab] 'help-previous-ref)
(define-key help-mode-map [(shift tab)] 'help-previous-ref)
;; Documentation only, since we use minor-mode-overriding-map-alist.
(define-key help-mode-map "\r" 'help-follow)

(defvar help-xref-stack nil
  "A stack of ways by which to return to help buffers after following xrefs.
Used by `help-follow' and `help-xref-go-back'.
An element looks like (POSITION FUNCTION ARGS...), where POSITION is
`(POINT . BUFFER-NAME)'.
To use the element, do (apply FUNCTION ARGS) then goto the point in
the named buffer.")
(put 'help-xref-stack 'permanent-local t)

(defvar help-xref-stack-item nil
  "An item for `help-follow' in this buffer to push onto `help-xref-stack'.
The format is (FUNCTION ARGS...).")
(put 'help-xref-stack-item 'permanent-local t)

(setq-default help-xref-stack nil help-xref-stack-item nil)

(defcustom help-mode-hook nil
  "Hook run by `help-mode'."
  :type 'hook
  :group 'help)

(defun help-mode ()
  "Major mode for viewing help text and navigating references in it.
Entry to this mode runs the normal hook `help-mode-hook'.
Commands:
\\{help-mode-map}"
  (interactive)
  (kill-all-local-variables)
  (use-local-map help-mode-map)
  (setq mode-name "Help")
  (setq major-mode 'help-mode)
  (make-local-variable 'font-lock-defaults)
  (setq font-lock-defaults nil)         ; font-lock would defeat xref
  (view-mode)
  (make-local-variable 'view-no-disable-on-exit)
  (setq view-no-disable-on-exit t)
  (run-hooks 'help-mode-hook))

(defun help-mode-setup ()
  (help-mode)
  (setq buffer-read-only nil))

(add-hook 'temp-buffer-setup-hook 'help-mode-setup)

(defun help-mode-finish ()
  (when (eq major-mode 'help-mode)
    ;; View mode's read-only status of existing *Help* buffer is lost
    ;; by with-output-to-temp-buffer.
    (toggle-read-only 1)
    (help-make-xrefs (current-buffer)))
  (setq view-return-to-alist
	(list (cons (selected-window) help-return-method))))

(add-hook 'temp-buffer-show-hook 'help-mode-finish)

(defun help-quit ()
  "Just exit from the Help command's command loop."
  (interactive)
  nil)

(defun help-with-tutorial (&optional arg)
  "Select the Emacs learn-by-doing tutorial.
If there is a tutorial version written in the language
of the selected language environment, that version is used.
If there's no tutorial in that language, `TUTORIAL' is selected.
With arg, you are asked to choose which language."
  (interactive "P")
  (let ((lang (if arg
		  (read-language-name 'tutorial "Language: " "English")
		(if (get-language-info current-language-environment 'tutorial)
		    current-language-environment
		  "English")))
	file filename)
    (setq filename (get-language-info lang 'tutorial))
    (setq file (expand-file-name (concat "~/" filename)))
    (delete-other-windows)
    (if (get-file-buffer file)
	(switch-to-buffer (get-file-buffer file))
      (switch-to-buffer (create-file-buffer file))
      (setq buffer-file-name file)
      (setq default-directory (expand-file-name "~/"))
      (setq buffer-auto-save-file-name nil)
      (insert-file-contents (expand-file-name filename data-directory))
      (goto-char (point-min))
      (search-forward "\n<<")
      (beginning-of-line)
      (delete-region (point) (progn (end-of-line) (point)))
      (let ((n (- (window-height (selected-window))
		  (count-lines (point-min) (point))
		  6)))
	(if (< n 12)
	    (newline n)
	  ;; Some people get confused by the large gap.
	  (newline (/ n 2))
	  (insert "[Middle of page left blank for didactic purposes.  "
		  "Text continues below]")
	  (newline (- n (/ n 2)))))
      (goto-char (point-min))
      (set-buffer-modified-p nil))))

(defun string-key-binding (key)
  "Value is the binding of KEY in a string.
If KEY is an event on a string, and that string has a `local-map'
or `keymap' property, return the binding of KEY in the string's keymap."
  (let* ((defn nil)
	 (start (when (vectorp key)
		  (if (memq (aref key 0) '(mode-line header-line))
		      (event-start (aref key 1))
		    (and (consp (aref key 0)) 
			 (event-start (aref key 0))))))
	 (string-info (and (consp start) (nth 4 start))))
    (when string-info
      (let* ((string (car string-info))
	     (pos (cdr string-info))
	     (local-map (and (> pos 0)
			     (< pos (length string))
			     (or (get-text-property pos 'local-map string)
				 (get-text-property pos 'keymap string)))))
	(setq defn (and local-map (lookup-key local-map key)))))
    defn))

(defun describe-key-briefly (key &optional insert)
  "Print the name of the function KEY invokes.  KEY is a string.
If INSERT (the prefix arg) is non-nil, insert the message in the buffer."
  (interactive "kDescribe key briefly: \nP")
  (save-excursion
    (let ((modifiers (event-modifiers (aref key 0)))
	  (standard-output (if insert (current-buffer) t))
	  window position)
      ;; For a mouse button event, go to the button it applies to
      ;; to get the right key bindings.  And go to the right place
      ;; in case the keymap depends on where you clicked.
      (if (or (memq 'click modifiers) (memq 'down modifiers)
	      (memq 'drag modifiers))
	  (setq window (posn-window (event-start (aref key 0)))
		position (posn-point (event-start (aref key 0)))))
      (if (windowp window)
	  (progn
	    (set-buffer (window-buffer window))
	    (goto-char position)))
      ;; Ok, now look up the key and name the command.
      (let ((defn (or (string-key-binding key)
		      (key-binding key)))
	    (key-desc (key-description key)))
	(if (or (null defn) (integerp defn))
	    (princ (format "%s is undefined" key-desc))
	  (princ (format (if insert
			     "`%s' (`%s')"
			   (if (windowp window)
			       "%s at that spot runs the command %s"
			     "%s runs the command %s"))
			 key-desc
			 (if (symbolp defn) defn (prin1-to-string defn)))))))))

(defvar help-return-method nil
  "What to do to \"exit\" the help buffer.
This is a list
 (WINDOW . t)              delete the selected window, go to WINDOW.
 (WINDOW . quit-window)    do quit-window, then select WINDOW.
 (WINDOW BUF START POINT)  display BUF at START, POINT, then select WINDOW.")

(defun print-help-return-message (&optional function)
  "Display or return message saying how to restore windows after help command.
Computes a message and applies the optional argument FUNCTION to it.
If FUNCTION is nil, applies `message' to it, thus printing it."
  (and (not (get-buffer-window standard-output))
       (let ((first-message
	      (cond ((special-display-p (buffer-name standard-output))
		     (setq help-return-method (cons (selected-window) t))
		     ;; If the help output buffer is a special display buffer,
		     ;; don't say anything about how to get rid of it.
		     ;; First of all, the user will do that with the window
		     ;; manager, not with Emacs.
		     ;; Secondly, the buffer has not been displayed yet,
		     ;; so we don't know whether its frame will be selected.
		     nil)
		    (display-buffer-reuse-frames
		     (setq help-return-method (cons (selected-window)
						    'quit-window))
		     nil)
		    ((not (one-window-p t))
		     (setq help-return-method
			   (cons (selected-window) 'quit-window))
		     "Type \\[switch-to-buffer-other-window] RET to restore the other window.")
		    (pop-up-windows
		     (setq help-return-method (cons (selected-window) t))
		     "Type \\[delete-other-windows] to remove help window.")
		    (t
		     (setq help-return-method
			   (list (selected-window) (window-buffer)
				 (window-start) (window-point)))
		     "Type \\[switch-to-buffer] RET to remove help window."))))
	 (funcall (or function 'message)
		  (concat
		   (if first-message
		       (substitute-command-keys first-message))
		   (if first-message "  ")
		   ;; If the help buffer will go in a separate frame,
		   ;; it's no use mentioning a command to scroll, so don't.
		   (if (special-display-p (buffer-name standard-output))
		       nil
		     (if (same-window-p (buffer-name standard-output))
			 ;; Say how to scroll this window.
			 (substitute-command-keys
			  "\\[scroll-up] to scroll the help.")
		       ;; Say how to scroll some other window.
		       (substitute-command-keys
			"\\[scroll-other-window] to scroll the help."))))))))

(defun describe-key (key)
  "Display documentation of the function invoked by KEY.  KEY is a string."
  (interactive "kDescribe key: ")
  (save-excursion
    (let ((modifiers (event-modifiers (aref key 0)))
	  window position)
      ;; For a mouse button event, go to the button it applies to
      ;; to get the right key bindings.  And go to the right place
      ;; in case the keymap depends on where you clicked.
      (if (or (memq 'click modifiers) (memq 'down modifiers)
	      (memq 'drag modifiers))
	  (setq window (posn-window (event-start (aref key 0)))
		position (posn-point (event-start (aref key 0)))))
      (if (windowp window)
	  (progn
	    (set-buffer (window-buffer window))
	    (goto-char position)))
      (let ((defn (or (string-key-binding key) (key-binding key))))
	(if (or (null defn) (integerp defn))
	    (message "%s is undefined" (key-description key))
	  (with-output-to-temp-buffer "*Help*"
	    (princ (key-description key))
	    (if (windowp window)
		(princ " at that spot"))
	    (princ " runs the command ")
	    (prin1 defn)
	    (princ "\n   which is ")
	    (describe-function-1 defn nil (interactive-p))
	    (print-help-return-message)))))))

(defun describe-mode ()
  "Display documentation of current major mode and minor modes.
The major mode description comes first, followed by the minor modes,
each on a separate page.

For this to work correctly for a minor mode, the mode's indicator variable
\(listed in `minor-mode-alist') must also be a function whose documentation
describes the minor mode."
  (interactive)
  (with-output-to-temp-buffer "*Help*"
    (when minor-mode-alist
      (princ "The major mode is described first.
For minor modes, see following pages.\n\n"))
    (princ mode-name)
    (princ " mode:\n")
    (princ (documentation major-mode))
    (help-setup-xref (list #'help-xref-mode (current-buffer)) (interactive-p))
    (let ((minor-modes minor-mode-alist))
      (while minor-modes
	(let* ((minor-mode (car (car minor-modes)))
	       (indicator (car (cdr (car minor-modes)))))
	  ;; Document a minor mode if it is listed in minor-mode-alist,
	  ;; bound locally in this buffer, non-nil, and has a function
	  ;; definition.
	  (if (and (boundp minor-mode)
		   (symbol-value minor-mode)
		   (fboundp minor-mode))
	      (let ((pretty-minor-mode minor-mode))
		(if (string-match "-mode$" (symbol-name minor-mode))
		    (setq pretty-minor-mode
			  (capitalize
			   (substring (symbol-name minor-mode)
				      0 (match-beginning 0)))))
		(while (and indicator (symbolp indicator)
			    (boundp indicator)
			    (not (eq indicator (symbol-value indicator))))
		  (setq indicator (symbol-value indicator)))
		(princ "\n\f\n")
		(princ (format "%s minor mode (%s):\n"
			       pretty-minor-mode
			       (if indicator
				   (format "indicator%s" indicator)
				 "no indicator")))
		(princ (documentation minor-mode)))))
	(setq minor-modes (cdr minor-modes))))
    (print-help-return-message)))

;; So keyboard macro definitions are documented correctly
(fset 'defining-kbd-macro (symbol-function 'start-kbd-macro))

(defun describe-distribution ()
  "Display info on how to obtain the latest version of GNU Emacs."
  (interactive)
  (find-file-read-only
   (expand-file-name "DISTRIB" data-directory)))

(defun describe-copying ()
  "Display info on how you may redistribute copies of GNU Emacs."
  (interactive)
  (find-file-read-only
   (expand-file-name "COPYING" data-directory))
  (goto-char (point-min)))

(defun describe-project ()
  "Display info on the GNU project."
  (interactive)
  (find-file-read-only
   (expand-file-name "THE-GNU-PROJECT" data-directory))
  (goto-char (point-min)))

(defun describe-no-warranty ()
  "Display info on all the kinds of warranty Emacs does NOT have."
  (interactive)
  (describe-copying)
  (let (case-fold-search)
    (search-forward "NO WARRANTY")
    (recenter 0)))

(defun describe-prefix-bindings ()
  "Describe the bindings of the prefix used to reach this command.
The prefix described consists of all but the last event
of the key sequence that ran this command."
  (interactive)
  (let* ((key (this-command-keys)))
    (describe-bindings
     (if (stringp key)
	 (substring key 0 (1- (length key)))
       (let ((prefix (make-vector (1- (length key)) nil))
	     (i 0))
	 (while (< i (length prefix))
	   (aset prefix i (aref key i))
	   (setq i (1+ i)))
	 prefix)))))
;; Make C-h after a prefix, when not specifically bound, 
;; run describe-prefix-bindings.
(setq prefix-help-command 'describe-prefix-bindings)

(defun view-emacs-news (&optional arg)
  "Display info on recent changes to Emacs.
With numeric argument, display information on correspondingly older changes."
  (interactive "P")
  (let* ((arg (if arg (prefix-numeric-value arg) 0))
	 (file (cond ((eq arg 0) "NEWS")
		     ((eq arg 1) "ONEWS")
		     (t
		      (nth (- arg 2)
			   (nreverse (directory-files data-directory
						      nil "^ONEWS\\.[0-9]+$"
						      nil)))))))
    (if file
	(find-file-read-only (expand-file-name file data-directory))
      (error "No such old news"))))

(defun view-order-manuals ()
  "Display the Emacs ORDERS file."
  (interactive)
  (find-file-read-only (expand-file-name "ORDERS" data-directory))
  (goto-address))

(defun view-emacs-FAQ ()
  "Display the Emacs Frequently Asked Questions (FAQ) file."
  (interactive)
;;;  (find-file-read-only (expand-file-name "FAQ" data-directory))
  (info "(efaq)"))

(defun view-emacs-problems ()
  "Display info on known problems with Emacs and possible workarounds."
  (interactive)
  (view-file (expand-file-name "PROBLEMS" data-directory)))

(defun view-lossage ()
  "Display last 100 input keystrokes.

To record all your input on a file, use `open-dribble-file'."
  (interactive)
  (with-output-to-temp-buffer "*Help*"
    (princ (mapconcat (function (lambda (key)
				  (if (or (integerp key)
					  (symbolp key)
					  (listp key))
				      (single-key-description key)
				    (prin1-to-string key nil))))
		      (recent-keys)
		      " "))
    (save-excursion
      (set-buffer standard-output)
      (goto-char (point-min))
      (while (progn (move-to-column 50) (not (eobp)))
	(search-forward " " nil t)
	(insert "\n"))
      (setq help-xref-stack nil
	    help-xref-stack-item nil))
    (print-help-return-message)))

(defalias 'help 'help-for-help)
(make-help-screen help-for-help
  "a b c C f F C-f i I k C-k l L m n p s t v w C-c C-d C-n C-p C-w; ? for help:"
  "You have typed %THIS-KEY%, the help character.  Type a Help option:
\(Use SPC or DEL to scroll through this text.  Type \\<help-map>\\[help-quit] to exit the Help command.)

a  command-apropos.  Give a substring, and see a list of commands
	(functions interactively callable) that contain
	that substring.  See also the  apropos  command.
b  describe-bindings.  Display table of all key bindings.
c  describe-key-briefly.  Type a command key sequence;
	it prints the function name that sequence runs.
C  describe-coding-system.  This describes either a specific coding system
        (if you type its name) or the coding systems currently in use
	(if you type just RET).
f  describe-function.  Type a function name and get documentation of it.
C-f Info-goto-emacs-command-node.  Type a function name;
	it takes you to the Info node for that command.
i  info. The  info  documentation reader.
I  describe-input-method.  Describe a specific input method (if you type
	its name) or the current input method (if you type just RET).
C-i  info-lookup-symbol.  Display the definition of a specific symbol
        as found in the manual for the language this buffer is written in.
k  describe-key.  Type a command key sequence;
	it displays the full documentation.
C-k Info-goto-emacs-key-command-node.  Type a command key sequence;
	it takes you to the Info node for the command bound to that key.
l  view-lossage.  Show last 100 characters you typed.
L  describe-language-environment.  This describes either a
	specific language environment (if you type its name)
	or the current language environment (if you type just RET).
m  describe-mode.  Print documentation of current minor modes,
	and the current major mode, including their special commands.
n  view-emacs-news.  Display news of recent Emacs changes.
p  finder-by-keyword. Find packages matching a given topic keyword.
s  describe-syntax.  Display contents of syntax table, plus explanations
t  help-with-tutorial.  Select the Emacs learn-by-doing tutorial.
v  describe-variable.  Type name of a variable;
	it displays the variable's documentation and value.
w  where-is.  Type command name; it prints which keystrokes
	invoke that command.

F  Display the frequently asked questions file.
h  Display the HELLO file which illustrates various scripts.
C-c Display Emacs copying permission (General Public License).
C-d Display Emacs ordering information.
C-n Display news of recent Emacs changes.
C-p Display information about the GNU project.
C-w Display information on absence of warranty for GNU Emacs."
  help-map)

(defun function-called-at-point ()
  "Return a function around point or else called by the list containing point.
If that doesn't give a function, return nil."
  (with-syntax-table emacs-lisp-mode-syntax-table
    (or (condition-case ()
	    (save-excursion
	      (or (not (zerop (skip-syntax-backward "_w")))
		  (eq (char-syntax (following-char)) ?w)
		  (eq (char-syntax (following-char)) ?_)
		  (forward-sexp -1))
	      (skip-chars-forward "'")
	      (let ((obj (read (current-buffer))))
		(and (symbolp obj) (fboundp obj) obj)))
	  (error nil))
	(condition-case ()
	    (save-excursion
	      (save-restriction
		(narrow-to-region (max (point-min)
				       (- (point) 1000)) (point-max))
		;; Move up to surrounding paren, then after the open.
		(backward-up-list 1)
		(forward-char 1)
		;; If there is space here, this is probably something
		;; other than a real Lisp function call, so ignore it.
		(if (looking-at "[ \t]")
		    (error "Probably not a Lisp function call"))
		(let ((obj (read (current-buffer))))
		  (and (symbolp obj) (fboundp obj) obj))))
	  (error nil)))))

(defvar symbol-file-load-history-loaded nil
  "Non-nil means we have loaded the file `fns-VERSION.el' in `exec-directory'.
That file records the part of `load-history' for preloaded files,
which is cleared out before dumping to make Emacs smaller.")

(defun load-symbol-file-load-history ()
  "Load the file `fns-VERSION.el' in `exec-directory' if not already done.
That file records the part of `load-history' for preloaded files,
which is cleared out before dumping to make Emacs smaller."
  (unless symbol-file-load-history-loaded
    (load (expand-file-name
	   ;; fns-XX.YY.ZZ.el does not work on DOS filesystem.
	   (if (eq system-type 'ms-dos)
	       "fns.el"
	     (format "fns-%s.el" emacs-version))
	   exec-directory)
	  ;; The file name fns-%s.el already has a .el extension.
	  nil nil t)
    (setq symbol-file-load-history-loaded t)))

(defun symbol-file (function)
  "Return the input source from which FUNCTION was loaded.
The value is normally a string that was passed to `load':
either an absolute file name, or a library name
\(with no directory name and no `.el' or `.elc' at the end).
It can also be nil, if the definition is not associated with any file."
  (load-symbol-file-load-history)
  (let ((files load-history)
	file functions)
    (while files
      (if (memq function (cdr (car files)))
	  (setq file (car (car files)) files nil))
      (setq files (cdr files)))
    file))

(defun describe-function (function)
  "Display the full documentation of FUNCTION (a symbol)."
  (interactive
   (let ((fn (function-called-at-point))
	 (enable-recursive-minibuffers t)	     
	 val)
     (setq val (completing-read (if fn
				    (format "Describe function (default %s): " fn)
				  "Describe function: ")
				obarray 'fboundp t nil nil (symbol-name fn)))
     (list (if (equal val "")
	       fn (intern val)))))
  (if function
      (with-output-to-temp-buffer "*Help*"
	(prin1 function)
	;; Use " is " instead of a colon so that
	;; it is easier to get out the function name using forward-sexp.
	(princ " is ")
	(describe-function-1 function nil (interactive-p))
	(print-help-return-message)
	(save-excursion
	  (set-buffer standard-output)
	  ;; Return the text we displayed.
	  (buffer-string)))
    (message "You didn't specify a function")))

(defun describe-function-1 (function parens interactive-p)
  (let* ((def (if (symbolp function)
		  (symbol-function function)
		function))
	 file-name string need-close
	 (beg (if (commandp def) "an interactive " "a ")))
    (setq string
	  (cond ((or (stringp def)
		     (vectorp def))
		 "a keyboard macro")
		((subrp def)
		 (if (eq 'unevalled (cdr (subr-arity def)))
		     (concat beg "special form")
		   (concat beg "built-in function")))
		((byte-code-function-p def)
		 (concat beg "compiled Lisp function"))
		((symbolp def)
		 (while (symbolp (symbol-function def))
		   (setq def (symbol-function def)))
		 (format "an alias for `%s'" def))
		((eq (car-safe def) 'lambda)
		 (concat beg "Lisp function"))
		((eq (car-safe def) 'macro)
		 "a Lisp macro")
		((eq (car-safe def) 'mocklisp)
		 "a mocklisp function")
		((eq (car-safe def) 'autoload)
		 (setq file-name (nth 1 def))
		 (format "%s autoloaded %s"
			 (if (commandp def) "an interactive" "an")
			 (if (eq (nth 4 def) 'keymap) "keymap"
			   (if (nth 4 def) "Lisp macro" "Lisp function"))
			 ))
                ;; perhaps use keymapp here instead
                ((eq (car-safe def) 'keymap)
                 (let ((is-full nil)
                       (elts (cdr-safe def)))
                   (while elts
                     (if (char-table-p (car-safe elts))
                         (setq is-full t
                               elts nil))
                     (setq elts (cdr-safe elts)))
                   (if is-full
                       "a full keymap"
                     "a sparse keymap")))
		(t "")))
    (when (and parens (not (equal string "")))
      (setq need-close t)
      (princ "("))
    (princ string)
    (with-current-buffer "*Help*"
      (save-excursion
	(save-match-data
	  (if (re-search-backward "alias for `\\([^`']+\\)'" nil t)
	      (help-xref-button 1 #'describe-function def
				"mouse-2, RET: describe this function")))))
    (or file-name
	(setq file-name (symbol-file function)))
    (if file-name
	(progn
	  (princ " in `")
	  ;; We used to add .el to the file name,
	  ;; but that's completely wrong when the user used load-file.
	  (princ file-name)
	  (princ "'")
	  ;; Make a hyperlink to the library.
	  (with-current-buffer "*Help*"
	    (save-excursion
	      (re-search-backward "`\\([^`']+\\)'" nil t)
	      (help-xref-button 1 #'(lambda (arg)
				      (let ((location
					     (find-function-noselect arg)))
					(pop-to-buffer (car location))
					(goto-char (cdr location))))
				function
				"mouse-2, RET: find function's definition")))))
    (if need-close (princ ")"))
    (princ ".")
    (terpri)
    ;; Handle symbols aliased to other symbols.
    (setq def (indirect-function def))
    ;; If definition is a macro, find the function inside it.
    (if (eq (car-safe def) 'macro)
	(setq def (cdr def)))
    (let ((arglist (cond ((byte-code-function-p def)
			  (car (append def nil)))
			 ((eq (car-safe def) 'lambda)
			  (nth 1 def))
			 ((and (eq (car-safe def) 'autoload)
			       (not (eq (nth 4 def) 'keymap)))
			  (concat "[Arg list not available until "
				  "function definition is loaded.]"))
			 (t t))))
      (cond ((listp arglist)
	     (princ (cons (if (symbolp function) function "anonymous")
			  (mapcar (lambda (arg)
				    (if (memq arg '(&optional &rest))
					arg
				      (intern (upcase (symbol-name arg)))))
				  arglist)))
	     (terpri))
	    ((stringp arglist)
	     (princ arglist)
	     (terpri))))
    (let ((doc (documentation function)))
      (if doc
	  (progn (terpri)
		 (princ doc)
		 (if (subrp def)
		     (with-current-buffer standard-output
		       (beginning-of-line)
		       ;; Builtins get the calling sequence at the end of
		       ;; the doc string.  Move it to the same place as
		       ;; for other functions.

		       ;; In cases where `function' has been fset to a
		       ;; subr we can't search for function's name in
		       ;; the doc string.  Kluge round that using the
		       ;; printed representation.  The arg list then
		       ;; shows the wrong function name, but that
		       ;; might be a useful hint.
		       (let* ((rep (prin1-to-string def))
			      (name (progn
				      (string-match " \\([^ ]+\\)>$" rep)
				      (match-string 1 rep))))
			 (if (looking-at (format "(%s[ )]" (regexp-quote name)))
			     (let ((start (point-marker)))
			       (goto-char (point-min))
			       (forward-paragraph)
			       (insert-buffer-substring (current-buffer) start)
			       (insert ?\n)
			       (delete-region (1- start) (point-max)))
			   (goto-char (point-min))
			   (forward-paragraph)
			   (insert
			    "[Missing arglist.  Please make a bug report.]\n")))
		       (goto-char (point-max))))
		 (help-setup-xref (list #'describe-function function)
				  interactive-p))
	(princ "not documented")))))

(defun variable-at-point ()
  "Return the bound variable symbol found around point.
Return 0 if there is no such symbol."
  (condition-case ()
      (with-syntax-table emacs-lisp-mode-syntax-table
	(save-excursion
	  (or (not (zerop (skip-syntax-backward "_w")))
	      (eq (char-syntax (following-char)) ?w)
	      (eq (char-syntax (following-char)) ?_)
	      (forward-sexp -1))
	  (skip-chars-forward "'")
	  (let ((obj (read (current-buffer))))
	    (or (and (symbolp obj) (boundp obj) obj)
		0))))
    (error 0)))

(defun help-xref-on-pp (from to)
  "Add xrefs for symbols in `pp's output between FROM and TO."
  (let ((ost (syntax-table)))
    (unwind-protect
	(save-excursion
	  (save-restriction
	    (set-syntax-table emacs-lisp-mode-syntax-table)
	    (narrow-to-region from to)
	    (goto-char (point-min))
	    (while (not (eobp))
	      (cond
	       ((looking-at "\"") (forward-sexp 1))
	       ((looking-at "#<") (search-forward ">" nil 'move))
	       ((looking-at "\\(\\(\\sw\\|\\s_\\)+\\)")
		(let* ((sym (intern-soft (match-string 1)))
		       (fn (cond ((fboundp sym) #'describe-function)
				 ((or (memq sym '(t nil))
				      (keywordp sym))
				  nil)
				 ((and sym (boundp sym))
				  #'describe-variable))))
		  (when fn (help-xref-button 1 fn sym)))
		(goto-char (match-end 1)))
	       (t (forward-char 1))))))
      (set-syntax-table ost))))

(defun describe-variable (variable &optional buffer)
  "Display the full documentation of VARIABLE (a symbol).
Returns the documentation as a string, also.
If VARIABLE has a buffer-local value in BUFFER (default to the current buffer),
it is displayed along with the global value."
  (interactive
   (let ((v (variable-at-point))
	 (enable-recursive-minibuffers t)
	 val)
     (setq val (completing-read (if (symbolp v)
				    (format
				     "Describe variable (default %s): " v)
				  "Describe variable: ")
				obarray 'boundp t nil nil
				(if (symbolp v) (symbol-name v))))
     (list (if (equal val "")
	       v (intern val)))))
  (unless (bufferp buffer) (setq buffer (current-buffer)))
  (if (not (symbolp variable))
      (message "You did not specify a variable")
    (let (valvoid)
      (with-current-buffer buffer
	(with-output-to-temp-buffer "*Help*"
	  (prin1 variable)
	  (if (not (boundp variable))
	      (progn
		(princ " is void")
		(setq valvoid t))
	    (let ((val (symbol-value variable)))
	      (with-current-buffer standard-output
		(princ "'s value is ")
		(terpri)
		(let ((from (point)))
		  (pp val)
		  (help-xref-on-pp from (point))
		  (if (< (point) (+ from 20))
		      (save-excursion
			(goto-char from)
			(delete-char -1)))))))
	  (terpri)
	  (if (local-variable-p variable)
	      (progn
		(princ (format "Local in buffer %s; " (buffer-name)))
		(if (not (default-boundp variable))
		    (princ "globally void")
		  (let ((val (default-value variable)))
		    (with-current-buffer standard-output
		      (princ "global value is ")
		      (terpri)
		      ;; Fixme: pp can take an age if you happen to
		      ;; ask for a very large expression.  We should
		      ;; probably print it raw once and check it's a
		      ;; sensible size before prettyprinting.  -- fx
		      (let ((from (point)))
			(pp val)
			(help-xref-on-pp from (point))
			(if (< (point) (+ from 20))
			    (save-excursion
			      (goto-char from)
			      (delete-char -1)))))))
		(terpri)))
	  (terpri)
	  (with-current-buffer standard-output
	    (if (> (count-lines (point-min) (point-max)) 10)
		(progn
		  ;; Note that setting the syntax table like below
		  ;; makes forward-sexp move over a `'s' at the end
		  ;; of a symbol.
		  (set-syntax-table emacs-lisp-mode-syntax-table)
		  (goto-char (point-min))
		  (if valvoid
		      (forward-line 1)
		    (forward-sexp 1)
		    (delete-region (point) (progn (end-of-line) (point)))
		    (insert " value is shown below.\n\n")
		    (save-excursion
		      (insert "\n\nValue:"))))))
	  (princ "Documentation:")
	  (terpri)
	  (let ((doc (documentation-property variable 'variable-documentation)))
	    (princ (or doc "not documented as a variable.")))
          (help-setup-xref (list #'describe-variable variable (current-buffer))
			   (interactive-p))
	  
	  ;; Make a link to customize if this variable can be customized.
	  ;; Note, it is not reliable to test only for a custom-type property
	  ;; because those are only present after the var's definition
	  ;; has been loaded.
	  (if (or (get variable 'custom-type) ; after defcustom
		  (get variable 'custom-loads) ; from loaddefs.el
		  (get variable 'standard-value)) ; from cus-start.el
	      (let ((customize-label "customize"))
		(terpri)
		(terpri)
		(princ (concat "You can " customize-label " this variable."))
		(with-current-buffer "*Help*"
		  (save-excursion
		    (re-search-backward
		     (concat "\\(" customize-label "\\)") nil t)
		    (help-xref-button 1 (lambda (v)
					  (if help-xref-stack
					      (pop help-xref-stack))
					  (customize-variable v))
				      variable
				      "mouse-2, RET: customize variable")))))
	  ;; Make a hyperlink to the library if appropriate.  (Don't
	  ;; change the format of the buffer's initial line in case
	  ;; anything expects the current format.)
	  (let ((file-name (symbol-file variable)))
	    (when file-name
	      (princ "\n\nDefined in `")
	      (princ file-name)
	      (princ "'.")
	      (with-current-buffer "*Help*"
		(save-excursion
		  (re-search-backward "`\\([^`']+\\)'" nil t)
		  (help-xref-button
		   1 (lambda (arg)
		       (let ((location
			      (find-variable-noselect arg)))
			 (pop-to-buffer (car location))
			 (goto-char (cdr location))))
		   variable "mouse-2, RET: find variable's definition")))))

	  (print-help-return-message)
	  (save-excursion
	    (set-buffer standard-output)
	    ;; Return the text we displayed.
	    (buffer-string)))))))

(defun describe-bindings (&optional prefix buffer)
  "Show a list of all defined keys, and their definitions.
We put that list in a buffer, and display the buffer.

The optional argument PREFIX, if non-nil, should be a key sequence;
then we display only bindings that start with that prefix.
The optional argument BUFFER specifies which buffer's bindings
to display (default, the current buffer)."
  (interactive "P")
  (or buffer (setq buffer (current-buffer)))
  (with-current-buffer buffer
    (describe-bindings-internal nil prefix))
  (with-current-buffer "*Help*"
    (help-setup-xref (list #'describe-bindings prefix buffer)
		     (interactive-p))))

(defun where-is (definition &optional insert)
  "Print message listing key sequences that invoke the command DEFINITION.
Argument is a command definition, usually a symbol with a function definition.
If INSERT (the prefix arg) is non-nil, insert the message in the buffer."
  (interactive
   (let ((fn (function-called-at-point))
	 (enable-recursive-minibuffers t)	     
	 val)
     (setq val (completing-read (if fn
				    (format "Where is command (default %s): " fn)
				  "Where is command: ")
				obarray 'commandp t))
     (list (if (equal val "")
	       fn (intern val))
	   current-prefix-arg)))
  (let* ((keys (where-is-internal definition overriding-local-map nil nil))
	 (keys1 (mapconcat 'key-description keys ", "))
	 (standard-output (if insert (current-buffer) t)))
    (if insert
	(if (> (length keys1) 0)
	    (princ (format "%s (%s)" keys1 definition))
	  (princ (format "M-x %s RET" definition)))
      (if (> (length keys1) 0)
	  (princ (format "%s is on %s" definition keys1))
	(princ (format "%s is not on any key" definition)))))
  nil)

(defun locate-library (library &optional nosuffix path interactive-call)
  "Show the precise file name of Emacs library LIBRARY.
This command searches the directories in `load-path' like `M-x load-library'
to find the file that `M-x load-library RET LIBRARY RET' would load.
Optional second arg NOSUFFIX non-nil means don't add suffixes `.elc' or `.el'
to the specified name LIBRARY.

If the optional third arg PATH is specified, that list of directories
is used instead of `load-path'.

When called from a program, the file name is normaly returned as a
string.  When run interactively, the argument INTERACTIVE-CALL is t,
and the file name is displayed in the echo area."
  (interactive (list (read-string "Locate library: ")
		     nil nil
		     t))
  (let (result)
    (catch 'answer
      (mapc
       (lambda (dir)
	 (mapc
	  (lambda (suf)
	    (let ((try (expand-file-name (concat library suf) dir)))
	      (and (file-readable-p try)
		   (null (file-directory-p try))
		   (progn
		     (setq result try)
		     (throw 'answer try)))))
	  (if nosuffix
	      '("")
	    '(".elc" ".el" "")
	    (let ((basic '(".elc" ".el" ""))
		  (compressed '(".Z" ".gz" "")))
	      ;; If autocompression mode is on,
	      ;; consider all combinations of library suffixes
	      ;; and compression suffixes.
	      (if (rassq 'jka-compr-handler file-name-handler-alist)
		  (apply 'nconc
			 (mapcar (lambda (compelt)
				   (mapcar (lambda (baselt)
					     (concat baselt compelt))
					   basic))
				 compressed))
		basic)))))
       (or path load-path)))
    (and interactive-call
	 (if result
	     (message "Library is file %s" result)
	   (message "No library %s in search path" library)))
    result))


;;; Grokking cross-reference information in doc strings and
;;; hyperlinking it.

;; This may have some scope for extension and the same or something
;; similar should be done for widget doc strings, which currently use
;; another mechanism.

(defcustom help-highlight-p t
  "*If non-nil, `help-make-xrefs' highlight cross-references.
Under a window system it highlights them with face defined by
`help-highlight-face'."
 :group 'help
 :version "20.3"
 :type 'boolean)

(defcustom help-highlight-face 'underline
  "Face used by `help-make-xrefs' to highlight cross-references.
Must be previously-defined."
  :group 'help
  :version "20.3"
  :type 'face)

(defvar help-back-label (purecopy "[back]")
  "Label to use by `help-make-xrefs' for the go-back reference.")

(defconst help-xref-symbol-regexp
  (purecopy (concat "\\(\\<\\(\\(variable\\|option\\)\\|"
		    "\\(function\\|command\\)\\|"
		    "\\(face\\)\\|"
		    "\\(symbol\\)\\|"
		    "\\(source \\(?:code \\)?\\(?:of\\|for\\)\\)\\)\\s-+\\)?"
		    ;; Note starting with word-syntax character:
		    "`\\(\\sw\\(\\sw\\|\\s_\\)+\\)'"))
  "Regexp matching doc string references to symbols.

The words preceding the quoted symbol can be used in doc strings to
distinguish references to variables, functions and symbols.")

(defconst help-xref-mule-regexp nil
  "Regexp matching doc string references to MULE-related keywords.

It is usually nil, and is temporarily bound to an appropriate regexp
when help commands related to multilingual environment (e.g.,
`describe-coding-system') are invoked.")


(defconst help-xref-info-regexp
  (purecopy "\\<[Ii]nfo[ \t\n]+node[ \t\n]+`\\([^']+\\)'")
  "Regexp matching doc string references to an Info node.")

(defun help-setup-xref (item interactive-p)
  "Invoked from commands using the \"*Help*\" buffer to install some xref info.

ITEM is a (FUNCTION . ARGS) pair appropriate for recreating the help
buffer after following a reference.  INTERACTIVE-P is non-nil if the
calling command was invoked interactively.  In this case the stack of
items for help buffer \"back\" buttons is cleared."
  (if interactive-p
      (setq help-xref-stack nil))
  (setq help-xref-stack-item item))

(defvar help-xref-following nil
  "Non-nil when following a help cross-reference.")

(defun help-make-xrefs (&optional buffer)
  "Parse and hyperlink documentation cross-references in the given BUFFER.

Find cross-reference information in a buffer and, if
`help-highlight-p' is non-nil, highlight it with face defined by
`help-highlight-face'; activate such cross references for selection
with `help-follow'.  Cross-references have the canonical form `...'
and the type of reference may be disambiguated by the preceding
word(s) used in `help-xref-symbol-regexp'.

If the variable `help-xref-mule-regexp' is non-nil, find also
cross-reference information related to multilingual environment
\(e.g., coding-systems).  This variable is also used to disambiguate
the type of reference as the same way as `help-xref-symbol-regexp'.

A special reference `back' is made to return back through a stack of
help buffers.  Variable `help-back-label' specifies the text for
that."
  (interactive "b")
  (save-excursion
    (set-buffer (or buffer (current-buffer)))
    (goto-char (point-min))
    ;; Skip the header-type info, though it might be useful to parse
    ;; it at some stage (e.g. "function in `library'").
    (forward-paragraph)
    (let ((old-modified (buffer-modified-p)))
      (let ((stab (syntax-table))
            (case-fold-search t)
            (inhibit-read-only t))
        (set-syntax-table emacs-lisp-mode-syntax-table)
        ;; The following should probably be abstracted out.
        (unwind-protect
            (progn
              ;; Info references
              (save-excursion
                (while (re-search-forward help-xref-info-regexp nil t)
                  (let ((data (match-string 1)))
		    (save-match-data
		      (unless (string-match "^([^)]+)" data)
			(setq data (concat "(emacs)" data))))
		    (help-xref-button 1 #'info data
				      "mouse-2, RET: read this Info node"))))
	      ;; Mule related keywords.  Do this before trying
	      ;; `help-xref-symbol-regexp' because some of Mule
	      ;; keywords have variable or function definitions.
	      (if help-xref-mule-regexp
		  (save-excursion
		    (while (re-search-forward help-xref-mule-regexp nil t)
		      (let* ((data (match-string 7))
			     (sym (intern-soft data)))
			(cond
			 ((match-string 3) ; coding system
			  (and sym (coding-system-p sym)
			       (help-xref-button
				7 #'describe-coding-system sym
				"mouse-2, RET: describe this coding system")))
			 ((match-string 4) ; input method
			  (and (assoc data input-method-alist)
			       (help-xref-button
				7 #'describe-input-method data
				"mouse-2, RET: describe this input method")))
			 ((or (match-string 5) (match-string 6)) ; charset
			  (and sym (charsetp sym)
			       (help-xref-button
				7 #'describe-character-set sym
				"mouse-2, RET: describe this character set")))
			 ((assoc data input-method-alist)
			  (help-xref-button
			   7 #'describe-input-method data
			   "mouse-2, RET: describe this input method"))
			 ((and sym (coding-system-p sym))
			  (help-xref-button
			   7 #'describe-coding-system sym
			   "mouse-2, RET: describe this coding system"))
			 ((and sym (charsetp sym))
			  (help-xref-button
			   7 #'describe-character-set sym
			   "mouse-2, RET: describe this character set")))))))
              ;; Quoted symbols
              (save-excursion
                (while (re-search-forward help-xref-symbol-regexp nil t)
                  (let* ((data (match-string 8))
                         (sym (intern-soft data)))
                    (if sym
                        (cond
                         ((match-string 3) ; `variable' &c
                          (and (boundp sym) ; `variable' doesn't ensure
                                        ; it's actually bound
                               (help-xref-button
				8 #'describe-variable sym
				"mouse-2, RET: describe this variable")))
                         ((match-string 4) ; `function' &c
                          (and (fboundp sym) ; similarly
                               (help-xref-button
				8 #'describe-function sym
				"mouse-2, RET: describe this function")))
			 ((match-string 5) ; `face'
			  (and (facep sym)
			       (help-xref-button 8 #'describe-face sym
				"mouse-2, RET: describe this face")))
                         ((match-string 6)) ; nothing for `symbol'
			 ((match-string 7)
			  (help-xref-button
			   8
			   #'(lambda (arg)
			       (let ((location
				      (find-function-noselect arg)))
				 (pop-to-buffer (car location))
				 (goto-char (cdr location))))
			   sym
			   "mouse-2, RET: find function's definition"))
                         ((and (boundp sym) (fboundp sym))
                          ;; We can't intuit whether to use the
                          ;; variable or function doc -- supply both.
                          (help-xref-button
			   8 #'help-xref-interned sym
			   "mouse-2, RET: describe this symbol"))
                         ((boundp sym)
			  (help-xref-button
			   8 #'describe-variable sym
			   "mouse-2, RET: describe this variable"))
			 ((fboundp sym)
			  (help-xref-button
			   8 #'describe-function sym
			   "mouse-2, RET: describe this function"))
			 ((facep sym)
			  (help-xref-button
			   8 #'describe-face sym)))))))
              ;; An obvious case of a key substitution:
              (save-excursion
                (while (re-search-forward
			;; Assume command name is only word characters
			;; and dashes to get things like `use M-x foo.'.
                        "\\<M-x\\s-+\\(\\sw\\(\\sw\\|-\\)+\\)" nil t)
                  (let ((sym (intern-soft (match-string 1))))
                    (if (fboundp sym)
                        (help-xref-button
			 1 #'describe-function sym
			 "mouse-2, RET: describe this command")))))
              ;; Look for commands in whole keymap substitutions:
              (save-excursion
		;; Make sure to find the first keymap.
		(goto-char (point-min))
                ;; Find a header and the column at which the command
                ;; name will be found.
                (while (re-search-forward "^key +binding\n\\(-+ +\\)-+\n\n"
                                          nil t)
                  (let ((col (- (match-end 1) (match-beginning 1))))
                    (while
                        ;; Ignore single blank lines in table, but not
                        ;; double ones, which should terminate it.
                        (and (not (looking-at "\n\\s-*\n"))
                             (progn
			       (and (eolp) (forward-line))
			       (end-of-line)
			       (skip-chars-backward "^\t\n")
                               (if (and (>= (current-column) col)
					(looking-at "\\(\\sw\\|-\\)+$"))
                                   (let ((sym (intern-soft (match-string 0))))
                                     (if (fboundp sym)
                                         (help-xref-button
                                          0 #'describe-function sym
					  "mouse-2, RET: describe this function"))))
			       (zerop (forward-line)))))))))
          (set-syntax-table stab))
	;; Delete extraneous newlines at the end of the docstring
	(goto-char (point-max))
	(while (and (not (bobp)) (bolp))
	  (delete-char -1))
        ;; Make a back-reference in this buffer if appropriate.
        (when (and help-xref-following help-xref-stack)
          (save-excursion
            (insert "\n\n" help-back-label))
          ;; Just to provide the match data:
          (looking-at (concat "\n\n\\(" (regexp-quote help-back-label) "\\)"))
          (help-xref-button 1 #'help-xref-go-back (current-buffer))))
      ;; View mode steals RET from us.
      (set (make-local-variable 'minor-mode-overriding-map-alist)
           (list (cons 'view-mode
                       (let ((map (make-sparse-keymap)))
                         (set-keymap-parent map view-mode-map)
                         (define-key map "\r" 'help-follow)
                         map))))
      (set-buffer-modified-p old-modified))))

(defun help-xref-button (match-number function data &optional help-echo)
  "Make a hyperlink for cross-reference text previously matched.

MATCH-NUMBER is the subexpression of interest in the last matched
regexp.  FUNCTION is a function to invoke when the button is
activated, applied to DATA.  DATA may be a single value or a list.
See `help-make-xrefs'.
If optional arg HELP-ECHO is supplied, it is used as a help string."
  ;; Don't mung properties we've added specially in some instances.
  (unless (get-text-property (match-beginning match-number) 'help-xref)
    (add-text-properties (match-beginning match-number)
			 (match-end match-number)
			 (list 'mouse-face 'highlight  
			       'help-xref (cons function
						(if (listp data)
						    data
						  (list data)))))
    (if help-echo
	(put-text-property (match-beginning match-number)
			   (match-end match-number)
			   'help-echo help-echo))
    (if help-highlight-p
	(put-text-property (match-beginning match-number)
			   (match-end match-number)
			   'face help-highlight-face))))

(defun help-insert-xref-button (string function data &optional help-echo)
  "Insert STRING and make a hyperlink from cross-reference text on it.

FUNCTION is a function to invoke when the button is activated, applied
to DATA.  DATA may be a single value or a list.  See `help-make-xrefs'.
If optional arg HELP-ECHO is supplied, it is used as a help string."
  (let ((pos (point)))
    (insert string)
    (goto-char pos)
    (search-forward string)
    (help-xref-button 0 function data help-echo)))



;; Additional functions for (re-)creating types of help buffers.
(defun help-xref-interned (symbol)
  "Follow a hyperlink which appeared to be an arbitrary interned SYMBOL.

Both variable and function documentation are extracted into a single
help buffer."
  (let ((fdoc (when (fboundp symbol) (describe-function symbol)))
	(facedoc (when (facep symbol) (describe-face symbol))))
    (when (or (boundp symbol) (not fdoc))
      (describe-variable symbol)
      ;; We now have a help buffer on the variable.  Insert the function
      ;; text before it.
      (when (or fdoc facedoc)
	(with-current-buffer "*Help*"
	  (goto-char (point-min))
	  (let ((inhibit-read-only t))
	    (when fdoc
	      (insert fdoc "\n\n"))
	    (when facedoc
	      (insert (make-string 30 ?-) "\n\n" (symbol-name symbol)
		      " is also a " "face." "\n\n" facedoc "\n\n"))
	    (insert (make-string 30 ?-) "\n\n" (symbol-name symbol)
		    " is also a " "variable." "\n\n"))
	  (help-setup-xref (list #'help-xref-interned symbol) nil))))))

(defun help-xref-mode (buffer)
  "Do a `describe-mode' for the specified BUFFER."
  (save-excursion
    (set-buffer buffer)
    (describe-mode)))

;;; Navigation/hyperlinking with xrefs

(defun help-follow-mouse (click)
  "Follow the cross-reference that you click on."
  (interactive "e")
  (let* ((start (event-start click))
	 (window (car start))
	 (pos (car (cdr start))))
    (with-current-buffer (window-buffer window)
      (help-follow pos))))

(defun help-xref-go-back (buffer)
  "From BUFFER, go back to previous help buffer text using `help-xref-stack'."
  (let (item position method args)
    (with-current-buffer buffer
      (when help-xref-stack
	(setq help-xref-stack (cdr help-xref-stack)) ; due to help-follow
	(setq item (pop help-xref-stack)
	      position (car item)
	      method (cadr item)
	      args (cddr item))))
    (apply method args)
    ;; We assume that the buffer we just recreated has the saved name,
    ;; which might not always be true.
    (when (get-buffer (cdr position))
      (with-current-buffer (cdr position)
	(goto-char (car position))))))

(defun help-go-back ()
  "Invoke the [back] button (if any) in the Help mode buffer."
  (interactive)
  (help-follow (1- (point-max))))

(defun help-follow (&optional pos)
  "Follow cross-reference at POS, defaulting to point.

For the cross-reference format, see `help-make-xrefs'."
  (interactive "d")
  (unless pos
    (setq pos (point)))
  (let* ((help-data
	  (or (and (not (= pos (point-max)))
		   (get-text-property pos 'help-xref))
	      (and (not (= pos (point-min)))
		   (get-text-property (1- pos) 'help-xref))
	      ;; check if the symbol under point is a function or variable
	      (let ((sym
		     (intern
		      (save-excursion
			(goto-char pos) (skip-syntax-backward "w_")
			(buffer-substring (point)
					  (progn (skip-syntax-forward "w_")
						 (point)))))))
		(when (or (boundp sym) (fboundp sym))
		  (list #'help-xref-interned sym)))))
         (method (car help-data))
         (args (cdr help-data)))
    (when help-data
      (setq help-xref-stack (cons (cons (cons pos (buffer-name))
					help-xref-stack-item)
				  help-xref-stack))
      (setq help-xref-stack-item nil)
      ;; There is a reference at point.  Follow it.
      (let ((help-xref-following t))
	(apply method args)))))

;; For tabbing through buffer.
(defun help-next-ref ()
  "Find the next help cross-reference in the buffer."
  (interactive)
  (let (pos)
    (while (not pos) 
      (if (get-text-property (point) 'help-xref) ; move off reference
	   (goto-char (or (next-single-property-change (point) 'help-xref)
                          (point))))
      (cond ((setq pos (next-single-property-change (point) 'help-xref))
	     (if pos (goto-char pos)))
	    ((bobp)
	     (message "No cross references in the buffer.")
	     (setq pos t))
	    (t				; be circular
	     (goto-char (point-min)))))))

(defun help-previous-ref ()
  "Find the previous help cross-reference in the buffer."
  (interactive)
  (let (pos)
    (while (not pos) 
      (if (get-text-property (point) 'help-xref) ; move off reference
	  (goto-char (or (previous-single-property-change (point) 'help-xref)
                         (point))))
      (cond ((setq pos (previous-single-property-change (point) 'help-xref))
	     (if pos (goto-char pos)))
	    ((bobp)
	     (message "No cross references in the buffer.")
	     (setq pos t))
	    (t				; be circular
	     (goto-char (point-max)))))))


;;; Automatic resizing of temporary buffers.

(defcustom temp-buffer-max-height (lambda (buffer) (/ (- (frame-height) 2) 2))
  "*Maximum height of a window displaying a temporary buffer.
This is the maximum height (in text lines) which `resize-temp-buffer-window'
will give to a window displaying a temporary buffer.
It can also be a function which will be called with the object corresponding
to the buffer to be displayed as argument and should return an integer
positive number."
  :type '(choice integer function)
  :group 'help
  :version "20.4")

(define-minor-mode temp-buffer-resize-mode
  "Toggle the mode which makes windows smaller for temporary buffers.
With prefix argument ARG, turn the resizing of windows displaying temporary
buffers on if ARG is positive or off otherwise.
This makes the window the right height for its contents, but never
more than `temp-buffer-max-height' nor less than `window-min-height'.
This applies to `help', `apropos' and `completion' buffers, and some others."
  nil nil nil :global t :group 'help
  (if temp-buffer-resize-mode
      ;; `help-make-xrefs' may add a `back' button and thus increase the
      ;; text size, so `resize-temp-buffer-window' must be run *after* it.
      (add-hook 'temp-buffer-show-hook 'resize-temp-buffer-window 'append)
    (remove-hook 'temp-buffer-show-hook 'resize-temp-buffer-window)))

(defun resize-temp-buffer-window ()
  "Resize the current window to fit its contents.
Will not make it higher than `temp-buffer-max-height' nor smaller than
`window-min-height'.  Do nothing if it is the only window on its frame, if it
is not as wide as the frame or if some of the window's contents are scrolled
out of view."
  (unless (or (one-window-p 'nomini)
              (not (pos-visible-in-window-p (point-min)))
              (/=  (frame-width) (window-width)))
    (fit-window-to-buffer
     (selected-window)
     (if (functionp temp-buffer-max-height)
	 (funcall temp-buffer-max-height (current-buffer))
       temp-buffer-max-height))))

;; `help-manyarg-func-alist' is defined primitively (in doc.c).
;; New primitives with `MANY' or `UNEVALLED' arglists should be added
;; to this alist.
;; The parens and function name are redundant, but it's messy to add
;; them in `documentation'.

;; This will find any missing items:
;; (let (l)
;;   (mapatoms (lambda (x)
;; 	      (if (and (fboundp x)
;; 		       (subrp (symbol-function x))
;; 		       (not (numberp (cdr (subr-arity (symbol-function x)))))
;; 		       (not (assq x help-manyarg-func-alist)))
;; 		  (push x l))))
;;   l)
(defconst help-manyarg-func-alist
  (purecopy
   '((list . "(list &rest OBJECTS)")
     (vector . "(vector &rest OBJECTS)")
     (make-byte-code . "(make-byte-code &rest ELEMENTS)")
     (call-process
      . "(call-process PROGRAM &optional INFILE BUFFER DISPLAY &rest ARGS)")
     (call-process-region
      . "(call-process-region START END PROGRAM &optional DELETE BUFFER DISPLAY &rest ARGS)")
     (string . "(string &rest CHARACTERS)")
     (+ . "(+ &rest NUMBERS-OR-MARKERS)")
     (- . "(- &optional NUMBER-OR-MARKER &rest MORE-NUMBERS-OR-MARKERS)")
     (* . "(* &rest NUMBERS-OR-MARKERS)")
     (/ . "(/ DIVIDEND DIVISOR &rest DIVISORS)")
     (max . "(max NUMBER-OR-MARKER &rest NUMBERS-OR-MARKERS)")
     (min . "(min NUMBER-OR-MARKER &rest NUMBERS-OR-MARKERS)")
     (logand . "(logand &rest INTS-OR-MARKERS)")
     (logior . "(logior &rest INTS-OR-MARKERS)")
     (logxor . "(logxor &rest INTS-OR-MARKERS)")
     (encode-time
      . "(encode-time SECOND MINUTE HOUR DAY MONTH YEAR &optional ZONE)")
     (insert . "(insert &rest ARGS)")
     (insert-and-inherit . "(insert-and-inherit &rest ARGS)")
     (insert-before-markers . "(insert-before-markers &rest ARGS)")
     (message . "(message STRING &rest ARGUMENTS)")
     (message-box . "(message-box STRING &rest ARGUMENTS)")
     (message-or-box . "(message-or-box STRING &rest ARGUMENTS)")
     (propertize . "(propertize STRING &rest PROPERTIES)")
     (format . "(format STRING &rest OBJECTS)")
     (apply . "(apply FUNCTION &rest ARGUMENTS)")
     (run-hooks . "(run-hooks &rest HOOKS)")
     (run-hook-with-args . "(run-hook-with-args HOOK &rest ARGS)")
     (run-hook-with-args-until-failure
      . "(run-hook-with-args-until-failure HOOK &rest ARGS)")
     (run-hook-with-args-until-success
      . "(run-hook-with-args-until-success HOOK &rest ARGS)")
     (funcall . "(funcall FUNCTION &rest ARGUMENTS)")
     (append . "(append &rest SEQUENCES)")
     (concat . "(concat &rest SEQUENCES)")
     (vconcat . "(vconcat &rest SEQUENCES)")
     (nconc . "(nconc &rest LISTS)")
     (widget-apply . "(widget-apply WIDGET PROPERTY &rest ARGS)")
     (make-hash-table . "(make-hash-table &rest KEYWORD-ARGS)")
     (insert-string . "(insert-string &rest ARGS)")
     (start-process . "(start-process NAME BUFFER PROGRAM &rest PROGRAM-ARGS)")
     (setq-default . "(setq-default SYMBOL VALUE [SYMBOL VALUE...])")
     (save-excursion . "(save-excursion &rest BODY)")
     (save-current-buffer . "(save-current-buffer &rest BODY)")
     (save-restriction . "(save-restriction &rest BODY)")
     (or . "(or CONDITIONS ...)")
     (and . "(and CONDITIONS ...)")
     (if . "(if COND THEN ELSE...)")
     (cond . "(cond CLAUSES...)")
     (progn . "(progn BODY ...)")
     (prog1 . "(prog1 FIRST BODY...)")
     (prog2 . "(prog2 X Y BODY...)")
     (setq . "(setq SYM VAL SYM VAL ...)")
     (quote . "(quote ARG)")
     (function . "(function ARG)")
     (defun . "(defun NAME ARGLIST [DOCSTRING] BODY...)")
     (defmacro . "(defmacro NAME ARGLIST [DOCSTRING] BODY...)")
     (defvar . "(defvar SYMBOL [INITVALUE DOCSTRING])")
     (defconst . "(defconst SYMBOL INITVALUE [DOCSTRING])")
     (let* . "(let* VARLIST BODY...)")
     (let . "(let VARLIST BODY...)")
     (while . "(while TEST BODY...)")
     (catch . "(catch TAG BODY...)")
     (unwind-protect . "(unwind-protect BODYFORM UNWINDFORMS...)")
     (condition-case . "(condition-case VAR BODYFORM HANDLERS...)")
     (track-mouse . "(track-mouse BODY ...)")
     (ml-if . "(ml-if COND THEN ELSE...)")
     (ml-provide-prefix-argument . "(ml-provide-prefix-argument ARG1 ARG2)")
     (ml-prefix-argument-loop . "(ml-prefix-argument-loop ...)")
     (with-output-to-temp-buffer
	 . "(with-output-to-temp-buffer BUFFNAME BODY ...)")
     (save-window-excursion . "(save-window-excursion BODY ...)")
     (find-operation-coding-system
      . "(find-operation-coding-system OPERATION ARGUMENTS ...)")
     (insert-before-markers-and-inherit
      . "(insert-before-markers-and-inherit &rest ARGS)"))))

;; Provide this for the sake of define-minor-mode which generates
;; defcustoms which require 'help'.

(provide 'help)

;;; help.el ends here
