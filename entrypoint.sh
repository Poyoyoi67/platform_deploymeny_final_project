#!/bin/sh
set -e

echo "Starting Container"

# Wait for MySQL using a simple TCP check instead of php console
MAX_TRIES=30
COUNT=0

echo "Waiting for database to be ready..."
until nc -z "$MYSQLHOST" "$MYSQLPORT" 2>/dev/null; do
    COUNT=$((COUNT + 1))
    if [ $COUNT -ge $MAX_TRIES ]; then
        echo "Database timeout - starting anyway..."
        break
    fi
    echo "Database not ready yet, retrying in 3 seconds..."
    sleep 3
done

echo "Running database migrations..."
php bin/console doctrine:migrations:migrate --no-interaction --allow-no-migration

echo "Clearing cache..."
php bin/console cache:clear --env=prod --no-warmup

echo "Warming up cache..."
php bin/console cache:warmup --env=prod

echo "Fixing permissions..."
chmod -R 777 var/

echo "Starting PHP-FPM..."
php-fpm -D

echo "Starting Nginx..."
exec nginx -g "daemon off;"