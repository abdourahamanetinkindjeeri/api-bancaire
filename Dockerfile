# ==========================
# Étape 1 : Build des dépendances PHP
# ==========================
FROM composer:2.6 AS composer-build

WORKDIR /app

# Copier uniquement composer.json et composer.lock pour profiter du cache Docker
COPY composer.json composer.lock /app/

# Installer les dépendances sans exécuter les scripts artisan
RUN composer install --no-scripts --optimize-autoloader --no-interaction --prefer-dist

# Copier le reste du code source
COPY . .

# Installer Swagger
RUN composer require "zircote/swagger-php:^4.0" --no-scripts --no-interaction --prefer-dist

# ==========================
# Étape 2 : Image finale PHP-FPM
# ==========================
FROM php:8.3-fpm-alpine

# Installer dépendances système et extensions compilables
RUN apk add --no-cache \
        bash \
        freetype-dev \
        libjpeg-turbo-dev \
        libwebp-dev \
        libpng-dev \
        postgresql-client \
        postgresql-dev \
        zlib-dev \
        oniguruma-dev \
        libxml2-dev \
        gmp-dev \
        autoconf \
        gcc \
        g++ \
        make \
        libtool \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install \
        pdo \
        pdo_pgsql \
        bcmath \
        gd \
        pcntl \
    && apk del gcc g++ make autoconf libtool

# Créer un utilisateur non-root
RUN addgroup -g 1000 laravel \
    && adduser -G laravel -g laravel -s /bin/sh -D laravel

# Définir le répertoire de travail
WORKDIR /var/www/html

# Copier le code depuis l'étape build
COPY --from=composer-build /app /var/www/html

# Créer les répertoires nécessaires et définir les permissions
RUN mkdir -p storage/framework/{cache,data,sessions,testing,views} \
    && mkdir -p storage/logs bootstrap/cache \
    && chown -R laravel:laravel /var/www/html \
    && chmod -R 775 storage bootstrap/cache

# Copier le script d'entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Utilisateur non-root par défaut
USER laravel

# Exposer le port 8000 (pour dev)
EXPOSE 8000

# Entrypoint
ENTRYPOINT ["/entrypoint.sh"]

# Commande par défaut
CMD ["php", "artisan", "serve", "--host=0.0.0.0", "--port=8000"]
