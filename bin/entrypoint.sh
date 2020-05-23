#!/bin/bash

set -e

# Get config for first database from environment variables with no counter.
export HOSTNAME_1="${HOSTNAME_1:-$HOSTNAME}"
export DBHOST_1="${DBHOST_1:-${DBHOST:-mysql}}"
export DBPASSWORD_1="${DBPASSWORD_1:-$DBPASSWORD}"
export DBPORT_1="${DBPORT_1:-${DBPORT:-3306}}"
export DBUSER_1="${DBUSER_1:-${DBUSER:-root}}"

exec "$@"
