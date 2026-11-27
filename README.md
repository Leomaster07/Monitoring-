# Déploiement Wazuh à nœud unique

Ce dépôt démarre le gestionnaire Wazuh, l’indexeur et le tableau de bord avec
Docker Compose. Les images utilisent la version **4.14.11** de Wazuh.

## Limites de ressources

Lorsque la base de données est incluse, la pile est limitée à un total de
3 Go de mémoire vive et 2 processeurs : indexeur, 1 Go / 1 processeur ;
gestionnaire, 768 Mo / 0,5 processeur ; tableau de bord, 512 Mo / 0,25
processeur ; serveur web, 256 Mo / 0,125 processeur ; base de données,
512 Mo / 0,125 processeur. Le tas JVM de l’indexeur est limité à 512 Mo afin de
laisser de la mémoire pour ses autres besoins. Ces limites s’appliquent aux
conteneurs, et non à la construction des images. Elles sont volontairement
modestes et peuvent ralentir le démarrage ou les services ; les conteneurs
peuvent redémarrer s’ils dépassent leur limite de mémoire.

## Prérequis

- Docker Desktop avec le moteur WSL 2 et Docker Compose v2.
- Au moins 4 cœurs processeur, 8 Go de mémoire vive et 50 Go d’espace disque
  libre.
- Dans un terminal WSL 2, définissez la limite requise de mappage mémoire de
  l’indexeur :

  ```sh
  sudo sysctl -w vm.max_map_count=262144
  ```

## Démarrage

Exécutez ces commandes depuis la racine du dépôt dans PowerShell :

```powershell
Copy-Item .\\.env.example .\\.env
notepad .\\.env
docker compose up -d --build
docker compose ps
```

Au premier `docker compose up`, le service `certificates` génère
automatiquement les certificats TLS internes de Wazuh. Il les conserve dans le
volume Docker nommé `wazuh_certs` ; il n’est pas nécessaire de cloner ou de
commettre des certificats générés. Les autres services Wazuh attendent la fin
de cette génération. Le volume conserve la même autorité de certification et
les mêmes certificats de nœud lors des redémarrages.

Après le démarrage de l’indexeur, sa configuration de sécurité est initialisée
avant le démarrage du gestionnaire et du tableau de bord.

Ajoutez votre clé publique SSH à la ligne `SSH_PUBLIC_KEY` du fichier `.env`.
Si vous n’avez pas encore de paire de clés, créez-en une :

```powershell
ssh-keygen -t ed25519 -f "$env:USERPROFILE\\.ssh\\id_ed25519"
```

Utilisez le contenu du fichier `.pub` obtenu pour la valeur de
`SSH_PUBLIC_KEY`. Le service SSH n’accepte que l’authentification par clé
publique pour l’utilisateur non privilégié `webadmin` ; les mots de passe et
la connexion SSH de l’utilisateur root sont désactivés. Les clés SSH sont
conservées dans un volume Compose. L’agent du serveur web s’enregistre auprès
du gestionnaire sous le nom `webserver`.

Le service de base de données fait partie de la pile par défaut. Définissez
`MARIADB_ROOT_PASSWORD` dans `.env` (valeur requise), puis démarrez avec :

```powershell
docker compose up -d --build
```

Le port MariaDB est accessible uniquement depuis la machine locale, sur le
port 3307 ; l’agent de base de données s’enregistre sous le nom `database`.

Le premier démarrage peut prendre plusieurs minutes pendant l’initialisation
de l’indexeur. Ouvrez <https://localhost> et acceptez l’avertissement lié au
certificat TLS autosigné.

La page de test Nginx est accessible à l’adresse <http://localhost:8080>. SSH
est accessible localement sur le port 2222 :

```powershell
ssh -p 2222 webadmin@localhost
```

Identifiants par défaut du tableau de bord au premier démarrage :

- Nom d’utilisateur : `admin`
- Mot de passe : `SecretPassword`

Le mot de passe initial de l’API Wazuh pour `wazuh-wui` est
`MyS3cr37P450r.*-`. Ce sont les identifiants de démonstration fournis en
amont. Par défaut, HTTPS du tableau de bord (port 443), l’API du gestionnaire
(port 55000) et l’API de l’indexeur (port 9200) sont accessibles uniquement
depuis la machine locale. L’enregistrement des agents et l’envoi de leurs
événements vers le gestionnaire utilisent les ports 1515 et 1514 (TCP), et
Syslog utilise le port 514 (UDP). Pour autoriser l’accès distant au tableau de
bord, changez les identifiants de démonstration, modifiez les adresses
d’écoute dans `docker-compose.yml` et limitez l’accès avec le pare-feu avant
toute exposition.

## Exploitation

```powershell
docker compose logs -f
docker compose down
```

La commande `docker compose down` conserve les volumes de données nommés. Pour
effectuer une réinstallation entièrement vierge, exécutez
`docker compose down --volumes`. Cette commande supprime toutes les données
stockées de Wazuh, y compris `wazuh_certs` ; au prochain démarrage, une
nouvelle autorité de certification et de nouveaux certificats de nœud seront
générés. Utilisez-la uniquement si vous souhaitez effacer définitivement ces
données.