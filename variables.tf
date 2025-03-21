variable "prefix" {
    description = "Préfixe pour nommer les ressources"
    default     = "flaskapp"
}

variable "location" {
    description = "Région Azure"
    default     = "East US"
}

variable "admin_username" {
    description = "Nom d'utilisateur admin pour la VM"
    default     = "azureuser"
}

variable "vm_size" {
    description = "Taille de la VM"
    default     = "Standard_B1s"
}

variable "db_username" {
    type    = string
    default = "postgresql"
}

variable "db_password" {
    type    = string
    default = "admin123"
}
