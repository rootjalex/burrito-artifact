import scipy
import sparse
import math
import numpy as np

import utils
import tester

import sys
import paths
sys.path.append(paths.BURRITO_PATH)
import burrito

sN, eN, rN = 0, 0, 0

def split_matrix(matrix):
    global sN, eN, rN
    sN, eN, rN = 0, (matrix.shape[0] + 1) // 2, 2
    a = matrix[:, :-2]
    b = matrix[sN:eN:rN, 2:]
    # print(a.shape, b.shape, a[sN:eN:rN, :].shape)
    assert(b.shape == a[sN:eN:rN, :].shape)
    return a, b

def process_burr(matrix):
    m0, m1 = split_matrix(matrix)
    return (utils.to_burrito_array(m0), utils.to_burrito_array(m1))

def f_burrito(m0, m1):
    return burrito.csr_slice_1d_csr_mul_csr(m0, m1, sN, eN, rN)

def process_burr_unfused(matrix):
    return process_burr(matrix)

def f_burr_unfused(m0, m1):
    return burrito.csr_slice_1d_csr_mul_csr_unfused(m0, sN, eN, rN, m1)

def process_scipy(matrix):
    return split_matrix(matrix)

def f_scipy(m0, m1):
    return m0[sN:eN:rN, :].multiply(m1)

def f_equals(b, s, p):
    # print(b, s, p)
    b = utils.from_burrito_array(b)
    p = utils.from_burrito_array(p)
    return (b.format == s.format) and (p.format == s.format) and \
           ((b != s).nnz == 0) and ((p != s).nnz == 0)

if __name__ == "__main__":
    tests = [
        tester.Tester("csr_slice_1d_csr_mul_csr", "csr", process_burr, f_burrito, process_scipy, f_scipy, process_burr_unfused, f_burr_unfused, f_equals),
    ]

    tester.run_partition(10, 0, 1, tests)
    # tester.run_matrix_test(10, ???, tests)
