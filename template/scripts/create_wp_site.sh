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
