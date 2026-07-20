# Jupyter Lab via SLURM

Launch a Jupyter Lab server on a compute node and access it from your laptop using an SSH tunnel.

!!! tip "Why bother?"
    Running notebooks on the login node is against RCC policy and will get your session killed under load.
    This workflow gives you a full compute node — RAM, CPUs, optional GPU — while keeping the familiar
    Jupyter interface in your local browser.

---

## Prerequisites

- An RCC account with access to Midway
- A Python/conda environment with `jupyterlab` installed — the script loads `python/miniforge-25.3.0`; swap for your own module or conda env
- SSH access from your laptop to the Midway login node

---

## The Script

Save this as `jupyter.sbatch` in your home or project directory on Midway.

```bash title="jupyter.sbatch"
#!/bin/bash
#SBATCH --job-name=jupyter_lab
#SBATCH --account=<pi-group>        # (1)
#SBATCH --partition=<partition>     # (2)
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1           # (3)
#SBATCH --mem=16G
#SBATCH --time=05:00:00
#SBATCH --output=jupyter_%j.log
#SBATCH --error=jupyter_%j.log

module load python/miniforge-25.3.0 # (4)

node=$(hostname -s)                 # short hostname of the compute node
port=$(shuf -i 15001-30000 -n 1)   # random high port — avoids collisions
user=$(whoami)

node_ip=$(getent hosts "$node" | awk '{print $1}')
[[ -z "$node_ip" ]] && node_ip=$node  # fall back to hostname if DNS lookup fails
echo "DEBUG: node=$node  node_ip=$node_ip" 1>&2

# Derive login-node hostname from the submit host
# e.g. midway3-login2 → midway3.rcc.uchicago.edu
cluster=${SLURM_SUBMIT_HOST%%-*}
cluster=${cluster%%.*}
login="${cluster}.rcc.uchicago.edu"

export JUPYTER_TOKEN=$(openssl rand -hex 24)  # (5)

connect_file="jupyter_connect_${SLURM_JOB_ID}.txt"
cat > "${connect_file}" <<INSTRUCTIONS
========================================================================
Jupyter Lab  |  job ${SLURM_JOB_ID}  |  ${node}:${port}

1) On your LAPTOP, open a tunnel:
     ssh -N -L ${port}:${node_ip}:${port} ${user}@${login}
     (add -f to background it: -f -o ExitOnForwardFailure=yes)
2) Open this URL in your browser (token already included):
     http://localhost:${port}/lab?token=${JUPYTER_TOKEN}

To stop:  scancel ${SLURM_JOB_ID}
========================================================================
INSTRUCTIONS

echo "Connection instructions written to: ${connect_file}" 1>&2

jupyter lab --no-browser --ip=${node_ip} --port=${port} --notebook-dir="${HOME}"
```

1. Your PI's RCC allocation, e.g. `pi-jsmith`. Run `accounts` on Midway to list yours.
2. E.g. `caslake`, `bigmem`, `gpu2`. See [RCC partitions](https://rcc.uchicago.edu/docs/using-midway/partitions/).
3. Increase for parallel/multi-threaded workloads. Add `--gres=gpu:1` for GPU access.
4. Swap for your own module or add `conda activate myenv` after this line.
5. A random 48-character token — no password prompt needed when opening the URL.

---

## Usage

### 1. Submit the job

```bash
sbatch jupyter.sbatch
# Submitted batch job 12345678
```

### 2. Wait for the job to start, then read the connection file

```bash
watch squeue -u $USER   # wait until status shows R (running)

cat jupyter_connect_12345678.txt
```

The file contains the exact `ssh` command and browser URL with the token already embedded.

### 3. Open the SSH tunnel from your laptop

Copy the `ssh -N -L ...` line and run it in a terminal **on your local machine**:

```bash
# Values will differ for your job:
ssh -N -L 27543:10.50.0.42:27543 cnetid@midway3.rcc.uchicago.edu
```

!!! note
    The terminal will hang — that's expected. The tunnel stays open as long as this process runs.
    To background it instead, use `-f -o ExitOnForwardFailure=yes` in place of `-N`.

### 4. Open Jupyter Lab in your browser

Paste the `http://localhost:PORT/lab?token=...` URL into your browser.  
The token is already in the URL — no password prompt.

### 5. Stop the job when done

```bash
scancel 12345678
```

---

## Tips

=== "More resources"
    Bump `--cpus-per-task`, `--mem`, or add `--gres=gpu:1` for GPU work.
    You can also use `--partition=bigmem` for large memory jobs.

=== "Custom notebook root"
    Edit the `--notebook-dir` flag at the end of the script to point to a specific project directory
    instead of `$HOME`.

=== "Custom conda env"
    Replace the `module load` line with:
    ```bash
    source ~/.bashrc
    conda activate myenv
    ```

=== "Persistent tunnel"
    Add to `~/.ssh/config` on your laptop to prevent idle timeouts:
    ```
    Host midway3.rcc.uchicago.edu
        ServerAliveInterval 60
        ServerAliveCountMax 5
    ```
