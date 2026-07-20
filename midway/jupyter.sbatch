#!/bin/bash
#SBATCH --job-name=jupyter_lab
#SBATCH --account=<pi-group>
#SBATCH --partition=<partition>
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=16G
#SBATCH --time=05:00:00
#SBATCH --output=jupyter_%j.log
#SBATCH --error=jupyter_%j.log

module load python/miniforge-25.3.0

node=$(hostname -s)
port=$(shuf -i 15001-30000 -n 1)
user=$(whoami)

node_ip=$(getent hosts "$node" | awk '{print $1}')
[[ -z "$node_ip" ]] && node_ip=$node
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
     (if you add -f, then use it as "-f -o ExitOnForwardFailure=yes")
2) Open this URL in your browser (token already included):
     http://localhost:${port}/lab?token=${JUPYTER_TOKEN}

To stop:  scancel ${SLURM_JOB_ID}   (from the login node)
========================================================================
INSTRUCTIONS

echo "Connection instructions written to: ${connect_file}" 1>&2

jupyter lab --no-browser --ip=${node_ip} --port=${port} --notebook-dir="${HOME}"
