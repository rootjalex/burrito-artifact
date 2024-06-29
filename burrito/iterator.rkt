#lang racket

(require
  (only-in racket/base error)
  (only-in racket/struct)
  rosette/lib/destruct
  "arith.rkt"
  "array.rkt"
  "cpp-utils.rkt"
  "cpp-lang.rkt"
  "format.rkt"
  "index.rkt"
  "seq.rkt"
)

(provide (prefix-out iterator: (all-defined-out)))

(define (make-proj-var k)
  (cpp:Variable (format "proj_~a" k)))

(define (init sexpr initset)
  (if (set-member? initset sexpr)
    void
    (begin
    (set-add! initset sexpr)
    (destruct sexpr
      [(seq:Dim idx array)
        (if (is-coo-level? array idx)
          (let ([i (array-idx-index array idx)])
            (if (equal? i 0)
              (cpp:Define cpp:index_t (cpp:array-index array (array-descendant array)) (cpp:Constant 0))
              ; TODO: define parent value if not in init set?
              (let ([p (array-idx-parent array idx)])
                (cpp:Define cpp:index_t (cpp:array-index array p) (eval (seq:Dim p array))))))
          (cpp:Define cpp:index_t (cpp:array-index array idx) (cpp:array-lb array idx)))]
      [(seq:Universe idx)
        (cpp:Define cpp:index_t (cpp:universe-idx-var idx) (cpp:Constant 0))]
      [(seq:Union a b) (cpp:Pair (init a initset) (init b initset))]
      [(seq:Intersect a b) (cpp:Pair (init a initset) (init b initset))]

      [(seq:Product a b)
        (if (and (seq:is-coordinate? a) (seq:is-coordinate? b))
          (init a initset)
          (cpp:Pair
            (cpp:Pair (init a initset) (init b initset))
            (cpp:While (cpp:And (valid a) (cpp:Not (valid b)))
              (cpp:Pair (_next a) (reset b)))))]
      [(seq:Concatenate a b) (error "TODO: init Concatenate?")]
      [(seq:Project a k I J)
        (if (equal? k 0)
          (init a initset)
          (cpp:Define cpp:cindex_t (make-proj-var k) (eval (seq:Project a 0 I J))))]
      [(seq:Filter a s e r)
        (cpp:Pair
          (init a initset)
          (cpp:While
            (cpp:And (valid a)
                    ; TODO: do CSE, this is gnarly.
                    (if (arith:is-const? 0 s) ; if s is 0, a < 0 is always false.
                      (cpp:Not (cpp:Equals (cpp:Mod (cpp:Sub (eval a) (cpp:from-arith s)) (cpp:from-arith r)) (cpp:Constant 0)))
                      (cpp:Or
                        (cpp:LT (eval a) (cpp:from-arith s))
                        (cpp:Not (cpp:Equals (cpp:Mod (cpp:Sub (eval a) (cpp:from-arith s)) (cpp:from-arith r)) (cpp:Constant 0))))))
            (_next a)))]

      [(seq:Offset s a) (init a initset)]
      [(seq:Pad a s) (init a initset)]

      [_ (error (format "Unrecognized seq:expr in init: ~a" sexpr))]))))

(define (reset sexpr)
  (destruct sexpr
    [(seq:Dim idx array)
      ; key difference with init: don't define! just assign.
      (if (is-coo-level? array idx)
        (error "How to reset a coordinate array?")
        (cpp:Assign (cpp:array-index array idx) (cpp:array-lb array idx)))]
    [(seq:Universe idx)
      (cpp:Assign cpp:index_t (cpp:universe-idx-var idx) (cpp:Constant 0))]
    [(seq:Union a b) (cpp:Pair (reset a) (reset b))]
    [(seq:Intersect a b) (cpp:Pair (reset a) (reset b))]

    [(seq:Product a b)
      (cpp:Pair
        (cpp:Pair (reset a) (reset b))
        (cpp:While (cpp:And (valid a) (cpp:Not (valid b)))
          (cpp:Pair (_next a) (reset b))))]
    [(seq:Concatenate a b) (error "TODO: reset Concatenate?")]
    [(seq:Project a k I J)
      (if (equal? k 0)
        (reset a)
        (cpp:Assign (make-proj-var k) (seq:Project a 0 I J)))]
    [(seq:Filter a s e r) (error "TODO: reset Filter?")]

    [(seq:Offset s a) (reset a)]
    [(seq:Pad a s) (reset a)]

    [_ (error (format "Unrecognized seq:expr in reset: ~a" sexpr))]))

