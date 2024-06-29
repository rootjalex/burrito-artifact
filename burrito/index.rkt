#lang racket

(require
  (only-in racket/struct make-constructor-style-printer)
  rosette/lib/destruct
  "arith.rkt")

(provide Index idx-name idx-size)

(struct Index (name size) #:transparent)

; TODO: I don't understand why this is necessary...
(define (idx-name idx)
  (Index-name idx))
(define (idx-size idx)
  (Index-size idx))
