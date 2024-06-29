#lang racket

(require
  (only-in racket/struct)
  "index.rkt")

(provide (all-defined-out))

; Level formats
(define Dense 'dense)
(define Compressed 'compressed)
(define Coordinate 'coordinate)

; modes is a list of idxs
; levels is a hashmap of idx to level format
(struct Format (modes levels) #:transparent)

(define (make-format assocs)
  (Format (map car assocs) (make-hash assocs)))

(define (get-idx-format f idx)
  (hash-ref (Format-levels f) idx))

(define (has-idx-parent? f idx)
  (not (equal? 0 (index-of (Format-modes f) idx))))

(define (is-csr? f)
  (and
    (equal? 2 (length (Format-modes f)))
    (equal? Dense (get-idx-format f (list-ref (Format-modes f) 0)))
    (equal? Compressed (get-idx-format f (list-ref (Format-modes f) 1)))))

(define (is-coo? f)
  (and
    (equal? 2 (length (Format-modes f)))
    (equal? Coordinate (get-idx-format f (list-ref (Format-modes f) 0)))
    (equal? Coordinate (get-idx-format f (list-ref (Format-modes f) 1)))))

(define (is-cvector? f)
  (and
    (equal? 1 (length (Format-modes f)))
    (equal? Compressed (get-idx-format f (list-ref (Format-modes f) 0)))))

(define (is-dvector? f)
  (and
    (equal? 1 (length (Format-modes f)))
    (equal? Dense (get-idx-format f (list-ref (Format-modes f) 0)))))
