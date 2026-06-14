ARG TAG=1.1.48-oe2403lts
ARG OC_VERSION=v2.4.6
FROM openeuler/opencode:$TAG

ARG OC_VERSION
# Install bun
RUN curl -fsSL https://bun.com/install | bash && echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bash_profile

# Install cursor
RUN curl -fsSL https://cursor.com/install | bash

# Install opencode-cursor script
RUN curl -fsSL https://raw.githubusercontent.com/Nomadcxx/opencode-cursor/refs/tags/${OC_VERSION}/install.sh | bash

# Utilities
RUN dnf clean all && dnf makecache && dnf install jq -y

# Set working directory to match the mount point in the user's docker run command
WORKDIR /workspace
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
    plugin: merge_field("plugin")\n\
  }\n\
'"'"' -s .config/opencode/opencode.json /root/.config/opencode/opencode.json > /root/.config/opencode/opencode.json' > /usr/local/bin/merge-config.sh && \
chmod +x /usr/local/bin/merge-config.sh

# Create entrypoint script that runs cursor-agent login then opencode
RUN printf '#!/bin/bash\n\
set -e\n\
source ~/.bash_profile\n\
cursor-agent login\n\
/usr/local/bin/merge-config.sh\n\
open-cursor sync-models\n\
cp -r ~/.cursor /workspace/.cursor\n\
exec "$@"' > /usr/local/bin/entrypoint.sh && \
chmod +x /usr/local/bin/entrypoint.sh

# Set the entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]