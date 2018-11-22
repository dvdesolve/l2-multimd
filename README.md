# l2-multimd
Management system to run several molecular dynamics simulations from one batch job on Lomonosov-2 cluster

## What is it?
This tool allows you to run several molecular dynamics simulations on Lomonosov-2 cluster simultaneously using only one SLURM job. Total number of nodes needed for allocation auto-computed according to provided taskfile.

## How to install
Clone this repo (or download archive) and extract in your home folder on Lomonosov-2 cluster. Then run `install.sh` and it will install all needed files to the `~/_scratch/opt/l2-multimd`.

## Usage
Load all needed modules and set environment variables if necessary. Don't forget about SLURM itself (script will remind you if no `sbatch` command is found)! Then copy all necessary folders and files for MD simulations inside `~/_scratch/...` directory. After that prepare the **TASKFILE** (see chapter below) and set directives properly. Finally, `cd` into your **DATAROOT** (see below) and run `~/_scratch/opt/l2-multimd/multimd.sh TASKFILE`.

## **TASKFILE** synopsis
**TASKFILE** consists of pairs *DIRECTIVE params*. Comments are allowed and marked with `#`. You can't use them inside line - only the whole line could be commented out. Any extra spaces at the beginning of the line are ignored. Empty lines are also ignored. Directive keywords are case-insensitive.

Here is the full list of supported directives (as of version 0.1.0):
* **DATAROOT**
* **AMBERROOT**
* **RUNTIME**
* **PARTITION**
* **NUMNODES**
* **BIN**
* **TASK**

Some of the directives (**DATAROOT**, **AMBERROOT** and **TASK**) are vital and should reside in **TASKFILE** in any case. **RUNTIME**, **PARTITION**, **NUMNODES** and **BIN** have some reasonable defaults hardcoded in `multimd.sh`. All unknown directives are ignored.

#### **DATAROOT**
This is the root directory where folders with data for MD simulations are stored. `multimd.sh` seeks here for the tasks directories. Value of the directive may contain whitespaces but in that case the whole path should be quoted. Remember that on Lomonosov-2 cluster all computations are carried out inside `~/_scratch`!

Syntax:
`DATAROOT /path/to/MD/root/dir`

#### **AMBERROOT**
This is the root directory where AMBER computational package is installed (`bin`, `lib` and other directories should sit here). Again, path may contain whitespaces but should be quoted. Also because of nature of Lomonosov-2 cluster AMBER should reside in `~/_scratch` too.

Syntax:
`AMBERROOT /path/to/AMBER/installation`

#### **RUNTIME**
Sets the runtime limit for the whole bunch of tasks. After that time SLURM will interrupt the job. Default value is `1-00:00:00`.

Syntax:
`RUNTIME DD-HH:MM:SS`
NB: any higher part of runtime specification is optional, e. g. you could use such as `RUNTIME 30:00`

#### **NUMNODES**
Sets default number of nodes per task. Useful if every task from the given list should use the same number of nodes. Default value is `3`.

Syntax:
`NUMNODES n`

#### **BIN**
This is default AMBER binary which should be used to perform calculations. Useful if every task uses the same binary executable. May contain spaces (quotes are necessary in this case). Default value is `pmemd.cuda.MPI`.

Syntax:
`BIN executable-name`

#### **TASK**
This is the core directive of job queueing. It allows you to specify directory name for every task and supply AMBER-friendly list of parameters such as topology files, config files, restart files and much more. The only mandatory argument is directory name for the task. Other parameters could be derived automatically. Unknown parameters are ignored. All parameters (with the exception of nodes number) can contain whitespaces, but remember about quotation!

Syntax:
`TASK dir-name [-N|--nodes n] [-b|--bin executable-name] [-p|--prmtop prmtop] [-i|--config config] [-c|--coord coordinates] [-o|--out output] [-r|--restart restart] [-x|--traj trajectory] [-inf|--mdinfo info]`

##### `dir-name`
This is the directory name where all necessary files for one task is stored.

##### `n`
The number of nodes for that task. If not specified then the value of **NUMNODES** is used.

##### `executable-name`
This is the replacement for default **BIN** executable. Rarely needed.

##### `prmtop`
Topology file for task. Default value is `dir-name.prmtop`

##### `config`
This is the file where all settings for MD simulation is specified. Default value is `dir-name.in`

##### `coordinates`
File with starting coordinates (and velocities, probably) for run. Default value is `dir-name.rst`

##### `output`
Where all output is kept. Default value is `dir-name.out`

##### `restart`
AMBER will save restart snapshots here. Default value is `dir-name.rst`. NB: there could be collision with `coordinates` file!

##### `trajectory`
File in which MD trajectory should be saved. NetCDF-format. Default value is `dir-name.nc`

##### `info`
Place where all MD run statistics are kept. Default value is `dir-name.mdinfo`
