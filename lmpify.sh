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
IMAGES=$1
GITHUB_USERNAME=""
DSTINATION_IMAGE_REGISTRY=""
DSTINATION_IMAGE_REGISTRY_NAMESPACE=""
WORKFLOW_NAME="lmpify"
LMPIFY_REPO=""

# ANSI escape codes for colored bold text.
BLUE_BOLD='\033[1;34m'
GREEN_BOLD='\033[1;32m'
RED_BOLD='\033[1;31m'
WHITE_BOLD='\033[1m'
RESET='\033[0m'

function help() {
  echo -e "${WHITE_BOLD}Usage:${RESET}"
  echo "    ./lmpify.sh [options]"
  echo -e "${WHITE_BOLD}Options:${RESET}"
  echo "    -i <comma-separated-images>       The images that need to be pulled, separated by commas. Example: 'busybox:latest,alpine:latest'"
  echo "    -u <github-username>              The GitHub username that used for running the GitHub Actions workflow."
  echo "    -r <destination-image-registry>   The destination image registry that used for storing the pulled images. Example: 'registry.cn-hangzhou.aliyuncs.com'"
  echo "    -n <destination-image-namespace>  The destination image registry namespace that used for storing the pulled images. Example: 'lmpify'"
  echo "    -h                                Show this help message."
  echo -e "${WHITE_BOLD}Example:${RESET}"
  echo "    ./lmpify.sh -i busybox:latest -u lmpify -r registry.cn-hangzhou.aliyuncs.com -n lmpify"
}

function parse_args() {
  CLI_OPTIONS=":i:u:r:n:h"

  if [ $# -eq 0 ]; then
    echo "No arguments provided."
    help
    exit 1
  fi

  while getopts ${CLI_OPTIONS} opt; do
    case ${opt} in
      i)
        IMAGES=${OPTARG}
        ;;
      u)
        GITHUB_USERNAME=${OPTARG}
        ;;
      r)
        DSTINATION_IMAGE_REGISTRY=${OPTARG}
        ;;
      n)
        DSTINATION_IMAGE_REGISTRY_NAMESPACE=${OPTARG}
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
  if [ -z "$IMAGES" ]; then
    echo -e "${RED_BOLD}The '-i' argument are required.${RESET}"
    help
    exit 1
  fi

  if [ -z "$GITHUB_USERNAME" ]; then
    echo -e "${RED_BOLD}The '-u' argument is required.${RESET}"
    help
    exit 1
  fi

  # Assuming you have already forked lmpify/lmpify.
  LMPIFY_REPO="$GITHUB_USERNAME/lmpify"

  if [ -z "$DSTINATION_IMAGE_REGISTRY" ]; then
    echo -e "${RED_BOLD}The '-r' argument is required.${RESET}"
    help
    exit 1
  fi

  if [ -z "$DSTINATION_IMAGE_REGISTRY_NAMESPACE" ]; then
    echo -e "${RED_BOLD}The '-n' argument is required.${RESET}"
    help
    exit 1
  fi

  if [ -z "$WORKFLOW_NAME" ]; then
    echo -e "${RED_BOLD}The '-w' argument is required.${RESET}"
    help
    exit 1
  fi

  if [ -z "$LMPIFY_REPO" ]; then
    echo -e "${RED_BOLD}The '-g' argument is required.${RESET}"
    help
    exit 1
  fi
}

function check_prerequisites() {
  # Check if the GitHub CLI is installed.
  if ! command -v gh &> /dev/null; then
    echo -e "${RED_BOLD} GitHub CLI is not installed. Please install it before running this script.${RESET}"
    exit 1
  fi

  # Check if the Docker is installed.
  if ! command -v docker &> /dev/null; then
    echo -e "${RED_BOLD} Docker is not installed. Please install it before running this script.${RESET}"
    exit 1
  fi

  # Check if the jq is installed.
  if ! command -v jq &> /dev/null; then
    echo -e "${RED_BOLD} jq is not installed. Please install it before running this script.${RESET}"
    exit 1
  fi
}

function trigger_lmpify() {
  printf "${BLUE_BOLD}Lmpifying the images %s${RESET}\n" "$IMAGES"

  # Run the GitHub Actions workflow.
  gh workflow run "$WORKFLOW_NAME" --field "images=$IMAGES" --repo "$LMPIFY_REPO"

  # Let's sleep for a few seconds to allow the workflow to start.
  sleep 2

  # Get the ID of the most recent executing workflow.
  RUN_ID=$(gh run list -R "$LMPIFY_REPO" --limit 1 --json 'databaseId,status' --jq '.[] | select(.status != "completed") | .databaseId')

  printf "${BLUE_BOLD}Start the GitHub workflow, ID: %s${RESET}\n" "$RUN_ID"

  # Watch the workflow run until it completes.
  gh run watch "$RUN_ID" --repo "$LMPIFY_REPO" --exit-status && STATUS="success" || STATUS="failure"

  # Check the result of the workflow.
  if [[ "$STATUS" == "success" ]]; then
    echo -e "${GREEN_BOLD}Workflow completed successfully.${RESET}\n"
    IFS=',' read -ra IMAGE_LIST <<< "$IMAGES"
    for image in "${IMAGE_LIST[@]}"; do
      # Extract the name and tag of the source image and replace the slashes with dashes.
      # For example: 'quay.io/coreos/etcd:v3.4.13' will be converted to 'quay-io-coreos-etcd:v3.4.13'.
      image_name=$(echo "${image}" | cut -d':' -f 1 | sed 's/[./]/-/g')
      image_tag=$(echo "${image}" | cut -d':' -f 2)
      DST_IMAGE="$DSTINATION_IMAGE_REGISTRY/$DSTINATION_IMAGE_REGISTRY_NAMESPACE/$image_name:$image_tag"
      printf "${BLUE_BOLD}Pulling the image: %s${RESET}\n" "$DST_IMAGE"
      docker pull "$DST_IMAGE"
      printf "${BLUE_BOLD}Tagging the image: %s to %s${RESET}\n" "$DST_IMAGE" "$image"
      docker tag "$DST_IMAGE" "$image"
    done
  else
    echo -e "${RED_BOLD}Workflow failed.${RESET}\n"
    exit 1
  fi
}

# The entry point of the script.
parse_args "$@"
check_args
check_prerequisites
trigger_lmpify
