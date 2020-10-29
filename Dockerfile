###########################################################
# base tools and dependencies
###########################################################
FROM mcr.microsoft.com/vscode/devcontainers/base:ubuntu-18.04 as base

FROM base as rover_version

ARG versionRover

RUN echo ${versionRover} > version.txt

###########################################################
# Getting latest version of terraform-docs
###########################################################
FROM golang:1.13 as terraform-docs
ARG versionTerraformDocs
ENV versionTerraformDocs=${versionTerraformDocs}

RUN GO111MODULE="on" go get github.com/terraform-docs/terraform-docs@${versionTerraformDocs}

###########################################################
# Getting latest version of tfsec
###########################################################
FROM golang:1.13 as tfsec
ARG versionTfsec
ENV versionTfsec=${versionTfsec}

# to force the docker cache to invalidate when there is a new version
RUN GO111MODULE="on" go get github.com/tfsec/tfsec/cmd/tfsec@${versionTfsec}

###########################################################
# Getting latest version of Azure CAF Terraform provider
###########################################################
FROM golang:1.13 as azurecaf

ARG versionAzureCafTerraform
ENV versionAzureCafTerraform=${versionAzureCafTerraform}

# to force the docker cache to invalidate when there is a new version
ADD https://api.github.com/repos/aztfmod/terraform-provider-azurecaf/git/ref/tags/${versionAzureCafTerraform} version.json
RUN cd /tmp && \
    git clone https://github.com/aztfmod/terraform-provider-azurecaf.git && \
    cd terraform-provider-azurecaf && \
    go build -o terraform-provider-azurecaf

###########################################################
# Getting latest version of yaegashi/terraform-provider-msgraph
###########################################################
FROM golang:1.13 as msgraph

# to force the docker cache to invalidate when there is a new version
ADD https://api.github.com/repos/aztfmod/terraform-provider-azurecaf/git/ref/heads/master version.json
RUN cd /tmp && \
    git clone https://github.com/yaegashi/terraform-provider-msgraph.git && \
    cd terraform-provider-msgraph && \
    go build -o terraform-provider-msgraph

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
# ARG versionAzureCli
# ARG versionKubectl
ARG versionTflint
ARG versionJq
# ARG versionDockerCompose
ARG versionTfsec

# Install needed packages and setup non-root user. Use a separate RUN statement to add your own dependencies.
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID
ARG SOURCE_SOCKET=/var/run/docker-host.sock
ARG TARGET_SOCKET=/var/run/docker.sock
COPY library-scripts/*.sh /tmp/library-scripts/

# Install Azure CLI
RUN apt-get update \
    # Use azcli
    && if [ "${INSTALL_AZURE_CLI}" = "true" ]; then bash /tmp/library-scripts/azcli-debian.sh; fi \
    # Clean up
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/* /tmp/library-scripts/

COPY library-scripts/*.sh /tmp/library-scripts/

RUN apt-get update \
    && /bin/bash /tmp/library-scripts/common-debian.sh "${INSTALL_ZSH}" "${USERNAME}" "${USER_UID}" "${USER_GID}" "${UPGRADE_PACKAGES}" \
    # Use Docker script from script library to set things up
    && if [ "${INSTALL_DOCKER}" = "true" ]; then /bin/bash /tmp/library-scripts/docker-debian.sh "${ENABLE_NONROOT_DOCKER}" "${SOURCE_SOCKET}" "${TARGET_SOCKET}" "${USERNAME}"; fi \
    # Docker compose
    && apt install -y docker-compose gnupg2 pass make \
    # Terraform, tflint
    && bash /tmp/library-scripts/terraform-debian.sh "0.13.5" "${versionTflint}" \
    # Clean up
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/* /tmp/library-scripts/

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
COPY --from=msgraph /tmp/terraform-provider-msgraph/terraform-provider-msgraph /bin/
COPY --from=tfsec /go/bin/tfsec /bin/
COPY --from=terraform-docs /go/bin/terraform-docs /bin/

WORKDIR /tf/rover

COPY ./scripts/rover.sh .
COPY ./scripts/functions.sh .
COPY ./scripts/banner.sh .
COPY ./scripts/clone.sh .
COPY ./scripts/sshd.sh .
COPY --from=rover_version version.txt /version.txt

RUN echo "alias rover=/tf/rover/rover.sh" >> /home/${USERNAME}/.bashrc && \
    echo "alias t=/usr/bin/terraform" >> /home/${USERNAME}/.bashrc && \
    echo "alias rover=/tf/rover/rover.sh" >> /root/.bashrc && \
    echo "alias t=/usr/bin/terraform" >> /root/.bashrc && \
    # mkdir -p /tf && \
    # mkdir -p /tf/caf && \
    # chown -R ${USERNAME}:1000 /tf/rover /tf/caf /home/${USERNAME}/.ssh && \
    chown -R ${USERNAME}:1000 /tf/rover /home/${USERNAME}/.ssh && \
    chmod +x /tf/rover/sshd.sh

USER ${USERNAME}
WORKDIR /tf/caf

# Setting the ENTRYPOINT to docker-init.sh will configure non-root access to 
# the Docker socket if "overrideCommand": false is set in devcontainer.json. 
# The script will also execute CMD if you need to alter startup behaviors.
ENTRYPOINT [ "/usr/local/share/docker-init.sh" ]
CMD [ "sleep", "infinity" ]