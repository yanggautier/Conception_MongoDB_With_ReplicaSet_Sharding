#!/bin/bash

# Fonction pour vérifier si un port est en écoute
check_mongodb_ports() {
    echo "Vérification des ports MongoDB..."
    for port in 27017 27018 27019 27020; do
        if nc -z localhost $port; then
            echo "✅ Port $port est actif"
        else
            echo "❌ Port $port n'est pas accessible"
        fi
    done
}

# Fonction pour vérifier le statut des processus MongoDB
check_mongodb_processes() {
    echo -e "\nProcessus MongoDB en cours d'exécution:"
    ps aux | grep mongod | grep -v grep
}

# Fonction pour vérifier l'état du replica set
check_replicaset_status() {
    echo -e "\nStatut du Replica Set:"
    mongosh --quiet --eval "
        try {
            // Vérifier le statut global
            let status = rs.status();
            print('État du cluster:');
            print('---------------');
            print('Nom du replica set: ' + status.set);
            print('État actuel: ' + (status.ok ? 'OK' : 'Erreur'));
            
            // Afficher les membres et leur état
            print('\nMembres du replica set:');
            status.members.forEach(function(member) {
                print('\nServeur: ' + member.name);
                print('État: ' + member.stateStr);
                print('Santé: ' + member.health);
                if(member.stateStr === 'PRIMARY') {
                    print('🟢 C est le PRIMARY');
                }
            });

            // Vérifier la configuration
            print('\nConfiguration actuelle:');
            printjson(rs.conf());
        } catch(e) {
            print('Erreur lors de la vérification: ' + e);
        }
    "
}

# Exécution des vérifications
echo "=== Diagnostic du ReplicaSet MongoDB ==="
echo "======================================="
check_mongodb_ports
check_mongodb_processes
check_replicaset_status