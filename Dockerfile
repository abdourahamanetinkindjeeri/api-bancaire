# ==========================
# Étape 1 : Build des dépendances PHP
# ==========================
FROM composer:2.6 AS composer-build

WORKDIR /app

# Copier uniquement composer.json et composer.lock pour profiter du cache Docker
COPY composer.json composer.lock /app/

# Installer les dépendances sans exécuter les scripts artisan
RUN composer install --no-scripts --optimize-autoloader --no-interaction --prefer-dist

# Copier le reste du code
COPY . .

# Installer Swagger si nécessaire
RUN composer require "zircote/swagger-php:^4.0" --no-scripts --no-interaction --prefer-dist

# ==========================
# Étape 2 : Image finale PHP-FPM
# ==========================
FROM php:8.3-fpm-alpine

# Installer les extensions PHP nécessaires pour Laravel
RUN apk add --no-cache \
        postgresql-dev \
        libpng-dev \
        libjpeg-turbo-dev \
        libwebp-dev \
        freetype-dev \
        oniguruma-dev \
        bash \
    && docker-php-ext-install \
        pdo \
        pdo_pgsql \
        bcmath \
        gd \
        mbstring \
        exif \
        pcntl \
        tokenizer \
        xml

# Créer un utilisateur non-root
RUN addgroup -g 1000 laravel \
    && adduser -G laravel -g laravel -s /bin/sh -D laravel

# Définir le répertoire de travail
WORKDIR /var/www/html

# Copier le code depuis l'étape build
COPY --from=composer-build /app /var/www/html

# Copier les clés OAuth depuis /etc/secrets fourni par Render
RUN cp /etc/secrets/oauth-private.key storage/oauth-private.key \
    && cp /etc/secrets/oauth-public.key storage/oauth-public.key

# Créer les répertoires nécessaires et donner les bonnes permissions
RUN mkdir -p storage/framework/{cache,data,sessions,testing,views} \
    && mkdir -p storage/logs bootstrap/cache \
    && chown -R laravel:laravel /var/www/html \
    && chmod -R 775 storage bootstrap/cache

# Utilisateur non-root par défaut
USER laravel

# Exposer le port 8000 (pour dev)
EXPOSE 8000

# Commande par défaut (développement)
CMD ["php", "artisan", "serve", "--host=0.0.0.0", "--port=8000"]