(define (valid sexpr)
  (destruct sexpr
    [(seq:Dim idx array)
      (if (is-coo-level? array idx)
        (let ([i (array-idx-index array idx)]
              [ivalid (cpp:LT (cpp:array-index array (array-descendant array)) (cpp:Variable (format "~a_nnz" (Array-name array))))])
          (if (equal? i 0)
            ivalid
            (let ([pidx (array-idx-parent array idx)])
              (cpp:And ivalid (cpp:Equals (cpp:array-index array pidx) (eval (seq:Dim pidx array)))))))
        (cpp:LT (cpp:array-index array idx) (cpp:array-ub array idx)))]
    [(seq:Universe idx) (cpp:LT (cpp:universe-idx-var idx) (cpp:universe-extent idx))]
    [(seq:Union a b) (cpp:And (valid a) (valid b))]
    [(seq:Intersect a b) (cpp:And (valid a) (valid b))]

    [(seq:Product a b)
      (if (and (seq:is-coordinate? a) (seq:is-coordinate? b))
        (valid a)
        (cpp:And (valid a) (valid b)))]
    [(seq:Concatenate a b) (cpp:And (valid a) (valid b))]
    [(seq:Project a k I J)
      (if (equal? k 0)
        (valid a)
        (cpp:And (valid a) (cpp:Equals (make-proj-var k) (eval (seq:Project a 0 I J)))))]
    [(seq:Filter a s e r) (cpp:And (valid a) (cpp:LT (eval a) (cpp:from-arith e)))]

    [(seq:Offset s a) (valid a)]
    [(seq:Pad a s) (valid a)]

    [_ (error (format "Unrecognized seq:expr in valid: ~a" sexpr))]))

; TODO: need to start upcasting...
(define (eval sexpr)
  (destruct sexpr
    [(seq:Dim idx array) (cpp:access-array-crd array idx)]
    [(seq:Universe idx) (cpp:universe-idx-var idx)]
    [(seq:Union a b) (cpp:Min (eval a) (eval b))]
    [(seq:Intersect a b) (cpp:Min (eval a) (eval b))]

    [(seq:Product a b)
      ; a * |b| + b
      (cpp:Add (cpp:Mul (eval a) (cpp:from-arith (seq:size b))) (eval b))]
    [(seq:Concatenate a b) (error "TODO: eval Concatenate?")]
    [(seq:Project a k I J)
      (let ([eval-a (eval a)])
        (if (equal? k 0)
          (cpp:Div eval-a (cpp:from-arith J))
          (cpp:Mod eval-a (cpp:from-arith J))))]
    [(seq:Filter a s e r) (cpp:Div (cpp:Sub (eval a) (cpp:from-arith s)) (cpp:from-arith r))] ; TODO: is there rounding?

    [(seq:Offset s a) (cpp:Add (cpp:from-arith s) (eval a))]
    [(seq:Pad a s) (eval a)]

    [_ (error (format "Unrecognized seq:expr in eval: ~a" sexpr))]))

(define (next value sexpr)
  (destruct sexpr
    [(seq:Dim idx array)
      ; standard conditional update.
      (if (and (is-coo-level? array idx) (not (equal? idx (array-descendant array))))
        void
        (cpp:IncAssign (cpp:array-index array idx) (cpp:Equals value (eval sexpr))))]
    [(seq:Universe idx)
      (cpp:IncAssign (cpp:universe-idx-var idx) (cpp:Equals value (eval sexpr)))]
    [(seq:Union a b) (cpp:Pair (next value a) (next value b))]
    [(seq:Intersect a b) (cpp:Pair (next value a) (next value b))]

    [(seq:Product a b)
      (if (and (seq:is-coordinate? a) (seq:is-coordinate? b))
        (next value b)
        ; TODO: is there a better way than doing this remapping here?
        ; Also should probably have a make-if helper, this is ugly.
        (cpp:IfBlock
          (list
            (cons
              (cpp:Equals value (eval sexpr))
              (cpp:Pair
                (_next b)
                (cpp:While (cpp:And (valid a) (cpp:Not (valid b)))
                  (cpp:Pair (_next a) (reset b))))))))]
    [(seq:Concatenate a b) (error "TODO: next Concatenate?")]
    [(seq:Project a k I J) (error "TODO: next Project?")]
    [(seq:Filter a s e r) (error "TODO: next Filter?")]

    [(seq:Offset s a) (next (cpp:Sub value (cpp:from-arith s)) a)]
    [(seq:Pad a s) (next value a)]

    [_ (error (format "Unrecognized seq:expr in next: ~a" sexpr))]))

