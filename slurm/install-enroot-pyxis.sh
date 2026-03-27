#!/bin/bash
# ===========================================================================
# Install Enroot + Pyxis on SLURM compute nodes
# ===========================================================================
#
# WHAT THIS DOES:
#   Installs Enroot (container runtime) and Pyxis (SLURM plugin) so users
#   can run containers directly from SLURM:
#     sbatch --container-image=nvcr.io/nvidia/pytorch:24.01-py3 --gpus=1 job.sh
#
# WHY ENROOT (not Docker):
#   - No root needed (critical for shared HPC clusters)
#   - Designed for HPC — fast image import, no daemon
#   - Works with NVIDIA GPU Container Toolkit out of the box
#
# WHY PYXIS:
#   - NVIDIA's official SLURM plugin for container support
#   - Adds --container-image, --container-mounts flags to sbatch/srun
#   - Seamless — researchers just add one flag to their existing scripts
#
# USAGE:
#   Run this script on each compute node (via startup script or Ansible)
#   sudo bash install-enroot-pyxis.sh

set -euo pipefail

echo "=== Installing Enroot and Pyxis ==="

# --- Install Enroot ---
# Enroot converts Docker images into unprivileged sandboxes
ENROOT_VERSION="3.5.0"

echo "Installing Enroot ${ENROOT_VERSION}..."
curl -fSsL -o /tmp/enroot_${ENROOT_VERSION}-1_amd64.deb \
  "https://github.com/NVIDIA/enroot/releases/download/v${ENROOT_VERSION}/enroot_${ENROOT_VERSION}-1_amd64.deb"
curl -fSsL -o /tmp/enroot+caps_${ENROOT_VERSION}-1_amd64.deb \
  "https://github.com/NVIDIA/enroot/releases/download/v${ENROOT_VERSION}/enroot+caps_${ENROOT_VERSION}-1_amd64.deb"

apt-get update -qq
apt-get install -y -qq /tmp/enroot_${ENROOT_VERSION}-1_amd64.deb
apt-get install -y -qq /tmp/enroot+caps_${ENROOT_VERSION}-1_amd64.deb

# Configure Enroot
mkdir -p /etc/enroot
cat > /etc/enroot/enroot.conf << 'ENROOT_CONF'
# Where Enroot stores container images and runtime data
ENROOT_RUNTIME_PATH=/run/enroot/user-$(id -u)
ENROOT_DATA_PATH=/tmp/enroot-data/user-$(id -u)
ENROOT_CACHE_PATH=/tmp/enroot-cache

# Enable GPU support inside containers
ENROOT_MOUNT_HOME=yes
ENROOT_RESTRICT_DEV=yes
ENROOT_ROOTFS_WRITABLE=yes
ENROOT_CONF

echo "Enroot installed successfully."

# --- Install Pyxis ---
# Pyxis is SLURM's container plugin — adds --container-image to sbatch
PYXIS_VERSION="0.20.0"

echo "Installing Pyxis ${PYXIS_VERSION}..."
apt-get install -y -qq git build-essential libslurm-dev

cd /tmp
git clone --depth 1 --branch "v${PYXIS_VERSION}" https://github.com/NVIDIA/pyxis.git
cd pyxis
make install

# Register Pyxis with SLURM
# This tells SLURM "use pyxis for container support"
SLURM_PLUGSTACK_CONF="/etc/slurm/plugstack.conf.d/pyxis.conf"
mkdir -p "$(dirname ${SLURM_PLUGSTACK_CONF})"
echo "required /usr/local/lib/slurm/spank_pyxis.so" > "${SLURM_PLUGSTACK_CONF}"

echo "Pyxis installed successfully."

# --- Install NVIDIA Container Toolkit ---
# Allows Enroot to access GPUs inside containers
echo "Installing NVIDIA Container Toolkit..."
distribution=$(. /etc/os-release; echo $ID$VERSION_ID)
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L "https://nvidia.github.io/libnvidia-container/${distribution}/libnvidia-container.list" | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

apt-get update -qq
apt-get install -y -qq nvidia-container-toolkit
nvidia-ctk runtime configure --runtime=enroot

echo "NVIDIA Container Toolkit installed successfully."

echo ""
echo "=== Installation Complete ==="
echo "Users can now run: sbatch --container-image=nvcr.io/nvidia/pytorch:24.01-py3 --gpus=1 job.sh"
