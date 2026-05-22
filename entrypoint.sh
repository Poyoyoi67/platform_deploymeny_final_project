#!/bin/sh
set -e

echo "Waiting for database to be ready..."
until php bin/console doctrine:query:sql "SELECT 1" > /dev/null 2>&1; do
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
exec php-fpm