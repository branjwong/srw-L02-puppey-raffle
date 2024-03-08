FROM ghcr.io/trailofbits/eth-security-toolbox:nightly-20240304

USER root
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends make

USER ethsec
ENV SHELL /bin/bash
