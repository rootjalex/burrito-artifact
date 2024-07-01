from pathlib import Path

PROJECTS_PATH = Path(__file__).resolve().parent.parent
BURRITO_PATH = str(PROJECTS_PATH / "pyburrito/build")
IO_COO_PATH = str(PROJECTS_PATH / "io_coo/build")
SUITESPARSE_PATH = str(PROJECTS_PATH / "suitesparse")