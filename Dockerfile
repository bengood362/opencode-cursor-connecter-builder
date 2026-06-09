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

# Set working directory to match the mount point in the user's docker run command
WORKDIR /workspace

# Create entrypoint script that runs cursor-agent login then opencode
RUN printf '#!/bin/bash\n\
set -e\n\
source ~/.bash_profile\n\
cursor-agent login\n\
open-cursor sync-models\n\
cp -r ~/.cursor /workspace/.cursor\n\
exec "$@"' > /usr/local/bin/entrypoint.sh && \
chmod +x /usr/local/bin/entrypoint.sh

# Set the entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]