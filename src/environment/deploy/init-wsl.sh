#!/bin/bash

# Update the apt package list.
sudo apt-get update -y

# Install Docker's package dependencies.
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    dos2unix \
    jq \
    software-properties-common \
    unzip \
    nodejs \
    npm

# Download and add Docker's official public PGP key.
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

# Verify the fingerprint.
sudo apt-key fingerprint 0EBFCD88

# Add the `stable` channel's Docker upstream repository.
#
# If you want to live on the edge, you can change "stable" below to "test" or
# "nightly". I highly recommend sticking with stable!
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

# Update the apt package list (for the new apt repo).
sudo apt-get update -y

# Install the latest version of Docker CE.
sudo apt-get install -y docker-ce

# Allow your user to access the Docker CLI without needing root access.
sudo usermod -aG docker $USER

# Install Python and PIP.
sudo apt-get install -y python python-pip

# Install Docker Compose into your user's home directory.
pip install --user docker-compose

# connect
echo "export DOCKER_HOST=tcp://localhost:2375" >> ~/.bashrc && source ~/.bashrc

# install azure cli
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# install packer
PACKER_CLI_VERSION=1.4.5
curl https://releases.hashicorp.com/packer/${PACKER_CLI_VERSION}/packer_${PACKER_CLI_VERSION}_linux_amd64.zip -o packer.zip
unzip packer.zip
sudo mv packer /usr/bin
rm packer.zip

# install terraform
TERRAFORM_CLI_VERSION=0.12.13
curl https://releases.hashicorp.com/terraform/${TERRAFORM_CLI_VERSION}/terraform_${TERRAFORM_CLI_VERSION}_linux_amd64.zip -o terraform.zip
unzip terraform.zip
sudo mv terraform /usr/bin
rm terraform.zip

# setup npm so we don't seend sudo
mkdir ~/.npm-global
npm config set prefix '~/.npm-global'
echo "export PATH=~/.npm-global/bin:\$PATH" >> ~/.profile
source ~/.profile
