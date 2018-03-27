# Configure the Microsoft Azure Provider
provider "azurerm" { }

# Create a resource group if it doesn’t exist
resource "azurerm_resource_group" "demo_resource_group" {
    name     = "fpdemo"
    location = "West US 2"

    tags {
        environment = "Terraform Demo"
    }
}

# Create virtual network
resource "azurerm_virtual_network" "demo_virtual_network" {
    name                = "fpdemo"
    address_space       = ["10.0.0.0/16"]
    location            = "eastus"
    resource_group_name = "${azurerm_resource_group.demo_resource_group.name}"

    tags {
        environment = "Terraform Demo"
    }
}

# Create subnet
resource "azurerm_subnet" "demo_subnet" {
    name                 = "fpdemo"
    resource_group_name  = "${azurerm_resource_group.demo_resource_group.name}"
    virtual_network_name = "${azurerm_virtual_network.demo_virtual_network.name}"
    address_prefix       = "10.0.1.0/24"
}

# Create public IPs
resource "azurerm_public_ip" "demo_public_ip" {
    name                         = "fppublicip"
    location                     = "eastus"
    resource_group_name          = "${azurerm_resource_group.demo_resource_group.name}"
    public_ip_address_allocation = "static"

    tags {
        environment = "Terraform Demo"
    }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "demo_security_group" {
    name                = "fpsecuritygroups"
    location            = "eastus"
    resource_group_name = "${azurerm_resource_group.demo_resource_group.name}"

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags {
        environment = "Terraform Demo"
    }
}

# Create network interface
resource "azurerm_network_interface" "demo_nic" {
    name                      = "myNIC"
    location                  = "eastus"
    resource_group_name       = "${azurerm_resource_group.demo_resource_group.name}"
    network_security_group_id = "${azurerm_network_security_group.demo_security_group.id}"

    ip_configuration {
        name                          = "myNicConfiguration"
        subnet_id                     = "${azurerm_subnet.demo_subnet.id}"
        private_ip_address_allocation = "dynamic"
        public_ip_address_id          = "${azurerm_public_ip.demo_public_ip.id}"
    }

    tags {
        environment = "Terraform Demo"
    }
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = "${azurerm_resource_group.demo_resource_group.name}"
    }

    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "demo_storage_account" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = "${azurerm_resource_group.demo_resource_group.name}"
    location                    = "eastus"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags {
        environment = "Terraform Demo"
    }
}

# Create virtual machine
resource "azurerm_virtual_machine" "demo_vm" {
    name                  = "myVM"
    location              = "eastus"
    resource_group_name   = "${azurerm_resource_group.demo_resource_group.name}"
    network_interface_ids = ["${azurerm_network_interface.demo_nic.id}"]
    vm_size               = "Standard_DS1_v2"

    storage_os_disk {
        name              = "myOsDisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    storage_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "16.04.0-LTS"
        version   = "latest"
    }

    os_profile {
        computer_name  = "myvm"
        admin_username = "azureuser"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/azureuser/.ssh/authorized_keys"
            key_data = "ssh-rsa potato"
        }
    }

    boot_diagnostics {
        enabled = "true"
        storage_uri = "${azurerm_storage_account.demo_storage_account.primary_blob_endpoint}"
    }

    tags {
        environment = "Terraform Demo"
    }

    provisioner "local-exec" {
      command = "sleep 90; ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u azureuser --private-key id_rsa -i '${azurerm_public_ip.demo_public_ip.ip_address}', master.yml"
    }
}

output "vm_ip" {
  value = "${azurerm_public_ip.demo_public_ip.ip_address}"
}
