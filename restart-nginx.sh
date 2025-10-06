# Nettoyer le fichier PID s'il existe
sudo rm -f /run/nginx.pid

# Vérifier la configuration
sudo nginx -t

# Démarrer Nginx
sudo systemctl start nginx

# Vérifier le statut
sudo systemctl status nginx