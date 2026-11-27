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

- Linux (testé sur Ubuntu Server) avec Docker Engine et Docker Compose v2.
- Au moins 4 cœurs processeur, 8 Go de mémoire vive et 50 Go d'espace disque libre.
- Un accès à Internet au premier démarrage (environ 3 Go d'images à télécharger).
- La limite de mappage mémoire requise par l'indexeur :

  ```sh
  sudo sysctl -w vm.max_map_count=262144
  ```

## Démarrage en 3 commandes

Depuis la racine du dépôt :

```sh
cp .env.example .env            # 1. créer son fichier de secrets
./setup.sh                      # 2. générer les hashes et les fichiers de configuration
docker compose up -d --build    # 3. démarrer la pile
```

Entre la commande 1 et la commande 2, ouvrez le fichier `.env` (par exemple avec
`nano .env`) et remplissez **toutes** les valeurs. Aucun mot de passe n'est fourni
dans le dépôt : chaque installation choisit les siens.

### Le fichier `.env`

| Variable | Rôle |
|---|---|
| `INDEXER_PASSWORD` | mot de passe du compte `admin` (connexion au tableau de bord) |
| `DASHBOARD_PASSWORD` | mot de passe du compte interne `kibanaserver` |
| `API_PASSWORD` | mot de passe de l'API Wazuh (compte `wazuh-wui`) |
| `SSH_PUBLIC_KEY` | clé publique SSH autorisée sur le serveur web (entre guillemets) |
| `MARIADB_ROOT_PASSWORD` | mot de passe root de la base de données |

Règles pour les mots de passe Wazuh : de 8 à 64 caractères, avec au moins une
majuscule, une minuscule, un chiffre et un symbole. Pour `API_PASSWORD`, le symbole
doit être l'un de `.` `*` `+` `?` `-`. N'utilisez ni espace, ni guillemet, ni `$`.

Le fichier `.env` n'est jamais envoyé dans Git. Pour la clé SSH, mettez la valeur
entre guillemets, par exemple `SSH_PUBLIC_KEY="ssh-ed25519 AAAA... nom"`. Si vous
n'avez pas de clé, créez-en une avec `ssh-keygen -t ed25519`.

### Ce que fait `setup.sh`

Le script lit le `.env`, calcule les hashes bcrypt des mots de passe de l'indexeur et
génère deux fichiers de configuration : `wazuh/config/wazuh_indexer/internal_users.yml`
et `wazuh/config/wazuh_dashboard/wazuh.yml`. Ces deux fichiers contiennent des secrets,
ils sont donc ignorés par Git ; seuls leurs modèles `.example` sont versionnés.

Au premier démarrage, le service `certificates` génère les certificats TLS internes
de Wazuh dans le volume `wazuh_certs` : il n'y a aucun certificat à créer ni à
versionner. Le premier démarrage peut prendre plusieurs minutes.

## Accès

| Service | Adresse |
|---|---|
| Tableau de bord Wazuh | <https://localhost> (acceptez le certificat autosigné) |
| Boîte mail des alertes (Mailpit) | <http://localhost:8025> |
| Serveur web | <http://localhost:8080> |
| SSH (utilisateur `webadmin`, clé uniquement) | `ssh -p 2222 webadmin@localhost` |

Connexion au tableau de bord : utilisateur `admin`, mot de passe = valeur de
`INDEXER_PASSWORD` dans votre `.env`.

Le tableau de bord (443), l'API du gestionnaire (55000), l'indexeur (9200), le
serveur web (8080, 2222) et la base de données (3307) ne sont accessibles que
depuis la machine locale. Le service SSH n'accepte que la clé publique de
`webadmin` : les mots de passe et la connexion root sont désactivés.
## Exploitation

```sh
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

## Notes de déploiement (Environnement VirtualBox)

En raison de conflits de ports sur la machine virtuelle, les ports exposés ont été modifiés par rapport à la configuration d'origine :
- **Serveur Web cible** : `http://localhost:9090`
- **Accès SSH** : Port `2223` (au lieu de 2222)

### Épreuve du feu
Le script `scenario.sh` permet de simuler les attaques. 
En cas de problème de clé SSH sur la VM, la détection a été prouvée via l'injection de logs dans le manager.
