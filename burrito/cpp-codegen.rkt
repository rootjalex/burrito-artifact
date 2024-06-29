#lang racket

(require
  (only-in racket/base error)
  (only-in racket/struct)
  rosette/lib/destruct
  "array.rkt"
  "cfir.rkt"
  "cpp-lang.rkt"
  "iterator.rkt"
  "cpp-utils.rkt"
  "index.rkt"
  "seq.rkt"
)

(provide (prefix-out cpp: (all-defined-out)))


; TODO: loop over sparse output needs to end write to compressed.
(define (codegen stmt initset out)
  (destruct stmt
    ; TODO: may need to update output index data structures.
    [(cfir:Loop idx sexpr locs body)
      (let* ([inits (iterator:init sexpr initset)]
             [loop-body
              (cpp:While (iterator:valid sexpr)
                (cpp:make-block
                  (cpp:Define cpp:cindex_t (cpp:make-cpp-idx idx) (iterator:eval sexpr))
                  ; update write for sparse intervals.
                  (if (and out (is-array-idx? out idx) (not (array-last-idx? out idx)) (not (seq:is-dense? sexpr)))
                    (let ([cidx (array-idx-child out idx)])
                      (if (is-cmp-level? out cidx)
                        (codegen-parent-update out idx)
                        void))
                    void)
                  (cpp:Block (map codegen-locator locs))
                  (codegen body (set-copy initset) out)
                  ; for dense iterations, we want to update the write here, not above.
                  (if (and out (is-array-idx? out idx) (not (array-last-idx? out idx)) (seq:is-dense? sexpr))
                    (let ([cidx (array-idx-child out idx)])
                      (if (is-cmp-level? out cidx)
                        (codegen-parent-single-update out idx)
                        void))
                    void)
                  ; If the body is not a switch, no conditions are checked,
                  ; so perform unconditional next.
                  ; TODO: generate for loops when possible!
                  (if (cfir:Switch? body)
                    (iterator:next (cpp:make-cpp-idx idx) sexpr)
                    (iterator:_next sexpr))))])
        (if (void? inits) loop-body (cpp:Pair inits loop-body)))]
    [(cfir:Pair b0 b1) (cpp:Pair (codegen b0 initset out) (codegen b1 initset out))]
    [(cfir:Switch idx cases)
      (cpp:IfBlock
        (map
          (lambda (c)
            (cons
              (iterator:equals (cpp:make-cpp-idx idx) (car c))
              (codegen (cdr c) (set-copy initset) out)))
          cases))]
    [(cfir:Update body array idx)
      ; idx is not the last array idx.
      ; if child is sparse, need to update parent.
      (let ([cidx (array-idx-child array idx)]
            [_body (codegen body initset out)])
        (if (is-cmp-level? array cidx)
          (cpp:Pair _body (codegen-final-update array idx))
          _body))]
    [(cfir:Allocate array body)
      (if (is-scalar-array? array)
        (cpp:Pair
          (cpp:Define cpp:value_t (cpp:Variable (Array-name array)) (cpp:Constant 0))
          (codegen body initset out))
        (error (format "TODO: handle non-scalar cfir:Allocate: ~a" (cfir:print stmt))))]

    [(cfir:Assign array rhs)
      (cpp:Block
        (append
          ; Must write to any compressed dimensions.
          (codegen-index-writes-list array)
          ; Perform assignment/compute.
          (list (cpp:Assign (cpp:codegen-array-access array) (cpp:from-expr rhs)))
          ; Update compressed iterators.
          (codegen-index-increment-list array)))]
    [(cfir:Reduce array rhs)
      (if (is-scalar-array? array)
        (cpp:IncAssign (cpp:codegen-array-access array) (cpp:from-expr rhs))
        (error (format "TODO: handle non-scalar cfir:Reduce: ~a" (cfir:print stmt))))]

    [void void]
    [_ (error (format "Unrecognized stmt in cpp:codegen: ~a" stmt))]))

(define (codegen-index-writes-list array)
  (let* ([idxs (array-idxs array)]
         [non-dense (filter (lambda (idx) (not (is-dense-level? array idx))) idxs)]
         [idx-writes (map (lambda (idx) (codegen-index-write array idx)) non-dense)])
    idx-writes))

(define (codegen-index-write array idx)
  (cpp:Assign (cpp:access-array-crd array idx) (cpp:Variable (idx-name idx))))

(define (codegen-index-increment-list array)
  (if (is-scalar-array? array)
    '()
    (let* ([idxs (array-idxs array)]
           [last-idx (last idxs)])
      (if (is-dense-level? array last-idx)
        '()
        (list
          ; TODO: does this only work for compressed?
          ; need to make sure this works for COO as well.
          (cpp:IncAssign (cpp:array-index array last-idx) (cpp:Constant 1)))))))

(define (codegen-locator loc)
  ; syntax is a, b for b = eval(a)
  (iterator:locate (iterator:eval (car loc)) (cdr loc) #t))

(define (codegen-parent-update array idx)
  (cpp:For (cpp:array-index array idx) #f
           (cpp:Variable (idx-name idx))
           (cpp:Constant 1)
    (cpp:Assign (cpp:Access (cpp:Variable (get-level-name array idx)) (cpp:Add (cpp:array-index array idx) (cpp:Constant 1)))
                (cpp:array-index array (array-idx-child array idx)))))

(define (codegen-parent-single-update array idx)
  (cpp:Pair
    (cpp:IncAssign (cpp:array-index array idx) (cpp:Constant 1))
    (cpp:Assign (cpp:Access (cpp:Variable (get-level-name array idx)) (cpp:array-index array idx))
                (cpp:array-index array (array-idx-child array idx)))))

(define (codegen-final-update array idx)
  (cpp:For (cpp:array-index array idx) #f
           (cpp:Variable (string-upcase (idx-name idx)))
           (cpp:Constant 1)
    (cpp:Assign (cpp:Access (cpp:Variable (get-level-name array idx)) (cpp:Add (cpp:array-index array idx) (cpp:Constant 1)))
                (cpp:array-index array (array-idx-child array idx)))))

