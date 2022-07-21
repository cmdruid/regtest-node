FROM debian:bullseye-slim

ARG HOMEDIR="/root"
ARG RUNPATH="$HOMEDIR/run"
ARG LIBPATH="$RUNPATH/lib"
ARG CLNPATH="$HOMEDIR/.lightning"

## Install dependencies.
RUN apt-get update && apt-get install -y \
  curl git iproute2 jq libevent-dev libsodium-dev lsof man netcat \
  openssl procps python3 python3-pip qrencode socat xxd neovim \
  autoconf automake build-essential libtool libgmp-dev libsqlite3-dev \
  pkg-config net-tools zlib1g-dev gettext

## Install python modules.
RUN pip3 install --upgrade pip
RUN pip3 install poetry mako mrkd mistune==0.8.4 Flask pyln-client

## Install Node.
RUN curl -fsSL https://deb.nodesource.com/setup_17.x | bash - && apt-get install -y nodejs

## Install node packages.
RUN npm install -g npm yarn clightningjs

## Copy over binaries.
COPY build/out/* /tmp/bin/

WORKDIR /tmp

## Unpack and/or install binaries.
RUN for file in /tmp/bin/*; do \
  if ! [ -z "$(echo $file | grep .tar.)" ]; then \
    echo "Unpacking $file to /usr ..." \
    && tar --wildcards --strip-components=1 -C /usr -xf $file \
  ; else \
    echo "Moving $file to /usr/local/bin ..." \
    && chmod +x $file && mv $file /usr/local/bin/ \
  ; fi \
; done

## Clean up temporary files.
RUN rm -rf /tmp/* /var/tmp/*

## Uncomment this if you also want to wipe all repository lists.
#RUN rm -rf /var/lib/apt/lists/*

## Install sparko binary
RUN PLUGPATH="$CLNPATH/plugins" && mkdir -p $PLUGPATH \
  && curl https://github.com/fiatjaf/sparko/releases/download/v2.9/sparko_linux_amd64 \
  -fsL#o $PLUGPATH/sparko && chmod +x $PLUGPATH/sparko

## Install RTL REST API.
RUN PLUGPATH="$CLNPATH/plugins" && mkdir -p $PLUGPATH && cd $PLUGPATH \
  && git clone https://github.com/Ride-The-Lightning/c-lightning-REST.git cl-rest \
  && cd cl-rest && npm install

## Copy configuration and run environment.
COPY config /
COPY run $RUNPATH/

## Add bash aliases to .bashrc.
RUN alias_file="~/.bash_aliases" \
  && printf "if [ -e $alias_file ]; then . $alias_file; fi\n\n" >> $HOMEDIR/.bashrc

## Make sure scripts are executable.
RUN for file in `grep -lr '#!/usr/bin/env' $RUNPATH`; do chmod +x $file; done

## Symlink entrypoint and login to PATH.
RUN ln -s $RUNPATH/entrypoint.sh /usr/local/bin/workbench

## Configure run environment.
ENV PATH="$LIBPATH/bin:$HOMEDIR/.local/bin:$PATH"
ENV PYPATH="$LIBPATH/pylib:$PYPATH"
ENV NODE_PATH="$LIBPATH/nodelib:$NODE_PATH"
ENV RUNPATH="$RUNPATH"
ENV LIBPATH="$LIBPATH"
ENV LOGPATH="/var/log"
ENV ONIONPATH="/data/tor/services"

## Configure Core Lightning Environment
ENV LNPATH="$HOMEDIR/.lightning"
ENV PLUGPATH="$RUNPATH/plugins/"
ENV LNRPCPATH="$LNPATH/regtest/lightning-rpc"

WORKDIR /root/run/repo/clightning
RUN poetry install

WORKDIR $HOMEDIR

ENTRYPOINT [ "workbench" ]
CMD [ "start" ]
