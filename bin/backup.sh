#!/bin/bash

set -e

setup.sh

for i in {1..5}; do
	export HOSTNAME_VAR="HOSTNAME_$i"
	export DBHOST_VAR="DBHOST_$i"
	export DBPASSWORD_VAR="DBPASSWORD_$i"
	export DBPORT_VAR="DBPORT_$i"
	export DBUSER_VAR="DBUSER_$i"

	export HOSTNAME="${!HOSTNAME_VAR:-$DBHOST_$i}"
	export DBHOST="${!DBHOST_VAR}"
	export DBPASSWORD="${!DBPASSWORD_VAR}"
	export DBPORT="${!DBPORT_VAR:-3306}"
	export DBUSER="${!DBUSER_VAR}"

	# No more databases.
	for var in DBHOST DBUSER; do
		[[ -z "${!var}" ]] && {
			echo 'Finished backup successfully'
			exit 0
		}
	done

	echo "Dumping database cluster $i: $DBUSER@$DBHOST:$DBPORT"

	# Wait for MySQL to become available.
	COUNT=0
	until mysqlshow -h $DBHOST -P $DBPORT -u $DBUSER -p $DBPASSWORD > /dev/null 2>&1; do
		if [[ "$COUNT" == 0 ]]; then
			echo "Waiting for MySQL to become available..."
		fi
		(( COUNT += 1 ))
		sleep 1
	done
	if (( COUNT > 0 )); then
		echo "Waited $COUNT seconds."
	fi

	mkdir -p "/mysqldump"

	# Dump individual databases directly to restic repository.
	DBLIST=$(mysql -h $DBHOST -P $DBPORT -u $DBUSER -p $DBPASSWORD -e "SELECT schema_name from INFORMATION_SCHEMA.SCHEMATA WHERE schema_name NOT IN ('sys', 'information_schema', 'mysql', 'performance_schema')")
	for dbname in $DBLIST; do
		echo "Dumping database '$dbname'"
		mysqldump --databases $dbname --add-drop-database --triggers --routines --events --set-gtid-purged=OFF -h $DBHOST -P $DBPORT -u $DBUSER -p $DBPASSWORD  > /mysqldump/$dbname.sql || true  # Ignore failures
	done

	echo "Sending database dumps to S3"
	while ! restic backup --host "$HOSTNAME" "/mysqldump"; do
		echo "Sleeping for 10 seconds before retry..."
		sleep 10
	done

	echo 'Finished sending database dumps to S3'

	rm -rf "/mysqldump"
done
