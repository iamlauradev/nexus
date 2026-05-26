#!/bin/sh
set -e

echo "Waiting for PostgreSQL..."
until python3 -c "import psycopg2; psycopg2.connect(host='$DB_HOST', dbname='$DB_NAME', user='$DB_USER', password='$DB_PASSWORD')" 2>/dev/null; do
    echo "  postgres not ready, retrying in 2s..."
    sleep 2
done
echo "PostgreSQL ready."

echo "Running Alembic migrations..."
alembic upgrade head

echo "Starting Nexus API..."
exec uvicorn main:app --host 0.0.0.0 --port 8000 --workers 1
