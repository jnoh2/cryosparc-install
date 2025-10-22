# Installing CryoSPARC on Sherlock
Steps were derived from the [instructions](https://guide.cryosparc.com/setup-configuration-and-management/how-to-download-install-and-configure/downloading-and-installing-cryosparc) from CryoSPARC and a presentation by Zhiyong Zhang in the SRCC-support team. Additional thank you to Haoqing Wang for advice & debugging at several steps, and to Josh Carter for test running the whole thing, brainstorming on ways to make the system more efficient and finding errors to fix.

## Table of Contents

* [Basic Installation Steps](https://github.com/jnoh2/cryosparc-install/tree/main#basic-installation-steps)
* [Adding Additional Parameters for the Submission Script](https://github.com/jnoh2/cryosparc-install/tree/main#adding-additional-parameters-for-the-submission-script)
* [Storage Management](https://github.com/jnoh2/cryosparc-install/tree/main#storage-management)

## Basic Installation Steps
### Step 1 : Get a license number from CryoSPARC & port number to use for the lab
- For the license number, fill out the form at their download [website](https://cryosparc.com/download), and you'll get an e-mail with the license number
- For the port number, go to the Barnes Lab drive and under "Inventories" find "Sherlock Port Availabilities" sheet listing empty and used port numbers. Find a port that is either empty or used by someone who is no longer likely to use it again (i.e. no longer in the lab). It should be a 5 digit number like 39000.
### Step 2 : Download CryoSPARC to $GROUP_HOME
Connect to dev node
```
sdev -t 3:00:00 -p cobarnes -g 1
```
Create a screen to return to in case anything goes wrong. Replace \<SUNetID\> with your SUNetID
```
screen -S <SUNetID>_cs
```
Set variables to use during the rest of the installation
Replace \<SUNetID\> with your SUNetID
Replace \<LicenseID\> with your License ID
Replace \<PORTNum\> with your selected Port Number
```
export SUNETID=<SUNetID>
export CS_PATH=$GROUP_HOME/$SUNETID_cs
export LICENSE_ID=<LicenseID>
export PORT_NUM=<PORTNum>
```
Create a folder to download into
```
mkdir $CS_PATH
cd $CS_PATH
mkdir cryosparc_db
```
Download
```
curl -L https://get.cryosparc.com/download/master-latest/$LICENSE_ID -o cryosparc_master.tar.gz
curl -L https://get.cryosparc.com/download/worker-latest/$LICENSE_ID -o cryosparc_worker.tar.gz
tar -xf cryosparc_master.tar.gz cryosparc_master
tar -xf cryosparc_worker.tar.gz cryosparc_worker
```
### Step 3 : Install CryoSPARC
Install CryoSPARC Master
```
cd cryosparc_master
./install.sh --license $LICENSE_ID --hostname sh03-11n13.int --dbpath $CS_PATH/cryosparc_db --port $PORT_NUM
```
Start CryoSPARC
```
./bin/cryosparcm start
```
Create the login account you will use. Replace each of the five fields with your own information before copy-pasting!!!
```
cryosparcm createuser --email "<e-mail>" \
                      --password "<password>" \
                      --username "<username>" \
                      --firstname "<firstname>" \
                      --lastname "<lastname>"
```
Install CryoSPARC Worker
```
cd ..
cd cryosparc_worker
ml cuda/11.7.1
./install.sh --license $LICENSE_ID --cudapath $CUDA_HOME
./bin/cryosparcw connect --worker sh03-11n13 --master sh03-11n13 --port $PORT_NUM --nossd
cd ..
```
Prepare to connect master to worker. Copy and paste three following blocks of code
```
cat <<EOF >  cluster_info.json
{
    "name" : "barnes-sherlock",
    "worker_bin_path" : "$CS_PATH/cryosparc_worker/bin/cryosparcw",
    "cache_path" : "$GROUP_SCRATCH",
    "cache_reserve_mb" : 10000,
    "cache_quota_mb": 1000000,
    "send_cmd_tpl" : "{{ command }}",
    "qsub_cmd_tpl" : "sbatch {{ script_path_abs }}",
    "qstat_cmd_tpl" : "squeue -j {{ cluster_job_id }}",
    "qdel_cmd_tpl" : "scancel {{ cluster_job_id }}",
    "qinfo_cmd_tpl" : "sinfo",
    "transfer_cmd_tpl" : "scp {{ src_path }} loginnode:{{ dest_path }}"
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
#SBATCH -p cobarnes
#SBATCH -N 1
#SBATCH -n 1
#SBATCH --gpus=0
#
#SBATCH -t 7-00:00:00
#SBATCH --signal=B:SIGUSR1@360
#
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=$SUNETID@stanford.edu

_resubmit() {
    ## Resubmit the job for the next execution
    echo "$(date): job $SLURM_JOBID received SIGUSR1 at $(date), re-submitting"
    cryosparcm stop
    sbatch $0
}
trap _resubmit SIGUSR1

cd $CS_PATH

echo
echo "Loading cryosparc GUI"
echo

cryosparcm start

echo "Loaded cryosparc GUI"
echo

echo "$(date): job $SLURM_JOBID starting on $SLURM_NODELIST"
while true; do
    echo "$(date): normal execution"
    sleep 300
done
EOF

```
Connect CryoSPARC to the cluster
```
cryosparcm cluster connect
```
### Step 4 : Start the CryoSPARC GUI
The max time for a Sherlock job is 7 days. This code will start a job that will resubmit a job every 7 days to restart your CryoSPARC GUI. If you start a job that doesn't finish before the GUI restarts, it'll probably be cancled. I would honestly recommend canceling this job submission each time you're done for the day and resubmit the above code block each time you want to start working again.
```
sbatch cs-master.sh
```
To cancel the job when you're done
```
scancel -n cs-master
```
To check if your job has started
```
squeue -u $SUNETID
```
### Step 5 : Connect to the CryoSPARC GUI
Terminate the screen
```
exit
```
Exit the dev mode
```
exit
```
Then, on your own separate terminal (NOT Sherlock), replacing \<SUNetID\> with your SUNetID (this should be similar to logging on to Sherlock) and \<PORTNum\> with your Port Number
```
ssh -XYNfL \<PORTNum\>:sh03-11n13:\<PORTNum\> <SUNetID>@sherlock.stanford.edu
```
Then on any browser on your computer, go to the following url, replacing \<PORTNum\> with your Port Number
```
localhost:<PORTNum>
```
Note: Step 4 can take 5-10 minutes to start up (or faster), so continue to refresh if you don't see anything yet
Once you see the login screen, you can log in with the credentials you inputted at step 3
### Step 6 : Configure CryoSPARC
1. Once logged in, go to admin (key symbol on the left)
2. Go to Cluster Configuration Tab
3. Add a few Key-Value pairs, replacing \<SUNetID\> with your SUNetID

> Key = time_requested | Value = 24:00:00

> Key = partition_requested | Value = cobarnes

> Key = cpu_requested | Value = 1

> Key = sunetid | Value = \<SUNetID\>

And you're done! Test out the functionality of the installation by processing with some small sample batch.

### Step 7 : Submit Jobs
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

## Storage Management
1. Let users know not to use CryoSPARC or do any related activities
2. Ensure sufficient space at group home (enough for some degree of read/write possible)
3. Ensure master node is running with sufficient job time left
4. Turn on maintenance mode
```
cryosparcm maintenancemode on
```
5. Add a message of the day to indicate the change
```
cryosparcm cli "set_instance_banner(True, 'Maintenance Mode On', 'Memory is being managed; please do not do any work here at the moment')"
```
6. Ensure no more jobs running or submitted
7. Detach and/or delete any unncessary projects
8. Remove detached projects from the database. This should not affect the project folder itself
9. Backup into a scratch directory, then note its size
```
TEMP_CS_DIR_BACKUP="/scratch/users/jnoh2/cs-temp-backup"
cryosparcm backup --dir="$TEMP_CS_DIR_BACKUP" #Run this as a job
```
9. Note the size of the original cryosparc instance
10. Run compaction through MongoDB
```
cryosparcm restart
cryosparcm compact #Run this as a job
```
11. Note the size of the new cryosparc instance and compare to the backup + original sizes
12. Store a backup copy in group_home
13. Turn maintenance mode off
```
cryosparcm maintenancemode off
```
14. Turn message of the day off
```
cryosparcm cli "set_instance_banner(False)"
```
15. Let users know to check for integrity of their projects

## Updating versions
1. Let users know not to use CryoSPARC or do any related activities
2. Ensure sufficient space at group home (~10 Gb)
3. Ensure master node is running with sufficient job time left
4. Turn on maintenance mode
```
cryosparcm maintenancemode on
```
5. Add a message of the day to indicate the change
```
cryosparcm cli "set_instance_banner(True, 'Maintenance Mode On', 'CryoSPARC is being updated; please do not use')"
```
6. Ensure no more jobs running or submitted
7. Backup into a scratch directory
```
TEMP_CS_DIR_BACKUP="/scratch/users/jnoh2/cs-temp-backup"
cryosparcm backup --dir="$TEMP_CS_DIR_BACKUP" #Run this as a job
```
8. Carry out a complete shutdown. If the ps command yields zombie cryosparc processes, kill the process that has "supervisord" in its process name.
```
cryosparcm stop
ps -weo pid,ppid,start,cmd | grep -e cryosparc -e mongo | grep -v grep
```
9. Confirm complete shutdown
```
ps -weo pid,ppid,start,cmd | grep -e cryosparc -e mongo | grep -v grep
cryosparcm status
```
10. Check for updates
```
cryosparcm update --check
```
11. If there are updates, go to the folder with the cryosparc installation and copy master and worker tar files into archive
12. Run the update
```
cryosparcm update #Run this as a job
```
13. Once complete, turn message of the day off
```
cryosparcm cli "set_instance_banner(False)"
```
