FROM debian:bullseye-slim

ARG HOMEDIR="/root"
ARG RUNPATH="$HOMEDIR/run"
ARG LIBPATH="$RUNPATH/lib"

## Install dependencies.
RUN apt-get update && apt-get install -y \
  curl git iproute2 jq libevent-dev libsodium-dev lsof man netcat \
  openssl procps python3 python3-pip qrencode socat xxd neovim

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

## Install python modules.
RUN pip3 install Flask pyln-client

## Install Node.
RUN curl -fsSL https://deb.nodesource.com/setup_17.x | bash - && apt-get install -y nodejs

## Install node packages.
RUN npm install -g npm yarn

## Install sparko binary
RUN PLUGPATH="$HOMEDIR/.lightning/plugins" && mkdir -p $PLUGPATH \
  && curl https://github.com/fiatjaf/sparko/releases/download/v2.9/sparko_linux_amd64 \
  -fsL#o $PLUGPATH/sparko && chmod +x $PLUGPATH/sparko

## Install RTL REST API.
# RUN mkdir -p /root/.lightning \
#   && cd /root/.lightning \
#   && git clone https://github.com/Ride-The-Lightning/c-lightning-REST.git \
#   && cd cl-rest && npm install

WORKDIR $HOMEDIR

## Configure user account for Tor.
# RUN addgroup tor \
#   && adduser --system --no-create-home tor \
#   && adduser tor tor \
#   && chown -R tor:tor /var/lib/tor /var/log/tor

## Copy configuration and run environment.
COPY config $HOMEDIR/config/
COPY run $RUNPATH/

## Add bash aliases to .bashrc.
RUN alias_file="~/config/.bash_aliases" \
  && printf "if [ -e $alias_file ]; then . $alias_file; fi\n\n" >> $HOMEDIR/.bashrc

## Make sure scripts are executable.
RUN for file in `grep -lr '#!/usr/bin/env' $RUNPATH`; do chmod +x $file; done

## Configure additional paths.
ENV PATH="$LIBPATH/bin:$HOMEDIR/.local/bin:$PATH"
ENV PYPATH="$LIBPATH/pylib:$PYPATH"

ENTRYPOINT [ "$RUNPATH/entrypoint.sh" ]
