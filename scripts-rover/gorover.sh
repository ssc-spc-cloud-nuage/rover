#!/bin/bash

# command can be plan, apply, destroy or validate
env=${1}
command=${2}
blueprint=${PWD##*/}
date=`date +%Y%m%d%H%M%S`

if [[ -z ${env} || -z ${command} ]]; then
  echo 'one or more script variables are undefined'
  echo "expecting: ./gorover.sh <environment name> <plan|apply|destroy|validate>"
  echo ""
  exit 1
fi

if [[ ${1} = *-* ]]; then
  echo "environment name must not contain -. Use _ instead"
  echo ""
  exit 1
fi

if [[ ${#1} -lt 3 ]]; then
  echo "environment name must be 3 characters or greater"
  echo ""
  exit 1
fi

case "${command}" in
  plan|apply|destroy|validate)
    ;;
  *)
    echo "Accepted command is one of: plan, apply, destroy or validate"
    echo ""
    exit 1
    ;;
esac

set -o allexport

if [[ -f "/tf/caf/envvars/${env}.envvars" ]]; then
  source /tf/caf/envvars/${env}.envvars
else
  echo "/tf/caf/envvars/${env}.envvars file is missing. Please ensure it exist!"
  echo ""
  exit 1
fi

TF_DATA_DIR=/home/vscode/.terraform.cache/${blueprint}.${env}
mkdir -p ${TF_DATA_DIR}
#if [[ ! -L cache.${env} ]] ; then
#  ln -s ${TF_DATA_DIR} cache.${env}
#fi

set +o allexport

if [[ ! -z "${LAUNCHPAD_SUBSCRIPTION}" ]]; then
  echo "Setting subsctiption to ${LAUNCHPAD_SUBSCRIPTION}"
  az account set --subscription ${LAUNCHPAD_SUBSCRIPTION}
fi

if [[ ! -f "/tf/caf/${blueprint}/environments/${env}.tfvars" ]]; then
  echo "/tf/caf/${blueprint}/environments/${env}.tfvars file is missing. Please ensure it exist!"
  echo ""
  exit 1
fi

# Taking backup of statefile before applying if cache already exist

if [[ ${command} == "apply" ]]; then
  if [[ -d ${TF_DATA_DIR} ]]; then
    current=${PWD}
    cd code
    echo "Taking backup of state file"
    terraform state pull > ${TF_DATA_DIR}/terraform.state.${date}
    cd ${current}
  else
    echo "cache does not yet exist, can't take backup."
  fi
fi

shift # Remove 1st argument from the list (environment name)

if [[ ${blueprint} == "L0_blueprint_launchpad" ]]; then
  /tf/rover/rover.sh -lz /tf/caf/${blueprint}/code -a $@ -launchpad -env ${env} -tfstate "${blueprint}_${env}.tfstate" -parallelism=30 -var-file="/tf/caf/${blueprint}/environments/${env}.tfvars"
else
  /tf/rover/rover.sh -lz /tf/caf/${blueprint}/code -a $@ -env ${env} -tfstate "${blueprint}_${env}.tfstate" -parallelism=30 -var-file="/tf/caf/${blueprint}/environments/${env}.tfvars"
fi