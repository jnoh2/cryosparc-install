#!/bin/bash
#
#SBATCH --job-name=relion-cpu
#
#SBATCH -N 1
#SBATCH -n 4
#SBATCH -c 1
#
#SBATCH --time=24:00:00
#SBATCH --begin=now+0days
#SBATCH -p bigmem
#SBATCH --gpus=0
#SBATCH --mem=32G
#
#SBATCH -o relion-output.out
#SBATCH -e relion-error.err
#SBTACH --no-requeue
#
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=jnoh2@stanford.edu

echo "SLURM_JOBID="$SLURM_JOBID
echo "SLURM_JOB_NAME="$SLURM_JOB_NAME
echo "SLURM_JOB_NODELIST"=$SLURM_JOB_NODELIST
echo "SLURM_NNODES"=$SLURM_NNODES
echo "SLURMTMPDIR="$SLURMTMPDIR
echo "working directory="$SLURM_SUBMIT_DIR

echo $(date)

sleep 24h
