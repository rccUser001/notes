---
title: Jupyter Lab via SLURM
parent: Midway (RCC @ UChicago)
nav_order: 1
---

# Jupyter Lab via SLURM
{: .no_toc }

Launch a Jupyter Lab server on a compute node and access it from your laptop using an SSH tunnel.
{: .fs-6 .fw-300 }

---

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

## Why use this?

{: .tip }
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

Save this as `jupyter.sbatch` in your home or project directory on Midway, or [download it directly](https://raw.githubusercontent.com/rccUser001/notes/main/midway/jupyter.sbatch).

```bash
#!/bin/bash
#SBATCH --job-name=jupyter_lab
#SBATCH --account=<pi-group>        # your PI's RCC allocation, e.g. pi-jsmith
#SBATCH --partition=<partition>     # e.g. caslake, bigmem, gpu2
#SBATCH --reservation=<reservation> # e.g. event1
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1           # increase for parallel workloads
#SBATCH --mem=16G
#SBATCH --time=05:00:00
#SBATCH --output=jupyter_%j.log
#SBATCH --error=jupyter_%j.log

module load python/miniforge-25.3.0

node=$(hostname -s)                 # short hostname of the compute node
port=$(shuf -i 15001-30000 -n 1)   # random port — avoids collisions
user=$(whoami)

node_ip=$(getent hosts "$node" | awk '{print $1}')
[[ -z "$node_ip" ]] && node_ip=$node  # fall back to hostname if DNS lookup fails
echo "DEBUG: node=$node  node_ip=$node_ip" 1>&2

cluster=${SLURM_SUBMIT_HOST%%-*}
cluster=${cluster%%.*}
login="${cluster}.rcc.uchicago.edu"

export JUPYTER_TOKEN=$(openssl rand -hex 24)

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

---

## Usage

### 1. Submit the job

```bash
sbatch jupyter.sbatch
# Submitted batch job 12345678
```

### 2. Wait for it to start, then read the connection file

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

{: .note }
The terminal will hang — that's expected. The tunnel stays open as long as this process runs.
To background it instead, use `-f -o ExitOnForwardFailure=yes` in place of `-N`.

### 4. Open Jupyter Lab in your browser

Paste the `http://localhost:PORT/lab?token=...` URL into your browser. No password prompt — the token is already in the URL.

### 5. Stop the job when done

```bash
scancel 12345678
```

---

## Tips

**More resources** — Bump `--cpus-per-task`, `--mem`, or add `--gres=gpu:1` for GPU work.

**Custom notebook root** — Edit the `--notebook-dir` flag at the end of the script.

**Custom conda env** — Replace the `module load` line with:
```bash
source ~/.bashrc
conda activate myenv
```

**Persistent tunnel** — Add to `~/.ssh/config` on your laptop to prevent idle timeouts:
```
Host midway3.rcc.uchicago.edu
    ServerAliveInterval 60
    ServerAliveCountMax 5
```
