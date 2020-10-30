#!/bin/bash

# command can be plan, apply, destroy or validate
env=${1}

command=${2}
blueprint=${PWD##*/}
date=`date +%Y%m%d%H%M%S`

if [[ -z ${env} || -z ${command} ]]; then
  echo 'one or more script variables are undefined'
  # echo "expecting: ./runactions.sh <environment name> <apply|destroy>"
  echo "expecting: ./runactions.sh <environment name> <apply>"
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
  apply|destroy)
    ;;
  *)
    # echo "Accepted command for runactions.sh is one of: apply, destroy"
    echo "Accepted command for runactions.sh is one of: apply"
    echo ""
    exit 1
    ;;
esac

/tf/rover/gorover.sh ${env} plan
read -p 'Do you want to proceed with the apply via a pipeline (yes/no): ' proceed

if [ -z "$proceed" ];
then
  echo 'Inputs cannot be blank please try again'
  exit 0
fi

if [ "${proceed,,}" = "yes" ];
then
  mkdir -p .actions
  echo "/tf/rover/gorover.sh $@ -auto-approve" > .actions/cicdrun.sh
  chmod +x .actions/cicdrun.sh
  git add .
  git commit -m "runactions ${env} ${command} in ${blueprint} on ${date}"
  git tag "${blueprint}_${env}_${command}_${date}"
  git push
  git push --tags
fi