#!/bin/bash

#**************************   PARAMETERS  *******************************#
# Default parameters
DOCKER_IMAGE="admin-ubuntu22.04-devel:test_cuda"
DEFAULT_USER=admin
MOUNT_COMMAND=""
WORKDIR_CMD=""
CONTAINER_NAME=""
KEEP_CONTAINER=false
REMOVE_CONTAINER_CMD="--rm"
ADDITIONAL_PARAMS=""

# Enable/disable link/mount runtime NVIDIA
ENABLE_RUNTIME_NVIDIA=true

# Function to display help message
function show_help() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -i, --input_image                                   Specify the Docker image (<docker_image_name>:<docker_tag>; required)"
    echo "  -k, --keep-conntainer                               Keep the container after exit and keep exist container (no argument; optional);"
    echo "                                                      default is remove container after exit and remove already exist container"
    echo "      --name <container_name>                         Assign a name to the container (string; optional)"
    echo "  -v, --volume <host_dir>:<container_dir>             Bind mount a volume (string; required, can be used multiple times)"
    echo "  -u, --user <user>                                   Specify the user inside the container (string ;optional, default: admin)"
    echo "  -h, --help                                          Show this help message (no argument; optional)"
    echo "  -w, --workdir <workdir>                             Working directory inside the container (string; optional)"
    echo "  -a, --additional-parameters                         Additional parameters."
    echo "                                                      You can add other parameters of \"docker run\" command here "
    echo "                                                      but note that put the content in double quotes. (string; optional)"
    echo "  Example: ./enter_docker.sh \\
            -i nvcr.io/nvidia/cuda:11.7.1-base-ubuntu22.04 \\
            -v $PWD/bin:/home/admin/example_app/bin \\
            -w /home/admin/example_app \\
            -a \"--cpu 5\""
}

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -i|--input_image) DOCKER_IMAGE="$2"; shift ;;
        -k|--keep-conntainer) KEEP_CONTAINER=true; REMOVE_CONTAINER_CMD="" ;;
        --name) CONTAINER_NAME=$2;CONTAINER_NAME_CMD="--name $CONTAINER_NAME"; shift ;;
        -v|--volume) MOUNT_COMMAND="$MOUNT_COMMAND -v $2"; shift ;;
        -u|--user) DEFAULT_USER="$2"; shift ;;
        -h|--help) show_help; exit 0 ;;
        -w|--workdir) WORKDIR_CMD="-w $2"; shift ;;
        -a|--additional-parameters) ADDITIONAL_PARAMS="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; show_help; exit 1 ;;
    esac
    shift
done

# Check required parameters
# if [ -z "$MOUNT_COMMAND" ]; then
#     echo "Error: -v/--volume are required."
#     show_help
#     exit 1
# fi
if [ -z "$DOCKER_IMAGE" ] ; then
    echo "Error: -i/--input_image are required."
    show_help
    exit 1
fi

# Enable runtime NVIDIA if required
if [[ "$DOCKER_IMAGE" == *"no-cuda"* ]]; then
    ENABLE_RUNTIME_NVIDIA=false
fi

if [[ "$ENABLE_RUNTIME_NVIDIA" = true ]]; then
    runtime_nvidia_cmd="--runtime=nvidia --gpus all -e NVIDIA_DRIVER_CAPABILITIES=all"
else
    runtime_nvidia_cmd=""
fi

# Set DISPLAY if not set
if [ -z "$DISPLAY" ]; then
    export DISPLAY=:0
fi
xhost +local:

# Docker run options
docker_run_opts="--privileged -it --net=host --ipc=host -u $DEFAULT_USER \
    --tmpfs /tmp:exec \
    --device=/dev/bus/usb:/dev/bus/usb \
    --device /dev/snd:/dev/snd \
    --device=/dev/input:/dev/input \
    $runtime_nvidia_cmd \
    -e DISPLAY=$DISPLAY \
    $MOUNT_COMMAND \
    -v /dev/shm:/dev/shm \
    -v /tmp/.X11-unix/:/tmp/.X11-unix \
    -v /etc/timezone:/etc/timezone:ro \
    -v /etc/localtime:/etc/localtime:ro \
    $WORKDIR_CMD \
    $CONTAINER_NAME_CMD"

container_exists=$(docker ps -a -q -f name=^${CONTAINER_NAME}$)
if [ -z $container_exists ]; then
    echo "Container $CONTAINER_NAME does not exist"
    KEEP_CONTAINER=false
fi

docker_cmd=""
# Add --rm if KEEP_CONTAINER is false
if [[ "$KEEP_CONTAINER" = false ]]; then
    docker_cmd="docker run $REMOVE_CONTAINER_CMD $docker_run_opts $ADDITIONAL_PARAMS $DOCKER_IMAGE bash"
    # Check if the CONTAINER_NAME is not empty
    if [[ -n "$CONTAINER_NAME" ]]; then
        echo "remove container $CONTAINER_NAME if it exist"
        docker rm --force $CONTAINER_NAME || true
    fi
else
  container_running=$(docker ps -q -f name=^${CONTAINER_NAME}$)
  echo "container_exists: $container_exists"
  if [ -n "$container_running" ]; then
    echo "* Container $CONTAINER_NAME is running. Attaching to the container..."
    
    docker_cmd="docker attach ${CONTAINER_NAME}"
  else
    echo "* Container $CONTAINER_NAME is NOT running. Starting the container..."
    docker_cmd="docker start -ai ${CONTAINER_NAME}"
  fi
fi

echo "Docker command: $docker_cmd"

# Run Docker container
$docker_cmd