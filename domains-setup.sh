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
    # Vérifier si le service docker existe et s'il est actif
    if systemctl list-unit-files | grep -q '^docker.service'; then
        if sudo systemctl is-active --quiet docker; then
            docker_was_active=1
            echo "⚠️  Docker est actif — arrêt temporaire pour libérer les ports..."
            sudo systemctl stop docker
        fi
    fi

    # S'assurer que Docker sera redémarré à la sortie si on l'a arrêté
    trap 'if [ "$docker_was_active" -eq 1 ]; then echo "🔄 Redémarrage de Docker..."; sudo systemctl start docker; fi' EXIT
    # --- Fin gestion Docker ---

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

    # Activer la configuration principale
    sudo ln -sf "$main_conf" "/etc/nginx/sites-enabled/"

    # Vérifier la configuration avant de continuer
    sudo nginx -t || { echo "Erreur de configuration Nginx"; exit 1; }
    sudo systemctl reload nginx

    # Installer Certbot si nécessaire (avant génération des certificats)
    if ! command -v certbot &> /dev/null; then
        echo "Installation de Certbot..."
        sudo apt update
        sudo apt install -y certbot python3-certbot-nginx
    fi

    # Générer le certificat SSL pour le domaine principal
    echo "Génération du certificat SSL pour $main_domain..."
    sudo certbot --nginx -d $main_domain -d www.$main_domain
else
    echo "⏭️  Configuration du domaine principal ignorée."
    
    # --- Gérer Docker temporairement même si on skip le domaine principal ---
    docker_was_active=0
    if systemctl list-unit-files | grep -q '^docker.service'; then
        if sudo systemctl is-active --quiet docker; then
            docker_was_active=1
            echo "⚠️  Docker est actif — arrêt temporaire pour libérer les ports..."
            sudo systemctl stop docker
        fi
    fi
    trap 'if [ "$docker_was_active" -eq 1 ]; then echo "🔄 Redémarrage de Docker..."; sudo systemctl start docker; fi' EXIT
    # --- Fin gestion Docker ---
    
    # Installer Nginx et Certbot si nécessaire
    if ! command -v nginx &> /dev/null; then
        echo "Installation de Nginx..."
        sudo apt update
        sudo apt install -y nginx
        sudo systemctl start nginx
    fi
    
    if ! command -v certbot &> /dev/null; then
        echo "Installation de Certbot..."
        sudo apt update
        sudo apt install -y certbot python3-certbot-nginx
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

    # Activer et tester la configuration API
    sudo ln -sf "$api_conf" "/etc/nginx/sites-enabled/"
    sudo nginx -t || { echo "Erreur de configuration Nginx pour $api_domain"; exit 1; }
    sudo systemctl reload nginx

    # Générer le certificat SSL pour ce sous-domaine
    echo "Génération du certificat SSL pour $api_domain..."
    sudo certbot --nginx -d $api_domain -d www.$api_domain

    # Sauvegarder pour le récapitulatif
    apis+=("$api_domain:$api_port")
done

# Recharger la configuration finale
sudo systemctl reload nginx

# Afficher récapitulatif
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
echo "   - Redirection www activée pour les domaines créés"
