#lang racket

(require
  (only-in racket/base error)
  (only-in racket/struct)
  rosette/lib/destruct
  "arith.rkt"
  "array.rkt"
  "expr.rkt"
  "index.rkt"
)

(provide (prefix-out seq: (all-defined-out)))

(struct Dim (idx array) #:transparent)
(struct Universe (idx) #:transparent)
(struct Union (a b) #:transparent)
(struct Intersect (a b) #:transparent)
(struct Product (a b) #:transparent)
(struct Concatenate (a b) #:transparent)
(struct Project (a k I J) #:transparent)
(struct Filter (a s e r) #:transparent)
(struct Offset (s a) #:transparent)
(struct Pad (a s) #:transparent)

(struct Empty (size) #:transparent)
(struct Full (size) #:transparent)

(define (is-empty-seq? expr)
  (or (Empty? expr) (Full? expr)))

(define (print expr)
  (destruct expr
    [(Dim idx array) (format "~a_~a" (idx-name idx) (Array-name array))]
    [(Universe idx) (format "U_~a" (idx-name idx))]
    [(Union a b) (format "(~a \\cup ~a)" (print a) (print b))]
    [(Intersect a b) (format "(~a \\cap ~a)" (print a) (print b))]

    [(Product a b) (format "(~a \\times ~a)" (print a) (print b))]
    [(Concatenate a b) (format "(~a \\sqcup ~a)" (print a) (print b))]
    [(Project a k I J) (format "\\pi_{~v}(~a, (~a, ~a))" k (print a) (arith:print I) (arith:print J))]
    [(Filter a s e r) (format "~a[~a:~a:~a]" (print a) (arith:print s) (arith:print e) (arith:print r))]

    [(Offset s a) (format "(|~a| + ~a)" (arith:print s) (print a))]
    [(Pad a s) (format "(~a + |~a|)" (print a) (arith:print s))]

    [(Empty _) "empty"]
    [(Full _) "full"]

    [_ (error (format "Unrecognized seq:expr: ~a" expr))]))

(define (derive expr idx)
;   (displayln (format "Deriving idx: ~a from expr: ~a" (idx-name idx) (expr:print expr)))
  (destruct expr
    [(Read array)
      (if (member idx (array-idxs array))
          (Dim idx array)
          ; TODO: is this right...?
        ;   (Universe idx))]
          (error (format "Cannot derive idx: ~a from expr: ~a" (idx-name idx) (expr:print expr))))]
    [(Add a b) (Union (derive a idx) (derive b idx))]
    [(Mul a b) (Intersect (derive a idx) (derive b idx))]
    [(Sum i a) (derive a idx)]
    ; TODO: is this right...?
    ; (error (format "Unexpected sum in seq:derive: ~a" (expr:print expr)))]

    [(Broadcast i a)
      (if (equal? idx i)
        (Universe idx)
        (derive a idx))]
    [(Collapse a i j k)
      (if (equal? idx k)
        (Product (derive a i) (derive a j))
        (derive a idx))]
    [(Concat a b i j k)
      (if (equal? idx k)
        (Concatenate (derive a i) (derive b j))
        (Union (derive a idx) (derive b idx)))]
    [(Split a i j k)
      (cond
        [(equal? idx j) (Project (derive a i) 0 (idx-size j) (idx-size k))]
        [(equal? idx k) (Project (derive a i) 1 (idx-size j) (idx-size k))]
        [else (derive a idx)])]
    [(Slice a i j s e r)
      (if (equal? idx j)
        (Filter (derive a i) s e r)
        (derive a idx))]
    
    [_ (error (format "Unrecognized expr in derive: ~a" expr))]))


(define (remove expr sub)
  (if (equal? expr sub)
    (if (is-dense? expr)
      (Full (size expr))
      (Empty (size expr)))
    (destruct expr
      [(Dim _ _) expr]
      [(Universe _) expr]
      [(Union a b) (Union (remove a sub) (remove b sub))]
      [(Intersect a b) (Intersect (remove a sub) (remove b sub))]

      [(Product a b) (Product (remove a sub) (remove b sub))]
      [(Concatenate a b) (Concatenate (remove a sub) (remove b sub))]
      [(Project a k I J) (Project (remove a sub) k I J)]
      [(Filter a s e r) (Filter (remove a sub) s e r)]

      [(Offset s a) (Offset s (remove a sub))]
      [(Pad a s) (Pad (remove a sub) s)]

      [_ (error (format "Unrecognized seq:expr in remove: ~a" expr))])))

; Helper functions for simplify
(define (iters expr)
  (destruct expr
    [(Dim idx array) (set (cons idx array))]
    [(Universe _) (set)]
    [(Union a b) (set-union (iters a) (iters b))]
    [(Intersect a b) (set-union (iters a) (iters b))]

    [(Product a b) (set-union (iters a) (iters b))]
    [(Concatenate a b) (set-union (iters a) (iters b))] ; TODO: is this right?
    [(Project a k I J) (if (equal? 0 k) (set (cons k a)) (set-add (iters a) (cons k a)))]
    [(Filter a s e r) (iters a)]

    [(Offset s a) (iters a)]
    [(Pad a s) (iters a)]

    [_ (error (format "Unrecognized seq:expr in iters: ~a" expr))]))

(define (is-dense? expr)
  (destruct expr
    [(Dim idx array) (is-dense-level? array idx)]
    [(Universe _) #t]
    [(Union a b) (and (is-dense? a) (is-dense? b))]
    [(Intersect a b) (and (is-dense? a) (is-dense? b))]

    [(Product a b) (and (is-dense? a) (is-dense? b))]
    [(Concatenate a b) (and (is-dense? a) (is-dense? b))] ; TODO: is this right?
    [(Project a k I J) (is-dense? a)]
    [(Filter a s e r) (is-dense? a)]

    [(Offset s a) (is-dense? a)]
    [(Pad a s) (is-dense? a)]

    [_ (error (format "Unrecognized seq:expr in is-dense?: ~a" expr))]))

(define (is-coordinate? expr)
  (destruct expr
    [(Dim idx array) (is-coo-level? array idx)]
    [_ #f]))

(define (size expr)
  (destruct expr
    [(Dim idx array) (idx-size idx)]
    [(Universe idx) (idx-size idx)]
    [(Union a b)
      (let ([asize (size a)] [bsize (size b)])
        (if (equal? asize bsize)
          asize
          (error (format "Unequal sizes in union: ~a versus ~a" (arith:print asize) (arith:print bsize)))))]
    [(Intersect a b)(let ([asize (size a)] [bsize (size b)])
        (if (equal? asize bsize)
          asize
          (error (format "Unequal sizes in intersect: ~a versus ~a" (arith:print asize) (arith:print bsize)))))]

    [(Product a b) (arith:Mul (size a) (size b))]
    [(Concatenate a b) (arith:Add (size a) (size b))]
    [(Project a k I J)
      (cond
        [(equal? k 0) I]
        [(equal? k 1) J]
        [else (error (format "Unrecognized projection: ~a" (print expr)))])]
    [(Filter a s e r) (arith:simplify (arith:Div (arith:Add (arith:Sub e s) (arith:Sub r (arith:Constant 1))) r))]

    [(Offset s a) (arith:Add s (size a))]
    [(Pad a s) (arith:Add s (size a))]

    [(Full sz) sz]
    [(Empty sz) sz]

    [_ (error (format "Unrecognized seq:expr in size: ~a" expr))]))

(define (simplify expr defs)
  (destruct expr
    [(Dim idx array)
      (cond
        [(idx-defined? idx array defs) expr]
        [(is-dense-level? array idx) (Full (idx-size idx))]
        [else (Empty (idx-size idx))])]
    [(Universe idx) expr]
    [(Union a b)
      (let ([x (simplify a defs)] [y (simplify b defs)])
        (cond
          [(Full? x) x]
          [(Full? y) y]
          [(and (Empty? x) (Empty? y)) x]
          [(Empty? x) y]
          [(Empty? y) x]
          [else (Union x y)]))]
    [(Intersect a b)
      (let ([x (simplify a defs)] [y (simplify b defs)])
        (cond
          ; TODO: should these first two be and-ed?
          [(Full? x) x]
          [(Full? y) y]
          [(and (Empty? x) (Empty? y)) x]
          [(and (Empty? x) (is-dense? y)) (Full (Empty-size x))]
          [(and (Empty? y) (is-dense? x)) (Full (Empty-size y))]
          [(Empty? x) x]
          [(Empty? y) y]
          [else (Intersect x y)]))]

    [(Product a b)
      (let ([x (simplify a defs)])
        (cond
          [(and (Full? x) (is-dense? b)) (Full (arith:Mul (size a) (size b)))]
          [(or (Full? x) (Empty? x)) (Empty (arith:Mul (size a) (size b)))]
          [else
            (let* ([new-defs (set-union defs (iters x))]
                   [y (simplify b new-defs)])
              (cond
                [(or (Empty? y) (Full? y))
                  (error (format "Unexpected product simplification: ~a -> ~a \\times ~a" expr x y))]
                ; TODO: more cases?
                [else (Product x y)]))]))]
    [(Concatenate a b)
      (let ([x (simplify a defs)] [y (simplify b defs)])
        (cond
          [(or (Full? x) (Empty? x)) (Offset (size a) y)]
          [(or (Full? y) (Empty? y)) (Pad x (size b))]
          [else (Concatenate x y)]))]
    [(Project a k I J)
      (let ([x (simplify a defs)])
        (cond
          [(Full? x) (Full (size expr))]
          [(Empty? x) (Empty (size expr))]
          [(or (equal? 0 k) (set-member? defs (cons (- k 1) x))) (Project x k I J)]
          [(is-dense? expr) (Full  (if (equal? 0 k) I J))]
          [else (Empty (if (equal? 0 k) I J))]))]
    [(Filter a s e r)
      (let ([x (simplify a defs)])
        (cond
          [(Full? x) (Full (size expr))]
          [(Empty? x) (Empty (size expr))]
          [else (Filter x s e r)]))]

    [(Offset s a)
      (let ([x (simplify a defs)])
        (cond
          [(Full? x) (Full (size expr))]
          [(Empty? x) (Empty (size expr))]
          [else (Offset s x)]))]
    [(Pad a s)
      (let ([x (simplify a defs)])
        (cond
          [(Full? x) (Full (size expr))]
          [(Empty? x) (Empty (size expr))]
          [else (Pad x s)]))]

    [(Empty _) expr]
    [(Full _) expr]

    [_ (error (format "Unrecognized seq:expr in simplify: ~a" expr))]))


(define (edges sexpr)
  (destruct sexpr
    [(Dim _ _) (set sexpr)]
    [(Universe _) (set sexpr)]
    [(Union a b) (set-union (edges a) (edges b))]
    [(Intersect a b) (set-union (edges a) (edges b))]

    [(Product a b) (edges a)]
    [(Concatenate a b) (edges a)] ; TODO: is this right?
    [(Project a k I J) (set-add (edges a) sexpr)]
    [(Filter a s e r) (set-add (edges a) sexpr)]

    [(Offset s a) (edges a)]
    [(Pad a s) (edges a)]

    [_ (error (format "Unrecognized seq:expr in edges: ~a" sexpr))]))

(define (handle-concat expr)
  (destruct expr
    [(Dim _ _) expr]
    [(Universe _) expr]
    [(Union a b) (Union (handle-concat a) (handle-concat b))]
    [(Intersect a b) (Intersect (handle-concat a) (handle-concat b))]

    [(Product a b) (Product (handle-concat a) b)]
    [(Concatenate a b) (Pad (handle-concat a) (size b))] ; TODO: is this right?
    [(Project a k I J) (Project (handle-concat a) k I J)]
    [(Filter a s e r) (Filter (handle-concat a) s e r)]

    [(Offset s a) (Offset s (handle-concat a))]
    [(Pad a s) (Pad (handle-concat a) s)]

    [_ (error (format "Unrecognized seq:expr in handle-concat: ~a" expr))]))

(define (contains-intersect? expr)
  (destruct expr
    [(Dim _ _) #f]
    [(Universe _) #f]
    [(Union a b) (or (contains-intersect? a) (contains-intersect? b))]
    [(Intersect a b) #t]

    [(Product a b) (or (contains-intersect? a) (contains-intersect? b))]
    [(Concatenate a b) (or (contains-intersect? a) (contains-intersect? b))]
    [(Project a k I J) (contains-intersect? a)]
    [(Filter a s e r) (contains-intersect? a)]

    [(Offset s a) (contains-intersect? a)]
    [(Pad a s) (contains-intersect? a)]

    [_ (error (format "Unrecognized seq:expr in contains-intersect?: ~a" expr))]))

(define (contains-intersect/union? expr)
  (destruct expr
    [(Dim _ _) #f]
    [(Universe _) #f]
    [(Union a b) #t]
    [(Intersect a b) #t]

    [(Product a b) (or (contains-intersect/union? a) (contains-intersect/union? b))]
    [(Concatenate a b) (or (contains-intersect/union? a) (contains-intersect/union? b))]
    [(Project a k I J) (contains-intersect/union? a)]
    [(Filter a s e r) (contains-intersect/union? a)]

    [(Offset s a) (contains-intersect/union? a)]
    [(Pad a s) (contains-intersect/union? a)]

    [_ (error (format "Unrecognized seq:expr in contains-intersect/union?: ~a" expr))]))

(define (remove-dense expr)
  (if (is-dense? expr)
    (values 'removed (list expr))
    (destruct expr
      [(Union a b)
        (let-values ([(x x-locs) (remove-dense a)]
                     [(y y-locs) (remove-dense b)])
          (cond
            [(symbol? x) (values y (append x-locs y-locs))]
            [(symbol? y) (values x (append x-locs y-locs))]
            [else (values (Union x y) (append x-locs y-locs))]))]
      [(Intersect a b)
        (let-values ([(x x-locs) (remove-dense a)]
                     [(y y-locs) (remove-dense b)])
          (cond
            [(symbol? x) (values y (append x-locs y-locs))]
            [(symbol? y) (values x (append x-locs y-locs))]
            [else (values (Intersect x y) (append x-locs y-locs))]))]
      [_ (values expr (list))])))

(define (build-pairs l v)
  (map (lambda (c) (cons v c)) l))

; returns two items: re-written expr, list of assocs
(define (find-locators expr)
  (destruct expr
    [(Dim _ _) (values expr (list))]
    [(Universe idx) (values expr (list))]
    [(Union a b)
      (let-values ([(a-expr a-locs) (find-locators a)]
                   [(b-expr b-locs) (find-locators b)])
        (cond
          [(and (is-dense? a) (is-dense? b))
            ; TODO: return b-expr if simpler than a?
            (values a-expr (append a-locs b-locs (list (cons a-expr b-expr))))]
          ; TODO: other cases?
          [else
            (values (Union a-expr b-expr) (append a-locs b-locs))]))]
    [(Intersect a b)
      (let-values ([(a-expr a-locs) (find-locators a)]
                   [(b-expr b-locs) (find-locators b)])
        (cond
          ; TODO: ordering of evaluation plays a performance difference...
          [(not (is-dense? a))
            ; Use a to locate into b.
            (let-values ([(y y-dense) (remove-dense b-expr)])
              (let* ([ret (if (symbol? y) a-expr (Intersect a-expr y))]
                     [y-locs (build-pairs y-dense ret)])
                (values ret (append a-locs b-locs y-locs))))]
          [(not (is-dense? b))
            ; Use b to locate into a.
            (let-values ([(x x-dense) (remove-dense a-expr)])
              (let* ([ret (if (symbol? x) b-expr (Intersect x b-expr))]
                     [x-locs (map (lambda (c) (cons ret c)) x-dense)])
                (values ret (append a-locs b-locs x-locs))))]
          ; both are dense. weird.
          [else
            (values a-expr (append a-locs b-locs (list (cons a-expr b-expr))))]))]

    [(Product a b)
      (let-values ([(a-expr a-locs) (find-locators a)]
                   [(b-expr b-locs) (find-locators b)])
        (values (Product a-expr b-expr) (append a-locs b-locs)))]
    [(Concatenate a b)
      (let-values ([(a-expr a-locs) (find-locators a)]
                   [(b-expr b-locs) (find-locators b)])
        (values (Concatenate a-expr b-expr) (append a-locs b-locs)))]
    [(Project a k I J)
      (let-values ([(a-expr a-locs) (find-locators a)])
        (values (Project a-expr k I J) a-locs))]
    [(Filter a s e r)
      (let-values ([(a-expr a-locs) (find-locators a)])
        (values (Filter a-expr s e r) a-locs))]

    [(Offset s a)
      (let-values ([(a-expr a-locs) (find-locators a)])
        (values (Offset s a-expr) a-locs))]
    [(Pad a s)
      (let-values ([(a-expr a-locs) (find-locators a)])
        (values (Pad a-expr s) a-locs))]

    [_ (error (format "Unrecognized seq:expr in find-locators: ~a" expr))]))

(define (contains? expr sub)
  (if (equal? expr sub)
    #t
    (destruct expr
      [(Dim _ _) #f]
      [(Universe _) #f]
      [(Union a b) (or (contains? a sub) (contains? b sub))]
      [(Intersect a b) (or (contains? a sub) (contains? b sub))]

      [(Product a b) (or (contains? a sub) (contains? b sub))]
      [(Concatenate a b) (or (contains? a sub) (contains? b sub))]
      [(Project a k I J) (contains? a sub)]
      [(Filter a s e r) (contains? a sub)]

      [(Offset s a) (contains? a sub)]
      [(Pad a s) (contains? a sub)]

      [_ (error (format "Unrecognized seq:expr in contains: ~a" expr))])))

(define (filter-locators locs sexpr)
  ; Remove all locators that are not defined by sexpr.
  (filter (lambda (p) (contains? sexpr (car p))) locs))
