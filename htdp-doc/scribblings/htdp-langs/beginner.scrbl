#lang scribble/doc
@(require "common.rkt" "std-grammar.rkt" "prim-ops.rkt"
          (for-label lang/htdp-beginner))


@title[#:tag "beginner"]{初级}

@section-index["BSL"]

@declare-exporting[lang/htdp-beginner #:use-sources (lang/htdp-beginner lang/private/teachprims)]

@grammar

@i1-2-expl 

@racketgrammar*+library[
#:literals (define define-struct lambda cond else if and or require lib planet
            check-expect check-random check-within check-error check-satisfied)
(name check-satisfied check-expect check-random check-within check-member-of check-range check-error require)
[program (code:line def-or-expr #, @dots)]
[def-or-expr definition
             expr
             test-case             
             library-require]
[definition (define (name variable variable #, @dots) expr)
            (define name expr)
            (define name (lambda (variable variable #, @dots) expr))
            (define-struct name (name #, @dots))]
[expr (code:line (name expr expr #, @dots))
      (cond [expr expr] #, @dots [expr expr])
      (cond [expr expr] #, @dots [else expr])
      (if expr expr expr)
      (and expr expr expr #, @dots)
      (or expr expr expr #, @dots)
      name
      (code:line @#,elem{@racketvalfont{'}@racket[name]})
      (code:line @#,elem{@racketvalfont{'}@racket[()]})
      number
      boolean 
      string
      character]
]

@prim-nonterms[("beginner") define define-struct]

@prim-variables[("beginner") empty true false .. ... .... ..... ......]

@; --------------------------------------------------

@section[#:tag "beginner-syntax"]{语法}

@(define-forms/normal define)
@(define-form/explicit-lambda define lambda)

@deftogether[(
@defform/none[(unsyntax @elem{@racketvalfont{'}@racket[name]})]
@defform[(quote name)]
)]{

引用的@racket[name]就是符号。符号是一种值，就和@racket[0]或@racket['()]一样。}

@(prim-forms ("beginner")
             define 
             lambda
             define-struct []
             define-wish
             cond
             else
             if
             and 
             or
             check-expect
             check-random
             check-satisfied
             check-within
             check-error
             check-member-of
             check-range
             require
             true false
             #:with-beginner-function-call #t
             )

@; --------------------------------------------------
             
@section[#:tag "beginner-pre-defined"]{预定义函数}

后续小节列出了编程语言中内置的函数。所有其他函数要么从教学包中导入，要么必须在程序中定义。

@(require (submod lang/htdp-beginner procedures))
@(render-sections (docs) #'here "htdp-beginner")

@;prim-op-defns[ #'here '()]
