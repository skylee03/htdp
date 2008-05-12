#lang scheme/base

(require scheme/file scheme/class scheme/unit scheme/contract drscheme/tool framework mred)
(require "test-display.scm")
(provide tool@)

(define tool@
  (unit (import drscheme:tool^) (export drscheme:tool-exports^)

    (define (phase1) (void))
    (define (phase2) (void))

    ;; Overriding interactions as the current-rep implementation
    (define (test-interactions-text%-mixin %)
      (class* % ()
        (inherit get-top-level-window get-definitions-text)

        (define/public (display-test-results test-display)
          (let* ([dr-frame (get-top-level-window)]
                 [ed-def (get-definitions-text)]
                 [tab (and ed-def (send ed-def get-tab))])
            (when (and dr-frame ed-def tab)
              (send test-display display-settings dr-frame tab ed-def)
              (send test-display display-results))))

        (super-instantiate ())))

    (define (test-definitions-text%-mixin %)
      (class* % ()
        (inherit begin-edit-sequence end-edit-sequence)

        (define colorer-frozen-by-test? #f)
        (define/public (test-froze-colorer?) colorer-frozen-by-test?)
        (define/public (toggle-test-status)
          (set! colorer-frozen-by-test?
                (not colorer-frozen-by-test?)))

        (define/public (begin-test-color)
          (begin-edit-sequence #f))
        (define/public (end-test-color)
          (end-edit-sequence))

        (define/augment (on-delete start len)
          (begin-edit-sequence)
          (inner (void) on-delete start len))
        (define/augment (after-delete start len)
          (inner (void) after-delete start len)
          (when colorer-frozen-by-test?
            (send this thaw-colorer)
            (send this toggle-test-status))
          (end-edit-sequence))

        (define/augment (on-insert start len)
          (begin-edit-sequence)
          (inner (void) on-insert start len))
        (define/augment (after-insert start len)
          (inner (void) after-insert start len)
          (when colorer-frozen-by-test?
            (send this thaw-colorer)
            (send this toggle-test-status))
          (end-edit-sequence))

        (super-instantiate ())))

    (define (test-frame-mixin %)
      (class* % ()
        (inherit get-current-tab)

        (define/public (display-test-panel editor)
          (send test-panel update-editor editor)
          (unless (send test-panel is-shown?)
            (send test-frame add-child test-panel)
            (let ([test-box-size
                   (get-preference 'test:test-dock-size (lambda () '(2/3 1/3)))])
              (send test-frame set-percentages test-box-size))))
        (define test-panel null)
        (define test-frame null)

        (define test-windows null)
        (define/public (register-test-window t)
          (set! test-windows (cons t test-windows)))
        (define/public (deregister-test-window t)
          (set! test-windows (remq t test-windows)))

        (define/public (dock-tests)
          (for ([t test-windows]) (send t show #f))
          (let ([ed (send (get-current-tab) get-test-editor)])
            (when ed (display-test-panel ed)))
          (send dock-menu-item swap-labels))
        (define/public (undock-tests)
          (when (send test-panel is-shown?) (send test-panel remove))
          (for ([t test-windows]) (send t show #t))
          (send dock-menu-item swap-labels))

        (define/override (make-root-area-container cls parent)
          (let* ([outer-p (super make-root-area-container
                                 panel:vertical-dragable% parent)]
                 [louter-panel (make-object vertical-panel% outer-p)]
                 [test-p (make-object test-panel% outer-p '(deleted))]
                 [root (make-object cls louter-panel)])
            (set! test-panel test-p)
            (send test-panel update-frame this)
            (set! test-frame outer-p)
            root))

        (define/augment (on-tab-change from-tab to-tab)
          (let ([test-editor (send to-tab get-test-editor)]
                [panel-shown? (send test-panel is-shown?)]
                [dock? (get-preference 'test:test-window:docked? (lambda () #f))])
            (cond [(and test-editor panel-shown? dock?)
                   (send test-panel update-editor test-editor)]
                  [(and test-editor dock?)
                   (display-test-panel test-editor)]
                  [(and panel-shown? (not dock?))
                   (undock-tests)]
                  [panel-shown? (send test-panel remove)])
            (inner (void) on-tab-change from-tab to-tab)))

        (inherit get-menu-bar get-menu% register-capability-menu-item get-definitions-text
                 get-insert-menu)
        (define testing-menu 'not-init)
        (define dock-menu-item 'not-init)
        (define dock-label "Dock Report")
        (define undock-label "Undock Report")
        
        (define dock-menu-item%
          (class menu:can-restore-menu-item%
            (inherit set-label)
            (define docked? #t)
            (define/public (is-report-docked?) docked?)
            (define/public (set-docked?! d) (set! docked? d))
            (define/public (swap-labels)
              (if docked?
                  (send this set-label dock-label)
                  (send this set-label undock-label))
              (set! docked? (not docked?)))
            (define/public (dock-report) 
              (unless docked? (dock-tests) (put-preferences '(test:test-window:docked?) '(#t))))
            (define/public (undock-report) 
              (when docked? (undock-tests) (put-preferences '(test:test-window:docked?) '(#f))))
            (super-instantiate ())))
        
        (define/override (add-show-menu-items show-menu)
          (super add-show-menu-items show-menu)
          (let ([dock? (get-preference 'test:test-window:docked? (lambda () #t))])
            (when (eq? dock-menu-item 'not-init)
              (set! dock-menu-item 
                    (make-object dock-menu-item% 
                      (if dock? undock-label dock-label) 
                      show-menu 
                      (lambda (_1 _2)
                        (if (send _1 is-report-docked?)
                            (send _1 undock-report)
                            (send _1 dock-report)))))
              (register-capability-menu-item 'tests:dock-menu show-menu))
            (send dock-menu-item set-docked?! dock?)))
        
        (define/private (test-menu-init)
          (let ([menu-bar (get-menu-bar)]
                [test-label "Testing"]
                [enable-label "Enable Tests"]
                [disable-label "Disable Tests"])
                
            (set! testing-menu (make-object (get-menu%) test-label menu-bar))
            (letrec ([enable-menu-item%
                      (class menu:can-restore-menu-item%
                        (define enabled? #t)
                        (define/public (is-test-enabled?) enabled?)
                        (define/public (set-test-enabled?! e) (set! enabled? e))
                        (define/public (enable-tests)
                          (unless enabled?
                            (set! enabled? #t)
                            (send this set-label disable-label)
                            (put-preferences '(tests:enable?) '(#t))))
                        (define/public (disable-tests)
                          (when enabled?
                            (set! enabled? #f)
                            (send this set-label enable-label)
                            (put-preferences '(tests:enable?) '(#f))))
                        (super-instantiate ()))]
                     [enable? (get-preference 'tests:enable? (lambda () #t))]
                     [enable-menu-item (make-object enable-menu-item%
                                         (if enable? disable-label enable-label)
                                         testing-menu
                                         (lambda (_1 _2)
                                           (if (send _1 is-test-enabled?)
                                               (send _1 disable-tests)
                                               (send _1 enable-tests))) #f)])
              
              (send enable-menu-item set-test-enabled?! enable?)
              (register-capability-menu-item 'tests:test-menu testing-menu))))
        
        (define/override (language-changed)
          (super language-changed)
          (let* ([settings (send (get-definitions-text) get-next-settings)]
                 [language (drscheme:language-configuration:language-settings-language settings)]
                 [show-testing (send language capability-value 'tests:test-menu)]
                 [insert-menu (get-insert-menu)])
            (when (eq? testing-menu 'not-init) (test-menu-init))
            (cond
              [show-testing
               (let ([menus (send (send testing-menu get-parent) get-items)])
                 (let d-loop ([m menus]) (unless (null? m) (send (car m) delete) (d-loop (cdr m))))
                 (let r-loop ([m menus])
                   (unless (null? m)
                     (cond
                       [(eq? (car m) insert-menu)
                        (send (car m) restore)               
                        (send testing-menu restore)
                        (r-loop (cdr m))]
                       [else (send (car m) restore) (r-loop (cdr m))]))))]
              [else (send testing-menu delete)])))
        
        (unless (drscheme:language:capability-registered? 'tests:dock-menu)
          (drscheme:language:register-capability 'tests:dock-menu (flat-contract boolean?) #f))
          
        (unless (drscheme:language:capability-registered? 'tests:test-menu)
          (drscheme:language:register-capability 'tests:test-menu (flat-contract boolean?) #f))
        (super-instantiate ())
        ))

    (define (test-tab%-mixin %)
      (class* % ()
        (inherit get-frame get-defs)

        (define test-editor #f)
        (define/public (get-test-editor) test-editor)
        (define/public (current-test-editor ed)
          (set! test-editor ed))

        (define test-window #f)
        (define/public (get-test-window) test-window)
        (define/public (current-test-window w) (set! test-window w))

        (define/public (update-test-preference test?)
          (let* ([language-settings
                  (preferences:get
                   (drscheme:language-configuration:get-settings-preferences-symbol))]
                 [language
                  (drscheme:language-configuration:language-settings-language
                   language-settings)]
                 [settings
                  (drscheme:language-configuration:language-settings-settings
                   language-settings)])
            (when (object-method-arity-includes? language 'update-test-setting 2)
              (let ([next-setting
                     (drscheme:language-configuration:make-language-settings
                      language
                      (send language update-test-setting settings test?))])
                (preferences:set
                 (drscheme:language-configuration:get-settings-preferences-symbol)
                 next-setting)
                (send (get-defs) set-next-settings next-setting)))))

        (define/augment (on-close)
          (when test-window
            (when (send test-window is-shown?)
              (send test-window show #f))
            (send (get-frame) deregister-test-window test-window))
          (inner (void) on-close))

        (super-instantiate ())))

    (drscheme:get/extend:extend-definitions-text test-definitions-text%-mixin)
    (drscheme:get/extend:extend-interactions-text test-interactions-text%-mixin)
    (drscheme:get/extend:extend-unit-frame test-frame-mixin)
    (drscheme:get/extend:extend-tab test-tab%-mixin)

    ))