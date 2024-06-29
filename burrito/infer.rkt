#lang racket

(require
  (only-in racket/base error)
  racket/set
  rosette/lib/destruct
  "array.rkt"
  "expr.rkt"
  "index.rkt"
)

(provide infer)

(define (infer expr)
  (destruct expr
    [(Read array) (apply set (array-idxs array))]
    [(Add a b)
      (let ([Sa (infer a)] [Sb (infer b)])
        (if (set=? Sa Sb) Sa (error (format "Shapes not equal: ~a + ~a" Sa Sb))))]
    [(Mul a b)
      (let ([Sa (infer a)] [Sb (infer b)])
        (if (set=? Sa Sb) Sa (error (format "Shapes not equal: ~a * ~a" Sa Sb))))]
    [(Sum idx a)
      (let ([Sa (infer a)])
        (if (set-member? Sa idx) (set-remove Sa idx) (error (format "Shape does not contain reduced index: ~a not in ~a" (idx-name idx) Sa))))]

    [(Broadcast idx a)
      (let ([Sa (infer a)])
        (if (set-member? Sa idx) (error (format "Shape contains broadcasted index: ~a in ~a" (idx-name idx) Sa)) (set-add Sa idx)))]
    [(Collapse a i j k)
      (let ([Sa (infer a)])
        (cond
          [(not (set-member? Sa i)) (error (format "Shape does not contain collapsed index: ~a not in ~a" (idx-name i) Sa))]
          [(not (set-member? Sa j)) (error (format "Shape does not contain collapsed index: ~a not in ~a" (idx-name j) Sa))]
          [(set-member? Sa k) (error (format "Shape contains constructed index: ~a in ~a" (idx-name k) Sa))]
          [else (set-add (set-subtract Sa (set i j)) k)]))]
    [(Concat a b i j k)
      (let ([Sa (infer a)] [Sb (infer b)])
        (cond
          [(not (set-member? Sa i)) (error (format "Shape does not contain concated index: ~a not in ~a" (idx-name i) Sa))]
          [(not (set-member? Sb j)) (error (format "Shape does not contain concated index: ~a not in ~a" (idx-name j) Sb))]
          [(not (set=? (set-remove Sa i) (set-remove Sb j))) (error (format "Concated shapes not equal: ~a != ~a" (set-remove Sa i) (set-remove Sb j)))]
          [(set-member? Sa k) (error (format "Shape contains constructed index: ~a in ~a" (idx-name k) Sa))]
          [(set-member? Sb k) (error (format "Shape contains constructed index: ~a in ~a" (idx-name k) Sb))]
          [else (set-add (set-remove Sa i) k)]))]
    [(Split a i j k)
      (let ([Sa (infer a)])
        (cond
          [(not (set-member? Sa i)) (error (format "Shape does not contain split index: ~a not in ~a" (idx-name i) Sa))]
          [(set-member? Sa j) (error (format "Shape contains constructed index: ~a in ~a" (idx-name j) Sa))]
          [(set-member? Sa k) (error (format "Shape contains constructed index: ~a in ~a" (idx-name k) Sa))]
          [else (set-union (set-remove Sa i) (set j k))]))]
    [(Slice a i j _ _ _)
      (let ([Sa (infer a)])
        (cond
          [(not (set-member? Sa i)) (error (format "Shape does not contain sliced index: ~a not in ~a" (idx-name i) Sa))]
          [(set-member? Sa j) (error (format "Shape contains constructed index: ~a in ~a" (idx-name j) Sa))]
          [else (set-add (set-remove Sa i) j)]))]

    [_ (error (format "Unrecognized expr in infer: ~a" expr))]))
