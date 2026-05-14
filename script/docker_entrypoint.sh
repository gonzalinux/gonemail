#!/bin/sh
set -e

echo "Creating database if it doesn't exist..."
/app/bin/gonemail eval "Gonemail.Release.create()" || echo "Database creation failed, may already exist"

echo "Running migrations..."
/app/bin/gonemail eval "Gonemail.Release.migrate()" || echo "Migration failed, continuing..."

echo "Starting Gonemail..."
exec /app/bin/gonemail start
