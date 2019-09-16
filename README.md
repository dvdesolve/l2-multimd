# l2-multimd
Management system to run several molecular dynamics simulations from one batch job on Lomonosov-2 cluster


## What is it?
This tool allows you to run several molecular dynamics simulations on Lomonosov-2 cluster simultaneously using only one SLURM job. Total number of nodes needed for allocation auto-computed according to provided taskfile.


## Dependencies
You need `bash` interpreter of version 4.0 or higher


## How to install
Clone this repo (or download archive) and extract in your home folder on Lomonosov-2 cluster. Then run `install.sh` and it will install all needed files to the `~/_scratch/opt/l2-multimd`.


## Usage
Load all needed modules and set environment variables if necessary. Don't forget about SLURM itself (script will remind you if `sbatch` command isn't found)! Then copy all necessary folders and files for MD simulations somewhere to scratch filesystem. After that prepare the **TASKFILE** (see corresponding chapter below) and set necessary directives. Finally, `cd` into your **DATAROOT** (see below), choose necessary engine and run `~/_scratch/opt/l2-multimd/multimd.sh engine TASKFILE`.


## **TASKFILE** synopsis
**TASKFILE** consists of pairs *DIRECTIVE params*. Comments are allowed and marked with `#`. You can't use them inside line - only the whole line could be commented out. Any extra spaces at the beginning of the line are ignored. Empty lines are also ignored. Directive keywords are case-insensitive.

Here is the full list of supported directives (as of version 0.4.3):
* **DATAROOT**
* **AMBERROOT**
* **NAMDROOT**
* **GAUSSIANROOT**
* **RUNTIME**
* **PARTITION**
* **NUMNODES**
* **BIN**
* **TASK**

Some of the directives (**DATAROOT**, **AMBERROOT**/**NAMDROOT**/**GAUSSIANROOT** and **TASK**) are vital and should reside in **TASKFILE** in any case. **RUNTIME**, **PARTITION**, **NUMNODES** and **BIN** have some reasonable defaults hardcoded in `multimd.sh`. All unknown directives are ignored.

#### **DATAROOT**
This is the root directory where folders with data for MD simulations are stored. `multimd.sh` seeks here for the tasks directories. Value of the directive may contain whitespaces but in that case the whole path should be quoted. Remember that on Lomonosov-2 cluster all computations are carried out on scratch filesystem!

Syntax:
`DATAROOT /path/to/MD/root/dir`

#### **AMBERROOT**
This is the root directory where AMBER computational package is installed (`bin`, `lib` and other directories should sit here). Path may contain whitespaces but should be enclosed in quotes. Because of how Lomonosov-2 cluster works AMBER distrib should reside somewhere on scratch filesystem.

Syntax:
`AMBERROOT /path/to/amber/installation`

#### **NAMDROOT**
This is the root directory where NAMD computational package is installed (`namd2`, `numd-runscript.sh` and other files should sit here). Path may contain whitespaces but should be quoted. Because of how Lomonosov-2 cluster works NAMD distrib should reside on scratch filesystem too.

Syntax:
`NAMDROOT /path/to/namd/installation`

#### **GAUSSIANROOT**
This is the root directory where Gaussian computational package is installed. `gVER` (where `gVER` should be the same as **BIN** directive, e. g. `g09` or `g16`), `gv` and (perhaps) other directories should sit here. Path may contain whitespaces but should be quoted. Because of the nature of Lomonosov-2 cluster Gaussian installation should reside on scratch filesystem. **Important:** only use that engine if you've licensed Gaussian installed!

Syntax:
`GAUSSIANROOT /path/to/gaussian/installation`

#### **RUNTIME**
Sets the runtime limit for the whole bunch of tasks. After that time SLURM will interrupt the job. Default value is `05:00`.

Syntax:
`RUNTIME DD-HH:MM:SS`
NB: any higher part of runtime specification is optional, e. g. you could use such as `RUNTIME 30:00`

#### **PARTITION**
Sets the cluster partition to run simulation on.

Syntax:
`PARTITION partition-name`
Number of CPU cores and GPU cards per node is computed automatically and depends on `partition-name`. Possible values are `test`, `compute` and `pascal`. Default value is `test`

#### **NUMNODES**
Sets default number of nodes per task. Useful if every task from the given list should use the same number of nodes. Default value is `1`.

Syntax:
`NUMNODES n`

#### **BIN**
This is default binary which should be used to perform calculations. Useful if every task uses the same binary executable. May contain spaces (quotes are necessary in this case). Default value is `sander`. **Important:** if you're using Gaussian engine then **GAUSSIANROOT** should contain directory which is named the same as **BIN** directive, for example: `g03`, `g09`, `g16`!

Syntax:
`BIN executable-name`

#### **TASK**
This is the core directive of job queueing. It allows you to specify directory name for every task and (in case AMBER engine is used) supply AMBER-friendly list of parameters such as topology files, config files, restart files and much more. The only mandatory argument is directory name for the task. Other parameters could be derived automatically. Unknown parameters are ignored. All parameters (with the exception of nodes number) can contain whitespaces, but remember about quotation!

Syntax:
`TASK dir-name [{-N|--nodes n} | {-T|--threads t}] [-b|--bin executable-name] [-i|--cfg config] [-o|--out output] [-p|--prmtop prmtop] [-c|--inpcrd coordinates] [-r|--restrt restart] [-ref|--refc restraints] [-x|--mdcrd trajectory] [-v|--mdvel velocities] [-inf|--mdinfo info] [-cpin cph-input] [-cpout cph-output] [-cprestrt cph-restart] [-groupfile remd-groupfile] [-ng replicas] [-rem re-type]`

