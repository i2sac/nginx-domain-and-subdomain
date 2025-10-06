# 🔧 Script de Configuration Automatisée Nginx + SSL pour Domaine & Sous-domaines

Ce script Bash permet de configurer automatiquement un serveur **Nginx** avec **SSL Let's Encrypt** pour :

* Un **domaine principal** (ex : `monsite.com`) pointant vers une application (Next.js, React, etc.) sur un port local (ex : `3000`)
* Un ou **plusieurs sous-domaines** (ex : `api.monsite.com`, `admin.monsite.com`) pointant vers des APIs ou applications sur d'autres ports locaux

Il crée automatiquement :

* Les fichiers de configuration Nginx (`/etc/nginx/sites-available/...`)
* Les liens symboliques dans `sites-enabled/`
* Les certificats SSL Let's Encrypt via `certbot`
* Les redirections automatiques HTTP → HTTPS et www → non-www

---

## ⚙️ Prérequis

* Un serveur Ubuntu/Debian avec accès root ou sudo
* Les ports 80 et 443 ouverts (`sudo ufw allow 'Nginx Full'`)
* Les **noms de domaines configurés** dans votre zone DNS pointant vers l'adresse IP de votre serveur
* Docker (optionnel) — sera géré automatiquement par le script

---

## 🚀 Utilisation

```bash
chmod +x domains-setup.sh
./domains-setup.sh
```

### Workflow interactif :

1. **Configuration du domaine principal** (optionnel)
   - Répondez `o` (oui) ou `N` (non) à la question : *"Voulez-vous configurer le domaine principal ?"*
   - Si **oui** : entrez le domaine (ex: `monsite.com`) et le port (ex: `3000`)
   - Si **non** : passez directement à la configuration des sous-domaines

2. **Ajout de sous-domaines** (répétable)
   - Pour chaque sous-domaine : répondez `o` à *"Voulez-vous ajouter un sous-domaine API ?"*
   - Entrez le sous-domaine (ex: `api.monsite.com`) et son port (ex: `8000`)
   - Répondez `N` quand vous avez terminé

Le script :

1. ✅ Vérifie et installe Nginx si nécessaire
2. 🐳 **Arrête temporairement Docker** (si actif) pour libérer les ports
3. 📝 Génère les fichiers de configuration Nginx
4. 🔗 Crée les liens symboliques dans `sites-enabled/`
5. ✔️ Teste la configuration Nginx (`nginx -t`)
6. 🔐 Installe Certbot si absent
7. 🔒 Génère les certificats SSL pour chaque domaine
8. 🔄 Recharge Nginx
9. 🐳 **Redémarre Docker** automatiquement

---

## ✅ Résultat

Une fois le script exécuté avec succès, vous obtenez :

* `https://monsite.com` → application principale (port `3000`) *(si configuré)*
* `https://api.monsite.com` → API backend (port `8000`)
* `https://admin.monsite.com` → Interface admin (port `5000`)
* *(autant de sous-domaines que souhaité)*

Avec pour chacun :
- ✅ Certificat SSL valide (Let's Encrypt)
- ✅ Redirection automatique HTTP → HTTPS
- ✅ Redirection www → non-www
- ✅ Configuration reverse proxy optimisée

---

## 🐳 Gestion Automatique de Docker

Le script détecte automatiquement si Docker est actif et :

- 🛑 L'arrête temporairement pour éviter les conflits de ports (notamment 80/443)
- ✅ Le redémarre automatiquement à la fin, **même en cas d'erreur**
- 🔒 Garantit que la génération des certificats SSL fonctionne correctement

Cela évite les erreurs type *"Address already in use"* lors de la génération des certificats.

---

## ⏭️ Cas d'usage : Ajouter uniquement des sous-domaines

Si vous avez déjà configuré votre domaine principal et souhaitez uniquement ajouter des sous-domaines :

1. Lancez le script : `./domains-setup.sh`
2. Répondez **N** à *"Voulez-vous configurer le domaine principal ?"*
3. Ajoutez autant de sous-domaines que nécessaire
4. Le script gérera Docker et les certificats SSL automatiquement

---

## 📁 Scripts Utilitaires Inclus

Le repository contient également des scripts de maintenance :

### `reset-nginx.sh`
Réinitialise complètement Nginx (suppression et réinstallation)
```bash
./reset-nginx.sh
```

### `stop-nginx.sh`
Arrête Nginx proprement
```bash
./stop-nginx.sh
```

### `restart-nginx.sh`
Redémarre Nginx après vérification de la configuration
```bash
./restart-nginx.sh
```

---

## 🛠 Personnalisation

Vous pouvez facilement adapter le script pour :

* Ajouter des en-têtes de sécurité (HSTS, CSP, etc.)
* Activer HTTP/2 ou HTTP/3
* Configurer des limites de taux (rate limiting)
* Ajouter une configuration `default_server`
* Gérer des chemins spécifiques (locations multiples)

---

## 🧹 Nettoyage / Suppression

Pour supprimer une configuration :

```bash
# Supprimer les fichiers de configuration
sudo rm /etc/nginx/sites-available/monsite.com
sudo rm /etc/nginx/sites-enabled/monsite.com

# Supprimer le certificat SSL
sudo certbot delete --cert-name monsite.com

# Recharger Nginx
sudo systemctl reload nginx
```

Pour réinitialiser complètement Nginx :
```bash
./reset-nginx.sh
```

---

## 🔒 Sécurité

Le script :
- ✅ Génère des certificats SSL valides via Let's Encrypt
- ✅ Force HTTPS pour tous les domaines
- ✅ Configure le reverse proxy avec les en-têtes appropriés
- ✅ Active le renouvellement automatique des certificats (via Certbot)

**Note** : Pensez à configurer le renouvellement automatique avec un cron job :
```bash
sudo certbot renew --dry-run
```

---

## 📄 Licence

Ce script est fourni sous licence **MIT** — libre d'utilisation et de modification.

**Auteur** : Louis Isaac DIOUF  
**Repository** : [nginx-domain-and-subdomain](https://github.com/i2sac/nginx-domain-and-subdomain)

---

## 🆘 Dépannage

### Le script échoue lors de la génération SSL
- Vérifiez que vos domaines pointent bien vers votre serveur (DNS)
- Assurez-vous que les ports 80 et 443 sont ouverts
- Docker est peut-être encore actif : exécutez `sudo systemctl stop docker`

### Nginx refuse de démarrer
```bash
sudo nginx -t  # Vérifier la configuration
sudo journalctl -u nginx -n 50  # Voir les logs
```

### Port déjà utilisé
```bash
sudo lsof -i :80  # Voir quel processus utilise le port 80
sudo lsof -i :443  # Voir quel processus utilise le port 443
```

---

## 🌟 Contribution

Les contributions sont les bienvenues ! N'hésitez pas à :
- Ouvrir une issue pour signaler un bug
- Proposer une pull request pour améliorer le script
- Partager vos cas d'usage

---

**Bon déploiement ! 🚀**
