### Installation
- Github clone
- Load modules as in relion\_install.txt
- Make the file as in relion\_make.txt
- Include relion\_template.sh
- Install ctffind
- Make scratch directory for relion
- Include the following in .bashrc

```
export RELION=$HOME/cryoem/relion/build/bin/relion
export RELION_LOAD='ml x11/7.7 openmpi/4.1.2 fftw/3.3.10 system libtiff/4.0.8 openjpeg/2.3.1 fltk/1.3.4 cuda/11.5.0'

export PATH="/home/users/jnoh2/cryoem/relion/build/bin:$PATH"

# from Haoqing
export RELION_QSUB_EXTRA1="Memory"
export RELION_QSUB_EXTRA1_DEFAULT="64G"
export RELION_QSUB_EXTRA2="Number of GPUs"
export RELION_QSUB_EXTRA2_DEFAULT="0"
export RELION_QSUB_EXTRA3="Time"
export RELION_QSUB_EXTRA3_DEFAULT="96:00:00"
#export RELION_QSUB_EXTRA4="Partition"
#export RELION_QSUB_EXTRA4_DEFAULT="gpu"

export RELION_QUEUE_NAME="cobarnes"
export RELION_QSUB_COMMAND="sbatch"
export RELION_QUEUE_USE="yes"
export RELION_QSUB_EXTRA_COUNT=3
export RELION_QSUB_TEMPLATE="/home/users/jnoh2/cryoem/relion_template.sh"
export RELION_CTFFIND_EXECUTABLE='/home/users/jnoh2/cryoem/relion/ctffind'
export RELION_SCRATCH_DIR='/scratch/users/jnoh2/relion_scratch'

\#export RELION_CPU="/home/users/jnoh2/cryoem/relion_cpu.sh"
\#export RELION_GPU="/home/users/jnoh2/cryoem/relion_gpu.sh"
```

### Usage
```
ssh -XY \[SUNETID\]@login.sherlock.stanford.edu
srun --x11=all -p gpu -G 1 --time=1:00:00 --pty bash
$RELION_LOAD
```
Navigate to path of interest

```
relion
```
