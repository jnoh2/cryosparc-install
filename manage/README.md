# Managing CryoSPARC on Sherlock
I want to thank the many people who contributed to helping figure things out, including Haoqing Wang and Josh Carter.

## Adding additional parameters for the submission script
You may want to be able to adjust more parameters in the Sherlock job submission script. For example, you may want to use a different partition from what you're using. Here are the steps to adding more adjustable parameters for the submission script.

### Step 1 : Name the variable for which you want to make adjustable
If you want to be able to adjust a certain parameter, come up with how you want to refer to it. In this example, we want to be able to adjust the partition we are using when we submit the job. We will call that parameter `{{ partition_requested }}`. Note, the curly braces and spacing is IMPORTANT!

### Step 2 : Edit your submission script 
Suppose your `cluster_script.sh` file in your main cryosparc installation folder looks like the following:
```
#!/bin/bash
#
#SBATCH --job-name=cs-{{ project_uid }}-{{ job_uid }}
#SBATCH --output={{ job_log_path_abs }}
#SBATCH --error={{ job_log_path_abs }}
#
#SBATCH -p cobarnes
#SBATCH -N 1
#SBATCH --nodelist=sh03-11n13
#SBATCH -n {{ num_gpu*2 }}
#SBATCH --gpus={{ num_gpu }}
#SBATCH --mem={{ (ram_gb*2)|int }}G
#
#SBATCH -t {{ time_requested }}
#
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=$SUNETID@stanford.edu

echo "\$(date): job \$SLURM_JOBID starting on \$SLURM_NODELIST"
echo

ml cuda/11.7.1

echo
echo "Starting cryosparc worker job"
echo

{{ run_cmd }}

echo "Finished cryosparc worker job"
echo
```
Replace where you want the text replacement for the parameter to go. In this example, we want `cobarnes` replaced with our variable of choice, `{{ partition_requested }}`. After replacement, `cluster_script.sh` should now look like this:
```
#!/bin/bash
#
#SBATCH --job-name=cs-{{ project_uid }}-{{ job_uid }}
#SBATCH --output={{ job_log_path_abs }}
#SBATCH --error={{ job_log_path_abs }}
#
#SBATCH -p {{ partition_requested }}
#SBATCH -N 1
#SBATCH --nodelist=sh03-11n13
#SBATCH -n {{ num_gpu*2 }}
#SBATCH --gpus={{ num_gpu }}
#SBATCH --mem={{ (ram_gb*2)|int }}G
#
#SBATCH -t {{ time_requested }}
#
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=$SUNETID@stanford.edu

echo "\$(date): job \$SLURM_JOBID starting on \$SLURM_NODELIST"
echo

ml cuda/11.7.1

echo
echo "Starting cryosparc worker job"
echo

{{ run_cmd }}

echo "Finished cryosparc worker job"
echo
```
Note the change on line 7
### Step 3 : Connect the new job submission script to CryoSPARC
Make sure you are in the directory that contains `cluster_script.sh` and `cluster_info.json`. Then enter the following:
```
cryosparcm cluster connect
```
### Step 4 : Indicate the use of the parameter on the CryoSPARC GUI
1. Go to your cryosparc GUI instance on your browser.
2. Go to admin (key symbol on the left)
3. Go to Cluster Configuration tab
4. Add the Key-Value pair for which the "Key" is your parameter name WITHOUT curly braces and the "Value" should be the default for your parameter. In this example, you would add the following:
> Key = partition_requested | Value = cobarnes
