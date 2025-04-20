#!/bin/bash
set -e

echo "🚀 Configurando entorno Docker para WordPress"

# 1. Configurar permisos de Docker
if ! groups | grep -q docker; then
    echo "🔧 Añadiendo usuario al grupo docker..."
    sudo usermod -aG docker $USER
    newgrp docker
fi

# 2. Crear estructura de directorios
mkdir -p ~/docker/wordpress/template/{data/{mysql,wordpress},scripts,certs}

# Archivo docker-compose.yml
cat > ~/docker/wordpress/template/docker-compose.yml <<'EOL'
version: '3.8'

services:
  wordpress:
    image: wordpress:php8.2-apache
    container_name: ${PROJECT_NAME}_wp
    restart: unless-stopped
    env_file: .env
    environment:
      WORDPRESS_DB_HOST: db
      WORDPRESS_DB_USER: ${DB_USER}
      WORDPRESS_DB_PASSWORD: ${DB_PASSWORD}
      WORDPRESS_DB_NAME: ${DB_NAME}
      WORDPRESS_CONFIG_EXTRA: |
        define('WP_HOME', 'https://${DOMAIN}');
        define('WP_SITEURL', 'https://${DOMAIN}');
        define('FORCE_SSL_ADMIN', true);
    volumes:
      - ./data/wordpress/wp-content:/var/www/html/wp-content
      - ./data/wordpress/wp-config.php:/var/www/html/wp-config.php
    networks:
      - wp-network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.${PROJECT_NAME}-wp.rule=Host(`${DOMAIN}`)"
      - "traefik.http.routers.${PROJECT_NAME}-wp.entrypoints=websecure"
      - "traefik.http.routers.${PROJECT_NAME}-wp.tls.certresolver=myresolver"
      - "traefik.http.services.${PROJECT_NAME}-wp.loadbalancer.server.port=80"

  db:
    image: mysql:8.0
    container_name: ${PROJECT_NAME}_db
    restart: unless-stopped
    env_file: .env
    environment:
      MYSQL_DATABASE: ${DB_NAME}
      MYSQL_USER: ${DB_USER}
      MYSQL_PASSWORD: ${DB_PASSWORD}
      MYSQL_ROOT_PASSWORD: ${DB_ROOT_PASSWORD}
    volumes:
      - ./data/mysql:/var/lib/mysql
    networks:
      - wp-network
    command: --default-authentication-plugin=mysql_native_password

  phpmyadmin:
    image: phpmyadmin/phpmyadmin
    container_name: ${PROJECT_NAME}_pma
    restart: unless-stopped
    depends_on:
      - db
    environment:
      PMA_HOST: db
      MYSQL_USER: ${DB_USER}
      MYSQL_PASSWORD: ${DB_PASSWORD}
      MYSQL_ROOT_PASSWORD: ${DB_ROOT_PASSWORD}
    networks:
      - wp-network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.${PROJECT_NAME}-pma.rule=Host(`pma.${DOMAIN}`)"
      - "traefik.http.routers.${PROJECT_NAME}-pma.entrypoints=websecure"
      - "traefik.http.routers.${PROJECT_NAME}-pma.tls.certresolver=myresolver"
      - "traefik.http.services.${PROJECT_NAME}-pma.loadbalancer.server.port=80"

  traefik:
    image: traefik:v2.10
    command:
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.myresolver.acme.tlschallenge=true"
      - "--certificatesresolvers.myresolver.acme.email=${ACME_EMAIL}"
      - "--certificatesresolvers.myresolver.acme.storage=/letsencrypt/acme.json"
      - "--serverstransport.insecureskipverify=true"  # Añade esta línea
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - "./certs:/certs"  # Añade este volumen
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
      - "./letsencrypt:/letsencrypt"
    networks:
      - wp-network

networks:
  wp-network:
    driver: bridge
EOL

# Archivo .env.example
cat > ~/docker/wordpress/template/.env.example <<'EOL'
# Project Settings
PROJECT_NAME=myproject
DOMAIN=myproject.test
ACME_EMAIL=your-real-email@example.com

# Database
DB_NAME=wordpress
DB_USER=wp_user
DB_PASSWORD=Wp@SecurePass123
DB_ROOT_PASSWORD=Root@SecurePass123

# WordPress
WP_DEBUG=1
WP_ENV=development
EOL

# Script para crear proyectos
cat > ~/docker/wordpress/template/scripts/create_wp_site.sh <<'EOL'
#!/bin/bash
set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <project_name>"
  exit 1
fi

