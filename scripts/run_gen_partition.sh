#!/bin/bash

if [ $# -eq 0 ]
  then
    echo "Usage: $0 <directory_name> <n>"
    exit 1
fi

RES_DIR=$1

if [ -d "$RES_DIR" ]; then
    echo "FAILURE: Directory '$RES_DIR' already exists."
    exit 1
else
    echo "Making directory '$RES_DIR'"
    mkdir $RES_DIR
fi

module load slurm

N=$2

for ((i=0; i<=$N; i++))
do
    echo "Launching partition $i..."
    # TODO: change `lanka-v3` to your partition name, and `commit-main`
    srun --partition lanka-v3 --qos commit-main -N 1 --cpu_bind=verbose,cores --exclusive -t 16:0:0 --mem=0 ./run_partition.sh $RES_DIR/out$i-$N.txt $i $N &
done

wait
