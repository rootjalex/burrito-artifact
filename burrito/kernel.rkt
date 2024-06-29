#lang racket

(require
  (only-in racket/struct)
  "format.rkt"
)

(provide (all-defined-out))

(struct Kernel (array expr) #:transparent)
