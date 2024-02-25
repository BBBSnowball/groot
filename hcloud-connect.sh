#!/usr/bin/env bash
SERVER_NAME="$1"
if [ -z "$SERVER_NAME" ] ; then
  echo "Usage: $0 servername [cmd]" >&2
  exit 1
fi
shift
exec ssh -F .servers/"$SERVER_NAME"/config server "$@"
