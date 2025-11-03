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

# Installer les outils de compilation et extensions nécessaires
RUN apk add --no-cache \
        bash \
        autoconf \
        gcc \
        g++ \
        make \
        libtool \
        postgresql-dev \
        freetype-dev \
        libjpeg-turbo-dev \
        libwebp-dev \
        libpng-dev \
        oniguruma-dev \
        zlib-dev \
        libxml2-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install \
        pdo \
        pdo_pgsql \
        bcmath \
        gd \
        mbstring \
        exif \
        pcntl \
        tokenizer \
        xml \
    && apk del gcc g++ make autoconf libtool

# Créer un utilisateur non-root
RUN addgroup -g 1000 laravel \
    && adduser -G laravel -g laravel -s /bin/sh -D laravel

# Définir le répertoire de travail
WORKDIR /var/www/html

# Copier le code depuis l'étape build
COPY --from=composer-build /app /var/www/html

# Copier les clés OAuth depuis Render Secret Files
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

# Commande par défaut pour le développement
CMD ["php", "artisan", "serve", "--host=0.0.0.0", "--port=8000"]
