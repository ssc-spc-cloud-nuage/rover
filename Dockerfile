###########################################################
# base tools and dependencies
###########################################################
FROM mcr.microsoft.com/vscode/devcontainers/base:ubuntu-18.04 as base

###########################################################
# Getting latest version of Azure CAF Terraform provider
###########################################################
FROM golang:1.15.6 as azurecaf

ARG versionAzureCafTerraform
ENV versionAzureCafTerraform=${versionAzureCafTerraform}

# to force the docker cache to invalidate when there is a new version
ADD https://api.github.com/repos/aztfmod/terraform-provider-azurecaf/git/ref/tags/${versionAzureCafTerraform} version.json
RUN cd /tmp && \
    git clone https://github.com/aztfmod/terraform-provider-azurecaf.git && \
    cd terraform-provider-azurecaf && \
    go build -o terraform-provider-azurecaf

###########################################################
# tools
###########################################################
FROM base
# [Option] Upgrade OS packages to their latest versions
ARG UPGRADE_PACKAGES="false"
# [Option] Install Docker CLI
ARG INSTALL_DOCKER="true"
# [Option] Enable non-root Docker access in container
ARG ENABLE_NONROOT_DOCKER="true"
# [Option] Install Azure CLI
ARG INSTALL_AZURE_CLI="true"
# Arguments set during docker-compose build -b --build from .env file
ARG versionTerraform
ARG versionTflint
ARG versionJq
ARG versionTfsec
ARG versionTerraformDocs
ARG versionAzureCli
# ARG versionKubectl
# ARG versionDockerCompose
# Install needed packages and setup non-root user. Use a separate RUN statement to add your own dependencies.
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID
ARG SOURCE_SOCKET=/var/run/docker-host.sock
ARG TARGET_SOCKET=/var/run/docker.sock
COPY library-scripts/*.sh /tmp/library-scripts/

# Install Azure CLI
#
# Add Azure repository
#
RUN curl -sL https://packages.microsoft.com/keys/microsoft.asc | \
    gpg --dearmor | \
    tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null && \
#
# Add Azure CLI apt repository
# Release: https://github.com/Azure/azure-cli/releases
#
    echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ bionic main"  | \
    tee /etc/apt/sources.list.d/azure-cli.list && \
    curl https://packages.microsoft.com/config/ubuntu/18.04/prod.list | tee /etc/apt/sources.list.d/msprod.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    azure-cli=${versionAzureCli}-1~bionic \
    # Clean up
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/* /tmp/library-scripts/

COPY library-scripts/*.sh /tmp/library-scripts/

# Terraform, tflint
# Release terraform: https://github.com/hashicorp/terraform/releases
# Release tflint: https://github.com/terraform-linters/tflint/releases
#
RUN bash /tmp/library-scripts/terraform-debian.sh "${versionTerraform}" "${versionTflint}" \
    # Clean up
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/* /tmp/library-scripts/

#
# Install tfsec
# Release: https://github.com/tfsec/tfsec/releases
#
RUN echo "Installing tfsec ${versionTfsec} ..." && \
    curl -sSL -o /bin/tfsec https://github.com/tfsec/tfsec/releases/download/v${versionTfsec}/tfsec-linux-amd64 && \
    chmod +x /bin/tfsec

#
# Install terraform docs
# Release: https://github.com/terraform-docs/terraform-docs/releases
#
RUN echo "Installing terraform docs ${versionTerraformDocs}..." && \
curl -sSL -o /bin/terraform-docs https://github.com/terraform-docs/terraform-docs/releases/download/v${versionTerraformDocs}/terraform-docs-v${versionTerraformDocs}-linux-amd64 && \
chmod +x /bin/terraform-docs

# Install kubectl
RUN curl -sSL -o /usr/local/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl \
    && chmod +x /usr/local/bin/kubectl

# Install Helm
RUN curl -s https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash -

#
# Install jq
#
RUN echo "Installing jq ${versionJq}..." && \
    curl -L -o /usr/bin/jq https://github.com/stedolan/jq/releases/download/jq-${versionJq}/jq-linux64 && \
    chmod +x /usr/bin/jq

ARG SSH_PASSWD

ENV SSH_PASSWD=${SSH_PASSWD} \
    USERNAME=${USERNAME} \
    versionTerraform=${versionTerraform} \
    versionTflint=${versionTflint} \
    versionJq=${versionJq} \
    TF_DATA_DIR="/home/${USERNAME}/.terraform.cache" \
    TF_PLUGIN_CACHE_DIR="/home/${USERNAME}/.terraform.cache/plugin-cache"

COPY ./scripts/sshd_config /home/${USERNAME}/.ssh/sshd_config

# Add Community terraform providers
COPY --from=azurecaf /tmp/terraform-provider-azurecaf/terraform-provider-azurecaf /bin/

WORKDIR /tf/rover

COPY ./scripts-rover/* ./

RUN echo "alias rover=/tf/rover/rover.sh" >> /home/${USERNAME}/.bashrc && \
    #echo "alias rover=/tf/rover/rover.sh" >> /root/.bashrc && \
    echo "alias gorover=/tf/rover/gorover.sh" >> /home/${USERNAME}/.bashrc && \
    #echo "alias gorover=/tf/rover/gorover.sh" >> /root/.bashrc && \
    echo "alias goterraform=/tf/rover/goterraform.sh" >> /home/${USERNAME}/.bashrc && \
    #echo "alias goterraform=/tf/rover/goterraform.sh" >> /root/.bashrc && \
    echo "alias runactions=/tf/rover/runactions.sh" >> /home/${USERNAME}/.bashrc && \
    #echo "alias runactions=/tf/rover/runactions.sh" >> /root/.bashrc && \
    echo "alias t=/usr/bin/terraform" >> /home/${USERNAME}/.bashrc && \
    #echo "alias t=/usr/bin/terraform" >> /root/.bashrc && \
    #echo "function rop() { /tf/rover/gorover.sh "$1" plan; }" >> /root/.bashrc && \
    #echo "function roa() { /tf/rover/gorover.sh "$1" apply; }" >> /root/.bashrc && \
    #echo "function rod() { /tf/rover/gorover.sh "$1" destroy; }" >> /root/.bashrc && \
    #echo "function roc() { /tf/rover/runactions.sh "$1"; }" >> /root/.bashrc && \
    echo "function rop() { /tf/rover/gorover.sh \${1} plan; }" >> /home/${USERNAME}/.bashrc && \
    echo "function roa() { /tf/rover/gorover.sh \${1} apply; }" >> /home/${USERNAME}/.bashrc && \
    echo "function rod() { /tf/rover/gorover.sh \${1} destroy; }" >> /home/${USERNAME}/.bashrc && \
    echo "function roc() { /tf/rover/runactions.sh \${1}; }" >> /home/${USERNAME}/.bashrc && \
    # mkdir -p /tf && \
    # mkdir -p /tf/caf && \
    # chown -R ${USERNAME}:1000 /tf/rover /tf/caf /home/${USERNAME}/.ssh && \
    chown -R ${USERNAME}:1000 /tf/rover /home/${USERNAME}/.ssh && \
    chmod +x /tf/rover/sshd.sh

ARG versionRover
ENV versionRover=${versionRover}
RUN echo ${versionRover} > /tf/rover/version.txt

USER ${USERNAME}
# WORKDIR /tf/caf

# Setting the ENTRYPOINT to docker-init.sh will configure non-root access to 
# the Docker socket if "overrideCommand": false is set in devcontainer.json. 
# The script will also execute CMD if you need to alter startup behaviors.
# ENTRYPOINT [ "/usr/local/share/docker-init.sh" ]
CMD [ "sleep", "infinity" ]