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
        return burrito.coo_split_cv64to32(matrix, N, M)
    else:
        return burrito.coo_split_cv(matrix, N, M)

def process_scipy(matrix):
    return [process_matrix(matrix)]

def f_scipy(matrix):
    return matrix.reshape(N, M)

def process_pydata(matrix):
    return [sparse.GCXS.from_scipy_sparse(matrix).reshape((matrix.shape[0] * matrix.shape[1],))]

def f_pydata(matrix):
    return matrix.reshape((N, M)).asformat("coo")

def f_equals(b, s, p):
    b = utils.from_burrito_array(b)
    p = p.to_scipy_sparse()
    # print(b.format, s.format, p.format)
    # print((b != s).nnz, (p != s).nnz)
    return (b.format == s.format) and (p.format == s.format) and \
           ((b != s).nnz == 0) and ((p != s).nnz == 0)

if __name__ == "__main__":
    tests = [
        tester.Tester("coo_slice_cv", "csr", process_burr, f_burrito, process_scipy, f_scipy, process_pydata, f_pydata, f_equals),
    ]

    tester.run_partition(10, 0, 1, tests)
