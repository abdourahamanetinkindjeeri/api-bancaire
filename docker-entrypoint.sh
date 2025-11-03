#!/bin/sh

# Copier les clés OAuth depuis Render Secret Files si elles existent
if [ -f /etc/secrets/oauth-private.key ]; then
    cp /etc/secrets/oauth-private.key storage/oauth-private.key
fi

if [ -f /etc/secrets/oauth-public.key ]; then
    cp /etc/secrets/oauth-public.key storage/oauth-public.key
fi

# Attendre que la base de données soit prête
echo "Waiting for database to be ready..."
while ! pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USERNAME"; do
  echo "Database is unavailable - sleeping"
  sleep 1
done

echo "Database is up - executing migrations"
php artisan migrate --force

echo "Starting Laravel application..."
exec "$@"
