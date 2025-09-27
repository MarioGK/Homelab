FROM alpine:latest

RUN apk update

# Install dotnet 10 dependencies
RUN apk add --no-cache \
    build-base \
    bash \
    curl \
    icu-libs \
    krb5-libs \
    libgcc \
    libintl \
    libssl3 \
    libstdc++ \
    zlib \
    wget

ENV DOTNET_SDK_URL="https://builds.dotnet.microsoft.com/dotnet/Sdk/10.0.100-rc.1.25451.107/dotnet-sdk-10.0.100-rc.1.25451.107-linux-musl-x64.tar.gz"
RUN wget -O dotnet-sdk.tar.gz $DOTNET_SDK_URL
RUN mkdir -p /usr/share/dotnet
RUN tar -zxf dotnet-sdk.tar.gz -C /usr/share/dotnet
RUN rm dotnet-sdk.tar.gz
RUN ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet
RUN export DOTNET_ROOT=/usr/share/dotnet
RUN export PATH=$PATH:/usr/share/dotnet
RUN echo 'export DOTNET_ROOT=/usr/share/dotnet' >> /etc/profile
RUN echo 'export PATH=$PATH:/usr/share/dotnet' >> /etc/profile

RUN dotnet --version

RUN apk add --no-cache \
    avahi \
    dbus \
    git \
    iputils \
    nodejs \
    npm \
    openssh \
    python3 \
    py3-pip \
    sudo

#Setup a non-root user
ARG USERNAME=mariogk
ARG USER_UID=1000
ARG USER_GID=$USER_UID
RUN addgroup -g $USER_GID $USERNAME \
    && adduser -u $USER_UID -G $USERNAME -s /bin/bash -D $USERNAME \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Switch to non-root user
USER $USERNAME
WORKDIR /home/$USERNAME

# Make sure that dotnet is available in the PATH for the non-root user
ENV DOTNET_ROOT=/usr/share/dotnet
ENV PATH=$PATH:/usr/share/dotnet
RUN echo 'export DOTNET_ROOT=/usr/share/dotnet' >> /home/$USERNAME/.bashrc
RUN echo 'export PATH=$PATH:/usr/share/dotnet' >> /home/$USERNAME/.bashrc
RUN source /home/$USERNAME/.bashrc
# Verify installation
RUN dotnet --version

#Install claude code
RUN npm install -g @anthropic-ai/claude-code

#Make sure that npm global packages are available in the PATH
ENV PATH=$PATH:/home/$USERNAME/.npm-global/bin
RUN echo 'export PATH=$PATH:/home/$USERNAME/.npm-global/bin' >> /home/$USERNAME/.bashrc
RUN source /home/$USERNAME/.bashrc
# Verify installation
RUN which claude-code