##### `dir-name`
This is the directory name where all necessary files for one task is stored.

##### `-N|--nodes n`
Number of nodes for executing task in parallel. If not specified then the value of **NUMNODES** is used. If `-T|--threads t` option is present then it will obsolete current option (only for certain binaries/engines, see below). Also see the [parallelization policy](#parallelization-policy) for more details.

##### `-T|--threads t`
Number of threads for executing task in parallel. The number of nodes for supplying this threads count is computed automatically and based on selected **PARTITION**. If `-N|--nodes n` option is present then current option will take precedence over it. This directive has effect only for NAMD engine (`namd2` binary) and some executables for AMBER engine: `sander.MPI`, `pmemd.MPI`, `pmemd.cuda.MPI`. Also see the [parallelization policy](#parallelization-policy) for more details.

##### `-b|--bin executable-name`
Replacement for default **BIN** executable. Allows to use specific binary for task execution.

##### `-i|--cfg config`
File where all settings for calculation are specified. Default value is `<dir-name>.in` in case of AMBER engine, `<dir-name>.conf` if NAMD engine is used and `<dir-name>.gin` for Gaussian engine.

##### `-o|--out output`
Where all output is kept. Default value is `<dir-name>.out`.

##### `-p|--prmtop prmtop`
*AMBER-specific directive.* Topology file for task. Default value is `<dir-name>.prmtop`.

##### `-c|--inpcrd coordinates`
*AMBER-specific directive.* File with starting coordinates (and velocities, probably) for run. Default value is `<dir-name>.ncrst`.

##### `-r|--restrt restart`
*AMBER-specific directive.* AMBER will save restart snapshots here. Default value is `<dir-name>.ncrst`. NB: there could be collision with `<coordinates>` file!

##### `-ref|--refc restraints`
*AMBER-specific directive.* AMBER reads positional restraints from that file. There is no default value for this parameter.

##### `-x|--mdcrd trajectory`
*AMBER-specific directive.* File in which MD trajectory should be saved. Default value is `<dir-name>.nc`.

##### `-v|-mdvel velocities`
*AMBER-specific directive.* AMBER will save velocities here, unless `ntwv` parameter in simulation config is equal to `-1`. There is no default value for this parameter.

##### `-inf|--mdinfo info`
*AMBER-specific directive.* File where all MD run statistics are kept. Default value is `<dir-name>.mdinfo`.

##### `-cpin cph-input`
*AMBER-specific directive.* File with protonation state definitions. Default value is empty.

##### `-cpout cph-output`
*AMBER-specific directive.* Protonation state definitions will be saved here. Default value is empty.

##### `-cprestrt cph-restart`
*AMBER-specific directive.* Protonation state definitions for restart will be saved here. Default value is empty.

##### `-groupfile remd-groupfile`
*AMBER-specific directive.* Reference groupfile for replica exchange run. Default value is empty.

##### `-ng replicas`
*AMBER-specific directive.* Number of replicas. Default value is empty.

##### `-rem re-type`
*AMBER-specific directive.* Replica exchange type. Default value is empty.


## Parallelization policy
**l2-multimd** software manages it's own policy to run jobs in parallel. Specific technique depends on selected engine, executable and number of nodes/threads requested. Currently Lomonosov-2 cluster provides the following partitions for performing calculations:

Partition name | CPU type | GPU type | Number of CPU cores (`NUMCORES`) | Number of GPUs | Available RAM, Gb
---------------|----------|----------|----------------------------------|----------------|------------------
`test` | Intel Haswell-EP E5-2697v3, 2.6 GHz | NVidia Tesla K40M | 14 | 1 | 64
`compute` | Intel Haswell-EP E5-2697v3, 2.6 GHz | NVidia Tesla K40M | 14 | 1 | 64
`pascal` | Intel Xeon Gold 6126, 2.6 GHz | Nvidia P100 | 12 | 2 | 96

Here are basic rules for all possible combinations supported by **l2-multimd**.

#### AMBER engine
Executables `sander`, `pmemd` and `pmemd.cuda` can only be run in single instance (1 thread and 1 node). Thus, option `-T|--threads t` is incompatible with these executables.

If there are no `-T|--threads t` option is specified in task definition then `sander.MPI` and `pmemd.MPI` will be run with `NODES * NUMCORES` threads without oversubscribing. However, if that option is present then `-N|--nodes n` option will be ignored and required number of nodes for the task will be recalculated according to the `NUMCORES` property of selected partition.

For `pmemd.cuda.MPI` executable thread allocation depends on selected partition. If `pascal` partition has been requested then 2 threads per node will be allocated for execution and both GPUs will be available for calculations. Otherwise, `pmemd.cuda.MPI` will have only 1 thread per node. Option `-T|--threads t` is incompatible with this executable.

#### NAMD engine
Threads number for calculation will be the following: `THREADS = NODES * NUMCORES`. If `pascal` partition has been requested then both GPUs will be available for `namd2`. Option `-T|--threads t` is incompatible with this engine.

#### Gaussian engine
Currently **l2-multimd** doesn't support Linda + Gaussian bindings so all tasks will be run *exactly on 1 node*, however the number of threads depends on user-supplied config file. Because of specific way of setting Gaussian calculations in parallel it's all up to user to prepare config input properly to run on desirable number of CPU cores and GPU cards. If `pascal` partition has been requested then both GPUs will be available for Gaussian executables. Option `-T|--threads t` is incompatible with this engine.
