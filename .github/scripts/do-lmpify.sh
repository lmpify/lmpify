#!/usr/bin/env bash
# Copyright 2024 lmpify
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Set the script to exit immediately if any command exits with a non-zero status.
set -e

# The required arguments to be passed to the script.
IMAGES=""
DSTINATION_IMAGE_REGISTRY=""
DSTINATION_IMAGE_REGISTRY_NAMESPACE=""
DSTINATION_IMAGE_REGISTRY_USERNAME=""
DSTINATION_IMAGE_REGISTRY_PASSWORD=""

# If set to true, the script will not overwrite the images that are already existing in the destination registry.
# To improve the performance, we can skip the images that are already existing in the destination registry.
ENABLE_OVERWRITE=${LMPIFY_ENABLE_OVERWRITE:-false}

# If set to true, the script will enable the debug mode for Skopeo.
ENABLE_SKOPEO_DEBUG=${LMPIFY_ENABLE_SKOPEO_DEBUG:-false}

# ANSI escape codes for colored bold text.
BLUE_BOLD='\033[1;34m'
GREEN_BOLD='\033[1;32m'
RED_BOLD='\033[1;31m'
WHITE_BOLD='\033[1m'
RESET='\033[0m'

# Define the Skopeo command.
SKOPEO_CMD="docker run quay.io/skopeo/stable:latest"

function help() {
  echo -e "${WHITE_BOLD}Usage:${RESET}"
  echo "    ./do-lmpify.sh [options]"
  echo -e "${WHITE_BOLD}Options:${RESET}"
  echo "    -i <comma-separated-images>       The images that need to be pulled, separated by commas. Example: 'busybox:latest,alpine:latest'"
  echo "    -r <destination-image-registry>   The destination image registry that used for storing the pulled images. Example: 'registry.cn-hangzhou.aliyuncs.com'"
  echo "    -n <destination-image-namespace>  The destination image registry namespace that used for storing the pulled images. Example: 'lmpify'"
  echo "    -u <destination-image-username>   The username used to authenticate with the destination image registry."
  echo "    -p <destination-image-password>   The password used to authenticate with the destination image registry."
  echo "    -o                                Overwrite the images whether they already exist in the destination registry. Can be detected by environment variable 'LMPIFY_ENABLE_OVERWRITE'. Default is false."
  echo "    -d                                Enable the debug mode for Skopeo. Can be detected by environment variable 'LMPIFY_ENABLE_SKOPEO_DEBUG'. Default is false."
  echo "    -h                                Show this help message."
  echo -e "${WHITE_BOLD}Example:${RESET}"
  echo "    ./do-lmpify.sh -i busybox:latest,alpine:latest -r registry.cn-hangzhou.aliyuncs.com -n lmpify -u lmpify -p lmpify123456"
}

function parse_args() {
  CLI_OPTIONS=":i:r:n:u:p:odh"

  if [ $# -eq 0 ]; then
    echo "No arguments provided."
    help
    exit 1
  fi

  while getopts ${CLI_OPTIONS} opt; do
    case ${opt} in
      i)
        echo $OPTARG
        IMAGES=${OPTARG}
        ;;
      r)
        DSTINATION_IMAGE_REGISTRY=${OPTARG}
        ;;
      n)
        DSTINATION_IMAGE_REGISTRY_NAMESPACE=${OPTARG}
        ;;
      u)
        DSTINATION_IMAGE_REGISTRY_USERNAME=${OPTARG}
        ;;
      p)
        DSTINATION_IMAGE_REGISTRY_PASSWORD=${OPTARG}
        ;;
      o)
        ENABLE_OVERWRITE=true
        ;;
      d)
        ENABLE_SKOPEO_DEBUG=true
        ;;
      h)
        help
        exit 0
        ;;
      :)
        echo -e "${RED_BOLD} Option -${OPTARG} requires an argument.${RESET}"
        help
        exit 1
        ;;
      ?)
        echo -e "${RED_BOLD} Invalid option: -${OPTARG}.${RESET}"
        help
        exit 1
        ;;
    esac
  done
}

