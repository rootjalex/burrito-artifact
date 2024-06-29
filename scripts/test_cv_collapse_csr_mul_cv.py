import scipy
import sparse
import math

import utils
import tester

import sys
import paths
sys.path.append(paths.BURRITO_PATH)
import burrito

UINT32MAX = 0xFFFFFFFF

def split_matrix(matrix):
    N, M = matrix.shape[0],  matrix.shape[1]
    a = matrix
    b = matrix.reshape(1, N * M).tocsr()
    # print("before:", a.shape, b.shape)
    temp = b[:, 1:]
    b = scipy.sparse.csr_array((temp.data, temp.indices, temp.indptr), shape=(1, N * M))
    # print("after:", a.shape, b.shape)
    return a, b

def process_burr(matrix):
    m0, m1 = split_matrix(matrix)
    return (utils.to_burrito_array(m0), utils.csr_to_cvector(m1))

def f_burrito(m0, m1):
    if m1.size > UINT32MAX:
        return burrito.cv_collapse_csr_mul_cv32to64(m0, m1)
    else:
        return burrito.cv_collapse_csr_mul_cv(m0, m1)

def process_scipy(matrix):
    return split_matrix(matrix)

def f_scipy(m0, m1):
    return m0.reshape(1, m1.shape[1]).multiply(m1)

def process_burr_unfused(matrix):
    m0, m1 = split_matrix(matrix)
    return (utils.to_burrito_array(m0), utils.csr_to_cvector(m1))

def f_burr_unfused(m0, m1):
    if m1.size > UINT32MAX:
        # print("BIG")
        return burrito.cv_collapse_csr_mul_cv32to64_unfused(m0, m1)
    else:
        # print("REG")
        return burrito.cv_collapse_csr_mul_cv_unfused(m0, m1)

def f_equals(b, s, p):
    # print(b, s, p)
    b = utils.cvector_to_coo(b)
    p = utils.cvector_to_coo(p)
    s = s.tocoo() # this is useless, it's 1D CSR, just for == purposes.
    # print("\n", b.format, s.format, p.format)
    # print((b != s).nnz, (p != s).nnz)
    # print(b.shape, s.shape)
    # print(b.nnz, s.nnz)
    return (b.format == s.format) and (p.format == s.format) and \
           ((b != s).nnz == 0) and ((p != s).nnz == 0)

if __name__ == "__main__":
    tests = [
        tester.Tester("cv_collapse_csr_mul_cv", "csr", process_burr, f_burrito, process_scipy, f_scipy, process_burr_unfused, f_burr_unfused, f_equals),
    ]

    tester.run_partition(10, 0, 1, tests)
    # tester.run_matrix_test(10, ???, tests)