PROJECT_NAME=$1
BASE_DIR="$HOME/docker/wordpress"
TEMPLATE_DIR="$BASE_DIR/template"
PROJECT_DIR="$BASE_DIR/$PROJECT_NAME"

# Verificar si el directorio ya existe
if [ -d "$PROJECT_DIR" ]; then
  echo "Error: El directorio $PROJECT_DIR ya existe"
  exit 1
fi

# Verificar que existen los archivos fuente
if [ ! -f "$TEMPLATE_DIR/docker-compose.yml" ]; then
  echo "Error: No se encontró docker-compose.yml en $TEMPLATE_DIR"
  exit 1
fi

if [ ! -f "$TEMPLATE_DIR/.env.example" ]; then
  echo "Error: No se encontró .env.example en $TEMPLATE_DIR"
  exit 1
fi

# Crear estructura del proyecto
echo "Creando directorio del proyecto..."
mkdir -p "$PROJECT_DIR"/{data/{mysql,wordpress},letsencrypt}

# Copiar archivos base
echo "Copiando archivos de configuración..."
cp "$TEMPLATE_DIR/docker-compose.yml" "$PROJECT_DIR/"
cp "$TEMPLATE_DIR/.env.example" "$PROJECT_DIR/.env"

# Configurar .env
echo "Configurando variables de entorno..."
sed -i "s/myproject/${PROJECT_NAME}/g" "$PROJECT_DIR"/.env
sed -i "s/myproject\.test/${PROJECT_NAME}.test/g" "$PROJECT_DIR"/.env
sed -i "s/your-real-email@example.com/your-email@${PROJECT_NAME}.test/g" "$PROJECT_DIR"/.env

# Configurar hosts (solo en WSL)
if grep -q "WSL" /proc/version; then
  echo "🔧 Configurando archivo hosts en WSL..."
  echo "127.0.0.1 ${PROJECT_NAME}.test" | sudo tee -a /etc/hosts
  echo "127.0.0.1 pma.${PROJECT_NAME}.test" | sudo tee -a /etc/hosts
fi

# Crear wp-config.php inicial
echo "Creando wp-config.php..."
cat > "$PROJECT_DIR"/data/wordpress/wp-config.php <<EOF
<?php
define('DB_NAME', 'wordpress');
define('DB_USER', 'wp_user');
define('DB_PASSWORD', 'Wp@SecurePass123');
define('DB_HOST', 'db');
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', '');

define('WP_HOME', 'https://${PROJECT_NAME}.test');
define('WP_SITEURL', 'https://${PROJECT_NAME}.test');
define('FORCE_SSL_ADMIN', true);
\$_SERVER['HTTPS'] = 'on';

\$table_prefix = 'wp_';

if (!defined('ABSPATH')) {
    define('ABSPATH', __DIR__ . '/');
}

require_once ABSPATH . 'wp-settings.php';
EOF

# Scripts de utilidad
echo "Creando scripts de control..."
cat > "$PROJECT_DIR"/start.sh <<EOF
#!/bin/bash
cd "$PROJECT_DIR"
docker-compose up -d
echo "✅ WordPress: https://${PROJECT_NAME}.test"
echo "✅ phpMyAdmin: https://pma.${PROJECT_NAME}.test"
EOF

cat > "$PROJECT_DIR"/stop.sh <<EOF
#!/bin/bash
cd "$PROJECT_DIR"
docker-compose down
EOF

# Configurar permisos
chmod +x "$PROJECT_DIR"/{start.sh,stop.sh}
chmod -R 755 "$PROJECT_DIR"/data/wordpress

echo "🎉 Sitio WordPress creado correctamente en: $PROJECT_DIR"
echo "🔹 Para iniciar: cd $PROJECT_DIR && ./start.sh"
echo "🔹 Para detener: cd $PROJECT_DIR && ./stop.sh"
EOL

# Configurar permisos
chmod +x ~/docker/wordpress/template/scripts/create_wp_site.sh

# Crear enlace simbólico
ln -sf ~/docker/wordpress/template/scripts/create_wp_site.sh ~/docker/wordpress/create_wp_site.sh
chmod +x ~/docker/wordpress/create_wp_site.sh

# 4. Generar certificado autofirmado inicial
openssl req -newkey rsa:2048 -nodes -keyout ~/docker/wordpress/template/certs/key.pem \
  -x509 -days 365 -out ~/docker/wordpress/template/certs/cert.pem \
  -subj "/CN=localhost" -addext "subjectAltName=DNS:localhost"


echo "✅ Instalación completada!"
echo "Ahora puedes crear nuevos sitios con:"
echo "  ~/docker/wordpress/create_wp_site.sh nombre-del-sitio"

