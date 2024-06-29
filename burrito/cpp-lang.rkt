#lang racket

(require
  (only-in racket/base error)
  (only-in racket/struct)
  rosette/lib/destruct
)

(provide (prefix-out cpp: (all-defined-out)))

; Statement types
(struct While (cond body) #:transparent)
(struct For (var init? extent step body) #:transparent)
(struct Pair (body0 body1) #:transparent)
(struct Block (stmts) #:transparent) ; n-ary Pair
(struct IfBlock (pairs) #:transparent)
(struct Define (lhstype lhs rhs) #:transparent)
(struct Assign (lhs rhs) #:transparent)
(struct IncAssign (lhs rhs) #:transparent)

; Expr types

; Arithmetic (TODO: re-use arith?)
(struct Constant (val) #:transparent)
(struct Variable (name) #:transparent)
(struct Access (array idx) #:transparent)
(struct Add (a b) #:transparent)
(struct Mul (a b) #:transparent)
(struct Sub (a b) #:transparent)
(struct Div (a b) #:transparent)
(struct Mod (a b) #:transparent)
(struct Min (a b) #:transparent)

; Booleans
(struct And (a b) #:transparent)
(struct Or (a b) #:transparent)
(struct Equals (a b) #:transparent)
(struct Not (a) #:transparent)
(struct LT (a b) #:transparent)


(define index_t "index_t")
(define cindex_t "const index_t")
(define value_t "value_t")

(define (set-index_t! _index_t)
  (set! index_t _index_t)
  (set! cindex_t (string-append "const " _index_t)))

(define (print-stmt stmt)
  (_print-stmt stmt ""))

(define INDENT-STEP "  ")

(define (next-indent indent)
  (string-append indent INDENT-STEP))

(define (_print-stmt stmt indent)
  (destruct stmt
    [(While c body)
      (format "~awhile (~a) {\n~a\n~a}" indent (print-expr c) (_print-stmt body (next-indent indent)) indent)]
    [(For var init? extent step body)
      (format "~afor (~a; ~a < ~a; ~a += ~a) {\n~a\n~a}" indent (if init? (format "~a ~a = 0" index_t (print-expr var)) "") (print-expr var) (print-expr extent) (print-expr var) (print-expr step) (_print-stmt body (next-indent indent)) indent)]
    [(Block bodies)
      (string-join
        (filter-map (lambda (body) (let ([s (_print-stmt body indent)]) (and (non-empty-string? s) s))) bodies) "\n")]
    [(Pair body0 body1) (format "~a\n~a" (_print-stmt body0 indent) (_print-stmt body1 indent))]
    [(IfBlock pairs)
      (string-append indent
        (string-join
          (map
            (lambda (pair)
              (if (pair? pair)
                (format "if (~a) {\n~a\n~a}" (print-expr (car pair)) (_print-stmt (cdr pair) (next-indent indent)) indent)
                (format "{\n~a\n~a}" (_print-stmt pair (next-indent indent)) indent)))
            pairs)
          " else "))]
    [(Define lhstype lhs rhs) (format "~a~a ~a = ~a;" indent (print-type lhstype) (print-lhs lhs) (print-expr rhs))]
    [(Assign lhs rhs) (format "~a~a = ~a;" indent (print-lhs lhs) (print-expr rhs))]
    [(IncAssign lhs rhs) (format "~a~a += ~a;" indent (print-lhs lhs) (_print-expr rhs #t))]

    [void ""]
    [_ (error (format "Unrecognized stmt in cpp:_print-stmt: ~a" stmt))]))

(define (print-lhs expr)
  (destruct expr
    [(Variable name) name]
    [(Access array idx) (format "~a[~a]" (print-lhs array) (print-expr idx))]
    [_ (error (format "Unrecognized expr in cpp:print-lhs: ~a" expr))]))

(define (print-expr expr)
  (_print-expr expr #f))

(define (_print-expr expr [parens? #t])
  (destruct expr
    [(Constant val) (format "~v" val)]
    [(Variable name) name]
    [(Access array idx) (format "~a[~a]" (print-lhs array) (print-expr idx))]
    [(Add a b) (format (if parens? "(~a + ~a)" "~a + ~a") (_print-expr a parens?) (_print-expr b parens?))]
    [(Mul a b) (format (if parens? "(~a * ~a)" "~a * ~a") (_print-expr a #t) (_print-expr b #t))]
    [(Sub a b) (format (if parens? "(~a - ~a)" "~a - ~a") (_print-expr a parens?) (_print-expr b #t))]
    [(Div a b) (format (if parens? "(~a / ~a)" "~a / ~a") (_print-expr a #t) (_print-expr b #t))]
    [(Mod a b) (format (if parens? "(~a % ~a)" "~a % ~a") (_print-expr a #t) (_print-expr b #t))]
    [(Min a b) (format "min(~a, ~a)" (_print-expr a #f) (_print-expr b #f))]

    [(And a b) (format (if parens? "(~a && ~a)" "~a && ~a") (_print-expr a #t) (_print-expr b #t))]
    [(Or a b) (format (if parens? "(~a || ~a)" "~a || ~a") (_print-expr a #t) (_print-expr b #t))]
    [(Equals a b) (format (if parens? "(~a == ~a)" "~a == ~a") (_print-expr a #t) (_print-expr b #t))]
    [(Not a) (format "!~a" (_print-expr a #t))]
    [(LT a b) (format (if parens? "(~a < ~a)" "~a < ~a") (_print-expr a #t) (_print-expr b #t))]

    [void ""]
    [_ (error (format "Unrecognized expr in cpp:print-expr: ~a" expr))]))

(define (print-type type)
  ; TODO: this is a hook in case types get more complicated...
  type)

(define (make-block . stmts)
  ; TODO: unfold nested blocks.
  (Block stmts))
