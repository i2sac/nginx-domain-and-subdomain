#!/bin/bash

echo "=========================================="
echo "Script de désinstallation/réinstallation de Coolify"
echo "=========================================="
echo ""

# Confirmation
read -p "⚠️  Cela va supprimer TOUTES les données Coolify. Continuer ? (oui/non) : " confirm
if [ "$confirm" != "oui" ]; then
    echo "Annulé."
    exit 0
fi

echo ""
echo "🗑️  Étape 1/6 : Arrêt de tous les conteneurs Coolify..."
docker ps -a | grep -E "coolify|ghcr.io/coollabsio" | awk '{print $1}' | xargs -r docker stop

echo ""
echo "🗑️  Étape 2/6 : Suppression de tous les conteneurs Coolify..."
docker ps -a | grep -E "coolify|ghcr.io/coollabsio" | awk '{print $1}' | xargs -r docker rm -f

echo ""
echo "🗑️  Étape 3/6 : Suppression des volumes Coolify..."
docker volume ls | grep coolify | awk '{print $2}' | xargs -r docker volume rm -f

echo ""
echo "🗑️  Étape 4/6 : Suppression des réseaux Coolify..."
docker network ls | grep coolify | awk '{print $2}' | xargs -r docker network rm

echo ""
echo "🗑️  Étape 5/6 : Suppression des fichiers Coolify..."
rm -rf /data/coolify

echo ""
echo "🧹 Nettoyage des ressources Docker inutilisées..."
docker system prune -f

echo ""
echo "=========================================="
echo "✅ Désinstallation terminée !"
echo "=========================================="
echo ""

# Réinstallation
read -p "📦 Voulez-vous réinstaller Coolify maintenant ? (oui/non) : " install
if [ "$install" == "oui" ]; then
    echo ""
    echo "🚀 Étape 6/6 : Installation de Coolify..."
    echo ""
    curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash
    
    echo ""
    echo "=========================================="
    echo "✅ Installation terminée !"
    echo "=========================================="
    echo ""
    echo "🌐 Accédez à Coolify sur : http://$(curl -s ifconfig.me):8000"
    echo ""
    echo "💡 Conseil : Lors de l'onboarding, choisissez 'This Machine' pour éviter les problèmes de configuration SSH !"
else
    echo ""
    echo "✅ Désinstallation terminée. Vous pouvez réinstaller plus tard avec :"
    echo "curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash"
fi
