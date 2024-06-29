#lang racket

(require
  (only-in racket/base error)
  (only-in racket/struct)
  rosette/lib/destruct
  "array.rkt"
  "cin.rkt"
  "expr.rkt"
  "index.rkt"
  "lattice.rkt"
  "seq.rkt"
)

(provide (rename-out [_codegen cfir:codegen] [print cfir:print]
                     [repl-assign-with-incr cfir:repl-assign-with-incr]
                     [Loop cfir:Loop] [Pair cfir:Pair]
                     [Switch cfir:Switch] [Switch? cfir:Switch?]
                     [Update cfir:Update] [Update? cfir:Update?]
                     [Allocate cfir:Allocate]
                     [Assign cfir:Assign] [Reduce cfir:Reduce]))

(struct Loop (idx sexpr locs body) #:transparent)
(struct Pair (body0 body1) #:transparent)
(struct Switch (idx cases) #:transparent)
; Write idx to array after body
; TODO: sparse vs. dense updates!
(struct Update (body array idx) #:transparent)
; Wrapped allocate for Where compilation.
(struct Allocate (array body) #:transparent)
(struct Assign (array rhs) #:transparent)
(struct Reduce (array rhs) #:transparent)

(define (print stmt)
  (pprint stmt ""))

(define (pprint stmt indent)
  ; (displayln (format "pprinting: ~a" stmt))
  (destruct stmt
    [(Loop idx sexpr locs body)
      (let ([str-body (pprint body (string-append indent "  "))]
            [str-locs (string-join (map (lambda (p) (format "~a = ~a" (seq:print (car p)) (seq:print (cdr p))) ) locs) " ")])
        (if (not (empty? locs))
          (format "~awhile ~a <- ~a with ~a\n~a" indent (idx-name idx) (seq:print sexpr) str-locs str-body)
          (format "~awhile ~a <- ~a\n~a" indent (idx-name idx) (seq:print sexpr) str-body)))]
    [(Pair b0 b1) (format "~a;\n~a" (pprint b0 indent) (pprint b1 indent))]
    [(Switch idx cases)
      (format "~aswitch ~a\n~a" indent (idx-name idx)
        (let ([next-indent (string-append indent "  ")])
          (string-join
            (map
              (lambda (c)
                (format "~acase ~a:\n~a" next-indent (seq:print (car c)) (pprint (cdr c) (string-append next-indent "  "))))
              cases)
            "\n")))]
    [(Update body array idx)
      (format "~a{\n~a\n~a} update ~a ~a" indent (pprint body (string-append indent "  ")) indent (Array-name array) (idx-name idx))]
    [(Allocate array body)
      (format "~aallocate ~a {\n~a\n~a}" indent (print-array-access array) (pprint body (string-append indent "  ")) indent)]

    [(Assign array rhs)
      (format "~a~a = ~a" indent (print-array-access array) (expr:print rhs))]
    [(Reduce array rhs)
      (format "~a~a += ~a" indent (print-array-access array) (expr:print rhs))]

    [_ (error (format "Unrecognized stmt in cfir:print: ~a" stmt))]))


(define (_codegen stmt)
  (codegen stmt (set)))

(define (codegen stmt defs)
  (destruct stmt
    [(cin:ForAll idx sexpr body)
      (let ([new-sexpr (seq:simplify sexpr defs)])
        (cg-forall idx new-sexpr body defs))]
    [(cin:Pair b0 b1) (Pair (codegen b0 defs) (codegen b1 defs))]
    [(cin:Where t p c)
      ; TODO: does this change defs at all?
      (Allocate t
        (Pair (codegen p defs) (codegen c defs)))]
    [(cin:Assign array rhs) (Assign array rhs)]
    [(cin:Reduce array rhs) (Reduce array rhs)]

    [_ (error (format "Unrecognized cin:stmt in cfir:codegen: ~a" stmt))]))

(require racket/pretty)

(define (cg-forall idx _sexpr body defs)
  (define-values (sexpr locs) (seq:find-locators _sexpr))
  (let* ([lattice (lattice:construct sexpr defs)]
        ;  [_ (displayln (format "sexpr: ~a" (seq:print sexpr)))]
        ;  [_ (displayln (format "locs: ~a" (pretty-print locs)))]
        ;  [_ (displayln (format "Lattice: ~a" (lattice:print lattice)))]
         [points (lattice:tsort lattice)]
         ; TODO: filter locs based on point?
         [build (lambda (point) (cg-loop idx point lattice body defs locs))]
         [bodies (map build points)]
         [written-array (cin:get-written-array body)]
         [body (foldr (lambda (a acc) (Pair acc a)) (car bodies) (cdr bodies))])
    ; remove Update if this is a reduction loop or iterates over a dense thing.
    ; TODO: inner-loop update can be simplified for dense _sexpr too...
    (if (and
          (is-array-idx? written-array idx)
          (not (seq:is-dense? _sexpr))
          ; (void? (displayln (format "here (0): ~a -> ~a" idx written-array)))
          (not (array-last-idx? written-array idx)))
      (Update body written-array idx)
      body)))

(define (cg-loop idx point lattice body defs _locs)
  (let* ([locs (seq:filter-locators _locs point)]
         [locs-defs (if (not (empty? locs)) (apply set-union (map (lambda (p) (seq:iters (cdr p))) locs)) (set))]
         [make-new-defs (lambda (sp) (set-union defs (seq:iters sp) locs-defs))]
         [build
           (lambda (sp)
             (let ([new-defs (make-new-defs sp)])
               (cons sp (codegen (cin:simplify body new-defs) new-defs))))]
         [sub-points (lattice:sub-points lattice point)]
         [bodies (map build sub-points)]
         [switch
           (if (or (> (length sub-points) 1) (seq:contains-intersect? point))
             (Switch idx bodies)
             (cdr (first bodies)))])
    (Loop idx point locs switch)))


(define (repl-assign-with-incr stmt name)
  ; (displayln (format "pprinting: ~a" stmt))
  (destruct stmt
    [(Loop idx sexpr locs body)
      (Loop idx sexpr locs (repl-assign-with-incr body name))]
    [(Pair b0 b1)
      (Pair (repl-assign-with-incr b0 name) (repl-assign-with-incr b1 name))]
    [(Switch idx cases)
      (Switch idx (map (lambda (p) (cons (car p) (repl-assign-with-incr (cdr p) name))) cases))]
    ; remove updates
    [(Update body array idx) (repl-assign-with-incr body name)]
    ; remove any allocations!
    [(Allocate array body) (repl-assign-with-incr body name)]
    [(Assign array rhs) (Reduce (make-scalar-array name) 1)]
    ; remove reductions as well!
    [(Reduce array rhs) void]

    [_ (error (format "Unrecognized stmt in cfir:print: ~a" stmt))]))

