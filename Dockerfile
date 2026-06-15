ARG TAG=1.1.48-oe2403lts
FROM openeuler/opencode:$TAG

# Dependencies version
ARG OC_VERSION=v2.4.6
ARG UA_VERSION=v2.7.3

# Utilities
RUN dnf clean all && dnf makecache && dnf install jq -y

# Non-root user preparation
ARG USERNAME=appuser
ARG USER_UID=1000
ARG USER_GID=1000

RUN printf '#!/bin/bash\n\
set -e\n\
jq -s '"'"'\n\
  def merge_field($field):\n\
    reduce .[] as $item (null;\n\
      . as $acc\n\
      | ($item[$field]) as $val\n\
      | if $val == null then\n\
          $acc\n\
        elif ($acc | type) == "array" and ($val | type) == "array" then\n\
          $acc + $val\n\
        elif ($acc | type) == "object" and ($val | type) == "object" then\n\
          $acc * $val\n\
        elif $acc == null then\n\
          $val\n\
        else\n\
          # Fallback: if types differ or unexpected, just replace\n\
          $val\n\
        end\n\
    );\n\
\n\
  {\n\
    "$schema": merge_field("$schema"),\n\
    plugin: merge_field("plugin"),\n\
    provider: merge_field("provider"),\n\
    permission: merge_field("permission"),\n\
    plugin: merge_field("plugin"),\n\
    lsp: merge_field("lsp")\n\
  }\n\
'"'"' -s /home/%s/workspace/.config/opencode/opencode.json /home/%s/.config/opencode/opencode.json > /home/%s/.config/opencode/opencode.json' "${USERNAME}" "${USERNAME}" "${USERNAME}" > "/merge-config.sh" && \
chmod +x "/merge-config.sh" && \
chown $USER_UID:$USER_GID "/merge-config.sh"

# Create entrypoint script that runs cursor-agent login then opencode
RUN printf '#!/bin/bash\n\
set -e\n\
source ~/.bash_profile\n\
cursor-agent login\n\
cp /home/%s/.config/opencode/opencode.json /home/%s/.config/opencode/opencode.json.bak \n\
/merge-config.sh\n\
open-cursor sync-models\n\
cp -r ~/.cursor /home/%s/workspace/.cursor\n\
exec "$@"' "${USERNAME}" "${USERNAME}" "${USERNAME}" > /entrypoint.sh && \
chmod +x /entrypoint.sh && \
chown $USER_UID:$USER_GID /entrypoint.sh

# Environment
RUN groupadd --gid "$USER_GID" "$USERNAME" \
  && useradd --uid "$USER_UID" --gid "$USER_GID" -m "$USERNAME"

USER "$USERNAME"
WORKDIR /home/"$USERNAME"/workspace

# Dependencies: npm global
RUN npm config set prefix ~/.local && PATH=~/.local/bin:$PATH

# Dependencies: bun
RUN curl -fsSL https://bun.com/install | bash && echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bash_profile

# Dependencies: cursor
RUN curl -fsSL https://cursor.com/install | bash

# Dependencies: opencode-cursor script
RUN curl -fsSL https://raw.githubusercontent.com/Nomadcxx/opencode-cursor/refs/tags/${OC_VERSION}/install.sh | bash
RUN curl -fsSL https://raw.githubusercontent.com/Egonex-AI/Understand-Anything/refs/tags/${UA_VERSION}/install.sh | bash -s opencode

# Set working directory to match the mount point in the user's docker run command
RUN mkdir -p /home/"${USERNAME}"/bin


# Set the entrypoint
ENV USERNAME=${USERNAME}
ENTRYPOINT ["/entrypoint.sh"]
# ENTRYPOINT ["/bin/sh", "-c", "cd $HOME && exec /home/$USERNAME/bin/entrypoint.sh ${@}"]