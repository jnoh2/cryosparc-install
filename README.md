# Installing CryoSPARC on Sherlock
(Attribution: These instructions for installing CryoSPARC on Sherlock are a fork of the instructions developed and published by [jnoh2](https://github.com/jnoh2/cryosparc-install/blob/main/README.md). The instructions were originally derived from [CryoSPARC's](https://guide.cryosparc.com/setup-configuration-and-management/how-to-download-install-and-configure/downloading-and-installing-cryosparc) install instructions and a presentation by Zhiyong Zhang (Stanford Research Computing), with additional credit going to Haoqing Wang for advice and debugging, and to Josh Carter for testing.)

The following instructions were modified from their original form with a generic Sherlock user in mind who does not have access to a PI group partition or the owners partition.

## Table of Contents



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
Create your CryoSPARC login credentials. Replace each of the five fields in between with your own details---keep the quotation marks when entering with your information but remove the brackets, for example `--email "jane@stanford.edu"`
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
### Step 3: Create Submission Scripts
Next, prepare to connect the master instance to the worker instance. For this you will need the files `cluster_info.json`, `cluster_script.sh`, and `cs-master.sh`. Copy and paste the following code blocks into the terminal. Clicking the copy icon in the upper right hand corner of the code block will insure the entire field is copied. The `cat` command will automatically concatenate the lines in between it and marker (EOF) and pass it to file named `cluster_info.json`. 
```
cat <<EOF >  cluster_info.json
{
    "name" : "generic-sherlock",
    "worker_bin_path" : "$CS_PATH/cryosparc_worker/bin/cryosparcw",
    "cache_path" : "$L_SCRATCH",
    "cache_reserve_mb" : 10000,
    "cache_quota_mb": 500000,
    "send_cmd_tpl" : "{{ command }}",
    "qsub_cmd_tpl" : "sbatch {{ script_path_abs }}",
    "qstat_cmd_tpl" : "squeue -j {{ cluster_job_id }}",
    "qdel_cmd_tpl" : "scancel {{ cluster_job_id }}",
    "qinfo_cmd_tpl" : "sinfo",
}
EOF
```
Copy and paste the following code block to create `cluster_script.sh`. This script provides a template to CryoSPARC for submitting worker jobs.
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
Copy and paste the following code block to create `cs-master.sh`. This script will start and restart the CryoSPARC master instance.
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
    date -R >> $CS_PATH/cs-master.log
    ./cryosparc_master/bin/cryosparcm stop >> $CS_PATH/cs-master.log
    sbatch \$0
}
trap _resubmit SIGUSR1

cd $CS_PATH

echo "Loading cryosparc GUI"

date -R >> $CS_PATH/cs-master.log
./cryosparc_master/bin/cryosparcm restart >> $CS_PATH/cs-master.log

echo "Loaded cryosparc GUI"

echo "\$(date): job \$SLURM_JOBID starting on \$SLURM_NODELIST"

EOF
```

### Step 4: Finalizing the master instance connection, and Clean Up 
Last step, connect CryoSPARC to the cluster
```
cd $CS_PATH/cryosparc_master
./bin/cryosparcm cluster connect
```
At this point and both the master and worker instances are configured. 
To clean up, stop the cryosparc master instance started earlier in the setup and exit sh_dev mode.
```
./bin/cryosparcm stop
exit
```

## Start the CryoSPARC GUI
The max runtime for a job on Sherlock 7 days. The `_resubmit()` function in `cs-master.sh` automatically requeues the CryoSPARC master instance when the time limit is reached. If a worker job doesn't finish before the 7 day time limit, the worker job will mostly likely terminate itself.  

It is highly recommended you cancel the master instance each time you are done for the day and resubmit the job when you want to start working again. This helps free up Sherlock resources for other users and keeps your fairshare score from depleting. Your fairshare score is an important metric when running in the normal partition; it effects how long slurm will hold your job before allocating it resources. The higher your fairshare score, the faster your job will get through the queue. You can prevent unnecessary depletion of your fairshare score by requesting the minimum number of resources (cpus, memory, runtime) needed to run the master and worker jobs.

To submit the master job to the queue run the following command from your CryoSPARC directory containing `cs-master.sh`
```
sbatch cs-master.sh
```
To cancel the job when you're done
```
scancel -n cs-master
```
To check if your job has started
```
squeue --me
```
When the master instance is running, `squeue --me` will also output the hostname of the master node under NODELIST. The hostname has the format `sh##-##n##`. Copy this hostname for the next step.

### Connect to the CryoSPARC GUI
Now open a separate terminal on your computer. In the new terminal execute the following command to enable port forwarding, replacing sh##-##n## with the hostname, and \<SUNetID\> with your SUNetID, 
```
ssh -NfL 39000:sh##-##n##>:39000 <SUNetID>@sherlock.stanford.edu
```
Then on any browser on your computer, go to the following url, 
```
localhost:39000
```
Once you see the login screen, you can log in with the credentials you chose in step 2.

Note: If the browser is unable to connect, the port may need to be reset. First find the PID number of the open port.
```
lsof -i:39000
```
Copy the PID number, and kill the process directly
```
kill -9 <PID>
```
Now try rerunning the port forwarding command. If the previous steps don't reset the port, try closing and reopening your browser.

### Configure CryoSPARC
1. Once logged in, go to admin (key symbol on the left)
2. Go to Cluster Configuration Tab
3. Add a few Key-Value pairs, replacing \<SUNetID\> with your SUNetID

- Key = time_requested | Value = 24:00:00
- Key = partition_requested | Value = normal
- Key = cpu_requested | Value = 1
- Key = sunetid | Value = \<SUNetID\>

### Submit Jobs
For a given job, create and configure your job as needed. When you click "Queue Job" and you're given the option to modify the category "Queue to Lane"
1. Select "sherlock"
2. Select the number of gpus, number of cpus (if using gpus, consider getting double the number of cpus as gpus), amount of time you will need and your SUNetID
3. Click "Queue"

## Adding Additional Parameters for the Submission Script
You may want to be able to adjust more parameters in the Sherlock job submission script. 

### Step 1 : Name the variable for you want to modify
If you want to adjust certain hardcoded sbatch or bash parameters in your submission scripts from within CryoSPARC you can do so by adding Key-Value pairs in the cluster configuation tab. First come up with a unique variable name for the parameter you wish to modify.  For example, the `#SBATCH --partition=` parameter can be modified by declaring a `{{ partition_requested }}` variable name, as seen in `cluster_script.sh`. 

### Step 2 : Edit your submission script 
Within your scripts add the new parameter or replace the hardcoded value of a preexisting parameter with your variable name. When using your own variable in scripts, you must keep the curly braces and spaces surrounding the actual variable name. In CryoSPARC, the curly braces and spacing identify `partition_requested` as a variable.

### Step 3 : Connect the new job submission script to CryoSPARC
Make sure you are in the directory that contains `cluster_script.sh` and `cluster_info.json`. Then enter the following:
```
cryosparcm cluster connect
```
### Step 4 : Indicate the use of the parameter on the CryoSPARC GUI
1. Go to your CryoSPARC master instance on your browser.
2. Go to admin (key symbol on the left)
3. Go to Cluster Configuration tab
4. Add the Key-Value pair for which the "Key" is your variable name WITHOUT curly braces and spaces (i.e. `partition_requested`), and the "Value" should be the default for your parameter. In this example, you would add the following:
- Key = partition_requested | Value = normal
