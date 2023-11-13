#!/bin/sh

# Configuration
sqlport="${EMISHOWS_DB_SQL_PORT:-34000}"
httpport="${EMISHOWS_DB_HTTP_PORT:-34001}"
rpcport="${EMISHOWS_DB_RPC_PORT:-34002}"

retries=30
interval=1

datadir=data
certsdir="${datadir}/certs"
storedir="${datadir}/store"

tmpinit=$(mktemp --suffix=.sql --tmpdir=/tmp)

# Make sure the directories exists
mkdir --parents "${datadir}" "${certsdir}" "${storedir}"

# Replace environment variables in init file and save to temporary file
envsubst <src/init.sql >"${tmpinit}"

# Remove old certificates
rm --force "${certsdir:?}"/*

# Generate certificates
cockroachdb \
	connect \
	init \
	--sql-addr="0.0.0.0:${sqlport}" \
	--advertise-sql-addr="localhost:${sqlport}" \
	--http-addr="0.0.0.0:${httpport}" \
	--advertise-http-addr="localhost:${httpport}" \
	--listen-addr="0.0.0.0:${rpcport}" \
	--advertise-addr="localhost:${rpcport}" \
	--certs-dir="${certsdir}" \
	--single-node \
	>/dev/null

cockroachdb \
	cert \
	create-client \
	root \
	--certs-dir="${certsdir}" \
	--ca-key="${certsdir}/ca-client.key" \
	>/dev/null

# Start CockroachDB in the background
cockroachdb \
	start-single-node \
	--sql-addr="0.0.0.0:${sqlport}" \
	--advertise-sql-addr="localhost:${sqlport}" \
	--http-addr="0.0.0.0:${httpport}" \
	--advertise-http-addr="localhost:${httpport}" \
	--listen-addr="0.0.0.0:${rpcport}" \
	--advertise-addr="localhost:${rpcport}" \
	--certs-dir="${certsdir}" \
	--accept-sql-without-tls \
	--store="path=${storedir}" \
	&

echo 'Setting up...'

# Wait for CockroachDB to start up
for i in $(seq 1 "${retries}"); do
	if [ "${i}" -eq "${retries}" ]; then
		echo 'Could not connect to CockroachDB!'
		exit 1
	fi

	if cockroachdb \
		sql \
		--certs-dir="${certsdir}" \
		--port="${sqlport}" \
		--execute="" \
		>/dev/null 2>&1 \
		; then
		echo 'Connected to CockroachDB!'
		break
	else
		echo 'Waiting for connection to CockroachDB...'
		sleep "${interval}"
	fi
done

# Setup database
cockroachdb sql \
	--certs-dir="${certsdir}" \
	--port="${sqlport}" \
	--file="${tmpinit}"

echo 'Setup complete!'

# Wait for Radicale to exit
wait

# Cleanup
rm -rf "${tmpinit}"