; unconditional next.
(define (_next sexpr)
  (destruct sexpr
    [(seq:Dim idx array)
      ; unconditional update
      (if (and (is-coo-level? array idx) (not (equal? idx (array-descendant array))))
        void
        (cpp:IncAssign (cpp:array-index array idx) (cpp:Constant 1)))]
    [(seq:Universe idx)
      (cpp:IncAssign (cpp:universe-idx-var idx) (cpp:Constant 1))]
    [(seq:Union a b) (cpp:Pair (_next a) (_next b))]
    [(seq:Intersect a b) (cpp:Pair (_next a) (_next b))]

    [(seq:Product a b)
      (if (and (seq:is-coordinate? a) (seq:is-coordinate? b))
        (_next b)
        (cpp:Pair
          (_next b)
          (cpp:While (cpp:And (valid a) (cpp:Not (valid b)))
            (cpp:Pair (_next a) (reset b)))))]
    [(seq:Concatenate a b) (error "TODO: _next Concatenate?")]
    [(seq:Project a k I J)
      (if (equal? k 0)
        (cpp:While (cpp:And (valid a) (cpp:Equals (make-proj-var 1) (eval sexpr)))
          (_next a))
        (_next a))]
    [(seq:Filter a s e r)
      (cpp:Pair
        (_next a)
        (cpp:While (cpp:And (valid a) (cpp:Not (cpp:Equals (cpp:Mod (cpp:Sub (eval a) (cpp:from-arith s)) (cpp:from-arith r)) (cpp:Constant 0))))
          (_next a)))]

    [(seq:Offset s a) (_next a)]
    [(seq:Pad a s) (_next a)]

    [_ (error (format "Unrecognized seq:expr in _next: ~a" sexpr))]))

(define (equals value sexpr)
  ; TODO: should this just be
  ; (cpp:Equals value (eval sexpr))
  ; only if no intersections or unions...?
  ; or is it just unions?
  (destruct sexpr
    [(seq:Dim idx array)
      ; (cpp:Equals value (cpp:array-index array idx))]
      (cpp:Equals value (eval sexpr))]
    [(seq:Universe idx) (cpp:Equals value (cpp:universe-idx-var idx))]
    [(seq:Union a b) (cpp:And (equals value a) (equals value b))]
    [(seq:Intersect a b) (cpp:And (equals value a) (equals value b))]

    [(seq:Product a b)
      (if (or (seq:contains-intersect/union? a) (seq:contains-intersect/union? b))
        (cpp:And (equals (cpp:Div value (cpp:seq-size b)) a) (equals (cpp:Mod value (cpp:seq-size b)) b))
        (cpp:Equals value (eval sexpr)))]
    [(seq:Concatenate a b) (error "TODO: equals Concatenate? should not happen.")]
    [(seq:Project a k I J)
      (if (seq:contains-intersect/union? a)
        ; Need to recursively evaluate equality for projection.
        (error "Need to implement equals(proj(a \\cup b))")
        (cpp:Equals value (eval sexpr)))]
    ; TODO: investigate: Add and Mul is cheap, doing eval(filter) will perform a Div which is expensive!
    [(seq:Filter a s e r)
      (if (seq:contains-intersect/union? a)
        (equals (cpp:Add (cpp:Mul value (cpp:from-arith r)) (cpp:from-arith s)) a)
        (cpp:Equals value (eval sexpr)))]
    [(seq:Offset s a)
      (if (seq:contains-intersect/union? a)
        (equals (cpp:Sub value (cpp:from-arith s)) a)
        (cpp:Equals value (eval sexpr)))]
    [(seq:Pad a s) (equals value a)]

    [_ (error (format "Unrecognized seq:expr in equals: ~a" sexpr))]))

; TODO: need to start upcasting...
(define (locate value sexpr [define? #f])
(destruct sexpr
    [(seq:Dim idx array)
      (if define?
        (cpp:Define cpp:index_t (cpp:array-index array idx) value)
        (cpp:Assign (cpp:array-index array idx) value))]
    [(seq:Universe idx) void] ; I don't think this is ever needed?
    [(seq:Union a b) (cpp:Block (list (locate value a define?) (locate value b define?)))]
    [(seq:Intersect a b) (cpp:Block (list (locate value a define?) (locate value b define?)))]

    [(seq:Product a b)
      (let ([bsize (cpp:from-arith (seq:size b))])
        (cpp:Block (list (locate (cpp:Div value bsize) a define?) (locate (cpp:Mod value bsize) b define?))))]
    [(seq:Concatenate a b) (error "TODO: locate Concatenate? should not happen.")]
    [(seq:Project a k I J)
      (if (equal? k 0)
        (locate (cpp:Mul value (cpp:from-arith J)) a define?)
        (locate (cpp:Add (cpp:Mul (eval (seq:Project a 0 I J)) (cpp:from-arith J)) value) a define?))]
    [(seq:Filter a s e r) (locate (cpp:Add (cpp:Mul value (cpp:from-arith r)) (cpp:from-arith s)) a define?)]

    [(seq:Offset s a) (locate (cpp:Sub value (cpp:from-arith s)) sexpr define?)]
    ; TODO: what if value is > |a|? can that ever happen?
    [(seq:Pad a s) (locate value sexpr define?)]

    [_ (error (format "Unrecognized seq:expr in locate: ~a" sexpr))]))

