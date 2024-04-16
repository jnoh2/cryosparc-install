#!/bin/bash
#SBATCH -N 1
#SBATCH -n XXXmpinodesXXX
#SBATCH -c XXXthreadsXXX
#
#SBATCH --time=XXXextra3XXX
#SBATCH --begin=now+0days
#SBATCH -p XXXqueueXXX
#SBATCH --gpus=XXXextra2XXX
#SBATCH --mem=XXXextra1XXX
#
#SBATCH -o XXXoutfileXXX
#SBATCH -e XXXerrfileXXX
#SBTACH --no-requeue
#
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=jnoh2@stanford.edu

echo "SLURM_JOBID="$SLURM_JOBID
echo "SLURM_JOB_NAME="$SLURM_JOB_NAME
echo "SLURM_JOB_NODELIST"=$SLURM_JOB_NODELIST
echo "SLURM_NNODES"=$SLURM_NNODES
echo "SLURMTMPDIR="$SLURMTMPDIR
echo "working directory="$SLURM_SUBMIT_DIR

echo $(date)

source ~/.bashrc

$RELION_LOAD
echo $RELION_LOAD

echo "Running command"

echo "XXXcommandXXX"
srun XXXcommandXXX

echo "Finished command"
