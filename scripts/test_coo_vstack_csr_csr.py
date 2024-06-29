import scipy
import sparse

import utils
import tester

import sys
import paths
sys.path.append(paths.BURRITO_PATH)
import burrito

def split_matrix(matrix):
    matrix = matrix.tocsr()
    split = matrix.shape[0] // 2
    # Want to split vertically, so row-wise
    m0, m1 = matrix[0:split, :], matrix[split:, :]
    return m0.tocsr(), m1.tocsr()

def process_burr(matrix):
    m0, m1 = split_matrix(matrix)
    return (utils.to_burrito_array(m0), utils.to_burrito_array(m1))

def f_burrito(m0, m1):
    return burrito.coo_vstack_csr_csr(m0, m1)

def process_scipy(matrix):
    return split_matrix(matrix)

def f_scipy(m0, m1):
    return scipy.sparse.vstack([m0, m1], format="coo")

def process_pydata(matrix):
    m0, m1 = split_matrix(matrix)
    return (sparse.GCXS.from_scipy_sparse(m0), sparse.GCXS.from_scipy_sparse(m1))

def f_pydata(m0, m1):
    return sparse.concatenate([m0, m1], axis=0).asformat("coo")

def f_equals(b, s, p):
    # print(b, s, p)
    b = utils.from_burrito_array(b)
    p = p.to_scipy_sparse()
    # print(f"Formats: {b.format}, {p.format}, {s.format}")
    # print(f"nnz: {(b != s).nnz == 0}, {(p != s).nnz == 0}")
    return (b.format == s.format) and (p.format == s.format) and \
           ((b != s).nnz == 0) and ((p != s).nnz == 0)

if __name__ == "__main__":
    tests = [
        tester.Tester("coo_vstack_csr_csr", "csr", process_burr, f_burrito, process_scipy, f_scipy, process_pydata, f_pydata, f_equals),
    ]

    tester.run_partition(10, 0, 1, tests)
    # tester.run_matrix_test(10, "M10PI_n1.mtx", tests)
