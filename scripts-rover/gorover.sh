#!/bin/bash

# command can be plan, apply, destroy or validate
env=${1}
command=${2}
blueprint=${PWD##*/}
date=`date +%Y%m%d%H%M%S`

if [[ -z ${env} || -z ${command} ]]; then
  echo 'one or more script variables are undefined'
  echo "expecting: ./gorover.sh <environment name> <plan|apply|applyplan|destroy|import|validate>"
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
  plan|apply|applyplan|destroy|import|validate)
    ;;
  *)
    echo "Accepted command is one of: plan, apply, applyplan, destroy, import or validate"
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

# Create cache directory to avoid warnings
TF_DATA_DIR=${HOME}/.terraform.cache/${blueprint}.${env}
mkdir -p ${TF_DATA_DIR}
mkdir -p ${TF_PLUGIN_CACHE_DIR}

set +o allexport

if [[ ! -z "${LAUNCHPAD_SUBSCRIPTION}" ]]; then
  echo "Setting subsctiption to ${LAUNCHPAD_SUBSCRIPTION}"
  az account set --subscription ${LAUNCHPAD_SUBSCRIPTION}
  export ARM_SUBSCRIPTION_ID="${LAUNCHPAD_SUBSCRIPTION}"
fi

if [[ ! -f "/tf/caf/${blueprint}/environments/${env}.tfvars" ]]; then
  echo "/tf/caf/${blueprint}/environments/${env}.tfvars file is missing. Please ensure it exist!"
  echo ""
  exit 1
fi

shift # Remove 1st argument from the list (environment name)

# When applying a plan file directly no -var-file can be specified as the variables are already part of the plan
# This next if take care of setting the -var-file accordingly
if [[ ${command} == "applyplan" ]]; then
  varfile=""
else
  varfile="-var-file=/tf/caf/${blueprint}/environments/${env}.tfvars"
fi

echo "varfile is set to: ${varfile}"

if [[ ${blueprint} == "L0_blueprint_launchpad" ]]; then
  /tf/rover/rover.sh -lz /tf/caf/${blueprint}/code -launchpad -env ${env} -tfstate "${blueprint}_${env}.tfstate" -parallelism=80 ${varfile} -a $@ 
else
  /tf/rover/rover.sh -lz /tf/caf/${blueprint}/code -env ${env} -tfstate "${blueprint}_${env}.tfstate" -parallelism=80 ${varfile} -a $@ 
fi