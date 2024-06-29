#pragma once
#include "runtime.h"

#include "cv_collapse_csr.h"
#include "cv_mul_cv_cv.h"

#include "csr_vstack_csr_csr.h"
#include "dv_sum_csr_mul_dv.h"

#include "csr_slice_1d_csr.h"
#include "csr_mul_csr_csr.h"

template<typename csr_index_t, typename cv_index_t, typename value_t>
CVector<cv_index_t, value_t> cv_collapse_csr_mul_cv_unfused(const CSR<csr_index_t, value_t> &A, const CVector<cv_index_t, value_t> &b) {
    const CVector<cv_index_t, value_t> temp = cv_collapse_csr<csr_index_t, cv_index_t, value_t>(A);
    return cv_mul_cv_cv(temp, b);
}

template<typename index_t, typename value_t>
nVector<value_t> dv_sum_vstack_csr_csr_mul_dv_unfused(const CSR<index_t, value_t> &a, const CSR<index_t, value_t> &b, const nVector<value_t> &x) {
    const CSR<index_t, value_t> temp = csr_vstack_csr_csr(a, b);
    return dv_sum_csr_mul_dv(temp, x);
}

template<typename index_t, typename value_t>
CSR<index_t, value_t> csr_slice_1d_csr_mul_csr_unfused(const CSR<index_t, value_t> &a, const CSR<index_t, value_t> &b, const index_t s0, const index_t e0, const index_t r0) {
    const CSR<index_t, value_t> temp = csr_slice_1d_csr(a, s0, e0, r0);
    return csr_mul_csr_csr(temp, b);
}
