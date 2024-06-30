import seaborn
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import csv
import scipy
import math
import sys

import numpy as np

from parse_file import parse_file, parse_file_dict
FLOATMIN = 1e-5

INT32MAX = 2147483647

def get_data(filename):
    labels = ["matrix_name", "benchmark_name", "scipy_speedup", "pydata_speedup", "t_burrito", "t_scipy", "t_pydata"]
    parsed = parse_file(filename, labels)
    return parsed

def scatter_plot(data, pngname, benchmark_name, title, ax, suitesparse_dict, compare, ylabel, _key = "Sparsity", yticks = [1, 2, 4, 8, 16, 32, 64, 128], color = "#1f77b4"):
    benchmark_data = list(filter(lambda x: x["benchmark_name"] == benchmark_name, data))

    benchmark_data.sort(key=lambda x: float(suitesparse_dict[x["matrix_name"]][_key]))
    # grab e.g. "scipy_speedup"
    individual_data = list(map(lambda x: float(x[compare]), benchmark_data))
    key_data = list(map(lambda x: float(suitesparse_dict[x["matrix_name"]][_key]), benchmark_data))

    gmean = scipy.stats.gmean(individual_data)
    print(f"Benchmark: {title}; {compare} geomean: {gmean}; {compare} min: {min(individual_data)}; {compare} max: {max(individual_data)}")
    n = len(individual_data)
    # x = range(n)
    x = key_data
    ax.scatter(x, individual_data, s=0.1, c=color)
    # ax.plot(x, np.ones(n) * gmean, color="red")
    ax.plot(x, np.ones(n), color="black")

    ax.set_yscale("log")
    ax.set_yticks(yticks)
    yt = list(map(lambda x: str(int(x)) if float(int(x)) == x else str(x), yticks))
    ax.set_yticklabels(yt)
    ax.set_ylabel(ylabel)

    ax.set_xscale("log")
    ax.set_xlabel(_key)

    ax.set_title(f"{title}\nGeomean: {gmean:.3g}x")
    # ax.set_xticks([])
    # plt.show()
    plt.minorticks_off()
    plt.savefig(pngname, dpi=1000, bbox_inches="tight")

"""
def scatter_plot(filename, title, ax, suitesparse_dict, _key = "sparsity"):
    labels = ["name", "scipy_speedup", "pydata_speedup", "t_burrito", "t_scipy", "t_pydata"]
    parsed = parse_file(filename, labels)

    # burrito_data = list(map(lambda x: float(x["t_burrito"]), parsed))
    parsed = sorted(parsed, key=lambda x: suitesparse_dict[x["name"]][_key])
    scipy_data = list(map(lambda x: float(x["scipy_speedup"]), parsed))
    key_data = list(map(lambda x: float(suitesparse_dict[x["name"]][_key]), parsed))
    # pydata_data = list(map(lambda x: float(x["pydata_speedup"]), parsed))

    scipy_gmean = scipy.stats.gmean(scipy_data)
    # pydata_gmean = scipy.stats.gmean(pydata_data)
    print(f"Benchmark: {title}; scipy geomean: {scipy_gmean}; scipy min: {min(scipy_data)}; scipy max: {max(scipy_data)}")
    # print(f"                  ; pydata geomean: {pydata_gmean}; pydata min: {min(pydata_data)}; pydata max: {max(pydata_data)}")
    # print(f"Min {_key}: {min(key_data)}; Max {_key}: {max(key_data)}")
    # print(f"Min {_key}: {np.min(np.array(key_data))}; Max {_key}: {np.max(np.array(key_data))}")

    n = len(scipy_data)
    # x = range(n)
    x = key_data
    # ax.scatter(x, burrito_data, label="burrito")
    ax.scatter(x, scipy_data, label="scipy", s=1)
    # ax.scatter(x, pydata_data, label="pydata")
    # plt.legend(loc='upper left')
    ax.plot(x, np.ones(n) * scipy_gmean, color="red")
    ax.set_yscale("log")
    ax.set_xscale("log")
    yticks = [1, 2, 4, 8, 16, 32, 64, 128]
    ax.set_yticks(yticks)
    yt = list(map(lambda x: str(int(x)) if float(int(x)) == x else str(x), yticks))
    ax.set_yticklabels(yt)
    ax.set_title(f"{title}\nGeomean: {scipy_gmean:.3g}x")
    # ax.set_xticks([])
    plt.show()
"""

