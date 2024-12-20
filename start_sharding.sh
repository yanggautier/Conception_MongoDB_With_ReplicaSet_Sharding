#!/bin/bash

# Définition du chemin de base
DB_PATH="/usr/local/var/mongodb/shardata"

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
# Port pour mongo server
check_port 27017

# Ports pour les config servers
check_port 27021
check_port 27022
check_port 27023

# Ports pour sh1 Paris
check_port 27031
check_port 27032
check_port 27033

# Ports pour sh2 Lyon
check_port 27034
check_port 27035
check_port 27036

# Création des répertoires s'ils n'existent pas encore
dirs=("config1" "config2" "config3" "sh1_1" "sh1_2" "sh1_3" "sh2_1" "sh2_2" "sh2_3")

for dir in "${dirs[@]}"; do
    echo "Configuration du répertoire ${DB_PATH}/${dir}"
    
    # Création du répertoire
    mkdir -p "${DB_PATH}/${dir}"
    check_error "Impossible de créer ${DB_PATH}/${dir}"
    
    # Configuration des permissions
    chown -R $(whoami) "${DB_PATH}/${dir}"
    check_error "Impossible de changer le propriétaire de ${DB_PATH}/${dir}"
    
    chmod 755 "${DB_PATH}/${dir}"
    check_error "Impossible de modifier les permissions de ${DB_PATH}/${dir}"
    
    # Création du fichier de log avec les bonnes permissions
    touch "${DB_PATH}/${dir}/mongod.log"
    chmod 644 "${DB_PATH}/${dir}/mongod.log"
    check_error "Impossible de créer/configurer le fichier log"
done

# Création des nodes pour config server
echo "Démarrage des instances Config Server..."
mongod --configsvr --replSet configReplSet --port 27021 --dbpath "${DB_PATH}/config1" --bind_ip_all --fork --logpath "${DB_PATH}/config1/mongod.log"
check_error "Impossible de démarrer le premier nœud Configserver"
mongod --configsvr --replSet configReplSet --port 27022 --dbpath "${DB_PATH}/config2" --bind_ip_all --fork --logpath "${DB_PATH}/config2/mongod.log"
check_error "Impossible de démarrer le deuxième nœud Configserver"
mongod --configsvr --replSet configReplSet --port 27023 --dbpath "${DB_PATH}/config3" --bind_ip_all --fork --logpath "${DB_PATH}/config3/mongod.log"
check_error "Impossible de démarrer le trosième nœud Configserver"

sleep 2

# Création des nodes pour sh1 Paris
echo "Démarrage des instances de Shard 1..."
mongod --shardsvr --replSet sh1 --port 27031 --dbpath "${DB_PATH}/sh1_1" --bind_ip_all --fork --logpath "${DB_PATH}/sh1_1/mongod.log"
check_error "Impossible de démarrer le premier nœud de Shard 1"
mongod --shardsvr --replSet sh1 --port 27032 --dbpath "${DB_PATH}/sh1_2" --bind_ip_all --fork --logpath "${DB_PATH}/sh1_2/mongod.log"
check_error "Impossible de démarrer le deuxième nœud de Shard 1"
mongod --shardsvr --replSet sh1 --port 27033 --dbpath "${DB_PATH}/sh1_3" --bind_ip_all --fork --logpath "${DB_PATH}/sh1_3/mongod.log"
check_error "Impossible de démarrer le troisième nœud de Shard 1"

sleep 2

# Création des nodes pour sh2 Lyon
echo "Démarrage des instances de Shard 2..."
mongod --shardsvr --replSet sh2 --port 27034 --dbpath "${DB_PATH}/sh2_1" --bind_ip_all --fork --logpath "${DB_PATH}/sh2_1/mongod.log"
check_error "Impossible de démarrer le premier nœud de Shard 2"
mongod --shardsvr --replSet sh2 --port 27035 --dbpath "${DB_PATH}/sh2_2" --bind_ip_all --fork --logpath "${DB_PATH}/sh2_2/mongod.log"
check_error "Impossible de démarrer le deuxième nœud de Shard 2"
mongod --shardsvr --replSet sh2 --port 27036 --dbpath "${DB_PATH}/sh2_3" --bind_ip_all --fork --logpath "${DB_PATH}/sh2_3/mongod.log"
check_error "Impossible de démarrer le troisième nœud de Shard 2"

