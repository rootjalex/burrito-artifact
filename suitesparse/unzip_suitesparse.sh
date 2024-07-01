#!/bin/bash
#SBATCH -N 1
#SBATCH -t 360

# Command: ./unzip_suitesparse.sh

# From: https://github.com/weiya711/sam/blob/master/scripts/get_data/unpack_suitesparse.sh

for f in *.tar.gz; do
    tar -xvf "$f" --strip=1
    rm "$f"
done

for f in *.tar.gz.1; do
    rm "$f"
done

for f in *.mtx; do
    chmod ugo+r "$f"
done
