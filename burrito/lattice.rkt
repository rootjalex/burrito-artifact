#lang racket

(require
  (only-in racket/base error)
  racket/hash
  rosette/lib/destruct
  "seq.rkt"
;   graph
)

(provide Lattice (prefix-out lattice: construct) (prefix-out lattice: print) (prefix-out lattice: tsort) (prefix-out lattice: sub-points))

; A lattice is just a top node and a hash map of edges
; graph maps a seq:expr to a pair: (edge, simplified)
(struct Lattice (top graph) #:transparent)

(define (print lattice)
  (pprint (Lattice-top lattice) (Lattice-graph lattice) (mutable-set) "  "))

(define (pprint sexpr graph visited indent)
  (cond
    [(set-member? visited sexpr) ""]
    [(seq:is-empty-seq? sexpr) ""]
    [else
      (set-add! visited sexpr)
      (let* ([children (hash-ref graph sexpr)]
             [edges (string-join (map (lambda (se) (string-append indent (seq:print (car se)) " -- " (seq:print (cdr se)))) children) "\n")]
             [recurse (map (lambda (se) (pprint (cdr se) graph visited indent)) children)])
        (format "~a -> {\n~a\n}~a\n" (seq:print sexpr) edges (string-join recurse "\n")))]))
    ;   (format "~a-> {\n~a\n~a}"
    ;     indent
    ;     (string-join (map (lambda (se) (string-append (seq:print (car se)) " -- " (seq:print (cdr se)) (pprint (cdr se) graph visited (string-append indent "  ")))) (hash-ref graph sexpr)) "\n")
    ;     indent)]))

(define (add-child! edges child)
  (hash-union!
    edges child
    #:combine append))

(define (construct-graph sexpr defs visited)
;   (displayln (format "constructing: ~a" (seq:print sexpr)))
  (if (or (seq:is-empty-seq? sexpr) (set-member? visited sexpr)) (make-hash)
    (let ([top (seq:handle-concat sexpr)]
          [es (seq:edges sexpr)]
          [graph (make-hash)])
    ;   (displayln (format "Edges: ~a" (set-map es seq:print)))
      (set-add! visited sexpr)
      (let ([pairs
              (for/list ([e es])
                (let* ([r (seq:remove sexpr e)]
                       [s (seq:simplify r defs)]
                      ;  [_ (displayln (format "remove ~a from ~a -> ~a -> ~a" (seq:print e) (seq:print sexpr) (seq:print r) (seq:print s)))]
                       [child (construct-graph s defs visited)])
                  (add-child! graph child)
                  (cons e s)))])
          (add-child! graph (make-hash (list (cons top pairs))))
          graph))))

(define (construct sexpr defs)
  (let ([top (seq:handle-concat sexpr)])
    (Lattice top (construct-graph sexpr defs (mutable-set)))))

; (require mischief/sort)

; (require graph)

(define (tsort lattice)
  (reverse (tsort-helper (Lattice-top lattice) (Lattice-graph lattice) (mutable-set))))

(define (tsort-helper node graph visited)
  (cond
    [(set-member? visited node) '()]
    [(seq:is-empty-seq? node) '()]
    [else
      (set-add! visited node)
      (append
        (apply append
          (map
            (lambda (p) (tsort-helper (cdr p) graph visited))
            (hash-ref graph node)))
        (list node))]))

(define (sub-points lattice point)
  (let ([subs (tsort-helper point (Lattice-graph lattice) (mutable-set))]
        [iters (seq:iters point)])
    (reverse (filter (lambda (p) (subset? (seq:iters p) iters)) subs))))
