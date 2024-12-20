#!/bin/bash

# Définition du chemin de base
DB_PATH="/usr/local/var/mongodb/repldata/"

# Fonction de nettoyage
cleanup() {
    echo "Nettoyage des processus MongoDB existants..."
    pkill -9 mongod 2>/dev/null
    sleep 5
    rm -f ${DB_PATH}*/mongod.lock
}

# Fonction de vérification des erreurs
check_error() {
    if [ $? -ne 0 ]; then
        echo "Erreur: $1"
        exit 1
    fi
}

# Fonction de vérification de port
check_port() {
    if lsof -Pi ":$1" -sTCP:LISTEN -t >/dev/null ; then
        echo "Erreur: Le port $1 est déjà utilisé"
        exit 1
    fi
}

# Nettoyage initial
cleanup

# Vérification des ports
check_port 27017
check_port 27018
check_port 27019
check_port 27020

# Création et configuration des répertoires
dirs=("r0s1" "r0s2" "r0s3" "arb")

for dir in "${dirs[@]}"; do
    echo "Configuration du répertoire ${DB_PATH}${dir}"
    
    # Création du répertoire
    mkdir -p "${DB_PATH}${dir}"
    check_error "Impossible de créer ${DB_PATH}${dir}"
    
    # Configuration des permissions
    chown -R $(whoami) "${DB_PATH}${dir}"
    check_error "Impossible de changer le propriétaire de ${DB_PATH}${dir}"
    
    chmod 755 "${DB_PATH}${dir}"
    check_error "Impossible de modifier les permissions de ${DB_PATH}${dir}"
    
    # Création du fichier de log avec les bonnes permissions
    touch "${DB_PATH}${dir}/mongod.log"
    chmod 644 "${DB_PATH}${dir}/mongod.log"
    check_error "Impossible de créer/configurer le fichier log"
done

# Démarrage des instances MongoDB en arrière-plan
echo "Démarrage des instances MongoDB..."
mongod --replSet rs0 --port 27017 --dbpath "${DB_PATH}r0s1" --bind_ip_all --fork --logpath "${DB_PATH}r0s1/mongod.log"
check_error "Impossible de démarrer le premier nœud MongoDB"

mongod --replSet rs0 --port 27018 --dbpath "${DB_PATH}r0s2" --bind_ip_all --fork --logpath "${DB_PATH}r0s2/mongod.log"
check_error "Impossible de démarrer le deuxième nœud MongoDB"

mongod --replSet rs0 --port 27019 --dbpath "${DB_PATH}r0s3" --bind_ip_all --fork --logpath "${DB_PATH}r0s3/mongod.log"
check_error "Impossible de démarrer le troisième nœud MongoDB"

mongod --replSet rs0 --port 27020 --dbpath "${DB_PATH}arb" --bind_ip_all --fork --logpath "${DB_PATH}arb/mongod.log"
check_error "Impossible de démarrer l'arbitre MongoDB"

# Attendre que les serveurs soient prêts
echo "Attente du démarrage des serveurs..."
sleep 10

# Vérification que les serveurs sont bien démarrés
for port in 27017 27018 27019 27020; do
    if ! nc -z localhost $port; then
        echo "Erreur: Le serveur sur le port $port n'est pas accessible"
        exit 1
    fi
done

# Configuration du replica set
echo "Configuration du replica set..."
mongosh --port 27017 --eval '
config = {
  _id: "rs0",
  members: [
    {
      _id: 0,
      host: "localhost:27017",
      priority: 2
    },
    {
      _id: 1,
      host: "localhost:27018",
      priority: 1
    },
    {
      _id: 2,
      host: "localhost:27019",
      priority: 1
    },
    {
      _id: 3,
      host: "localhost:27020",
      arbiterOnly: true
    }
  ]
};
rs.initiate(config);'
check_error "Impossible d'initialiser le replica set"

echo "Attente de l'initialisation du replica set..."
sleep 10

echo "Importation des données de Paris..."
mongoimport --db testDB --collection test --port 27017 --type csv --headerline --file data/listings_Paris_modified.csv
check_error "Erreur lors de l'importation des données de Paris"

# Vérification du statut
echo "Vérification du statut final..."
mongosh --port 27017 --eval 'rs.status()'

echo "Configuration du replica set terminée!"