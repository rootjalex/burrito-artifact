import tester
import sys

# Comparison to handwritten kernels
import test_cv_collapse_coo
import test_coo_hstack_coo_coo
import test_coo_vstack_coo_coo
import test_csr_hstack_csr_csr
import test_csr_vstack_csr_csr
import test_csr_slice_1d_csr
# Portability kernels
import test_coo_split_cv
import test_csr_split_cv
import test_csr_hstack_coo_coo
import test_coo_vstack_csr_csr
import test_coo_hstack_csr_csr
import test_coo_slice_1d_csr
# Fusion benchmarks
import test_cv_collapse_csr_mul_cv
import test_dv_sum_vstack_csr_csr_mul_dv
import test_csr_slice_1d_csr_mul_csr

if __name__ == "__main__":
    assert(len(sys.argv) == 3)
    _, k, m = sys.argv
    k = int(k)
    m = int(m)

    tests = [
        # handwritten
        tester.Tester("cv_collapse_coo", "coo", test_cv_collapse_coo.process_burr, test_cv_collapse_coo.f_burrito, test_cv_collapse_coo.process_scipy, test_cv_collapse_coo.f_scipy, test_cv_collapse_coo.process_pydata, test_cv_collapse_coo.f_pydata, test_cv_collapse_coo.f_equals),
        tester.Tester("coo_hstack_coo_coo", "csr", test_coo_hstack_coo_coo.process_burr, test_coo_hstack_coo_coo.f_burrito, test_coo_hstack_coo_coo.process_scipy, test_coo_hstack_coo_coo.f_scipy, test_coo_hstack_coo_coo.process_pydata, test_coo_hstack_coo_coo.f_pydata, test_coo_hstack_coo_coo.f_equals),
        tester.Tester("coo_vstack_coo_coo", "csr", test_coo_vstack_coo_coo.process_burr, test_coo_vstack_coo_coo.f_burrito, test_coo_vstack_coo_coo.process_scipy, test_coo_vstack_coo_coo.f_scipy, test_coo_vstack_coo_coo.process_pydata, test_coo_vstack_coo_coo.f_pydata, test_coo_vstack_coo_coo.f_equals),
        tester.Tester("csr_hstack_csr_csr", "csr", test_csr_hstack_csr_csr.process_burr, test_csr_hstack_csr_csr.f_burrito, test_csr_hstack_csr_csr.process_scipy, test_csr_hstack_csr_csr.f_scipy, test_csr_hstack_csr_csr.process_pydata, test_csr_hstack_csr_csr.f_pydata, test_csr_hstack_csr_csr.f_equals),
        tester.Tester("csr_vstack_csr_csr", "csr", test_csr_vstack_csr_csr.process_burr, test_csr_vstack_csr_csr.f_burrito, test_csr_vstack_csr_csr.process_scipy, test_csr_vstack_csr_csr.f_scipy, test_csr_vstack_csr_csr.process_pydata, test_csr_vstack_csr_csr.f_pydata, test_csr_vstack_csr_csr.f_equals),
        tester.Tester("csr_slice_1d_csr", "csr", test_csr_slice_1d_csr.process_burr, test_csr_slice_1d_csr.f_burrito, test_csr_slice_1d_csr.process_scipy, test_csr_slice_1d_csr.f_scipy, test_csr_slice_1d_csr.process_pydata, test_csr_slice_1d_csr.f_pydata, test_csr_slice_1d_csr.f_equals),

        # portable
        tester.Tester("coo_split_cv", "csr", test_coo_split_cv.process_burr, test_coo_split_cv.f_burrito, test_coo_split_cv.process_scipy, test_coo_split_cv.f_scipy, test_coo_split_cv.process_pydata, test_coo_split_cv.f_pydata, test_coo_split_cv.f_equals),
        tester.Tester("csr_split_cv", "csr", test_csr_split_cv.process_burr, test_csr_split_cv.f_burrito, test_csr_split_cv.process_scipy, test_csr_split_cv.f_scipy, test_csr_split_cv.process_pydata, test_csr_split_cv.f_pydata, test_csr_split_cv.f_equals),
        tester.Tester("csr_hstack_coo_coo", "coo", test_csr_hstack_coo_coo.process_burr, test_csr_hstack_coo_coo.f_burrito, test_csr_hstack_coo_coo.process_scipy, test_csr_hstack_coo_coo.f_scipy, test_csr_hstack_coo_coo.process_pydata, test_csr_hstack_coo_coo.f_pydata, test_csr_hstack_coo_coo.f_equals),
        tester.Tester("coo_vstack_csr_csr", "csr", test_coo_vstack_csr_csr.process_burr, test_coo_vstack_csr_csr.f_burrito, test_coo_vstack_csr_csr.process_scipy, test_coo_vstack_csr_csr.f_scipy, test_coo_vstack_csr_csr.process_pydata, test_coo_vstack_csr_csr.f_pydata, test_coo_vstack_csr_csr.f_equals),
        tester.Tester("coo_hstack_csr_csr", "csr", test_coo_hstack_csr_csr.process_burr, test_coo_hstack_csr_csr.f_burrito, test_coo_hstack_csr_csr.process_scipy, test_coo_hstack_csr_csr.f_scipy, test_coo_hstack_csr_csr.process_pydata, test_coo_hstack_csr_csr.f_pydata, test_coo_hstack_csr_csr.f_equals),
        tester.Tester("coo_slice_1d_csr", "csr", test_coo_slice_1d_csr.process_burr, test_coo_slice_1d_csr.f_burrito, test_coo_slice_1d_csr.process_scipy, test_coo_slice_1d_csr.f_scipy, test_coo_slice_1d_csr.process_pydata, test_coo_slice_1d_csr.f_pydata, test_coo_slice_1d_csr.f_equals),

        # fusion
        tester.Tester("cv_collapse_csr_mul_cv", "csr", test_cv_collapse_csr_mul_cv.process_burr, test_cv_collapse_csr_mul_cv.f_burrito, test_cv_collapse_csr_mul_cv.process_scipy, test_cv_collapse_csr_mul_cv.f_scipy, test_cv_collapse_csr_mul_cv.process_burr_unfused, test_cv_collapse_csr_mul_cv.f_burr_unfused, test_cv_collapse_csr_mul_cv.f_equals, is_unfused=True),
        tester.Tester("dv_sum_vstack_csr_csr_mul_dv", "csr", test_dv_sum_vstack_csr_csr_mul_dv.process_burr, test_dv_sum_vstack_csr_csr_mul_dv.f_burrito, test_dv_sum_vstack_csr_csr_mul_dv.process_scipy, test_dv_sum_vstack_csr_csr_mul_dv.f_scipy, test_dv_sum_vstack_csr_csr_mul_dv.process_burr_unfused, test_dv_sum_vstack_csr_csr_mul_dv.f_burr_unfused, test_dv_sum_vstack_csr_csr_mul_dv.f_equals, is_unfused=True),
        tester.Tester("csr_slice_1d_csr_mul_csr", "csr", test_csr_slice_1d_csr_mul_csr.process_burr, test_csr_slice_1d_csr_mul_csr.f_burrito, test_csr_slice_1d_csr_mul_csr.process_scipy, test_csr_slice_1d_csr_mul_csr.f_scipy, test_csr_slice_1d_csr_mul_csr.process_burr_unfused, test_csr_slice_1d_csr_mul_csr.f_burr_unfused, test_csr_slice_1d_csr_mul_csr.f_equals, is_unfused=True),
    ]

    tester.run_partition(10, k, m, tests)
