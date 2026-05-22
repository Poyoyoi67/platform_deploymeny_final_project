#!/bin/sh
set -e

echo "Starting Container"

# Always run in production (dev bundles are not installed with --no-dev).
export APP_ENV=prod
export APP_DEBUG=0
echo "Running in APP_ENV=${APP_ENV}"

# Railway may expose MYSQLUSER or MYSQL_USER (same for password/database).
DB_HOST="${MYSQLHOST:-${MYSQL_HOST:-127.0.0.1}}"
DB_PORT="${MYSQLPORT:-${MYSQL_PORT:-3306}}"
DB_USER="${MYSQLUSER:-${MYSQL_USER:-}}"
DB_PASS="${MYSQLPASSWORD:-${MYSQL_PASSWORD:-}}"
DB_NAME="${MYSQLDATABASE:-${MYSQL_DATABASE:-}}"

if [ -z "$DATABASE_URL" ] && [ -n "$MYSQLHOST" ] && [ -n "$DB_USER" ]; then
    export DATABASE_URL="mysql://${DB_USER}:${DB_PASS}@${MYSQLHOST}:${MYSQLPORT}/${DB_NAME}?serverVersion=8.0.32&charset=utf8mb4"
    echo "DATABASE_URL configured from Railway MySQL variables."
fi

# Runtime overrides (PHP-FPM does not inherit shell exports by default).
{
    echo "APP_ENV=prod"
    echo "APP_DEBUG=0"
    if [ -n "$DATABASE_URL" ]; then
        echo "DATABASE_URL=${DATABASE_URL}"
    fi
} > .env.local

MAX_TRIES=30
COUNT=0

echo "Waiting for database to be ready at ${DB_HOST}:${DB_PORT}..."
until nc -z "$DB_HOST" "$DB_PORT" 2>/dev/null; do
    COUNT=$((COUNT + 1))
    if [ $COUNT -ge $MAX_TRIES ]; then
        echo "Database timeout - starting anyway..."
        break
    fi
    echo "Database not ready yet, retrying in 3 seconds..."
    sleep 3
done

echo "Running database migrations..."
php bin/console doctrine:migrations:migrate --env=prod --no-interaction --allow-no-migration

echo "Clearing cache..."
php bin/console cache:clear --env=prod --no-warmup

echo "Warming up cache..."
php bin/console cache:warmup --env=prod

echo "Fixing permissions..."
mkdir -p var/cache var/log
chmod -R 777 var/

PORT="${PORT:-8080}"
echo "Configuring Nginx to listen on 0.0.0.0:${PORT}..."
sed -i "s/listen 80;/listen 0.0.0.0:${PORT};/" /etc/nginx/conf.d/default.conf

echo "Starting PHP-FPM..."
php-fpm -D

echo "Testing Nginx configuration..."
nginx -t

echo "Container is ready. Open your Railway URL (listening on port ${PORT})."
echo "Nginx is running — new log lines appear when someone visits the site."
exec nginx -g "daemon off;"
