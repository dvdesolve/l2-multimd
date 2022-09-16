# l2-multimd
Management system to run several molecular dynamics simulations from one batch job on Lomonosov-2 cluster


## What is it?
This tool allows you to run several molecular dynamics simulations on Lomonosov-2 cluster simultaneously using only one SLURM job. Total number of nodes needed for allocation auto-computed according to provided [taskfile](#taskfile-synopsis).

Though this tool has been designed specially for [Lomonosov-2 supercomputer cluster](https://parallel.ru/cluster/lomonosov2.html) it can be easily modified for use with any cluster which uses [SLURM workload manager](https://slurm.schedmd.com/). Even if your cluster uses another workload manager **l2-multimd** can still be adapted for it without any major code modifications.

Feel free to use it, modify it and contribute to it by reporting bugs, suggesting enhancements, feature requests and pull requests.


## Supported engines
Currently the following engines are supported:
- [AMBER](https://ambermd.org/)
- [NAMD](https://www.ks.uiuc.edu/Research/namd/)
- [Gaussian](https://gaussian.com/). **WARNING**: support is still experimental because we have no Gaussian distribution so run wrappers are based on publicly available documentation only! No real checks were made at all so a lot of bugs possibly hide inside. Feel free to suggest changes/bugfixes/improvements via issues and pull requests.
- [CP2K](https://www.cp2k.org/)

## Dependencies
### Installation
For successfull installation make sure you have the following packages/utilities installed and available:
- `bash` (>= 4.0)
- `md5sum`
- `awk` (make sure that `awk` executable is in your `PATH`)
- `sed`

### Usage
To use **l2-multimd** on your cluster make sure that the following packages/utilities are available in your environment:
- `bash` (>= 4.0)
- SLURM package (`sbatch` and `srun` executables)
- `awk`
- `sed`
Also if you want to be able to run MPI versions of executables please install MPI package which provides `mpirun` binary (OpenMPI should work fine)


## How to install
Clone this repo (or download archive) and extract in your home folder on Lomonosov-2 cluster. Then run `install.sh` and it will install all needed files to the `~/_scratch/opt/l2-multimd`.


## Usage
Load all necessary modules (if you use `env-modules`) and/or set proper environment variables. Don't forget about SLURM itself (script will remind you if `sbatch` command isn't found). Then prepare file tree for your computations somewhere on scratch filesystem. After that prepare the `<taskfile>` (see [corresponding chapter below](#taskfile-synopsis)) and set necessary keywords. Finally, `cd` where your `<taskfile>` resides, choose necessary `<engine>` and run:
```
~/_scratch/opt/l2-multimd/multimd.sh <engine> <taskfile>
```
To make things even easier you can employ useful alias which **l2-multimd** provides for you: include in your `~/.bashrc` file the following lines (where `<username>` refers to your user name on cluster):
```
if [[ -e "/home/<username>/_scratch/opt/l2-multimd/bash-completion/multimd" ]]
then
    source /home/<username>/_scratch/opt/l2-multimd/bash-completion/multimd
fi
```
Don't forget to source `~/.bashrc` from your `~/.bash_profile` and re-login to make changes effective. After that you could run multiple jobs at once with this simple incantation:
```
l2-multimd <engine> <taskfile>
```


## **TASKFILE** synopsis
**TASKFILE** consists of pairs `KEYWORD options`. Comments are allowed and marked with `#`. You can't use them inside line - only the whole line could be commented out. Any extra spaces at the beginning of the line are ignored. Empty lines are also ignored. Keywords are case-insensitive.

**TASKFILE** is being processed in line-by-line fashion so keep it in mind. For example, task definitions can make use of some job-wide defaults such as number of nodes and executable names so if you want your defaults to be applied properly please be sure that all desirable task definitions are below the corresponding job-wide keywords.

Keywords can occur in **TASKFILE** several times. Every next keyword overrides previous incantations (with the exception of **TASK** keywords - it simply creates one more task). However it makes sense to use keywords several times only for two of them - **NUMNODES** and **BIN** and only if you want to run large job with dozens of tasks. Let's consider the following example:
```
...
# this is the first bunch of tasks; they should be run with sander.MPI and on 3 cluster nodes each
BIN sander.MPI
NUMNODES 3
TASK run1
TASK run2
...
TASK runN

# the rest of the tasks should be run with pmemd.cuda and only on 1 node
BIN pmemd.cuda
NUMNODES 1
TASK runN1
TASK runN2
...
TASK runNM
...
```
Here tasks in directories `run1` to `runN` will be run with `sander.MPI` executable and on 3 nodes per task. During the same job tasks in directories `runN1` to `runNM` will use `pmemd.cuda` and 1 node per task.

Here is the full list of supported keywords:
* **DATAROOT**
* **AMBERROOT**
* **NAMDROOT**
* **GAUSSIANROOT**
* **СP2KROOT**
* **RUNTIME**
* **PARTITION**
* **NUMNODES**
* **BIN**
* **TASK**

Some of the keywords (**DATAROOT**, **AMBERROOT**/**NAMDROOT**/**GAUSSIANROOT**/**СP2KROOT** and **TASK**) are vital and should reside in **TASKFILE** in any case. **RUNTIME**, **PARTITION**, **NUMNODES** and **BIN** have some reasonable defaults hardcoded in `multimd.sh`. All unknown keywords are ignored.

### **DATAROOT**
This is the root directory where folders with data for MD simulations are stored. `multimd.sh` seeks here for the tasks directories. This keyword may contain whitespaces but in that case the whole path should be quoted. Remember that on Lomonosov-2 cluster all computations are carried out on scratch filesystem!

Syntax:
`DATAROOT /path/to/MD/root/dir`

### **AMBERROOT**
This is the root directory where AMBER computational package is installed (`bin`, `lib` and other directories should reside here). Path may contain whitespaces but should be enclosed in quotes. Because of how Lomonosov-2 cluster works AMBER distrib should be installed somewhere on scratch filesystem. Ignored if selected engine is not `amber`.

Syntax:
`AMBERROOT /path/to/amber/installation`

### **NAMDROOT**
This is the root directory where NAMD computational package is installed (`namd2`, `numd-runscript.sh` and other files should sit here). Path may contain whitespaces but should be quoted. Because of how Lomonosov-2 cluster works NAMD distrib should be installed on scratch filesystem too. Ignored if selected engine is not `namd`.

Syntax:
`NAMDROOT /path/to/namd/installation`

### **GAUSSIANROOT**
This is the root directory where Gaussian computational package is installed. `gVER` (where `gVER` should be the same as **BIN** keyword, e. g. `g09` or `g16`), `gv` and (perhaps) other directories should sit here. Path may contain whitespaces but should be quoted. Because of the nature of Lomonosov-2 cluster Gaussian installation should be installed on scratch filesystem. **Important:** only use that engine if you've licensed Gaussian installed! Ignored if selected engine is not `gaussian`.

Syntax:
`GAUSSIANROOT /path/to/gaussian/installation`

### **CP2KROOT**
This is the directory where CP2K executable files (`cp2k.<VERSION>`, `cp2k_shell.<VERSION>`, `graph.<VERSION>`, `libcp2k_unittest.<VERSION>`) are located. Due to extreme variety of CP2K custom build configurations it cannot be predicted from CP2K root directory. Usually these executables are located in `exe/<ARCH>` subdirectory of cp2k root directory, for example, `/home/user/cp2k/exe/local_cuda_plumed`. Path may contain whitespaces but should be quoted. Because of how Lomonosov-2 cluster works CP2K distrib and all its computational libraries should be installed on scratch filesystem too. Ignored if selected engine is not `cp2k`.

Syntax:
`CP2KROOT /path/to/cp2k/installation/`

### **RUNTIME**
Sets the runtime limit for the whole bunch of tasks. After that time SLURM will interrupt the job. Default value is `05:00`.

Syntax:
`RUNTIME DD-HH:MM:SS`
NB: any higher part of runtime specification is optional, e. g. you could use such as `RUNTIME 30:00`

### **PARTITION**
Sets the cluster partition to run simulation on.

Syntax:
`PARTITION partition-name`
Number of CPU cores and GPU cards per node is computed automatically and depends on `partition-name`. Possible values are `test`, `compute` and `pascal`. Default value is `test`

### **NUMNODES**
Sets default number of nodes per task. Useful if every task from the given list should use the same number of nodes. Default value is `1`.

Syntax:
`NUMNODES n`

### **BIN**
This is default binary which should be used to perform calculations. Useful if every task uses the same binary executable. May contain spaces (quotes are necessary in this case). Default value is `sander`. **Important:** if you're using Gaussian engine then **GAUSSIANROOT** should contain directory which is named the same as **BIN** keyword, for example: `g03`, `g09`, `g16`!

Syntax:
`BIN executable-name`

### **TASK**
This is the core keyword for job queueing. It allows you to specify directory name for every task, input config files, output files and, if AMBER engine is used, to specify AMBER-compatible list of options such as topology files, restart files etc. The only mandatory argument is directory name for the task. Other options could be derived automatically (see default values for those options). Unknown options are ignored. All options (with the exception of nodes/threads number) can contain whitespaces, but remember about quotation!

Syntax:
`TASK dir-name [{-N|--nodes n} | {-T|--threads t}] [-b|--bin executable-name] [-i|--cfg config] [-o|--out output] [-p|--prmtop prmtop] [-c|--inpcrd coordinates] [-r|--restrt restart] [-ref|--refc restraints] [-x|--mdcrd trajectory] [-v|--mdvel velocities] [-e|--mden energies] [-inf|--mdinfo info] [-cpin cph-input] [-cpout cph-output] [-cprestrt cph-restart] [-groupfile remd-groupfile] [-ng replicas] [-rem re-type]`

#### Common options
These options have the same meaning for any engine.

##### `dir-name`
This is the directory name where all necessary files for one task is stored. Absolutely required.

##### `-N|--nodes n`
Number of nodes for executing task in parallel. If not specified then the value of **NUMNODES** is used. If `-T|--threads t` option is present then it will obsolete current option (only for certain binaries/engines, see below). Also see the [parallelization policy](#parallelization-policy) for more details.

##### `-T|--threads t`
Number of threads for executing task in parallel. The number of nodes for supplying this threads count is computed automatically and based on selected **PARTITION**. If `-N|--nodes n` option is present then current option will take precedence over it. This option has effect only for some executables of AMBER engine: `sander.MPI`, `pmemd.MPI`, `pmemd.cuda.MPI`. Also see the [parallelization policy](#parallelization-policy) for more details.

##### `-b|--bin executable-name`
Replacement for default **BIN** executable. Allows to use specific binary for task execution.

##### `-i|--cfg config`
File where all settings for calculation are specified. Default value is `<dir-name>.in` in case of AMBER engine, `<dir-name>.conf` if NAMD engine is used, `<dir-name>.gin` for Gaussian engine and `<dir-name>.inp` for CP2K engine.

##### `-o|--out output`
Where all output is kept. Default value is `<dir-name>.out`.

#### AMBER-specific options
These options are specific for AMBER engine. If another engine is requested these options will be skipped.

##### `-p|--prmtop prmtop`
Topology file for task. Default value is `<dir-name>.prmtop`.

##### `-c|--inpcrd coordinates`
File with starting coordinates (and velocities, probably) for run. Default value is `<dir-name>.ncrst`.

##### `-r|--restrt restart`
AMBER will save restart snapshots here. Default value is `<dir-name>.ncrst`. NB: there could be collision with `<coordinates>` file!

##### `-ref|--refc restraints`
AMBER reads positional restraints from that file. There is no default value for this parameter.

##### `-x|--mdcrd trajectory`
File in which MD trajectory should be saved. Default value is `<dir-name>.nc`.

##### `-v|-mdvel velocities`
AMBER will save velocities here, unless `ntwv` parameter in simulation config is equal to `-1`. There is no default value for this parameter.

##### `-e|-mden energies`
AMBER will save energies here. There is no default value for this parameter.

##### `-inf|--mdinfo info`
File where all MD run statistics are kept. Default value is `<dir-name>.mdinfo`.

##### `-cpin cph-input`
File with protonation state definitions. Default value is empty.

##### `-cpout cph-output`
Protonation state definitions will be saved here. Default value is empty.

##### `-cprestrt cph-restart`
Protonation state definitions for restart will be saved here. Default value is empty.

##### `-groupfile remd-groupfile`
Reference groupfile for replica exchange run. Default value is empty.

##### `-ng replicas`
Number of replicas. Default value is empty.

##### `-rem re-type`
Replica exchange type. Default value is empty.


## Parallelization policy
**l2-multimd** software manages it's own policy to run jobs in parallel. Specific technique depends on selected engine, executable and number of nodes/threads requested. Currently Lomonosov-2 cluster provides the following partitions for performing calculations:

Partition name | CPU type | GPU type | Number of CPU cores (`NUMCORES`) | Number of GPUs (`NUMGPUS`) | Available RAM, Gb
---------------|----------|----------|----------------------------------|----------------|------------------
`test` | Intel Haswell-EP E5-2697v3, 2.6 GHz | NVidia Tesla K40M | 14 | 1 | 64
`compute` | Intel Haswell-EP E5-2697v3, 2.6 GHz | NVidia Tesla K40M | 14 | 1 | 64
`pascal` | Intel Xeon Gold 6126, 2.6 GHz | NVidia Tesla P100 | 12 | 2 | 92
`volta1` | Intel Xeon Gold 6126, 2.6 GHz | NVidia Tesla V100 | 12 | 2 | 92
`volta2` | 2x Intel Xeon Xeon Gold 6240, 2.6 GHz | NVidia Tesla V100 | 36 | 2 | 1536 


Here are basic rules for all possible combinations supported by **l2-multimd**.

### AMBER engine
Executables `sander`, `pmemd` can only be run in single instance (1 thread and 1 node). Thus, option `-T|--threads t` is incompatible with these executables.

For `pmemd.cuda` the script will place independent tasks on all GPUs present on nodes. For example, if you asked for 8 tasks on `pascal` partition with 2 GPUs per node, the script will allocate 4 nodes and run 2 tasks per node on different GPUs. You can override this behavior by setting desired number of tasks per node in `-T|--threads t` variable (but not more than GPUs per node), for example, if your task consumes a lot of memory and have to be run in single instance per node.
You should create the number of tasks divisible by number of GPUs per node for maximum node utilization efficiency.

If there are no `-T|--threads t` option is specified in task definition then `sander.MPI` and `pmemd.MPI` will be run with `NODES * NUMCORES` threads without oversubscribing. However, if that option is present then `-N|--nodes n` option will be ignored and required number of nodes for the task will be recalculated according to the `NUMCORES` property of selected partition.

For `pmemd.cuda.MPI` executable thread allocation depends on selected partition. If `pascal` partition has been requested then 2 threads per node will be allocated for execution and both GPUs will be available for calculations. Otherwise, `pmemd.cuda.MPI` will have only 1 thread per node. Option `-T|--threads t` is incompatible with this executable.

### NAMD engine
Threads number for calculation will be the following: `THREADS = NODES * NUMCORES`. If `pascal` partition has been requested then both GPUs will be available for `namd2`. Option `-T|--threads t` is incompatible with this engine.

### Gaussian engine
Currently **l2-multimd** doesn't support Linda + Gaussian bindings so all tasks will be run *exactly on 1 node*, however the number of threads depends on user-supplied config file. Because of specific way of setting Gaussian calculations in parallel it's all up to user to prepare config input properly to run on desirable number of CPU cores and GPU cards. If `pascal` partition has been requested then both GPUs will be available for Gaussian executables. Option `-T|--threads t` is incompatible with this engine.

### CP2K engine
CP2K has three versions with different parallelization models to be used on supercomputer: 
1. **ssmp** version with OpenMP parallelization, which runs only on single node. Variables `OMP_NUM_THREADS` and `MKL_NUM_THREADS` will be set to number of CPU cores. Not recommended for use on multi-node cluster, but can support **CUDA**. The main executable binary is `cp2k.ssmp`.
2. **popt** version with single-threaded MPI parallelization. The script will execute a number of MPI processes equal to number of cores. The main executable binary is `cp2k.popt`.
3. **psmp** version, which provides combined MPI and OpenMP parallelization. This version also can be built with **CUDA** support. Currently script runs a number of MPI processes equal to total number of cores divided by `OMP_NUM_THREADS=MKL_NUM_THREADS=2`. The main executable binary is `cp2k.psmp`. **Recommended for use on Lomonosov-2 with CUDA support**. If `pascal` partition has been requested then both GPUs will be available for CP2K executables.
Option `-T|--threads t` is not yet compatible with this engine.
