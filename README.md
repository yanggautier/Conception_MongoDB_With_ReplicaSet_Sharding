# NosCités - Analyse des Locations Courte Durée 🏠

## Description du Projet
Application de suivi et d'analyse des locations courte durée pour l'association NosCités, permettant de mesurer l'impact des plateformes de location sur l'offre de logements à Paris et Lyon. Focus particulier sur l'effet "Jeux Olympiques 2024".

## 🎯 Objectifs
- Restauration et sécurisation de la base de données MongoDB
- Analyse de l'intégrité des données
- Mise en place d'une architecture distribuée robuste
- Création de tableaux de bord pour l'analyse d'impact

## 🛠️ Technologies Utilisées
- MongoDB
- Python (Pymongo, Polars)
- Power BI / Tableau
- MongoDB Compass

## 📋 Prérequis
- MongoDB installé (version 6.0+)
- Python 3.8+
- Packages Python :
  ```bash
  pip install pymongo polars pandas
  ```
- Power BI ou Tableau (pour la visualisation)

## 🚀 Installation et Configuration

### 1. Cloner le Projet
```bash
git clone [URL_DU_REPO]
cd noscites-analysis
```

### 2. Configuration MongoDB
#### Réplication Setup
```bash
# Démarrer les instances MongoDB
mongod --port 27017 --dbpath /data/db1 --replSet rs0
mongod --port 27018 --dbpath /data/db2 --replSet rs0
mongod --port 27019 --dbpath /data/db3 --replSet rs0
mongod --port 27020 --dbpath /data/db4 --replSet rs0 --arbiterOnly

# Configurer le ReplicaSet
mongosh
rs.initiate()
rs.add("localhost:27018")
rs.addArbiter("localhost:27019")
```

#### Sharding Setup
```bash
# Démarrer les config servers
mongod --configsvr --replSet configReplSet

# Démarrer mongos
mongos --configdb configReplSet/localhost:27019

# Activer le sharding
mongosh
sh.enableSharding("testDB.test")
sh.shardCollection("testDB.test", {city:1})
```


## 📈 Fonctionnalités Principales

### 1. Analyse des Données
- Distribution des types de location
- Statistiques des hôtes
- Taux d'occupation
- Analyse géographique

### 2. Architecture Distribuée
- Réplication entre Paris et Lyon
- Sharding basé sur la localisation
- Haute disponibilité

### 3. Visualisation
- Tableaux de bord Tableau
- Analyses temporelles
- Cartographie des locations

## 🔍 Requêtes Principales

### Statistiques de Base
```javascript
// Nombre d'annonces par type
db.locations.aggregate([
  {$group: {_id: "$type", count: {$sum: 1}}}
])

// Top 5 des locations les plus évaluées
db.locations.find().sort({"evaluations.count": -1}).limit(5)
```
