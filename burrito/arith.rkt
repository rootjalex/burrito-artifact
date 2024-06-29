#lang racket

(require
  (only-in racket/base error)
  (only-in racket/struct)
  rosette/lib/destruct
)

(provide (prefix-out arith: (all-defined-out)))

(struct Constant (val) #:transparent)
(struct Variable (name) #:transparent)
(struct Add (a b) #:transparent)
(struct Mul (a b) #:transparent)
(struct Sub (a b) #:transparent)
(struct Div (a b) #:transparent)

(define (print expr)
  (destruct expr
    [(Constant val) (format "~v" val)]
    [(Variable name) name]
    [(Add a b) (format "(~a + ~a)" (print a) (print b))]
    [(Mul a b) (format "(~a * ~a)" (print a) (print b))]
    [(Sub a b) (format "(~a - ~a)" (print a) (print b))]
    [(Div a b) (format "(~a / ~a)" (print a) (print b))]
    [_ (error (format "Unrecognized arith:expr: ~a" expr))]))

(define (is-const? value expr)
  (and (Constant? expr) (equal? value (Constant-val expr))))

(define (simplify expr)
  (destruct expr
    [(Constant val) expr]
    [(Variable name) expr]
    [(Add a b)
      (let ([x (simplify a)] [y (simplify b)])
        (cond
          [(is-const? 0 x) y]
          [(is-const? 0 y) x]
          [else (Add x y)]))]
    [(Mul a b)
      (let ([x (simplify a)] [y (simplify b)])
        (cond
          [(is-const? 1 x) y]
          [(is-const? 1 y) x]
          [(is-const? 0 x) x]
          [(is-const? 0 y) y]
          [else (Mul x y)]))]
    [(Sub a b)
      (let ([x (simplify a)] [y (simplify b)])
        (cond
          [(equal? x y) (Constant 0)]
          [(is-const? 0 y) x]
          [else (Sub x y)]))]
    [(Div a b)
      (let ([x (simplify a)] [y (simplify b)])
        (cond
          [(equal? x y) (Constant 1)]
          [(is-const? 1 y) x]
          [else (Div x y)]))]
    [_ (error (format "Unrecognized arith:expr in simplify: ~a" expr))]))
