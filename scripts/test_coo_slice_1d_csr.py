import scipy
import sparse
import math

import utils
import tester

import sys
import paths
sys.path.append(paths.BURRITO_PATH)
import burrito

sN, eN, rN = 0, 0, 0

def process_burr(matrix):
    global sN, eN, rN
    sN, eN, rN = 0, (matrix.shape[0] + 1) // 2, 2
    return [utils.to_burrito_array(matrix)]

def f_burrito(matrix):
    return burrito.coo_slice_1d_csr(matrix, sN, eN, rN)

def process_scipy(matrix):
    return [matrix]

def f_scipy(matrix):
    return matrix[sN:eN:rN, :].tocoo()

def process_pydata(matrix):
    return [sparse.GCXS.from_scipy_sparse(matrix)]

def f_pydata(matrix):
    # print("checking", flush=True)
    # m = matrix[sN:eN:rN, :]
    # print("sliced", flush=True)
    # m = m.asformat("coo")
    # print("tocoo", flush=True)
    # return m
    return matrix[sN:eN:rN, :].asformat("coo")

def f_equals(b, s, p):
    b = utils.from_burrito_array(b)
    p = p.to_scipy_sparse()
    return (b.format == s.format) and (p.format == s.format) and \
           ((b != s).nnz == 0) and ((p != s).nnz == 0)

if __name__ == "__main__":
    tests = [
        tester.Tester("coo_slice_1d_csr", "csr", process_burr, f_burrito, process_scipy, f_scipy, process_pydata, f_pydata, f_equals),
    ]

    tester.run_partition(10, 0, 1, tests)
    # tester.run_matrix_test(10, ???, tests)

