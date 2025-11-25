#!/bin/bash

echo "Choose an option to clean Docker:"
echo "1) Remove all containers"
echo "2) Remove all images"
echo "3) Remove all volumes"
echo "4) Remove everything (containers, images, volumes)"
echo "5) Exit"

read -p "Enter your choice: " choice

case $choice in
  1)
    docker ps -aq | xargs docker rm -f
    echo "All containers removed."
    ;;
  2)
    docker images -q | xargs docker rmi -f
    echo "All images removed."
    ;;
  3)
    docker volume ls -q | xargs docker volume rm -f
    echo "All volumes removed."
    ;;
  4)
    docker system prune -a --volumes -f
    echo "All Docker data cleaned."
    ;;
  5)
    echo "Exiting."
    exit 0
    ;;
  *)
    echo "Invalid choice."
    ;;
esac
