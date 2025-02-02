(define-module (gnu home)
  #:use-module (gnu home-services)
  #:use-module (gnu home-services shepherd)
  #:use-module (gnu home-services symlink-manager)
  #:use-module (gnu home-services shells)
  #:use-module (gnu home-services xdg)
  #:use-module (gnu services)
  #:use-module (gnu system keyboard)
  #:use-module (srfi srfi-1)
  #:use-module (guix records)
  #:export (home-environment
	    home-environment?
	    this-home-environment
	    home-environment-derivation
	    home-environment-home-directory
	    home-environment-symlink-name
	    home-environment-symlink-path))

(define-record-type* <home-environment> home-environment
  make-home-environment
  home-environment?
  this-home-environment

  ;; (layout)
  ;; (xdg-dirs)
  (packages home-environment-packages             ; list of (PACKAGE OUTPUT...)
            (default '()))

  (keyboard-layout home-environment-keyboard-layout
		   (default #f))

  ;; (xdg-base-dirs home-environment-xdg-base-dirs)
  ;; (xdg-user-dirs home-environment-xdg-user-dirs)

  (essential-services home-environment-essential-services ; list of services
                      (thunked)
                      (default (home-environment-default-essential-services
                                this-home-environment)))
  (services home-environment-user-services
	    (default '()))

  (home-directory home-environment-home-directory
		       (default #f))
  (symlink-name home-environment-symlink-name
		(default ".guix-home-environment"))

  (symlink-path home-environment-symlink-path (thunked)
		(default
		  (string-append
		   (home-environment-home-directory this-home-environment)
		   "/"
		   (home-environment-symlink-name this-home-environment))))

  ;; (location home-environment-location             ; <location>
  ;;           (default (and=> (current-source-location)
  ;;                           source-properties->location))
  ;;           (innate))
  )

(define (home-environment-default-essential-services he)
  "Return the list of essential services for home environment."
  (let* ((layout (home-environment-keyboard-layout he))
	 (layout-service
	  (if layout
	      (simple-service
	       'layout-env-vars home-environment-vars-service-type
	       `(("XKB_DEFAULT_LAYOUT" . ,(keyboard-layout-name layout))
		 ("XKB_DEFAULT_VARIANT" . ,(keyboard-layout-variant layout))
		 ("XKB_DEFAULT_OPTIONS" . ,(string-join
					    (keyboard-layout-options layout) ","))
		 ("XKB_DEFAULT_MODEL" . ,(keyboard-layout-model layout))))
	      #f)))
    (remove
     nil?
     (cons*
      layout-service
      (list
       (service home-shepherd-service-type)
       (service home-symlink-manager-service-type)

       ;; Will be instantiated automatically, but still explicitly
       ;; declared for clarity
       (service home-run-on-first-login-service-type)
       (service home-run-on-reconfigure-service-type)

       ;; It should be safe to use symlink-path as
       ;; GUIX_HOME_ENVIRONMENT_DIRECTORY, however
       ;; /var/guix/profiles/per-user/... is another option
       (service home-environment-vars-service-type
		`(("GUIX_HOME_ENVIRONMENT_DIRECTORY" .
		   ,(home-environment-symlink-path he))))

       ;; Make guix aware of `guix home` after first reconfigure, this
       ;; declaration must go before xdg-base-dirs.  Potentially
       ;; dangerous "fix", it makes possible for malicious channel
       ;; expose it's own guix subcommands.
       ;; TODO: Remove it once upstreamed.
       (simple-service
	'make-guix-aware-of-guix-home-subcomand
	home-environment-vars-service-type
	'(("GUILE_LOAD_PATH" .
	   "$XDG_CONFIG_HOME/guix/current/share/guile/site/3.0\
:$GUILE_LOAD_PATH")
	  ("GUILE_LOAD_COMPILED_PATH" .
	   "$XDG_CONFIG_HOME/guix/current/lib/guile/3.0/site-ccache\
:$GUILE_LOAD_COMPILED_PATH")))
       (service home-xdg-base-directories-service-type)

       (service home-shell-profile-service-type
		(home-shell-profile-configuration
		 (he-symlink-path (home-environment-symlink-path he))))
       (service home-service-type)
       (service home-profile-service-type (home-environment-packages he)))))))

(define* (home-environment-services he)
  "Return all the services of home environment."
  (instantiate-missing-services
   (append (home-environment-user-services he)
           (home-environment-essential-services he))))

(define* (home-environment-derivation he)
  "Return a derivation that builds OS."
  (let* ((services         (home-environment-services he))
         (home (fold-services services
			      #:target-type home-service-type)))
    (service-value home)))

;; home-profile-service-type
;; home-activation-service-type
;; home-shepherd-services-type

;; shepherd-service-type
;; https://specifications.freedesktop.org/autostart-spec/autostart-spec-latest.html


;; Guix home manager intro:
;; https://lists.gnu.org/archive/html/guix-devel/2019-09/msg00218.html
;; Service extension alternatives:
;; https://issues.guix.gnu.org/issue/27155
