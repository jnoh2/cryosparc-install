# Installing CryoSPARC on Sherlock
(Attribution: These instructions for installing CryoSPARC on Sherlock are a fork of the instructions developed and published by [jnoh2](https://github.com/jnoh2/cryosparc-install/blob/main/README.md). The instructions were originally derived from [CryoSPARC's](https://guide.cryosparc.com/setup-configuration-and-management/how-to-download-install-and-configure/downloading-and-installing-cryosparc) install instructions and a presentation by Zhiyong Zhang (Stanford Research Computing), with additional credit going to Haoqing Wang for advice and debugging, and to Josh Carter for testing.)

The following instructions were modified from their original form with a generic Sherlock user in mind who does not have access to a PI group partition or the `owners` partition.

## Table of Contents
## Automated Install 
The automated installation takes the steps in the prescribed in the manual installation section and automates them with a bash script. While the script has been tested it is not necessarily robust in dealing with user entry errors. 
### Step 0: Before Installing
Before starting the install, you need to obtain a CryoSPARC license. Fill out the download form on CryoSPARC's [website](https://cryosparc.com/download), and select the option that best describes your use case. For most Sherlock users the "I am an academic user carrying out non-profit academic reasearch at a university or educational/research." option will suffice. CryoSPARC will send you an email containing the license number within 24 hours.

### Step 1: Run Install Script
Download the current release of this directory in your home directory.
```
cd $HOME
curl -L https://github.com/chris-hypercag/cemc-cryosparc-sherlock-install/releases/download/v0.0.1/cemc-cryosparc-sherlock-install.tar.gz
tar -zxvf cemc-cryosparc-sherlock-install.tar.gz
```
Next, collect the following information: your CryoSPARC license number, your first and last name, and a password for your CryoSPARC account. You can also choose a   
Start an interactive job session, here we are asking for 4 cpu's 1 gpu for two hours. 
```
$ sh_dev -c 4 -g 1 -t 02:00:00
```


## Manual Installation Steps
### Step 0: Before Installing
Before starting the install, you need to obtain a CryoSPARC license. Fill out the download form on CryoSPARC's [website](https://cryosparc.com/download), and select the option that best describes your use case. For most Sherlock users the "I am an academic user carrying out non-profit academic reasearch at a university or educational/research." option will suffice. CryoSPARC will send you an email containing the license number within 24 hours.

### Step 1: Download CryoSPARC
Start an interactive job session
```
$ sh_dev -c 4 -g 1 -t 02:00:00
```
Set several environment variables that will be used throughout the installation.
```
export SUNETID=$USER
export CS_PATH=$GROUP_HOME/$USER/cryosparc/4.4.1
export PORT_NUM=39000
```
Next, set a license environment variable by replacing <LicenseID> with the number emailed to you. 
```
export LICENSE_ID=<LicenseID>
```
Create the install and database directories
```
mkdir -p $CS_PATH
mkdir -p $CS_PATH/cryosparc_db
cd $CS_PATH
```
Download the compressed files (.tar.gz) for the CryoSPARK master and worker programs
```
curl -L https://get.cryosparc.com/download/master-latest/$LICENSE_ID -o cryosparc_master.tar.gz
curl -L https://get.cryosparc.com/download/worker-latest/$LICENSE_ID -o cryosparc_worker.tar.gz
```
Decompress the files
```
tar -xf cryosparc_master.tar.gz cryosparc_master
tar -xf cryosparc_worker.tar.gz cryosparc_worker
```
### Step 2 : Install CryoSPARC
Install CryoSPARC Master
```
cd $CS_PATH/cryosparc_master
./install.sh --license $LICENSE_ID --dbpath $CS_PATH/cryosparc_db --port $PORT_NUM
```
The previous step creates file config.sh. In order to genearlize CryoSPARC for use on the normal partition, open config.sh in your prefered text editor (i.e. vim, nano, etc.), and comment out the line `export CRYOSPARC_MASTER_HOSTNAME="shXX-XXnXX.int"` by adding a `#` at begining of the line. 

Start the CryoSPARC master instance
```
./bin/cryosparcm start
```
Create your CryoSPARC login credentials. Replace each of the five fields in between the quotation marks with your own information.
```
./bin/cryosparcm createuser --email "<e-mail>" --password "<password>" --username "<username>" --firstname "<firstname>" --lastname "<lastname>"
```
Install CryoSPARC Worker
```
cd $CS_PATH/cryosparc_worker
ml cuda/11.7.1
./install.sh --license $LICENSE_ID
./bin/cryosparcw connect --worker <hostname> --master <hostname> --port $PORT_NUM --nossd
cd $CS_PATH
```
Prepare to connect master to worker. Copy and paste three following blocks of code
```
cat <<EOF >  cluster_info.json
{
    "name" : "normal-sherlock",
    "worker_bin_path" : "$CS_PATH/cryosparc_worker/bin/cryosparcw",
    "cache_path" : "$L_SCRATCH",
    "cache_reserve_mb" : 10000,
    "cache_quota_mb": 1000000,
    "send_cmd_tpl" : "{{ command }}",
    "qsub_cmd_tpl" : "sbatch {{ script_path_abs }}",
    "qstat_cmd_tpl" : "squeue -j {{ cluster_job_id }}",
    "qdel_cmd_tpl" : "scancel {{ cluster_job_id }}",
    "qinfo_cmd_tpl" : "sinfo",
}
EOF

```
```
cat <<EOF >  cluster_script.sh
#!/bin/bash
#
#SBATCH --job-name=cs-{{ project_uid }}-{{ job_uid }}
#SBATCH --output={{ job_log_path_abs }}
#SBATCH --error={{ job_log_path_abs }}
#
#SBATCH --partition={{ partition_requested }}
#SBATCH --nodes=1
#SBATCH --ntasks={{ cpu_requested }}
#SBATCH --gpus={{ num_gpu }}
#SBATCH --mem={{ (ram_gb*2)|int }}G
#
#SBATCH --time={{ time_requested }}
#
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user={{ sunetid }}@stanford.edu

echo "\$(date): job \$SLURM_JOBID starting on \$SLURM_NODELIST"

ml cuda/11.7.1

echo "Starting cryosparc worker job"

{{ run_cmd }}

echo "Finished cryosparc worker job"
EOF

```
```
cat <<EOF >  cs-master.sh
#!/bin/bash
#
#SBATCH --job-name=cs-master
#SBATCH --error=cs-master.err.%j --output=cs-master.out.%j
#
#SBATCH --dependency=singleton
#
#SBATCH --partition=normal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem-per-cpu=2G
#SBATCH --gpus=0
#
#SBATCH -t 7-00:00:00
#SBATCH --signal=B:SIGUSR1@360
#
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=$SUNETID@stanford.edu

_resubmit() {
    ## Resubmit the job for the next execution
    echo "\$(date): job \$SLURM_JOBID received SIGUSR1 at \$(date), re-submitting"
    ./cryosparc_master/bin/cryosparcm stop
    sbatch \$0
}
trap _resubmit SIGUSR1

cd $CS_PATH

echo "Loading cryosparc GUI"

./cryosparc_master/bin/cryosparcm start

echo "Loaded cryosparc GUI"

echo "\$(date): job \$SLURM_JOBID starting on \$SLURM_NODELIST"
while true; do
    echo "\$(date): normal execution"
    sleep 300
done
EOF

```
Connect CryoSPARC to the cluster
```
cd $CS_PATH/cryosparc_master
./bin/cryosparcm cluster connect
```

At this point CryoSPARC is installed and both the master and worker instances are configured. To clean up, stop the cryosparc master instance started earlier in the setup and exit sh_dev mode
```
./bin/cryosparcm stop
exit
```

## Start the CryoSPARC GUI
The max time for a Sherlock job is 7 days. This code will start a job that will resubmit a job every 7 days to restart your CryoSPARC GUI. If you start a job that doesn't finish before the GUI restarts, it'll probably be canceled. I would honestly recommend canceling this job submission each time you're done for the day and resubmit the above code block each time you want to start working again.
```
sbatch cs-master.sh
```
To cancel the job when you're done
```
scancel -n cs-master
```
To check if your job has started
```
squeue -u $USER
```
### Step 4 : Connect to the CryoSPARC GUI
Exit the dev mode
```
exit
```
Open a separate terminal on your computer. In the new terminal execute the following command to enable port forwarding from Sherlock, replacing \<SUNetID\> with your SUNetID, 
```
ssh -NfL 39000:shXX-XXnXX:39000 <SUNetID>@sherlock.stanford.edu
```
Then on any browser on your computer, go to the following url, 
```
localhost:39000
```
If the browser is unable to connect, try closing and reopening it. 

Note: Step 4 can take 5-10 minutes to start up (or faster), so continue to refresh if you don't see anything yet
Once you see the login screen, you can log in with the credentials you input at step 2
### Step 5 : Configure CryoSPARC
1. Once logged in, go to admin (key symbol on the left)
2. Go to Cluster Configuration Tab
3. Add a few Key-Value pairs, replacing \<SUNetID\> with your SUNetID

> Key = time_requested | Value = 24:00:00

> Key = partition_requested | Value = cobarnes

> Key = cpu_requested | Value = 1

> Key = sunetid | Value = \<SUNetID\>

And you're done! Test out the functionality of the installation by processing with some small sample batch.

### Step 6 : Submit Jobs
For a given job, create and configure your job as needed. When you click "Queue Job" and you're given the option to modify the category "Queue to Lane"
1. Select "barnes-sherlock (cluster)"
2. Select the number of gpus, number of cpus (if using gpus, consider getting double the number of cpus as gpus), amount of time you will need and your SUNetID
3. Click "Queue"

## Adding Additional Parameters for the Submission Script
You may want to be able to adjust more parameters in the Sherlock job submission script. For example, you may want to use a different partition from what you're using. Here are the steps to adding more adjustable parameters for the submission script.

### Step 1 : Name the variable for which you want to make adjustable
If you want to be able to adjust a certain parameter, come up with how you want to refer to it. In this example, we want to be able to adjust the partition we are using when we submit the job. We will call that parameter `{{ partition_requested }}`. Note, the curly braces and spacing is IMPORTANT! When you name your own parameter, you must keep the curly barces and spaces surrounding the actual text `partition_requested`

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
#SBATCH -n {{ cpu_requested }}
#SBATCH --gpus={{ num_gpu }}
#SBATCH --mem={{ (ram_gb*2)|int }}G
#
#SBATCH -t {{ time_requested }}
#
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user={{ sunetid }}@stanford.edu

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
#SBATCH -n {{ cpu_requested }}
#SBATCH --gpus={{ num_gpu }}
#SBATCH --mem={{ (ram_gb*2)|int }}G
#
#SBATCH -t {{ time_requested }}
#
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user={{ sunetid }}@stanford.edu

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
4. Add the Key-Value pair for which the "Key" is your parameter name WITHOUT curly braces and spaces (i.e. `partition_requested`), and the "Value" should be the default for your parameter. In this example, you would add the following:
> Key = partition_requested | Value = cobarnes

Some things that haven't been written in yet: installations for using 3DFlex
