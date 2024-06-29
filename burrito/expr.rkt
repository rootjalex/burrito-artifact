#lang racket

(require
  (only-in racket/base error)
  (only-in racket/struct)
  rosette/lib/destruct
  "arith.rkt"
  "array.rkt"
  "index.rkt"
)

(provide Read Add Mul Sum Broadcast Collapse Concat Split Slice
        (prefix-out expr: print) (prefix-out expr: contains-sum?)
        (prefix-out expr: find-sum) (prefix-out expr: replace)
        (prefix-out expr: simplify) (prefix-out expr: gather-arrays)
        (prefix-out expr: contains-reshape?) sum-expr sum-idx)

(struct Read (array) #:transparent)
(struct Add (a b) #:transparent)
(struct Mul (a b) #:transparent)
(struct Sum (idx a) #:transparent)
; Shape operators
(struct Broadcast (idx a) #:transparent)
(struct Collapse (a i j k) #:transparent)
(struct Concat (a b i j k) #:transparent)
(struct Split (a i j k) #:transparent)
(struct Slice (a i j s e r) #:transparent)

(define (print expr)
  (pprint expr #f))

(define (pprint expr paren?)
  (destruct expr
    [(Read array) (print-array-access array)]
    [(Add a b) (format (if paren? "(~a + ~a)" "~a + ~a") (print a) (print b))]
    [(Mul a b) (format (if paren? "(~a * ~a)" "~a * ~a") (print a) (print b))]
    [(Sum idx a) (format "sum(~a, ~a)" (idx-name idx) (print a))]

    [(Broadcast idx a) (format "bc(~a, ~a)" (idx-name idx) (print a))]
    [(Collapse a i j k) (format "collapse(~a, (~a, ~a) -> ~a)" (print a) (idx-name i) (idx-name j) (idx-name k))]
    [(Concat a b i j k) (format "concat((~a, ~a), (~a, ~a) -> ~a)" (print a) (print b) (idx-name i) (idx-name j) (idx-name k))]
    [(Split a i j k) (format "split(~a, ~a -> (~a, ~a))" (print a) (idx-name i) (idx-name j) (idx-name k))]
    [(Slice a i j s e r) (format "slice(~a, ~a[~a, ~a, ~a] -> ~a)" (print a) (idx-name i) (arith:print s) (arith:print e) (arith:print r) (idx-name j))]
    
    [_ (error (format "Unrecognized expr: ~a" expr))]))

(define (contains-sum? expr)
  (destruct expr
    [(Read _) #f]
    [(Add a b) (or (contains-sum? a) (contains-sum? b))]
    [(Mul a b) (or (contains-sum? a) (contains-sum? b))]
    [(Sum idx a) #t]

    [(Broadcast idx a) (contains-sum? a)]
    [(Collapse a i j k) (contains-sum? a)]
    [(Concat a b i j k) (or (contains-sum? a) (contains-sum? b))]
    [(Split a i j k) (contains-sum? a)]
    [(Slice a i j s e r) (contains-sum? a)]

    [_ (error (format "Unrecognized expr in expr:contains-sum?: ~a" expr))]))
; TODO: these could be merged.
(define (find-sum expr)
  (destruct expr
    [(Read _) #f]
    [(Add a b)
      (let ([x (find-sum a)])
        (if x x (find-sum b)))]
    [(Mul a b)
      (let ([x (find-sum a)])
        (if x x (find-sum b)))]
    [(Sum _ _) expr]

    [(Broadcast idx a) (find-sum a)]
    [(Collapse a _ _ _) (find-sum a)]
    [(Concat a b _ _ _)
      (let ([x (find-sum a)])
        (if x x (find-sum b)))]
    [(Split a _ _ _) (find-sum a)]
    [(Slice a _ _ _ _ _) (find-sum a)]

    [_ (error (format "Unrecognized expr in find-sum: ~a" expr))]))

(define (contains-reshape? expr)
  (destruct expr
    [(Read _) #f]
    [(Add a b) (or (contains-reshape? a) (contains-reshape? b))]
    [(Mul a b) (or (contains-reshape? a) (contains-reshape? b))]
    [(Sum idx a) (contains-reshape? a)]

    [(Broadcast idx a) (contains-reshape? a)]
    [(Collapse a i j k) #t]
    [(Concat a b i j k) (or (contains-reshape? a) (contains-reshape? b))]
    [(Split a i j k) #t]
    [(Slice a i j s e r) (contains-reshape? a)]

    [_ (error (format "Unrecognized expr in expr:contains-reshape?: ~a" expr))]))

(define (replace old repl expr)
  (if (equal? old expr)
    repl
    (destruct expr
      [(Read _) expr]
      [(Add a b) (Add (replace old repl a) (replace old repl b))]
      [(Mul a b) (Mul (replace old repl a) (replace old repl b))]
      [(Sum idx a) (Sum idx (replace old repl a))]

      [(Broadcast idx a) (Broadcast idx (replace old repl a))]
      [(Collapse a i j k) (Collapse (replace old repl a) i j k)]
      [(Concat a b i j k) (Concat (replace old repl a) (replace old repl b) i j k)]
      [(Split a i j k) (Split (replace old repl a) i j k)]
      [(Slice a i j s e r) (Slice (replace old repl a) i j s e r)]

      [_ (error (format "Unrecognized expr in replace: ~a" expr))])))

(define (sum-expr s)
  (Sum-a s))

(define (sum-idx s)
  (Sum-idx s))

(define (is-zero? expr)
  (equal? 'zero expr))

(define (make-zero)
  'zero)

(define (simplify expr defs)
  (destruct expr
    [(Read array)
      (if (idxs-defined? array defs) expr (make-zero))]
    [(Add a b)
      (let ([x (simplify a defs)] [y (simplify b defs)])
        (cond
          [(is-zero? x) y]
          [(is-zero? y) x]
          [(Add x y)]))]
    [(Mul a b)
      (let ([x (simplify a defs)] [y (simplify b defs)])
        (cond
          [(or (is-zero? x) (is-zero? y)) (make-zero)]
          [(Mul x y)]))]
    [(Sum idx a)
      (let ([x (simplify a defs)])
        (cond
          [(is-zero? x) (make-zero)]
          [(Sum idx x)]))]

    [(Broadcast idx a)
      (let ([x (simplify a defs)])
        (cond
          [(is-zero? x) (make-zero)]
          [(Broadcast idx x)]))]
    [(Collapse a i j k)
      (let ([x (simplify a defs)])
        (cond
          [(is-zero? x) (make-zero)]
          [(Collapse x i j k)]))]
    [(Concat a b i j k)
      (let ([x (simplify a defs)] [y (simplify b defs)])
        (cond
          [(and (is-zero? x) (is-zero? y)) (make-zero)]
          [(is-zero? x) y]
          [(is-zero? y) x]
          [(Concat x y i j k)]))]
    [(Split a i j k)
      (let ([x (simplify a defs)])
        (cond
          [(is-zero? x) (make-zero)]
          [(Split x i j k)]))]
    [(Slice a i j s e r)
      (let ([x (simplify a defs)])
        (cond
          [(is-zero? x) (make-zero)]
          [(Slice x i j s e r)]))]
    
    [_ (error (format "Unrecognized expr in expr:simplify: ~a" expr))]))

; TODO: might want to use sets?
(define (gather-arrays expr)
  (destruct expr
    [(Read array) (list array)]
    [(Add a b) (append (gather-arrays a) (gather-arrays b))]
    [(Mul a b) (append (gather-arrays a) (gather-arrays b))]
    [(Sum idx a) (gather-arrays a)]

    [(Broadcast idx a) (gather-arrays a)]
    [(Collapse a i j k) (gather-arrays a)]
    [(Concat a b i j k) (append (gather-arrays a) (gather-arrays b))]
    [(Split a i j k) (gather-arrays a)]
    [(Slice a i j s e r) (gather-arrays a)]

    [_ (error (format "Unrecognized expr in gather-arrays: ~a" expr))]))
