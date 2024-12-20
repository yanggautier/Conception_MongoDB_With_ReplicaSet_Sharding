#!/bin/bash

# Définition du chemin de base
DB_PATH="/usr/local/var/mongodb/repldata/"

# Fonction pour vérifier si un port est toujours actif
check_port() {
    nc -z localhost $1 2>/dev/null
    return $?
}

# Fonction d'arrêt gracieux
shutdown_mongodb() {
    echo "Arrêt des instances MongoDB..."
    
    # Arrêt via mongosh pour chaque instance
    for port in 27017 27018 27019 27020; do
        if check_port $port; then
            echo "Arrêt de l'instance sur le port $port..."
            mongosh --port $port --eval "db.adminCommand({shutdown: 1})" --quiet || true
        fi
    done
    
    # Attendre quelques secondes
    sleep 5
    
    # Vérifier si des processus sont encore en cours
    if pgrep mongod >/dev/null; then
        echo "Certains processus MongoDB sont toujours en cours. Forçage de l'arrêt..."
        pkill -9 mongod
        sleep 2
    fi
    
    # Nettoyage des fichiers lock
    echo "Nettoyage des fichiers lock..."
    rm -f ${DB_PATH}*/mongod.lock
    
    # Vérification finale
    if ! pgrep mongod >/dev/null; then
        echo "✅ Tous les processus MongoDB sont arrêtés"
    else
        echo "❌ Erreur: Certains processus MongoDB sont toujours en cours"
        echo "Processus restants:"
        ps aux | grep mongod | grep -v grep
        exit 1
    fi
}

# Exécution de l'arrêt
shutdown_mongodb