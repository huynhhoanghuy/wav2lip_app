#!/bin/bash

#Cause the script to exit if any commands fail
set -e
set -o pipefail

#**************************   PARAMETERS  *******************************#
# Distributions for admin aarch64
# 1. admin-l4t-35.3.1                         : Build from NVIDIA L4T Base (https://catalog.ngc.nvidia.com/orgs/nvidia/containers/l4t-base)
# 2. admin-l4t-35.2.1-ml                      : Build from NVIDIA L4T ML (https://catalog.ngc.nvidia.com/orgs/nvidia/containers/l4t-ml)
# 3. admin-l4t-35.2.1-pytorch                 : Build from NVIDIA L4T PyTorch (https://catalog.ngc.nvidia.com/orgs/nvidia/containers/l4t-pytorch)
# 4. admin-l4t-35.3.1-tensorflow              : Build from NVIDIA L4T TensorFlow (https://catalog.ngc.nvidia.com/orgs/nvidia/containers/l4t-tensorflow)
# Distributions for x86_64
# 1. admin-ubuntu20.04                        : Build from NVIDIA CUDA (https://catalog.ngc.nvidia.com/orgs/nvidia/containers/cuda)
# 2. admin-ubuntu20.04-no-cuda                : Build from Docker Hub Ubuntu (https://hub.docker.com/_/ubuntu)
# 3. admin-ubuntu22.04                        : Build from NVIDIA CUDA (https://catalog.ngc.nvidia.com/orgs/nvidia/containers/cuda)
# 4. admin-ubuntu22.04-no-cuda                : Build from Docker Hub Ubuntu (https://hub.docker.com/_/ubuntu)
distribution="admin-ubuntu22.04"
distribution="${distribution// /}" # Remove space characters in distribution

# Define output devel image tag, it use to specify the version of the docker images
tag=test_cuda

# Create a regular user for the image, the user must NOT root user. 
# And define the user ID and group ID for the regular user
host_user_id=$(id -u)
regular_username=admin
regular_user_uid=$host_user_id
regular_user_gid=$host_user_id

# The default user which uses to install packages.
# The user can be the root or the regular user.
# Use regular user to install python packages to 
default_user=admin

# Select cuda and cudnn version, empty cuda_major_vers, cudnn_major_vers for ignore the installation
# Ignore these parameters if using the no-cuda version
INSTALL_CUSTOM_CUDA=1  # 0: Do not install custom CUDA packages, 1: Install the following CUDA packages
cuda_major_vers=11
cuda_minor_vers=7
cudnn_major_vers=8
cudnn_version="$cudnn_major_vers.*.*.*-1+cuda$cuda_major_vers.$cuda_minor_vers"
CUDA_TOOLKIT_PACKAGE="cuda-toolkit-$cuda_major_vers-$cuda_minor_vers"
CUDNN_PACKAGE="libcudnn$cudnn_major_vers=$cudnn_version libcudnn$cudnn_major_vers-dev=$cudnn_version"
# CUDA_RUNTIME_PACKAGE="cuda-base-11-4 libcudnn8=8.*.*.*-1+cuda11.4"
CUSTOM_CUDA_PACKAGE="${CUDA_TOOLKIT_PACKAGE} ${CUDNN_PACKAGE}"

# Provide target platform of docker image
# Docker platform
# - NVIDIA Jetson: "linux/arm64"
# - PC (x86_64): "linux/amd64"
target_platform="linux/amd64"
#*************************   END PARAMETERS  ****************************#

# Check if the distribution contains "l4t" and if the target platform is not "linux/arm64"
if [[ $distribution == *"l4t"* ]] && [[ $target_platform != "linux/arm64" ]]; then
    echo "Error: The distribution '${distribution}' is intended for NVIDIA Jetson (linux/arm64), but the target platform is '${target_platform}'."
    exit 1
fi

base_img_name="${distribution}-base:latest"
devel_img_name="${distribution}-devel"
if [ -n "$tag" ]; then
    devel_img_name="${distribution}-devel:$tag"
fi

host_platform=`uname -m`
if [ "$host_platform" != "x86_64" ] && [ "$host_platform" != "aarch64" ]; then
    echo "[ERROR] detected unsupport achitect $host_platform"
    exit 1
fi

# Build the base image
docker build --network host --platform $target_platform \
    --build-arg regular_username=$regular_username \
    --build-arg regular_user_uid=$regular_user_uid \
    --build-arg regular_user_gid=$regular_user_gid \
    --build-arg distribution=$distribution \
    -t $base_img_name \
    -f Dockerfile.base .

# Build the develop image
# Verify the arch of the docker image
image_docker_arch=$(docker image inspect --format "{{.Architecture}}" $base_img_name)
echo "Arch: docker arch-$image_docker_arch; host arch: $host_platform"
docker_platform="linux/$image_docker_arch"

docker build -f Dockerfile.devel \
    --network host \
    --platform $docker_platform \
    --progress=plain \
    --build-arg username=$default_user \
    --build-arg base_image=$base_img_name \
    --build-arg INSTALL_CUSTOM_CUDA=$INSTALL_CUSTOM_CUDA \
    --build-arg CUSTOM_CUDA_PACKAGE="${CUSTOM_CUDA_PACKAGE}" \
    -t $devel_img_name .

echo "Finished building images:"
echo "    - Base image:  ${base_img_name} with architecture: ${image_docker_arch}"
echo "    - Devel image: ${devel_img_name} with architecture: ${image_docker_arch}"
