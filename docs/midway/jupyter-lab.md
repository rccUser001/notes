# Running Jupyter Lab on Midway via SLURM

Launch a Jupyter Lab server on a compute node and access it from your laptop using an SSH tunnel.  
This avoids running notebooks on the login node and lets you use full compute resources (RAM, CPUs, GPUs).

---

## Prerequisites

- An RCC account with access to Midway (midway3 or similar)
- Python/conda environment available — the script loads `python/miniforge-25.3.0`; swap for whichever module or conda env you use
- SSH access from your laptop to the Midway login node

---

## The Script

Save this as `jupyter.sbatch` in your home or project directory on Midway.

```bash
#!/bin/bash
#SBATCH --job-name=jupyter_lab
#SBATCH --account=<pi-group>        # your PI's RCC allocation, e.g. pi-jsmith
#SBATCH --partition=<partition>     # e.g. caslake, bigmem, gpu2
#SBATCH --reservation=<reservation> # e.g. event1
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1           # increase for parallel workloads
#SBATCH --mem=16G                   # total RAM for the job
#SBATCH --time=05:00:00             # wall-clock limit HH:MM:SS
#SBATCH --output=jupyter_%j.log     # stdout → this file (%j = job ID)
#SBATCH --error=jupyter_%j.log      # stderr → same file

module load python/miniforge-25.3.0

# ── Gather connection details ──────────────────────────────────────────────────
node=$(hostname -s)                              # short hostname of the compute node
port=$(shuf -i 15001-30000 -n 1)                # random port to avoid collisions
user=$(whoami)

node_ip=$(getent hosts "$node" | awk '{print $1}')
[[ -z "$node_ip" ]] && node_ip=$node            # fall back to hostname if DNS lookup fails
echo "DEBUG: node=$node  node_ip=$node_ip" 1>&2

# Derive the login-node hostname from the submit host (e.g. midway3-login2 → midway3.rcc.uchicago.edu)
cluster=${SLURM_SUBMIT_HOST%%-*}
cluster=${cluster%%.*}
login="${cluster}.rcc.uchicago.edu"

# ── Secure token (no password prompt) ─────────────────────────────────────────
export JUPYTER_TOKEN=$(openssl rand -hex 24)

# ── Write connection instructions to a file ───────────────────────────────────
connect_file="jupyter_connect_${SLURM_JOB_ID}.txt"
cat > "${connect_file}" <<INSTRUCTIONS
========================================================================
Jupyter Lab  |  job ${SLURM_JOB_ID}  |  ${node}:${port}

1) On your LAPTOP, open a tunnel:
     ssh -N -L ${port}:${node_ip}:${port} ${user}@${login}
     (add -f to send it to the background: -f -o ExitOnForwardFailure=yes)
2) Open this URL in your browser (token already included):
     http://localhost:${port}/lab?token=${JUPYTER_TOKEN}

To stop:  scancel ${SLURM_JOB_ID}   (from the login node)
========================================================================
INSTRUCTIONS

echo "Connection instructions written to: ${connect_file}" 1>&2

# ── Start Jupyter Lab ──────────────────────────────────────────────────────────
jupyter lab --no-browser --ip=${node_ip} --port=${port} --notebook-dir="${HOME}"
```

Download the raw file: [`jupyter.sbatch`](jupyter.sbatch)

---

## Usage

### 1. Submit the job

```bash
# On the Midway login node:
sbatch jupyter.sbatch
# → Submitted batch job 12345678
```

### 2. Wait for it to start, then read the connection file

```bash
# Watch until the job is running:
watch squeue -u $USER

# Once it shows R (running), cat the instructions file:
cat jupyter_connect_12345678.txt
```

The file prints the exact `ssh` command and browser URL with the token already embedded.

### 3. Open the SSH tunnel from your laptop

Copy the `ssh -N -L ...` line from the connection file and run it in a terminal on your **local machine**:

```bash
# Example (values will differ for your job):
ssh -N -L 27543:10.50.0.42:27543 cnetid@midway3.rcc.uchicago.edu
```

The terminal will hang — that is normal. The tunnel is active as long as this process runs.  
To background it instead: `ssh -f -o ExitOnForwardFailure=yes -N -L ...`

### 4. Open Jupyter Lab in your browser

Paste the `http://localhost:PORT/lab?token=...` URL from the connection file into your browser.  
No password needed — the token is already in the URL.

### 5. Stop the job when done

```bash
# On the login node:
scancel 12345678
```

---

## Tips

- **Increase resources** by bumping `--cpus-per-task`, `--mem`, or adding `--gres=gpu:1` for GPU work.
- **Change the notebook root** by editing the `--notebook-dir` flag at the bottom of the script.
- **Custom environment** — if you use a conda env, replace `module load ...` with `conda activate myenv` (after sourcing conda init in the script).
- **Persistent tunnel** — add `ServerAliveInterval 60` to your `~/.ssh/config` to keep the tunnel from timing out on idle connections.
