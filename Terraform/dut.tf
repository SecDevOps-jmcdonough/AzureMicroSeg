resource "azurerm_network_interface" "dut1nics" {
  for_each                      = var.dut1
  name                          = "${each.value.vmname}-${each.value.name}"
  location                      = azurerm_resource_group.rg.location
  resource_group_name           = azurerm_resource_group.rg.name
  enable_ip_forwarding          = true
  enable_accelerated_networking = false

  ip_configuration {
    name      = "ipconfig1"
    subnet_id = azurerm_subnet.subnets[each.value.subnet].id
    #subnet_id                     = data.azurerm_subnet.dut1subnetid[each.key].id
    private_ip_address_allocation = "static"
    private_ip_address            = each.value.ip
    public_ip_address_id          = (each.value.name == "port1" ? azurerm_public_ip.FGTPublicIp.id : null)
  }
}

resource "azurerm_public_ip" "FGTPublicIp" {
  name                = "${var.TAG}-${var.project}-FGTPublicIP"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"

  tags = {
    Project = "${var.project}"
  }

}

//############################  FGT NSGs ##################

resource "azurerm_network_security_group" "fgt_nsgs" {
  for_each = var.nsgs

  name                = "${var.TAG}-${var.project}-${each.value.name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_security_rule" "fgt_nsg_rules" {
  for_each = var.nsgrules

  name                        = each.value.rulename
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.fgt_nsgs[each.value.nsgname].name
  priority                    = each.value.priority
  direction                   = each.value.direction
  access                      = each.value.access
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"

}

//############################ NIC to NSG  ############################

resource "azurerm_network_interface_security_group_association" "fgtnicpub" {
  network_interface_id      = element([for nic in azurerm_network_interface.dut1nics : nic.id], 0)
  network_security_group_id = azurerm_network_security_group.fgt_nsgs["pub-nsg"].id
}
resource "azurerm_network_interface_security_group_association" "fgtnicpriv" {
  network_interface_id      = element([for nic in azurerm_network_interface.dut1nics : nic.id], 1)
  network_security_group_id = azurerm_network_security_group.fgt_nsgs["priv-nsg"].id
}

////////////////////////////////////////DUT//////////////////////////////
data "template_file" "dut1_customdata" {
  template = file("./assets/fgt-userdata.tpl")
  vars = {
    fgt_id             = element(values(var.dut1)[*].vmname, 0)
    fgt_license_file   = ""
    fgt_username       = var.username
    fgt_config_ha      = false
    fgt_ssh_public_key = ""

    Port1IP = element(values(var.dut1)[*].ip, 0)
    Port2IP = element(values(var.dut1)[*].ip, 1)

    public_subnet_mask  = cidrnetmask(var.vnetsubnets["fgt_public"]["cidr"])
    private_subnet_mask = cidrnetmask(var.vnetsubnets["fgt_private"]["cidr"])

    fgt_external_gw = cidrhost(var.vnetsubnets["fgt_public"]["cidr"], 1)
    fgt_internal_gw = cidrhost(var.vnetsubnets["fgt_private"]["cidr"], 1)

    vnet_network = var.vnetcidr[0]

    resource_group = var.azurerm_resource_group.rg.name

  }
}

resource "azurerm_virtual_machine" "dut1" {
  name                         = "${var.TAG}-${var.project}-fgt1"
  location                     = azurerm_resource_group.rg.location
  resource_group_name          = azurerm_resource_group.rg.name
  network_interface_ids        = [for nic in azurerm_network_interface.dut1nics : nic.id]
  primary_network_interface_id = element(values(azurerm_network_interface.dut1nics)[*].id, 0)
  vm_size                      = var.dut_vmsize

  identity {
    type = "SystemAssigned"
  }

  storage_image_reference {
    publisher = "fortinet"
    offer     = var.FGT_OFFER
    sku       = var.FGT_IMAGE_SKU
    version   = var.FGT_VERSION
  }

  plan {
    publisher = "fortinet"
    product   = var.FGT_OFFER
    name      = var.FGT_IMAGE_SKU
  }

  storage_os_disk {
    name              = "${var.TAG}-${var.project}-fgt1_OSDisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_data_disk {
    name              = "${var.TAG}-${var.project}-fgt1_DataDisk"
    managed_disk_type = "Premium_LRS"
    create_option     = "Empty"
    lun               = 0
    disk_size_gb      = "20"
  }
  os_profile {
    computer_name  = "${var.TAG}-${var.project}-fgt1"
    admin_username = var.username
    admin_password = var.password
    custom_data    = data.template_file.dut1_customdata.rendered
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  tags = {
    Project = "${var.project}"
  }

}

////////////////////////////////////////IAM/////////////////////////////

resource "azurerm_role_assignment" "fgt_reader_role" {
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Reader"
  principal_id         = azurerm_virtual_machine.dut1.identity[0].principal_id
  depends_on = [
    azurerm_virtual_machine.dut1
  ]
}