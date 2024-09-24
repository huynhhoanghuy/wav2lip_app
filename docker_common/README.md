## Usage of docker_common
- Clone the `docker_common` repository from [Git](https://caishare.adminrof.com/admin_inter/docker_common.git) to your project (Optional if need update).
- Follow the steps to set up and bring up the Docker environment: setup, build, run.
- Tested on Ubuntu 20.04 (GPU/ without GPU)

## Setup Docker tools
- Run the script setup_docker.sh to setup docker tools for x86_64 and nvidia jetson.

```bash
cd docker_common
./other/setup_docker.sh
```

## Build Docker images
- See/Update **parameters in build_base_env.sh** to customize the Docker image.
- Two images are generated: **distribution**_base and **distribution**_devel.
  - **distribution**_base: The base image includes common tools, libraries, and the default user is admin/admin.
  - **distribution**_devel: The development image, which installs extended packages based on the project requirements.
    * Update `setup/requirements*.txt` for extended Python packages. The orther install of the requirement files:
      1. The `setup/requirements-fist.txt` : The packages are installed *one by one*, it is as order in the requirement-order.txt
      2. The `setup/requirements.txt` The dependencies *automatically resolves and installs* for all the packages listed, ensuring that all required sub-packages are installed correctly.
      3. The `setup/requirements-last.txt` : The packages are installed *one by one*, it is as order in the requirement-order.txt
    * Update `setup/setup.sh` for advanced installation packages (libs, tools, etc.). *The root privileges* used to run the setup 
    * Update `setup/setup-user.sh` for advanced installation packages (libs, tools, etc.). *The regular user* used to run the setup
- Run `build_base_env.sh` to build the Docker image.
- Use `docker images` to check the built Docker images.
- Note: With no-hardware-gpu device, plese change `distribution` (admin-ubuntu20.04-no-cuda, admin-ubuntu22.04-no-cuda) and change `INSTALL_CUSTOM_CUDA=1` into `INSTALL_CUSTOM_CUDA=0` in `build_base_env.sh` file.

```bash
cd docker_common
./build_base_env.sh
```

> **NOTE**
> - The image with the name **distribution**_devel will be used for the development environment.

## Run container, and development environment ready to use
- Specify the name of the Docker image used to create the container with `docker images`, referring to the Docker image with the suffix *_devel*.
- See/Update **parameters in enter_docker.sh** to customize the environment (such as: DOCKER_IMAGE).
- Run `enter_docker.sh -h` to see more options.
- Use `docker ps -a` to check the list of running/stopped containers.

```bash
cd docker_common
bash enter_docker.sh --name <new_container_name> -k
```
- Example: `bash enter_docker.sh --name test_A -k`
- Recommendation:
    + Should use flag --name to identify container.
    + Should use flag -k to keep files every exit and re-start containter.

Note 1: After run container, please build source in container: 
- `cd PCsimulation/example/`
- `./install_env.sh`
- `./build.sh`

Note 2: With mount folder: Every change in host-folder will change in docker-folder.

## Save docker image as file
- Use `docker save -o path/to/<output_filename>.tar **distribution**_devel:**tag**`
- Example: `docker save -o docker_ubuntu20_A.tar admin-ubuntu20.04-devel:test_cuda`

## Load docker image
- Use `docker load -i path/to/<output_filename>.tar`
- Example: `docker load -i docker_ubuntu20_A.tar`

## Copy file from host into docker container
- Use `bash copy.sh -name <container_name> -src path/to/host_input`
- Example: `bash copy.sh -name test_A -src A`
- Note: If user want to change destination path, please adjust `copy.sh` file at tag: `DEST_PATH`

## Mount folder from host into docker container
- Use `bash enter_docker.sh --name <new_container_name> -v /path/to/host_input:/path/to/container_output`
- Example: `bash enter_docker.sh --name test_A -v /media/admin/DATA/A:/home/admin`
- Note: If use flag `-k`, flag `-v` will not work. 

## Copy file from container into host
- Use `docker cp <container_ID>:/path/to/input /path/to/host`
- Example: `docker cp acdee57352a1:/home/admin/A/A/PCsimulation/example/output /home/admin/1.Users/test`
- Note: Use `docker ps` into show container's info (container must start at that time)


## Example flow:
- Build image: `bash build_base_env.sh` (change `distribution`, `tag`, `INSTALL_CUSTOM_CUDA` if need)
- Load container by image: `bash enter_docker.sh --name test_A -k` (align `DOCKER_IMAGE` tag in `enter_docker.sh` with built-image)
- Copy file source and data from host: `bash copy.sh -name test_A -src A`; `bash copy.sh -name test_A -src input`
- Build source A: `cd A/A/PCsimulation/example/`; `bash install_env.sh`; `bash build.sh`
- Change path video in `A/A/PCsimulation/example/run.sh`, change config.yaml in `A/A/A/src/main/assets/config.yaml`
- Run app: `bash run.sh`
- Open host session terminal and check docker container ID: `docker ps`
- Get output from container into host (please use this command on host session terminal): `docker cp acdee57352a1:/home/admin/A/A/PCsimulation/example/output /home/admin/1.Users/test`
- Exit docker container: `exit` or push ctrl + D
- Reload docker container: `bash enter_docker.sh --name test_A -k` (if change name container, create a new container)

