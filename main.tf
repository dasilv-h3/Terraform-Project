resource "azurerm_resource_group" "rg" {
    name     = "${var.prefix}-rg"
    location = var.location
}

resource "azurerm_storage_account" "storage" {
    name                     = "${var.prefix}storage"
    resource_group_name      = azurerm_resource_group.rg.name
    location                 = azurerm_resource_group.rg.location
    account_tier             = "Standard"
    account_replication_type = "LRS"
}

resource "azurerm_storage_container" "container" {
    name                  = "flask-container"
    storage_account_name  = azurerm_storage_account.storage.name
    container_access_type = "private"
}

resource "azurerm_virtual_network" "vnet" {
    name                = "${var.prefix}-vnet"
    location            = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
    address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet" {
    name                 = "${var.prefix}-subnet"
    resource_group_name  = azurerm_resource_group.rg.name
    virtual_network_name = azurerm_virtual_network.vnet.name
    address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "public_ip" {
    name                = "${var.prefix}-publicip"
    resource_group_name = azurerm_resource_group.rg.name
    location            = azurerm_resource_group.rg.location
    allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "nic" {
    name                = "${var.prefix}-nic"
    location            = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name

    ip_configuration {
        name                          = "internal"
        subnet_id                     = azurerm_subnet.subnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.public_ip.id
    }
}

resource "azurerm_network_security_group" "nsg" {
    name                = "${var.prefix}-nsg"
    location            = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_security_rule" "allow_5000" {
    name                        = "allow-5000"
    priority                    = 100
    direction                   = "Inbound"
    access                      = "Allow"
    protocol                    = "Tcp"
    source_port_range           = "*"
    destination_port_range      = "5000"
    source_address_prefix       = "*"
    destination_address_prefix  = "*"
    resource_group_name         = azurerm_resource_group.rg.name
    network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_linux_virtual_machine" "vm" {
    name                  = "${var.prefix}-vm"
    resource_group_name   = azurerm_resource_group.rg.name
    location              = azurerm_resource_group.rg.location
    size                  = var.vm_size
    admin_username        = var.admin_username
    admin_password        = var.admin_password
    network_interface_ids = [azurerm_network_interface.nic.id]
    disable_password_authentication = false

    os_disk {
        caching              = "ReadWrite"
        storage_account_type = "Standard_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }
}

resource "time_sleep" "wait_for_ip" {
    depends_on = [azurerm_public_ip.public_ip]

    create_duration = "30s"
}

resource "null_resource" "provision_vm" {
    depends_on = [azurerm_linux_virtual_machine.vm, time_sleep.wait_for_ip]

    provisioner "file" {
        source      = "./${var.folder_app_name}"
        destination = "/home/${var.admin_username}/${var.folder_app_name}"

        connection {
            type        = "ssh"
            user        = var.admin_username
            password    = var.admin_password
            host        = azurerm_public_ip.public_ip.ip_address
            agent       = false
        }
    }

    provisioner "remote-exec" {
        inline = [
            "echo 'VM prête, début des installations'",
            "sudo apt update && apt upgrade -y",
            "sudo apt install -y libpq-dev python3-pip python3.8",
            "python3 -m pip install --upgrade pip",
            "sudo chmod -R 755 /home/${var.admin_username}/${var.folder_app_name}",
            "cd ${var.folder_app_name} && pip3 install -r requirements.txt",
            "python3 app.py"
        ]

        connection {
            type        = "ssh"
            user        = var.admin_username
            password    = var.admin_password
            host        = azurerm_public_ip.public_ip.ip_address
            agent       = false
        }
    }
}

resource "azurerm_postgresql_server" "db_server" {
    name                             = "flask-db-server"
    resource_group_name              = azurerm_resource_group.rg.name
    location                         = azurerm_resource_group.rg.location
    sku_name                         = "B_Gen5_1"
    storage_mb                       = 5120
    version                          = "11"
    administrator_login              = var.db_username
    administrator_login_password     = var.db_password
    ssl_enforcement_enabled          = false
    ssl_minimal_tls_version_enforced = "TLSEnforcementDisabled"
}

resource "azurerm_postgresql_firewall_rule" "allow_my_server" {
    name                = "AllowMyServer"
    resource_group_name = azurerm_resource_group.rg.name
    server_name         = azurerm_postgresql_server.db_server.name
    start_ip_address    = azurerm_public_ip.public_ip.ip_address
    end_ip_address      = azurerm_public_ip.public_ip.ip_address
}

resource "azurerm_postgresql_database" "flaskdb" {
    name                = "flaskdb"
    resource_group_name = azurerm_resource_group.rg.name
    server_name         = azurerm_postgresql_server.db_server.name
    charset            = "UTF8"
    collation          = "English_United States.1252"
}