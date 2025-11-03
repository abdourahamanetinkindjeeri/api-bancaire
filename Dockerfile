# Étape 1: Build des dépendances PHP
FROM composer:2.6 AS composer-build

WORKDIR /app

# Copier tout le code source
COPY . .

# Installer les dépendances Swagger et Laravel sans exécuter les scripts artisan
RUN composer require "zircote/swagger-php:^4.0" --no-scripts --no-interaction --prefer-dist \
    && composer install --no-scripts --optimize-autoloader --no-interaction --prefer-dist

# Lancer manuellement les scripts une fois tout installé


# Étape 2: Image finale pour l'application
FROM php:8.3-fpm-alpine

# Installer les extensions PHP nécessaires
RUN apk add --no-cache postgresql-dev \
    && docker-php-ext-install pdo pdo_pgsql

# Créer un utilisateur non-root
RUN addgroup -g 1000 laravel && adduser -G laravel -g laravel -s /bin/sh -D laravel

# Définir le répertoire de travail
WORKDIR /var/www/html

# Copier les fichiers du build
COPY --from=composer-build /app /var/www/html

# Copier les clés OAuth depuis un dossier sécurisé (doit être monté via docker-compose ou volume)
COPY ./secrets/oauth-private.key storage/oauth-private.key
COPY ./secrets/oauth-public.key storage/oauth-public.key
# Créer les répertoires nécessaires
RUN mkdir -p storage/framework/{cache,data,sessions,testing,views} \
    && mkdir -p storage/logs bootstrap/cache \
    && chown -R laravel:laravel /var/www/html \
    && chmod -R 775 storage bootstrap/cache

USER laravel

EXPOSE 8000

# Default command - can be overridden in docker-compose.yml
CMD ["php", "artisan", "serve", "--host=0.0.0.0", "--port=8000"]