sleep 2

# Initialisation des replica sets avec configuration complète
echo "Initialisation du replica set des config servers..."
mongosh --port 27021 --eval 'rs.initiate({
  _id: "configReplSet",
  configsvr: true,
  members: [
    { _id: 0, host: "127.0.0.1:27021" },
    { _id: 1, host: "127.0.0.1:27022" },
    { _id: 2, host: "127.0.0.1:27023" }
  ]
})'

echo "Attente de l'initialisation du replica set config..."
sleep 20

echo "Initialisation du replica set shard 1..."
mongosh --port 27031 --eval 'rs.initiate({
  _id: "sh1",
  members: [
    { _id: 0, host: "127.0.0.1:27031" },
    { _id: 1, host: "127.0.0.1:27032" },
    { _id: 2, host: "127.0.0.1:27033" }
  ]
})'

echo "Initialisation du replica set shard 2..."
mongosh --port 27034 --eval 'rs.initiate({
  _id: "sh2",
  members: [
    { _id: 0, host: "127.0.0.1:27034" },
    { _id: 1, host: "127.0.0.1:27035" },
    { _id: 2, host: "127.0.0.1:27036" }
  ]
})'

echo "Attente de l'initialisation des replica sets des shards..."
sleep 20

# Configurer le server sur le port 27017
mongos --configdb configReplSet/127.0.0.1:27021,127.0.0.1:27022,127.0.0.1:27023 --port 27017 --fork --logpath "${DB_PATH}/mongos.log"
check_error "Impossible de démarrer mongos"

sleep 5

# Ajout des ports des shards sur le server ou config server
echo "Ajout des shards..."
mongosh --port 27017 --eval 'sh.addShard("sh1/127.0.0.1:27031,127.0.0.1:27032,127.0.0.1:27033");
sh.addShard("sh2/127.0.0.1:27034,127.0.0.1:27035,127.0.0.1:27036");'

echo "Attente de la configuration des shards..."
sleep 10

# Créer une base de données et autoriser le sharding
mongosh --port 27017 --eval 'use testDB; sh.enableSharding("testDB");'

# Création de collection
mongosh --port 27017 --eval 'use testDB; db.createCollection("test");'

# Création d'index
mongosh --port 27017 --eval 'use testDB; 
db.test.createIndex({"city": 1});
db.test.createIndex({"location": "2dsphere"});
db.test.createIndex({"price": 1});
db.test.createIndex({"room_type": 1});
db.test.createIndex({"bedrooms": 1});
db.test.createIndex({"accommodates": 1});'

# Autoriser le sharding sur la collection
mongosh --port 27017 --eval 'sh.shardCollection("testDB.test", {"city":1});'

# Ajout de zone en tag 
mongosh --port 27017 --eval 'sh.addShardTag("sh1", "Paris");sh.addShardTag("sh2", "Lyon");'

# Ajout de range
mongosh --port 27017 --eval 'sh.addTagRange("testDB.test", {"city": "Paris"}, { "city": "Paris\uffff" }, "Paris");'
mongosh --port 27017 --eval 'sh.addTagRange("testDB.test", {"city": "Lyon"}, { "city": "Lyon\uffff" }, "Lyon");'

# Importation des données
# Vérification de l'existence des fichiers
if [ ! -f "data/listings_Paris_modified.csv" ]; then
    echo "Erreur: fichier listings_Paris.csv non trouvé"
    exit 1
fi

if [ ! -f "data/listings_Lyon_modified.csv" ]; then
    echo "Erreur: fichier listings_Lyon.csv non trouvé"
    exit 1
fi

# Importation des données de Paris
echo "Importation des données de Paris..."
mongoimport --db testDB --collection test --port 27017 --type csv --headerline --file data/listings_Paris_modified.csv
check_error "Erreur lors de l'importation des données de Paris"

# Importation des données de Lyon
echo "Importation des données de Lyon..."
mongoimport --db testDB --collection test --port 27017 --type csv --headerline --file data/listings_Lyon_modified.csv
check_error "Erreur lors de l'importation des données de Lyon"

# Vérification de l'importation et de la distribution
echo "Vérification de l'importation et de la distribution..."
mongosh --port 27017 --eval '
    use testDB;
    // Distribution des shards
    print("\nDistribution des shards :");
    db.test.getShardDistribution();
'