#!/usr/bin/bash

#*************************************************************************************************#
#
#   Add install scripts to this file to install packages for root user
#
#*************************************************************************************************#

echo -e "Setup extended packages! The setup for root"
echo -e "Add install scripts to this file to install packages for root user"

# build-essential
apt-get update
apt-get install -y build-essential

apt-get install -y ocl-icd-libopencl1 opencl-headers clinfo
mkdir -p /etc/OpenCL/vendors && \
echo "libnvidia-opencl.so.1" > /etc/OpenCL/vendors/nvidia.icd

apt -y install ffmpeg 
apt-get install -y alsa-base alsa-utils
apt-get install -y libasound-dev
apt-get install -y portaudio19-dev
apt-get install -y python3-pyaudio
apt-get install -y python-pyaudio 
apt-get install -y pulseaudio
python3.8 -m pip install torch==1.13.1 torchvision==0.14.1 --index-url https://download.pytorch.org/whl/cu117

python3.8 -m pip install numpy==1.23.0
python3.8 -m pip install --force-reinstall resampy==0.3.1
python3.8 -m pip install --force-reinstall numba==0.48
python3.8 -m pip install --force-reinstall tqdm==4.45.0
# python3.8 -m pip install --force-reinstall PyAudio==0.2.14