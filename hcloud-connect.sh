#!/usr/bin/env bash
SERVER_NAME="$1"
shift
exec ssh -F .servers/"$SERVER_NAME"/config server "$@"
