import scipy
import sparse
import math

import utils
import tester
import numpy as np

import sys
import paths
sys.path.append(paths.BURRITO_PATH)
import burrito

UINT32MAX = 0xFFFFFFFF

N, M = 0, 0

def process_matrix(matrix):
    global N, M
    N, M = matrix.shape
    return matrix.reshape(1, matrix.shape[0] * matrix.shape[1]).tocsr()

def process_burr(matrix):
    matrix = process_matrix(matrix)
    return [utils.csr_to_cvector(matrix)]

def f_burrito(matrix):
    if matrix.size > UINT32MAX:
        # print("big")
        return burrito.csr_split_cv64to32(matrix, N, M)
    else:
        # print("reg")
        return burrito.csr_split_cv(matrix, N, M)

def process_scipy(matrix):
    return [process_matrix(matrix)]

def f_scipy(matrix):
    return matrix.reshape(N, M).tocsr()

def process_pydata(matrix):
    return [sparse.GCXS.from_scipy_sparse(matrix).reshape((matrix.shape[0] * matrix.shape[1],))]

def f_pydata(matrix):
    return matrix.reshape((N, M)).asformat("csr")

def f_equals(b, s, p):
    # print("checking equality...", flush=True)
    # print(b.indices, b.indptr, b.data, flush=True)
    # print(np.all(b.data == s.data), flush=True)
    # print(b.indptr, flush=True)
    # print(s.indptr, flush=True)
    # raise Exception
    # idx = np.where(b.indptr != s.indptr)
    # print(idx)
    # print(b.indptr[:10], s.indptr[:10])
    # print(np.all(b.indptr == s.indptr), flush=True)
    # print(np.all(b.indices == s.indices), flush=True)
    b = utils.from_burrito_array(b)
    # print("here", flush=True)
    p = p.to_scipy_sparse()
    # print("here", flush=True)
    # print(b.format, s.format, p.format, flush=True)
    # print(b.data.dtype, s.data.dtype, flush=True)
    # print((b != s).nnz, flush=True)
    # print((p != s).nnz, flush=True)
    # print(b.)
    # print((b != s).nnz, (p != s).nnz, flush=True)
    return (b.format == s.format) and (p.format == s.format) and \
           ((b != s).nnz == 0) and ((p != s).nnz == 0)

if __name__ == "__main__":
    tests = [
        tester.Tester("csr_split_cv", "csr", process_burr, f_burrito, process_scipy, f_scipy, process_pydata, f_pydata, f_equals),
    ]

    tester.run_partition(10, 0, 1, tests)
    # tester.run_matrix_test(10, ???, tests)

