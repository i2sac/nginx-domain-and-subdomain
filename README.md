# 🔧 Script de Configuration Automatisée Nginx + SSL pour Domaine & API

Ce script Bash permet de configurer automatiquement un serveur **Nginx** avec **SSL Let's Encrypt** pour :

* Un **domaine principal** (ex : `monsite.com`) pointant vers une application (Next.js, React, etc.) sur un port local (ex : `3000`)
* Un **sous-domaine API** (ex : `api.monsite.com`) pointant vers une API (ex : Go Fiber) sur un autre port local (ex : `8000`)

Il crée :

* Deux fichiers de configuration Nginx (`/etc/nginx/sites-available/...`)
* Les liens symboliques dans `sites-enabled/`
* Les certificats SSL Let's Encrypt via `certbot`
* Une redirection automatique des versions `www.` vers les versions sans `www.`

---

## ⚙️ Prérequis

* Un serveur Ubuntu avec Nginx installé ou accessible
* Les ports 80 et 443 ouverts (`sudo ufw allow 'Nginx Full'`)
* Les **noms de domaines configurés** dans ta zone DNS pointant vers l'adresse IP de ton VPS

---

## 🚀 Utilisation

```bash
chmod +x setup-nginx.sh
./setup-nginx.sh
```

Tu seras invité à entrer :

* Le **domaine principal** (ex: `monsite.com`)
* Le **port de l'application principale** (ex: `3000`)
* Le **sous-domaine API** (ex: `api.monsite.com`)
* Le **port de l'API** (ex: `8000`)

Le script :

1. Vérifie la présence de Nginx et l’installe si besoin
2. Génère deux fichiers de configuration Nginx (`$main_domain`, `$api_domain`)
3. Crée les liens dans `/etc/nginx/sites-enabled/`
4. Teste la configuration Nginx (`nginx -t`)
5. Installe Certbot si absent
6. Génère les certificats SSL pour chaque domaine
7. Recharge Nginx

---

## ✅ Résultat

Une fois le script exécuté avec succès :

* `https://monsite.com` → application front (port `3000`)
* `https://api.monsite.com` → API backend (port `8000`)
* Redirection `www.` vers le domaine principal activée
* Certificats SSL valides via Let's Encrypt

---

## 🛠 Personnalisation

Tu peux adapter ce script pour ajouter :

* Un firewall UFW (`sudo ufw allow`)
* Le support de HTTP/2
* Des en-têtes de sécurité supplémentaires
* Une configuration avec `default_server` si nécessaire

---

## 🧹 Nettoyage

Pour supprimer les configurations :

```bash
sudo rm /etc/nginx/sites-available/monsite.com
sudo rm /etc/nginx/sites-available/api.monsite.com
sudo rm /etc/nginx/sites-enabled/monsite.com
sudo rm /etc/nginx/sites-enabled/api.monsite.com
sudo certbot delete --cert-name monsite.com
sudo certbot delete --cert-name api.monsite.com
```

Puis recharger Nginx :

```bash
sudo systemctl reload nginx
```

---

## 📄 Licence

Ce script est fourni tel quel, à adapter selon vos besoins.
Licence : MIT
