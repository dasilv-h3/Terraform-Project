# Guide complet pour déployer et gérer une infrastructure avec Terraform

Ce guide vous permettra de déployer, configurer et gérer une infrastructure à l'aide de Terraform.

## Prérequis

Avant de commencer, vous devez vous assurer que vous avez installé les outils suivants :

### 1. **Terraform**
   - Suivez les instructions pour installer Terraform : 
     - [Installation de Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli).

### 2. **Compte Cloud**
   Vous devez disposer d'un compte sur le cloud de votre choix (ex. **Azure**, **AWS**, **Google Cloud**, etc.) et d'un accès via les clés API ou l'authentification nécessaire.

### 3. **CLI du fournisseur de cloud**
   Vous devez installer la CLI du fournisseur de cloud (ex. Azure CLI, AWS CLI, etc.). Pour Azure, vous pouvez installer la CLI ici :
   - [Installer Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)

### 4. **Accès aux identifiants cloud**
Vous devez avoir les clés API ou l'authentification nécessaire pour pouvoir déployer des ressources sur votre fournisseur de cloud.

---

## Étapes pour cloner et lancer le projet

### Étape 1 : Cloner le projet

Clonez le projet depuis le dépôt Git :

```bash
git clone https://votre-repository-url.git
cd Terraform-Project
```
### Étape 2 : Configurer les variables d'environnement

Allez dans le dossier `flask-crud`, créez un fichier `.env` et ajoutez-y les valeurs nécessaires.

Exemple de fichier `.env` pour Azure :

```bash
AZURE_CONNECTION_STRING=
AZURE_ACCOUNT_NAME=
AZURE_STORAGE_KEY=
AZURE_CONTAINER=

DB_HOST=
DB_NAME=
DB_USER=
DB_PASSWORD=
DB_PORT=5432
```

### Étape 3 : Installer Terraform

Retournez dans le dossier principal et installez Terraform

- macOS
```bash
brew install terraform
```
- Ubuntu
```bash
sudo apt update
sudo apt install -y wget
wget https://releases.hashicorp.com/terraform/1.2.9/terraform_1.2.9_linux_amd64.zip
unzip terraform_1.2.9_linux_amd64.zip
sudo mv terraform /usr/local/bin/
```
- Windows
Téléchargez et extrayez Terraform depuis le site officiel de HashiCorp.

### Étape 4 : Initialisation de Terraform

Dans le répertoire du projet, initialisez Terraform avec la commande suivante :

```bash
terraform init
```

Cette commande va télécharger les plugins nécessaires pour interagir avec le fournisseur de cloud et configurer votre backend.

### Étape 5 : Configuration de l'infrastructure

Créez un fichier `terraform.tfvars` et ajoutez-y les valeurs nécessaires.

```bash
prefix          =
location        =
admin_username  =
admin_password  =
vm_size         =
db_username     =
db_password     =
folder_app_name = "flask-crud"
```

### Étape 6 : Déploiement de l'infrastructure

- Avant de déployer des ressources, vous pouvez générer un plan d'exécution pour voir quelles ressources Terraform va créer/modifier/supprimer. Utilisez la commande suivante :

```bash
terraform plan
```

Cela génère un plan détaillant les actions que Terraform va effectuer pour faire correspondre l'état actuel à l'état souhaité.

- Une fois que vous êtes satisfait du plan, appliquez-le avec la commande :

```bash
terraform apply
```
Terraform vous demandera de confirmer l'application des modifications. Tapez `yes` pour procéder.

Il se peut que la première fois que vous lancez cette commande, il y ait une erreur, relancez la commande pour récupérer l'ip

- Une fois que Terraform a terminé, vous pouvez vérifier vos ressources créées dans le cloud en vous rendant dans la console de votre fournisseur de cloud. Par exemple, pour Azure, vous pouvez vérifier dans le portail Azure.

- Si vous voulez détruire votre infrastructure, vous pouvez utilisez cette commande :

```bash
terraform destroy
```

Terraform vous demandera de confirmer l'application des modifications. Tapez `yes` pour procéder.