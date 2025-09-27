FROM alpine:latest

ARG DOTNET_SDK_URL="https://builds.dotnet.microsoft.com/dotnet/Sdk/10.0.100-rc.1.25451.107/dotnet-sdk-10.0.100-rc.1.25451.107-linux-musl-x64.tar.gz"

RUN apk add --no-cache \
        bash \
        build-base \
        ca-certificates \
        curl \
        icu-libs \
        krb5-libs \
        libgcc \
        libintl \
        libssl3 \
        libstdc++ \
        zlib \
        wget \
        git \
        iputils \
        nodejs \
        npm \
        openssh \
        python3 \
        py3-pip \
        sudo \
    && update-ca-certificates

## Install .NET SDK: download, extract, symlink in one layer to keep image small
RUN wget -qO dotnet-sdk.tar.gz "$DOTNET_SDK_URL" \
    && mkdir -p /usr/share/dotnet \
    && tar -zxf dotnet-sdk.tar.gz -C /usr/share/dotnet \
    && rm dotnet-sdk.tar.gz \
    && ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet \
    && dotnet --list-sdks

# Make dotnet available via environment (persists to later stages/users)
ENV DOTNET_ROOT=/usr/share/dotnet
ENV PATH=/usr/share/dotnet:${PATH}

# Create an unprivileged user and prepare npm global directory
ARG USERNAME=mariogk
ARG USER_UID=1000
ARG USER_GID=${USER_UID}
RUN addgroup -g ${USER_GID} ${USERNAME} \
    && adduser -u ${USER_UID} -G ${USERNAME} -s /bin/bash -D ${USERNAME} \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
    && mkdir -p /home/${USERNAME}/.npm-global \
    && chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}

# Set ENV for npm's global prefix and add its bin to the PATH
# This is the correct way to make global tools available to subsequent layers
ENV NPM_CONFIG_PREFIX=/home/${USERNAME}/.npm-global
ENV PATH=${NPM_CONFIG_PREFIX}/bin:${PATH}

# Switch to non-root user
USER ${USERNAME}
WORKDIR /home/${USERNAME}

# Install the npm tool globally
RUN npm install -g @anthropic-ai/claude-code && which claude