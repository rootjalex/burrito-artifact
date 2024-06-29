#lang racket

(require
  (only-in racket/struct make-constructor-style-printer)
  rosette/lib/destruct
  "arith.rkt"
  "array.rkt"
  "expr.rkt"
  "format.rkt"
  "index.rkt"
  "kernel.rkt"
  "compile.rkt"
)

; Define first vector
(define I (arith:Variable "I"))
(define i (Index "i" I))
(define A (Array "A" (make-format (list (cons i Compressed)))))

; Define second vector
(define J (arith:Variable "J"))
(define j (Index "j" J))
(define B (Array "B" (make-format (list (cons j Compressed)))))

; Define output vector
(define k (Index "k" (arith:Add I J)))
(define C (Array "C" (make-format (list (cons k Compressed)))))

; Construct concatenation kernel, and compile to file
(define expr (Concat (Read A) (Read B) i j k))
(compile (Kernel C expr) "cv_concat_cv_cv" "cv_concat_cv_cv.h")
