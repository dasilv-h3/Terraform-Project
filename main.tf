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
    name                = "${var.prefix}-vm"
    resource_group_name = azurerm_resource_group.rg.name
    location            = azurerm_resource_group.rg.location
    size               = var.vm_size
    admin_username     = var.admin_username
    network_interface_ids = [azurerm_network_interface.nic.id]

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

    admin_ssh_key {
        username   = var.admin_username
        public_key = file("~/.ssh/id_rsa.pub")
    }

    custom_data = filebase64("cloud-init.yaml")
}

resource "azurerm_postgresql_flexible_server" "db" {
    name                   = "flaskdb"
    resource_group_name    = azurerm_resource_group.rg.name
    location               = "West Europe"
    administrator_login    = var.db_username
    administrator_password = var.db_password
    sku_name               = "B_Standard_B1ms"
    version                = "13"
}