#lang racket

(require
  (only-in racket/base error)
  (only-in racket/struct)
  rosette/lib/destruct
  "array.rkt"
  "expr.rkt"
  "index.rkt"
  "infer.rkt"
  "kernel.rkt"
  "seq.rkt"
)

(provide (prefix-out cin: (all-defined-out)))

(struct ForAll (idx sexpr body) #:transparent)
(struct Pair (body0 body1) #:transparent)
(struct Where (temp producer consumer) #:transparent)
(struct Assign (array rhs) #:transparent)
(struct Reduce (array rhs) #:transparent)

(define (print stmt)
  (pprint stmt ""))

(define (pprint stmt indent)
  (destruct stmt
    [(ForAll idx sexpr body)
      (let ([str-body (pprint body (string-append indent "  "))])
        (format "~aforall ~a \\in ~a\n~a" indent (idx-name idx) (seq:print sexpr) str-body))]
    [(Pair b0 b1) (format "~a;\n~a" (pprint b0 indent) (pprint b1 indent))]
    [(Where t p c)
      (let ([str-p (pprint p (string-append indent "  "))]
            [str-c (pprint c (string-append indent "  "))])
        (format "~alet\n~a\n~ain\n~a" indent str-p indent str-c))]
    [(Assign array rhs)
      (format "~a~a = ~a" indent (print-array-access array) (expr:print rhs))]
    [(Reduce array rhs)
      (format "~a~a += ~a" indent (print-array-access array) (expr:print rhs))]

    [_ (error (format "Unrecognized stmt in cin:print: ~a" stmt))]))

; helper function for codegen.
(define (remove-shape-ops expr)
  (destruct expr
    [(Read _) expr]
    [(Add a b) (Add (remove-shape-ops a) (remove-shape-ops b))]
    [(Mul a b) (Mul (remove-shape-ops a) (remove-shape-ops b))]
    [(Sum _ _) (error (format "Unexpected sum in remove-shape-ops: ~a" (expr:print expr)))]

    [(Broadcast idx a) (remove-shape-ops a)]
    [(Collapse a i j k) (remove-shape-ops a)]
    ; Concatenations are the exception at this stage.
    [(Concat a b i j k) (Concat (remove-shape-ops a) (remove-shape-ops b) i j k)]
    [(Split a _ _ _) (remove-shape-ops a)]
    [(Slice a _ _ _ _ _) (remove-shape-ops a)]

    [_ (error (format "Unrecognized expr in remove-shape-ops: ~a" expr))]))

(define codegen-t-counter 0)
(define (get-counter)
  (let ([counter codegen-t-counter])
    (set! codegen-t-counter (+ counter 1))
    counter))
(define (get-temp-name)
  (string-append "t" (number->string (get-counter))))

(define (codegen-where output expr op)
  (let* ([t0-name (get-temp-name)]
         [t0 (make-scalar-array t0-name)]
         [reduct (expr:find-sum expr)]
         [new-expr (expr:replace reduct (Read t0) expr)]
         [reduct-expr (sum-expr reduct)]
         [reduct-idx (sum-idx reduct)]
         [recurse (codegen-base t0 reduct-expr Reduce)]
         [reduct-body (car recurse)]
         [reduct-seq (seq:derive (cdr recurse) reduct-idx)]
         [producer (ForAll reduct-idx reduct-seq reduct-body)]
         [consumer (op output (remove-shape-ops new-expr))])
    ; TODO: new-expr contains a scalar. How do you derive for a scalar??
    (cons (Where t0 producer consumer) expr)))

(define (codegen-base output expr op)
  (if (expr:contains-sum? expr)
    (codegen-where output expr op)
    (cons (op output (remove-shape-ops expr)) expr)))

(define (build-forall idx body-expr)
  (cons (ForAll idx (seq:derive (cdr body-expr) idx) (car body-expr)) (cdr body-expr)))

(define (codegen kernel)
  (let* ([output (Kernel-array kernel)]
         [loop-order (array-idxs output)]
         [expr (Kernel-expr kernel)]
         [shape (infer expr)])
    (when (not (set=? (list->set loop-order) shape))
      (error
        (format "Output array shape and rhs expr shape do not match:\n~a -> ~a\nversus\n~a -> ~a"
                output loop-order (expr:print expr) shape)))

    ; TODO: allow scheduling?
    ; TODO: loop reodering could just permute loop-order
    ; (displayln loop-order)
    ; TODO: precompute is much harder...

    ; codegen-base: replace sums with where statements.
    ; then recursively build forall loops.
    (car (foldr build-forall (codegen-base output expr Assign) loop-order))))

(define (simplify stmt defs)
  ; (displayln (format "Simplifying: ~a" (print stmt)))
  ; (displayln "defs:")
  ; (pretty-print defs)
  (destruct stmt
    [(ForAll idx sexpr body)
      (let ([new-sexpr (seq:simplify sexpr defs)])
        (when (seq:is-empty-seq? new-sexpr)
          (error (format "Simplification produced empty: ~a with ~a" (print stmt) defs)))
        (ForAll idx new-sexpr (simplify body (set-union defs (seq:iters new-sexpr)))))]
    [(Pair b0 b1) (Pair (simplify b0 defs) (simplify b1 defs))]
    [(Where t p c) (Where t (simplify p defs) (simplify c defs))]

    [(Assign array rhs)
      (let ([new-rhs (expr:simplify rhs defs)])
        (when (symbol? new-rhs)
          (error (format "Simplification produced zero: ~a with ~a" (print stmt) (print-defs defs))))
        (Assign array new-rhs))]
    [(Reduce array rhs)
      (let ([new-rhs (expr:simplify rhs defs)])
        (when (symbol? new-rhs)
          (error (format "Simplification produced zero: ~a with ~a" (print stmt)  (print-defs defs))))
        (Reduce array new-rhs))]

    [_ (error (format "Unrecognized stmt in cin:simplify: ~a" stmt))]))

(define (get-written-array stmt)
  (destruct stmt
    [(ForAll idx sexpr body) (get-written-array body)]
    [(Pair b0 b1)
      (let ([w0 (get-written-array b0)]
            [w1 (get-written-array b1)])
        (if (equal? w0 w1) w0 (error (format "get-written-array mismatch failure: ~a" (print stmt)))))]
    [(Where t p c) (get-written-array c)]
    [(Assign array rhs) array]
    [(Reduce array rhs) array]
    [_ (error (format "Unrecognized stmt in cin:get-written-array: ~a" stmt))]))
