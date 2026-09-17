# =============================================================================
# Hermes Agent Railway Template
# Based on the official Nous Research Hermes Agent image.
# Bump HERMES_VERSION to upgrade — see README "Updating".
# =============================================================================

ARG HERMES_VERSION=v2026.9.14
FROM nousresearch/hermes-agent:${HERMES_VERSION}

# The base image's ENTRYPOINT is /opt/hermes/docker/entrypoint-dispatch.sh
# (s6-overlay supervised gateway + dashboard). We wrap it to prime
# Railway-specific environment, then hand off unchanged.

COPY start.sh /usr/local/bin/railway-entrypoint
RUN chmod +x /usr/local/bin/railway-entrypoint

# Enable the built-in web dashboard (supervised alongside the gateway).
ENV HERMES_DASHBOARD=1

ENTRYPOINT ["/usr/local/bin/railway-entrypoint"]
# "gateway run" registers the supervised gateway service with s6-overlay.
CMD ["gateway", "run"]
