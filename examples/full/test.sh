#!/usr/bin/bash

export MYAPP_USER="John Smith"
# Will be overriden by CLI
export MYAPP_FREQUENCY=32
# Will be overriden by CLI
export MYAPP_WITNESS_NAME="Solomon"
export MYAPP_WITNESS_AGE=121

exec dub run -- some -O witness.name="Kevin Bacon" positional -O frequency=42 arguments -c myconfig.yaml
