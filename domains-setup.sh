#!/bin/bash

# Demander si l'utilisateur veut configurer le domaine principal
read -p "Voulez-vous configurer le domaine principal ? (o/N) : " configure_main
configure_main=${configure_main:-o}

main_domain=""
main_port=""

if [[ "$configure_main" =~ ^[oO] ]]; then
    # Demander les infos pour le domaine principal
    read -p "Nom de domaine principal (ex: monsite.com) : " main_domain
    read -p "Port de l'application principale (ex: 3000) : " main_port

    # Définir les chemins
    main_conf="/etc/nginx/sites-available/$main_domain"

    # Installer Nginx si nécessaire
    if ! command -v nginx &> /dev/null; then
        echo "Installation de Nginx..."
        sudo apt update
        sudo apt install -y nginx
        sudo systemctl start nginx
    fi

    # --- Gérer Docker temporairement ---
    docker_was_active=0
    if systemctl list-unit-files | grep -q '^docker.service'; then
        if sudo systemctl is-active --quiet docker; then
            docker_was_active=1
            echo "⚠️  Docker est actif — arrêt temporaire pour libérer les ports..."
            sudo systemctl stop docker
        fi
    fi
    trap 'if [ "$docker_was_active" -eq 1 ]; then echo "🔄 Redémarrage de Docker..."; sudo systemctl start docker; fi' EXIT

    # Vérifier que certbot est installé
    if ! command -v certbot &> /dev/null; then
        echo "❌ Certbot n'est pas installé. Installez-le d'abord avec snap :"
        echo "   sudo snap install --classic certbot"
        exit 1
    fi

    # Créer fichier de configuration HTTP UNIQUEMENT
    sudo tee "$main_conf" > /dev/null <<EOF