function check_args() {
  if [ -z "${IMAGES}" ]; then
    echo -e "${RED_BOLD}The '-i' argument is required.${RESET}"
    help
    exit 1
  fi

  if [ -z "${DSTINATION_IMAGE_REGISTRY}" ]; then
    echo -e "${RED_BOLD}The '-r' argument is required.${RESET}"
    help
    exit 1
  fi

  if [ -z "${DSTINATION_IMAGE_REGISTRY_NAMESPACE}" ]; then
    echo -e "${RED_BOLD}The '-n' argument is required.${RESET}"
    help
    exit 1
  fi

  if [ -z "${DSTINATION_IMAGE_REGISTRY_USERNAME}" ]; then
    echo -e "${RED_BOLD}The '-u' is required.${RESET}"
    help
    exit 1
  fi

  if [ -z "${DSTINATION_IMAGE_REGISTRY_PASSWORD}" ]; then
    echo -e "${RED_BOLD}The '-p' is required.${RESET}"
    help
    exit 1
  fi

  if [ "${ENABLE_SKOPEO_DEBUG}" = true ]; then
    SKOPEO_DEBUG_FLAG="--debug"
  fi

  # Prints the arguments.
  printf "${BLUE_BOLD}Pulling images '%s' and pushing them to '%s/%s'\n${RESET}" "${IMAGES}" "${DSTINATION_IMAGE_REGISTRY}" "${DSTINATION_IMAGE_REGISTRY_NAMESPACE}"
  printf "${BLUE_BOLD}ENABLE_OVERWRITE: %s\n${RESET}" "${ENABLE_OVERWRITE}"
  printf "${BLUE_BOLD}ENABLE_SKOPEO_DEBUG: %s\n${RESET}" "${ENABLE_SKOPEO_DEBUG}"
}

# Pull the images and push them to the destination image registry.
function do_lmpify() {
  # Convert the comma-separated string of images into an array.
  IFS=',' read -ra IMAGE_ARRAY <<< "${IMAGES}"

  # Loop through the array and copy each image using Skopeo.
  for image in "${IMAGE_ARRAY[@]}"; do
    # Extract the name and tag of the source image and replace the slashes with dashes.
    # For example: 'quay.io/coreos/etcd:v3.4.13' will be converted to 'quay-io-coreos-etcd:v3.4.13'.
    image_name=$(echo "${image}" | cut -d':' -f 1 | sed 's/[./]/-/g')
    image_tag=$(echo "${image}" | cut -d':' -f 2)

    # Build the full destination path for the image.
    DEST_IMAGE="${DSTINATION_IMAGE_REGISTRY}/${DSTINATION_IMAGE_REGISTRY_NAMESPACE}/${image_name}:${image_tag}"

    # Print a blue bold message before running the Skopeo command.
    printf "${BLUE_BOLD}Copying %s to %s...\n${RESET}" "${image}" "${DEST_IMAGE}"

    # If the image tag is not 'latest', check if the image already exists in the destination registry.
    # - if ENABLE_OVERWRITE is true, overwrite the image that already exists in the destination registry.
    # - if ENABLE_OVERWRITE is false, skip the image that already exists in the destination registry.
    if [ "${image_tag}" != "latest" ]; then
      # Check if the image already exists in the destination registry.
      if $SKOPEO_CMD inspect \
          --creds "${DSTINATION_IMAGE_REGISTRY_USERNAME}":"${DSTINATION_IMAGE_REGISTRY_PASSWORD}" \
          docker://"${DEST_IMAGE}" &> /dev/null; then
        if [ "${ENABLE_OVERWRITE}" = true ]; then
          printf "${BLUE_BOLD}The image %s already exists in the destination registry. Overwriting...\n${RESET}" "${DEST_IMAGE}"
        else
          printf "${BLUE_BOLD}The image %s already exists in the destination registry. Skipping...\n${RESET}" "${DEST_IMAGE}"
          continue
        fi
      fi
    fi

    # Use Skopeo to copy the image.
    if $SKOPEO_CMD copy -a ${SKOPEO_DEBUG_FLAG} \
        docker://"${image}" \
        --dest-creds "${DSTINATION_IMAGE_REGISTRY_USERNAME}":"${DSTINATION_IMAGE_REGISTRY_PASSWORD}" \
        docker://"${DEST_IMAGE}"; then
      printf "${GREEN_BOLD}Successfully copied %s to %s\n${RESET}" "${image}" "${DEST_IMAGE}"
    else
      printf "${RED_BOLD}Failed to copy %s to %s\n${RESET}" "${image}" "${DEST_IMAGE}"
      exit 1
    fi
  done
}

# The entry point of the script.
parse_args "$@"
check_args
do_lmpify