# (data, "coo_reshape_coo", "COO = reshape(COO)", ax, suitesparse_dict, _key = "nnz")
def time_scatter_plot(data, benchmark_name, title, ax, suitesparse_dict, _key = "Sparsity"):
    benchmark_data = list(filter(lambda x: x["benchmark_name"] == benchmark_name, data))

    benchmark_data.sort(key=lambda x: float(suitesparse_dict[x["matrix_name"]][_key]))
    # grab e.g. "scipy_speedup"
    # Some benchmarks were run before the 5s timeout was applied, cap at 5s for consistency
    burrito_timing = list(map(lambda x: min(5.0, float(x["t_burrito"])), benchmark_data))
    scipy_timing = list(map(lambda x: min(5.0, float(x["t_scipy"])), benchmark_data))
    pydata_timing = list(map(lambda x: min(5.0, float(x["t_pydata"])), benchmark_data))
    key_data = list(map(lambda x: float(suitesparse_dict[x["matrix_name"]][_key]), benchmark_data))

    # scipy_speedups = list(map(lambda x: float(x["scipy_speedup"]), benchmark_data))
    scipy_speedups = np.array(scipy_timing) / np.array(burrito_timing)
    pydata_speedups = np.array(pydata_timing) / np.array(burrito_timing)
    # pydata_speedups = list(map(lambda x: float(x["pydata_speedup"]), benchmark_data))
    scipy_gmean = scipy.stats.gmean(scipy_speedups)
    pydata_gmean = scipy.stats.gmean(pydata_speedups)
    scipy_min = np.min(scipy_speedups)
    scipy_max = np.max(scipy_speedups)
    pydata_min = np.min(pydata_speedups)
    pydata_max = np.max(pydata_speedups)
    print(f"Benchmark: {title};\n  scipy geomean: {scipy_gmean}; scipy min: {scipy_min}; scipy max: {scipy_max};\n  pydata geomean: {pydata_gmean}; pydata min: {pydata_min}; pydata max: {pydata_max};")

    x = key_data
    ax.scatter(x, pydata_timing, s=0.1, c="orange", label="pydata")
    ax.scatter(x, scipy_timing, s=0.1, c="red", label="scipy")
    ax.scatter(x, burrito_timing, s=0.1, c="blue", label="BURRITO")

    ax.minorticks_off()
    ax.set_yscale("log")
    # ax.set_yticks(yticks)
    # yt = list(map(lambda x: str(int(x)) if float(int(x)) == x else str(x), yticks))
    # ax.set_yticklabels(yt)
    ax.set_ylabel("Time (s)", fontsize='large')
    ax.set_ylim(1e-7, 1e1)
    plt.yticks(fontsize='large')

    ax.set_xscale("log")
    ax.set_xlabel(_key, fontsize='large')
    ax.set_xlim(1e1, 1e9)
    plt.xticks(fontsize='large')

    # ax.set_title(f"{title}")
    ax.legend(loc='upper left', fontsize='large', markerscale=10)

    # if "reshape_coo" in benchmark_name:
        # plt.text(0xFFFFFFFF, 10e-7, "UINT32MAX", color="red", fontsize=7)
        # plt.plot(0xFFFFFFFF, 10e-7, marker='|', color='red', markersize=10, label='UINT32MAX')
        # plt.text(0xFFFFFFFF, 10e-7, ' UINT32MAX', verticalalignment='bottom', horizontalalignment='left')
    # ax.set_xticks([])
    # plt.show()
    # plt.minorticks_off()
    plt.savefig("imgs/" + benchmark_name + ".pdf", dpi=1000, bbox_inches="tight")
    plt.clf()


