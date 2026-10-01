# syntax=docker/dockerfile:1
ARG UBUNTU_VERSION=24.04

FROM ubuntu:${UBUNTU_VERSION} AS agent-download
ARG AGENT_VERSION
ARG AGENT_PLATFORM=linux-x64
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl \
 && rm -rf /var/lib/apt/lists/*
RUN test -n "${AGENT_VERSION}" \
 && mkdir -p /azp/agent \
 && curl -fsSL "https://download.agent.dev.azure.com/agent/${AGENT_VERSION}/vsts-agent-${AGENT_PLATFORM}-${AGENT_VERSION}.tar.gz" \
    | tar -xz -C /azp/agent

FROM ubuntu:${UBUNTU_VERSION}
# Runtime dependencies for the agent; no Azure CLI to keep the image small. Package names match 24.04.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl git jq tzdata unzip zip \
      libicu74 libssl3t64 libkrb5-3 zlib1g \
 && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --uid 10001 --user-group agent

COPY --from=agent-download --chown=agent:agent /azp /azp
COPY --chown=agent:agent start.sh /azp/start.sh
RUN chmod +x /azp/start.sh && mkdir -p /azp/_work && chown agent:agent /azp/_work

USER 10001:10001
WORKDIR /azp
ENTRYPOINT ["/azp/start.sh"]
