#!/bin/bash
source /usr/local/bin/common.sh
grep '^###' "$CONF" | sed 's/^### /- /'

