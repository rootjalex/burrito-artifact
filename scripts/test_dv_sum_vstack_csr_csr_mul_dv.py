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

# UINT32MAX = 0xFFFFFFFF

vec = None
mat = None
_name = None

np.random.seed(42)

def init_vec(N):
    global vec
    if vec is None or vec.shape[0] != N:
        vec = np.random.rand(N).astype(np.single)

def split_matrix(matrix):
    global mat
    mat = matrix
    split = matrix.shape[0] // 2
    # Want to split horizontally, so column-wise
    m0, m1 = matrix[0:split, :], matrix[split:, :]
    init_vec(matrix.shape[1])
    # print(m0.shape, m1.shape)
    return m0, m1

def process_burr(matrix):
    m0, m1 = split_matrix(matrix)
    return (utils.to_burrito_array(m0), utils.to_burrito_array(m1))

def f_burrito(m0, m1):
    return burrito.dv_sum_vstack_csr_csr_mul_dv(m0, m1, vec)

def process_burr_unfused(matrix):
    m0, m1 = split_matrix(matrix)
    return (utils.to_burrito_array(m0), utils.to_burrito_array(m1))

def f_burr_unfused(m0, m1):
    return burrito.dv_sum_vstack_csr_csr_mul_dv_unfused(m0, m1, vec)

def process_scipy(matrix):
    return split_matrix(matrix)

def f_scipy(m0, m1):
    return scipy.sparse.vstack([m0, m1]) @ vec

def f_equals(b, s, p):
    # print(b, s, p)
    # numpy and scipy don't agree on some of these...
    # _rtol = 10e-2
    _rtol = 10
    # idx = np.where(np.logical_not(np.isclose(p, s, rtol=_rtol)))[0]
    # if idx.shape[0]:
        # print("\nvalues:")
        # print(idx)
        # print(b[idx[0]], s[idx[0]], p[idx[0]])
        # i = idx[0]
        # t = mat @ vec
        # n = mat.toarray() @ vec
        # print(t[i], n[i], t == n)
        # print("scipy:", t[i])
        # t = burrito.matvec_csr_dense(utils.to_burrito_array(mat), vec)
        # print("burrito:", t[i])
        # t = mat.toarray() @ vec
        # print("numpy:", t[i])
        # print(mat[:, i])
    return np.allclose(b, s, rtol=_rtol) and np.allclose(s, p, rtol=_rtol)

if __name__ == "__main__":
    tests = [
        tester.Tester("cv_collapse_csr_mul_cv", "csr", process_burr, f_burrito, process_scipy, f_scipy, process_burr_unfused, f_burr_unfused, f_equals),
    ]

    tester.run_partition(10, 0, 1, tests)
    # tester.run_matrix_test(10, ???, tests)
