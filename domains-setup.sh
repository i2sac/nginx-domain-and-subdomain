#!/bin/bash

# Demander les infos pour le domaine principal
read -p "Nom de domaine principal (ex: monsite.com) : " main_domain
read -p "Port de l'application principale (ex: 3000) : " main_port

# Demander les infos pour le sous-domaine API
read -p "Sous-domaine API (ex: api.monsite.com) : " api_domain
read -p "Port de l'application API (ex: 8000) : " api_port

# Définir les chemins
main_conf="/etc/nginx/sites-available/$main_domain"
api_conf="/etc/nginx/sites-available/$api_domain"

# Installer Nginx si nécessaire
if ! command -v nginx &> /dev/null; then
    echo "Installation de Nginx..."
    sudo apt update
    sudo apt install -y nginx
    sudo systemctl start nginx
fi

# Créer fichier de configuration pour le domaine principal
sudo tee "$main_conf" > /dev/null <<EOF
server {
    listen 80;
    server_name $main_domain www.$main_domain;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $main_domain www.$main_domain;
    
    ssl_certificate /etc/letsencrypt/live/$main_domain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$main_domain/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    location / {
        proxy_pass http://127.0.0.1:$main_port;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
    
    # Redirection www vers non-www
    if (\$host = www.$main_domain) {
        return 301 https://$main_domain\$request_uri;
    }
}
EOF

# Créer fichier de configuration pour le sous-domaine API
sudo tee "$api_conf" > /dev/null <<EOF
server {
    listen 80;
    server_name $api_domain www.$api_domain;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $api_domain www.$api_domain;
    
    ssl_certificate /etc/letsencrypt/live/$api_domain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$api_domain/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    location / {
        proxy_pass http://127.0.0.1:$api_port;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
    
    # Redirection www vers non-www
    if (\$host = www.$api_domain) {
        return 301 https://$api_domain\$request_uri;
    }
}
EOF

# Activer les configurations
sudo ln -sf "$main_conf" "/etc/nginx/sites-enabled/"
sudo ln -sf "$api_conf" "/etc/nginx/sites-enabled/"

# Vérifier la configuration avant de continuer
sudo nginx -t || { echo "Erreur de configuration Nginx"; exit 1; }
sudo systemctl reload nginx

# Installer Certbot si nécessaire
if ! command -v certbot &> /dev/null; then
    echo "Installation de Certbot..."
    sudo apt update
    sudo apt install -y certbot python3-certbot-nginx
fi

# Générer les certificats SSL
echo "Génération du certificat SSL pour $main_domain..."
sudo certbot --nginx -d $main_domain -d www.$main_domain

echo "Génération du certificat SSL pour $api_domain..."
sudo certbot --nginx -d $api_domain

# Recharger la configuration finale
sudo systemctl reload nginx

echo "✅ Configuration terminée :"
echo "   - https://$main_domain → port $main_port"
echo "   - https://$api_domain → port $api_port"
echo "   - Redirection www activée pour les deux domaines"
