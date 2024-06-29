#lang racket

(require
  (only-in racket/base error)
  (only-in racket/struct)
  rosette/lib/destruct
  "arith.rkt"
  "array.rkt"
  "cpp-lang.rkt"
  "expr.rkt"
  "format.rkt"
  "index.rkt"
  "seq.rkt"
)

(provide (prefix-out cpp: (all-defined-out)))

(define (make-cpp-idx idx)
  (cpp:Variable (idx-name idx)))


(define (from-arith expr)
  (destruct expr
    [(arith:Constant val) (cpp:Constant val)]
    [(arith:Variable name) (cpp:Variable name)]
    [(arith:Add a b) (cpp:Add (from-arith a) (from-arith b))]
    [(arith:Mul a b) (cpp:Mul (from-arith a) (from-arith b))]
    [(arith:Sub a b) (cpp:Sub (from-arith a) (from-arith b))]
    [(arith:Div a b) (cpp:Div (from-arith a) (from-arith b))]
    [_ (error (format "Unrecognized arith:expr in cpp:from-arith: ~a" expr))]))


(define (from-expr expr)
  (destruct expr
    [(Read array) (codegen-array-access array)]
    [(Add a b) (cpp:Add (from-expr a) (from-expr b))]
    [(Mul a b) (cpp:Mul (from-expr a) (from-expr b))]

    [(Concat a b i j k) (error (format "TODO: implement cpp:from-expr for concat: ~a" (expr:print expr)))]
    
    [_ (if (equal? 1 expr) (cpp:Constant 1) (error (format "Unrecognized expr in cpp:from-expr: ~a" expr)))]))

; TODO: clean this up with array.rkt
(define (array-stepper-name array idx)
  (format
    (if (is-dense-level? array idx)
      "~a_~a"
      "~ap_~a")
    (idx-name idx) (Array-name array)))

(define (array-index array idx)
  (cpp:Variable (array-stepper-name array idx)))

(define (array-lb array idx)
  (let ([level (array-idx-format array idx)])
    (cond
      [(eqv? level Dense) (cpp:Constant 0)]
      [(eqv? level Compressed)
        (let ([i (array-idx-index array idx)])
          (if (equal? 0 i)
            (cpp:Access (cpp:Variable (format "~a_pos" (Array-name array))) (cpp:Constant 0))
            (let ([pidx (array-idx-parent array idx)])
              (cpp:Access (cpp:Variable (get-level-name array pidx)) (array-index array pidx)))))]
      [else (error (format "TODO: implement lower bound for array level: ~a" level))])))

(define (array-index-size array idx)
  (cpp:Variable (format "~a~a" (string-upcase (idx-name idx)) (Array-name array))))

(define (array-ub array idx)
  (let ([level (array-idx-format array idx)])
    (cond
      [(eqv? level Dense) (array-index-size array idx)]
      [(eqv? level Compressed)
        (let ([i (array-idx-index array idx)])
          (if (equal? 0 i)
            (cpp:Access (cpp:Variable (format "~a_pos" (Array-name array))) (cpp:Constant 1))
            (let ([pidx (array-idx-parent array idx)])
              (cpp:Access (cpp:Variable (get-level-name array pidx)) (cpp:Add (array-index array pidx) (cpp:Constant 1))))))]
      [else (error (format "TODO: implement upper bound for array level: ~a" level))])))

(define (access-array-crd array idx)
  (let ([level (array-idx-format array idx)])
    (cond
      [(eqv? level Dense) (array-index array idx)]
      [(eqv? level Compressed)
        (cpp:Access
            (cpp:Variable (get-level-name array idx))
          (array-index array idx))]
      [(eqv? level Coordinate)
        (cpp:Access
          (cpp:Variable (get-level-name array idx))
          (array-index array (array-descendant array)))]
      [else (error (format "TODO: implement access crd for array level: ~a" level))])))

(define (universe-idx-var idx)
  (cpp:Variable (string-append "U_" (idx-name idx))))

(define (universe-extent idx)
  (from-arith (idx-size idx)))

(define (seq-size sexpr)
  (from-arith (seq:size sexpr)))

(define (read-array-idx array)
  (define (read-array-idx-rec idxs array)
    (cond
      [(null? idxs) (cpp:Constant 0)]
      [(eqv? Dense (array-idx-format array (car idxs)))
        (let ([size (from-arith (idx-size (car idxs)))])
          (cpp:Add (cpp:Mul (read-array-idx-rec (cdr idxs) array) size)
                    (cpp:Variable (idx-name (car idxs)))))]
      [(eqv? Compressed (array-idx-format array (car idxs)))
        (array-index array (car idxs))]
      [(eqv? Coordinate (array-idx-format array (car idxs)))
        (array-index array (car idxs))]
      [else (error (format "Unrecognized format in read-array-idx: ~a" (array-idx-format array (car idxs))))]))
  (read-array-idx-rec (reverse (array-idxs array)) array))

(define (codegen-array-access array)
  (if (is-scalar-array? array)
    (cpp:Variable (Array-name array))
    (cpp:Access (cpp:Variable (format "~a_data" (Array-name array)))
                (read-array-idx array))))

(define (compute-nnz expr)
  (destruct expr
    [(Read array) (cpp:Variable (format "~a.nnz" (Array-name array)))]
    [(Add a b) (cpp:Add (compute-nnz a) (compute-nnz b))]
    [(Mul a b) (cpp:Min (compute-nnz a) (compute-nnz b))]

    [(Concat a b i j k) (cpp:Add (compute-nnz a) (compute-nnz b))]

    [_ (error (format "Unrecognized expr in cpp:compute-nnz: ~a" expr))]))