def plot_portable(suitesparse_dict, data = None):
    if data is None:
        data = get_data("data/partition_portable.csv")

    # TODO: figure out subfigures

    fig = plt.figure()
    ax = fig.add_subplot(111)
    time_scatter_plot(data, "csr_reshape_coo", "CSR = reshape(COO)", ax, suitesparse_dict, _key = "nnz")
    fig = plt.figure()
    ax = fig.add_subplot(111)
    time_scatter_plot(data, "csr_hstack_coo_coo", "CSR = hstack(COO, COO)", ax, suitesparse_dict, _key = "nnz")
    fig = plt.figure()
    ax = fig.add_subplot(111)
    time_scatter_plot(data, "coo_hstack_csr_csr", "COO = hstack(CSR, CSR)", ax, suitesparse_dict, _key = "nnz")
    fig = plt.figure()
    ax = fig.add_subplot(111)
    time_scatter_plot(data, "coo_vstack_csr_csr", "COO = vstack(CSR, CSR)", ax, suitesparse_dict, _key = "nnz")
    fig = plt.figure()
    ax = fig.add_subplot(111)
    time_scatter_plot(data, "coo_slice_csr", "COO = slice(CSR)", ax, suitesparse_dict, _key = "nnz")
    fig = plt.figure()
    ax = fig.add_subplot(111)
    time_scatter_plot(data, "csr_reshape_csr", "CSR = reshape(CSR)", ax, suitesparse_dict, _key = "nnz")

def plot_handwritten(suitesparse_dict, data = None):
    if data is None:
        data = get_data("data/partition_handwritten.csv")

    plots = [
        ("coo_reshape_coo", "COO = reshape(COO)"),
        ("coo_hstack_coo_coo", "COO = hstack(COO, COO)"),
        ("coo_vstack_coo_coo", "COO = vstack(COO, COO)"),
        ("csr_hstack_csr_csr", "CSR = hstack(CSR, CSR)"),
        ("csr_vstack_csr_csr", "CSR = vstack(CSR, CSR)"),
        ("csr_slice_csr", "CSR = slice(CSR)"),
    ]

    key = "nnz"
    # count = len(plots)
    # fig, axes = plt.subplots(1, count, sharey=True)

    # for p, ax in zip(plots, axes):
    for p in plots:
        plt.clf()
        fig = plt.figure()
        ax = fig.add_subplot(111)
        time_scatter_plot(data, p[0], p[1], ax, suitesparse_dict, _key=key)
    
    # plt.savefig("handwritten.pdf", dpi=1000, bbox_inches="tight")

    # fig = plt.figure()
    # ax = fig.add_subplot(111)
    # time_scatter_plot(data, "coo_reshape_coo", "COO = reshape(COO)", ax, suitesparse_dict, _key = "nnz")
    # fig = plt.figure()
    # ax = fig.add_subplot(111)
    # time_scatter_plot(data, , ax, suitesparse_dict, _key = "nnz")
    # fig = plt.figure()
    # ax = fig.add_subplot(111)
    # time_scatter_plot(data, , ax, suitesparse_dict, _key = "nnz")
    # fig = plt.figure()
    # ax = fig.add_subplot(111)
    # time_scatter_plot(data, , ax, suitesparse_dict, _key = "nnz")
    # fig = plt.figure()
    # ax = fig.add_subplot(111)
    # time_scatter_plot(data, , ax, suitesparse_dict, _key = "nnz")
    # fig = plt.figure()
    # ax = fig.add_subplot(111)
    # time_scatter_plot(data, , ax, suitesparse_dict, _key = "nnz")


