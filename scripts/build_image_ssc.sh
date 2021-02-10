#!/bin/bash

set -e
./scripts/pre_requisites.sh


case "$1" in 
    "github")
        tag=$(date +"%g%m.%d%H")
        rover="sscspccloudnuage/rover:${tag}"
        ;;
    "dev")
        tag=$(date +"%g%m.%d%H%M")
        rover="sscspccloudnuage/roverdev:${tag}"
        ;;
    *)
        tag=$(date +"%g%m.%d%H%M")
        rover="sscspccloudnuage/roverdev:${tag}"
        ;;
esac

echo "Creating version ${rover}"

# Build the rover base image
docker-compose build --build-arg versionRover=${rover}

case "$1" in 
    "github")
        docker tag workspace_rover ${rover}
        docker tag workspace_rover sscspccloudnuage/rover:latest

        docker push sscspccloudnuage/rover:${tag}
        docker push sscspccloudnuage/rover:latest

        echo "Version sscspccloudnuage/rover:${tag} created."
        echo "Version sscspccloudnuage/rover:latest created."
        ;;
    "dev")
        docker tag workspace_rover sscspccloudnuage/roverdev:${tag}
        docker tag workspace_rover sscspccloudnuage/roverdev:latest

        docker push sscspccloudnuage/roverdev:${tag}
        docker push sscspccloudnuage/roverdev:latest
        echo "Version sscspccloudnuage/roverdev:${tag} created."
        echo "Version sscspccloudnuage/roverdev:latest created."
        ;;
    *)    
        docker tag workspace_rover sscspccloudnuage/roverdev:${tag}
        docker tag workspace_rover sscspccloudnuage/roverdev:latest
        echo "Local version created"
        echo "Version sscspccloudnuage/roverdev:${tag} created."
        echo "Version sscspccloudnuage/roverdev:latest created."
        ;;
esac
