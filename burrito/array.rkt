#lang racket

(require
  (only-in racket/struct)
  "arith.rkt"
  "format.rkt"
  "index.rkt"
)

(provide (all-defined-out))

(struct Array (name format) #:transparent)

; TODO: helper functions...

(define (array-idxs array)
  (Format-modes (Array-format array)))

(define (array-idx array n)
  (list-ref (Format-modes (Array-format array)) n))

(define (array-idx-format array idx)
  (get-idx-format (Array-format array) idx))

(define (is-dense-level? array idx)
  (equal? (array-idx-format array idx) Dense))

(define (is-coo-level? array idx)
  (equal? (array-idx-format array idx) Coordinate))

(define (is-cmp-level? array idx)
  (equal? (array-idx-format array idx) Compressed))

(define (is-array-idx? array idx)
  (member idx (array-idxs array)))

(define (print-array-access array)
  (format "~a[~a]" (Array-name array) (string-join (map idx-name (array-idxs array)) ", ")))

(define (make-scalar-array name)
  (Array name (make-format (list))))

(define (is-scalar-array? array)
  (equal? 0 (length (array-idxs array))))

(define (array-idx-index array idx)
  (let* ([idxs (array-idxs array)] [i (index-of idxs idx)])
    (if (number? i)
      i
      (error (format "Did not find idx: ~a in array: ~a" idx array)))))

(define (array-idx-parent array idx)
  (let ([i (array-idx-index array idx)])
    (if (equal? 0 i)
      (error (format "No parent to idx: ~a for array ~a" idx array))
      (list-ref (array-idxs array) (- i 1)))))

(define (array-descendant array)
  (list-ref (array-idxs array) (- (length (array-idxs array)) 1)))

(define (array-last-idx? array idx)
  (let ([i (array-idx-index array idx)])
    (equal? (length (array-idxs array)) (+ i 1))))

(define (array-idx-child array idx)
  (let ([i (array-idx-index array idx)])
    (if (equal? (length (array-idxs array)) (+ i 1))
      (error (format "No child to idx: ~a for array ~a" idx array))
      (list-ref (array-idxs array) (+ i 1)))))

(define (chain-is-dense? array idx i)
  (and (is-dense-level? array idx) (or (equal? 0 i) (chain-is-dense? array (array-idx-parent array idx) (- i 1)))))

(define (idx-defined? idx array defs)
  (let ([i (array-idx-index array idx)])
    (or (equal? 0 i) (chain-is-dense? array idx i) (set-member? defs (cons (array-idx-parent array idx) array)))))

(define (idxs-defined? array defs)
  (andmap (lambda (idx) (set-member? defs (cons idx array))) (array-idxs array)))

(define (print-defs defs)
  (string-join (set-map defs (lambda (d) (format "~a <- ~a" (idx-name (car d)) (Array-name (cdr d))))) "\n"))

(define (get-level-name array idx)
  (format "~a_~a~a" (Array-name array) (array-idx-format array idx) (array-idx-index array idx)))

(define (array-is-dense? array)
  (andmap (lambda (idx) (is-dense-level? array idx)) (array-idxs array)))
