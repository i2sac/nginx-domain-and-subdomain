sudo systemctl stop nginx
sudo apt-get remove --purge nginx nginx-common -y
sudo rm -rf /etc/nginx
sudo apt-get update -y
sudo apt-get install nginx -y