def time_scatter_plot_fusion(data, benchmark_name, title, ax, suitesparse_dict, _key = "Sparsity"):
    benchmark_data = list(filter(lambda x: x["benchmark_name"] == benchmark_name, data))

    benchmark_data.sort(key=lambda x: float(suitesparse_dict[x["matrix_name"]][_key]))
    burrito_timing = list(map(lambda x: float(x["t_burrito"]), benchmark_data))
    scipy_timing = list(map(lambda x: float(x["t_scipy"]), benchmark_data))
    # unfused_timing = list(map(lambda x: float(x["t_unfused"]), benchmark_data))
    unfused_timing = list(map(lambda x: float(x["t_pydata"]), benchmark_data))
    key_data = list(map(lambda x: float(suitesparse_dict[x["matrix_name"]][_key]), benchmark_data))

    scipy_speedups = list(map(lambda x: float(x["t_scipy"]) / (float(x["t_burrito"]) if float(x["t_burrito"]) != 0 else FLOATMIN), benchmark_data))
    # unfused_speedups = list(map(lambda x: float(x["t_unfused"]) / (float(x["t_burrito"]) if float(x["t_burrito"]) != 0 else FLOATMIN), benchmark_data))
    unfused_speedups = list(map(lambda x: float(x["t_pydata"]) / (float(x["t_burrito"]) if float(x["t_burrito"]) != 0 else FLOATMIN), benchmark_data))
    scipy_gmean = scipy.stats.gmean(scipy_speedups)
    unfused_gmean = scipy.stats.gmean(unfused_speedups)
    scipy_min = min(scipy_speedups)
    scipy_max = max(scipy_speedups)
    unfused_min = min(unfused_speedups)
    unfused_max = max(unfused_speedups)
    print(f"Benchmark: {title};\n  scipy geomean: {scipy_gmean}; scipy min: {scipy_min}; scipy max: {scipy_max};\n  unfused geomean: {unfused_gmean}; unfused min: {unfused_min}; unfused max: {unfused_max};")

    x = key_data
    ax.scatter(x, scipy_timing, s=0.1, c="red", label="scipy")
    ax.scatter(x, unfused_timing, s=0.1, c="orange", label="BURRITO (unf)")
    ax.scatter(x, burrito_timing, s=0.1, c="blue", label="BURRITO")

    ax.minorticks_off()
    ax.set_yscale("log")
    # ax.set_yticks(yticks)
    # yt = list(map(lambda x: str(int(x)) if float(int(x)) == x else str(x), yticks))
    # ax.set_yticklabels(yt)
    ax.set_ylabel("Time (s)", fontsize='large')
    ax.set_ylim(1e-7, 1e1)
    plt.yticks(fontsize='large')

    ax.set_xscale("log")
    ax.set_xlabel(_key, fontsize='large')
    ax.set_xlim(1e1, 1e9)
    plt.xticks(fontsize='large')

    # ax.set_title(f"{title}")
    ax.legend(loc='upper left', fontsize='large', markerscale=10)
    # ax.set_xticks([])
    # plt.show()
    # plt.minorticks_off()
    plt.savefig("imgs/" + benchmark_name + ".pdf", dpi=1000, bbox_inches="tight")
    plt.clf()



if __name__ == "__main__":
    print("Parsing data...", file=sys.stderr)
    suitesparse_dict = parse_file_dict("suitesparse/suitesparse_stats.csv", ["nnz", "Sparsity", "Size", "N", "M"])

    data = get_data("results/out.txt")

    plots = [
        # handwritten
        ("cv_collapse_coo", "C = collapse(COO)"),
        ("coo_hstack_coo_coo", "COO = hstack(COO, COO)"),
        ("coo_vstack_coo_coo", "COO = vstack(COO, COO)"),
        ("csr_vstack_csr_csr", "CSR = vstack(CSR, CSR)"),
        ("csr_hstack_csr_csr", "CSR = hstack(CSR, CSR)"),
        ("csr_slice_1d_csr", "CSR = slice(CSR)"),

        # portable
        ("coo_split_cv", "COO = split(C)"),
        ("csr_split_cv", "CSR = split(C)"),
        ("csr_hstack_coo_coo", "CSR = hstack(COO, COO)"),
        ("coo_hstack_csr_csr", "COO = hstack(CSR, CSR)"),
        ("coo_vstack_csr_csr", "COO = vstack(CSR, CSR)"),
        ("coo_slice_1d_csr", "COO = slice(CSR)"),
    ]

    for p in plots:
        plt.clf()
        fig = plt.figure()
        ax = fig.add_subplot(111)
        time_scatter_plot(data, p[0], p[1], ax, suitesparse_dict, _key="nnz")

    # fusion
    fig = plt.figure()
    ax = fig.add_subplot(111)
    time_scatter_plot_fusion(data, "cv_collapse_csr_mul_cv", "C = collapse(CSR) * C", ax, suitesparse_dict, _key = "nnz")

    fig = plt.figure()
    ax = fig.add_subplot(111)
    time_scatter_plot_fusion(data, "dv_sum_vstack_csr_csr_mul_dv", "D = sum(vstack(CSR, CSR) * D)", ax, suitesparse_dict, _key = "nnz")

    fig = plt.figure()
    ax = fig.add_subplot(111)
    time_scatter_plot_fusion(data, "csr_slice_1d_csr_mul_csr", "CSR = slice(CSR) * CSR", ax, suitesparse_dict, _key = "nnz")
