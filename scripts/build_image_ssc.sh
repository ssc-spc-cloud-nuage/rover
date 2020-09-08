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
        rover="sscspccloudnuage/rover:${tag}"
        ;;
esac

echo "Creating version ${rover}"

# Build the rover base image
sudo docker-compose build --build-arg versionRover=${rover}


case "$1" in 
    "github")
        sudo docker tag rover_rover ${rover}
        sudo docker tag rover_rover sscspccloudnuage/rover:latest

        sudo docker push sscspccloudnuage/rover:${tag}
        sudo docker push sscspccloudnuage/rover:latest

        echo "Version sscspccloudnuage/rover:${tag} created."
        echo "Version sscspccloudnuage/rover:latest created."
        ;;
    "dev")
        sudo docker tag rover_rover sscspccloudnuage/roverdev:${tag}
        sudo docker tag rover_rover sscspccloudnuage/roverdev:latest

        sudo docker push sscspccloudnuage/roverdev:${tag}
        sudo docker push sscspccloudnuage/roverdev:latest
        echo "Version sscspccloudnuage/roverdev:${tag} created."
        echo "Version sscspccloudnuage/roverdev:latest created."
        ;;
    *)    
        sudo docker tag rover_rover sscspccloudnuage/rover:$tag
        sudo docker tag rover_rover sscspccloudnuage/rover:latest
        echo "Local version created"
        echo "Version sscspccloudnuage/rover:${tag} created."
        echo "Version sscspccloudnuage/roverdev:latest created."
        ;;
esac
