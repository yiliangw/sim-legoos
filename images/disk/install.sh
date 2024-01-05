#!/bin/bash -eux

set -eux

apt-get purge cloud-init -y
apt-get update && apt-get install -y --force-yes build-essential


# Extract the source files
mkdir /simbricks && pushd /simbricks
tar -xf /dev/sdc

# Install linux
make -C linux modules_install install
