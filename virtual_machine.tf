resource "azurerm_resource_group" "test" {
  name     = "acctestRG"
  location = "East US"
}

resource "azurerm_virtual_network" "test" {
  name                = "acctvn"
  address_space       = ["10.0.0.0/16"]
  location            = "${azurerm_resource_group.test.location}"
  resource_group_name = "${azurerm_resource_group.test.name}"
}

resource "azurerm_subnet" "test" {
  name                      = "acctsub"
  resource_group_name       = "${azurerm_resource_group.test.name}"
  virtual_network_name      = "${azurerm_virtual_network.test.name}"
  address_prefix            = "10.0.2.0/24"
  network_security_group_id = "${azurerm_network_security_group.test.id}"
}

resource "azurerm_public_ip" "test" {
  name                         = "test-pip-${count.index}"
  count                        = 3
  location                     = "${azurerm_resource_group.test.location}"
  resource_group_name          = "${azurerm_resource_group.test.name}"
  public_ip_address_allocation = "Dynamic"
  idle_timeout_in_minutes      = 30

  tags {
    environment = "test"
  }
}

resource "azurerm_network_security_group" "test" {
  name                = "acceptanceTestSecurityGroup1"
  location            = "${azurerm_resource_group.test.location}"
  resource_group_name = "${azurerm_resource_group.test.name}"

  security_rule {
    name                       = "sparkconsole"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "ssh"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags {
    environment = "Production"
  }
}

resource "azurerm_network_interface" "test" {
  name                = "acctni-${count.index}"
  count               = 3
  location            = "${azurerm_resource_group.test.location}"
  resource_group_name = "${azurerm_resource_group.test.name}"

  ip_configuration {
    name                          = "testconfiguration1"
    subnet_id                     = "${azurerm_subnet.test.id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = "${element(azurerm_public_ip.test.*.id, count.index)}"
  }
}

# resource "azurerm_managed_disk" "test" {
#   name                 = "datadisk_existing-${count.index}"
#   location             = "${azurerm_resource_group.test.location}"
#   resource_group_name  = "${azurerm_resource_group.test.name}"
#   storage_account_type = "Standard_LRS"
#   create_option        = "Empty"
#   disk_size_gb         = "1023"
#   count                = 3
# }

resource "azurerm_virtual_machine" "test" {
  name                  = "acctvm-${count.index}"
  count                 = 3
  location              = "${azurerm_resource_group.test.location}"
  resource_group_name   = "${azurerm_resource_group.test.name}"
  network_interface_ids = ["${element(azurerm_network_interface.test.*.id, count.index)}"]
  vm_size               = "Standard_DS1_v2"

  # Uncomment this line to delete the OS disk automatically when deleting the VM
  delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "myosdisk${count.index}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
    disk_size_gb      = "128"
  }

  # Optional data disks
  storage_data_disk {
    name              = "datadisk_new-${count.index}"
    managed_disk_type = "Standard_LRS"
    create_option     = "Empty"
    lun               = 0
    disk_size_gb      = "1023"
  }

  # storage_data_disk {
  #   name            = "${element(azurerm_managed_disk.test.*.name, count.index)}"
  #   managed_disk_id = "${element(azurerm_managed_disk.test.*.id, count.index)}"
  #   create_option   = "Attach"
  #   lun             = 1
  #   disk_size_gb    = "${element(azurerm_managed_disk.test.*.disk_size_gb, count.index)}"
  # }

  os_profile {
    computer_name = "hostname"

    admin_username = "ubuntu"

    # admin_password = "Password1234!"
  }
  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      key_data = "${file("/Users/nsd61/.ssh/id_rsa.pub")}"
      path     = "/home/ubuntu/.ssh/authorized_keys"
    }
  }
  tags {
    environment = "staging"
  }
}

output "public_ips" {
  value = "${azurerm_public_ip.test.*.ip_address}"
}