server {
    listen 80;
    server_name $main_domain www.$main_domain;

    client_max_body_size 10m;
    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;
    send_timeout 60s;

    location / {
        proxy_pass http://127.0.0.1:$main_port;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

    # Activer la configuration HTTP
    sudo ln -sf "$main_conf" "/etc/nginx/sites-enabled/"
    
    if ! sudo nginx -t; then
        echo "❌ Erreur de configuration Nginx"
        exit 1
    fi
    
    sudo systemctl reload nginx
    echo "✅ Configuration HTTP créée pour $main_domain"

    # Générer le certificat SSL avec certbot standalone
    echo "🔐 Génération du certificat SSL pour $main_domain..."
    echo "    (Nginx sera arrêté temporairement)"
    
    # Arrêter nginx pour libérer le port 80
    sudo systemctl stop nginx
    
    # Obtenir le certificat en mode standalone
    if sudo certbot certonly --standalone \
        -d $main_domain -d www.$main_domain \
        --non-interactive \
        --agree-tos \
        --register-unsafely-without-email \
        --preferred-challenges http; then
        
        echo "✅ Certificat SSL obtenu avec succès"
        
        # Recréer la configuration avec HTTPS
        sudo tee "$main_conf" > /dev/null <<EOF
server {
    listen 80;
    server_name $main_domain www.$main_domain;

    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $main_domain www.$main_domain;

    ssl_certificate /etc/letsencrypt/live/$main_domain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$main_domain/privkey.pem;
    
    # SSL moderne
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers off;

    client_max_body_size 10m;
    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;
    send_timeout 60s;

    location / {
        proxy_pass http://127.0.0.1:$main_port;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }

    # Redirection www vers non-www
    if (\$host = www.$main_domain) {
        return 301 https://$main_domain\$request_uri;
    }
}
EOF
        
        # Redémarrer nginx avec la nouvelle config
        if sudo nginx -t; then
            sudo systemctl start nginx
            echo "✅ Domaine principal configuré avec HTTPS"
        else
            echo "❌ Erreur dans la configuration HTTPS"
            sudo systemctl start nginx
            exit 1
        fi
    else
        echo "❌ Échec de l'obtention du certificat SSL"
        echo "Vérifiez que :"
        echo "  1. Le domaine $main_domain pointe vers cette IP"
        echo "  2. Le port 80 est accessible depuis Internet"
        sudo systemctl start nginx
        exit 1
    fi

else
    echo "⏭️  Configuration du domaine principal ignorée."

    # --- Gérer Docker temporairement ---
    docker_was_active=0
    if systemctl list-unit-files | grep -q '^docker.service'; then
        if sudo systemctl is-active --quiet docker; then
            docker_was_active=1
            echo "⚠️  Docker est actif — arrêt temporaire..."
            sudo systemctl stop docker
        fi
    fi
    trap 'if [ "$docker_was_active" -eq 1 ]; then echo "🔄 Redémarrage de Docker..."; sudo systemctl start docker; fi' EXIT

    # Installer Nginx si nécessaire
    if ! command -v nginx &> /dev/null; then
        echo "Installation de Nginx..."
        sudo apt update
        sudo apt install -y nginx
        sudo systemctl start nginx
    fi

    # Vérifier certbot
    if ! command -v certbot &> /dev/null; then
        echo "❌ Certbot n'est pas installé. Installez-le d'abord avec snap"
        exit 1
    fi
fi

# Boucle pour ajouter plusieurs sous-domaines API
declare -a apis=()
while true; do
    read -p "Voulez-vous ajouter un sous-domaine API ? (o/N) : " add_api
    add_api=${add_api:-N}
    if [[ ! "$add_api" =~ ^[oO] ]]; then
        break
    fi

    read -p "Sous-domaine API (ex: api.monsite.com) : " api_domain
    read -p "Port de l'application API (ex: 8000) : " api_port

    api_conf="/etc/nginx/sites-available/$api_domain"

    # Config HTTP uniquement
    sudo tee "$api_conf" > /dev/null <<EOF
server {
    listen 80;
    server_name $api_domain www.$api_domain;

    client_max_body_size 10m;
    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;
    send_timeout 60s;

    location / {
        proxy_pass http://127.0.0.1:$api_port;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

    sudo ln -sf "$api_conf" "/etc/nginx/sites-enabled/"
    
    if ! sudo nginx -t; then
        echo "❌ Erreur de configuration Nginx pour $api_domain"
        exit 1
    fi
    
    sudo systemctl reload nginx
    echo "✅ Configuration HTTP créée pour $api_domain"

    # Générer le certificat SSL
    echo "🔐 Génération du certificat SSL pour $api_domain..."
    sudo systemctl stop nginx
    
    if sudo certbot certonly --standalone \
        -d $api_domain -d www.$api_domain \
        --non-interactive \
        --agree-tos \
        --register-unsafely-without-email \
        --preferred-challenges http; then
        
        echo "✅ Certificat SSL obtenu"
        
        # Config HTTPS complète
        sudo tee "$api_conf" > /dev/null <<EOF
server {
    listen 80;
    server_name $api_domain www.$api_domain;

    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $api_domain www.$api_domain;

    ssl_certificate /etc/letsencrypt/live/$api_domain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$api_domain/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers off;

    client_max_body_size 10m;
    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;
    send_timeout 60s;

    location / {
        proxy_pass http://127.0.0.1:$api_port;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }

    if (\$host = www.$api_domain) {
        return 301 https://$api_domain\$request_uri;
    }
}
EOF

        if sudo nginx -t; then
            sudo systemctl start nginx
            echo "✅ Sous-domaine $api_domain configuré avec HTTPS"
        else
            echo "❌ Erreur config HTTPS pour $api_domain"
            sudo systemctl start nginx
            exit 1
        fi
    else
        echo "❌ Échec certificat SSL pour $api_domain"
        sudo systemctl start nginx
        exit 1
    fi

    apis+=("$api_domain:$api_port")
done

echo ""
echo "✅ Configuration terminée :"
if [[ -n "$main_domain" ]]; then
    echo "   - https://$main_domain → port $main_port"
fi
if [ ${#apis[@]} -gt 0 ]; then
    for a in "${apis[@]}"; do
        domain=${a%%:*}
        port=${a##*:}
        echo "   - https://$domain → port $port"
    done
else
    echo "   - Aucun sous-domaine API ajouté."
fi
echo ""
echo "🔄 Renouvellement auto : certbot renew (déjà configuré par snap)"
