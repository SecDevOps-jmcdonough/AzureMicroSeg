//############################ Resource Group ############################

locals {
  config_files = {
    "aks-calico-azure" = {
      filename = "aks-calico-azure.json"
      content = <<K8SCONNECTOR
      {
          "apiVersion": "vlabs",
          "properties": {
              "orchestratorProfile": {
                  "kubernetesConfig": {
                      "networkPlugin": "azure",
                      "networkPolicy": "calico"
                  }
              },
              "masterProfile": {
                  "count": 1,
                  "dnsPrefix": "",
                  "vmSize": "Standard_D2_v3",
                  "vnetSubnetId": "/subscriptions/${var.azsubscriptionid}/resourceGroups/${azurerm_resource_group.rg.name}/providers/Microsoft.Network/virtualNetworks/${azurerm_virtual_network.vnet.name}/subnets/${azurerm_subnet.subnets["k8s_master"].name}",
                  "firstConsecutiveStaticIP": "${cidrhost(var.vnetsubnets["k8s_master"].cidr, 10)}"
              },
              "agentPoolProfiles": [
                  {
                      "name": "nodepool1",
                      "count": 1,
                      "vmSize": "Standard_D2_v3",
                      "vnetSubnetId": "/subscriptions/${var.azsubscriptionid}/resourceGroups/${azurerm_resource_group.rg.name}/providers/Microsoft.Network/virtualNetworks/${azurerm_virtual_network.vnet.name}/subnets/${azurerm_subnet.subnets["K8s_nodes"].name}",
                      "availabilityProfile": "AvailabilitySet"
                  }
              ],
              "linuxProfile": {
                  "adminUsername": "${var.username}",
                  "ssh": {
                      "publicKeys": [
                          {
                              "keyData": ""
                          }
                      ]
                  }
              }
          }
      }
      K8SCONNECTOR
    }
  }
}

resource "local_file" "file" {

  for_each = local.config_files

  filename = "${path.module}/${each.value.filename}"
  content  = each.value.content
}
resource "azurerm_resource_group" "rg" {
  name     = "${var.TAG}-${var.project}"
  location = var.vnetloc

  tags = {
    Project = "${var.project}"
  }
}

//############################ Create VNET  ############################

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.TAG}-${var.project}-vnet-${var.vnetloc}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = var.vnetcidr

  tags = {
    Project = "${var.project}"
  }
}

//############################ Create VNET Subnets ############################

resource "azurerm_subnet" "subnets" {
  for_each = var.vnetsubnets

  name                 = "${var.TAG}-${var.project}-subnet-${each.value.name}"
  resource_group_name  = azurerm_resource_group.rg.name
  address_prefixes     = [each.value.cidr]
  virtual_network_name = azurerm_virtual_network.vnet.name

}

//############################  Route Tables ############################
resource "azurerm_route_table" "vnet_route_tables" {
  for_each = var.vnetroutetables

  name                = "${var.TAG}-${var.project}-${each.value.name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  //disable_bgp_route_propagation = false
  tags = {
    Project = "${var.project}"
  }
}

//############################  RT Associations ############################
resource "azurerm_subnet_route_table_association" "vnet_rt_assoc" {
  for_each = var.vnetroutetables

  subnet_id = azurerm_subnet.subnets[each.key].id
  #subnet_id      = data.azurerm_subnet.pub_subnet.id
  route_table_id = azurerm_route_table.vnet_route_tables[each.key].id
}

//############################  RT Default Routes ############################
resource "azurerm_route" "vnet_fgt_pub_rt_default" {
  name                = "defaultInternet"
  resource_group_name = azurerm_resource_group.rg.name
  route_table_name    = azurerm_route_table.vnet_route_tables["fgt_public"].name
  address_prefix      = "0.0.0.0/0"
  next_hop_type       = "Internet"
}

resource "azurerm_route" "vnet_k8s_node_rt_default" {
  name                   = "default"
  resource_group_name    = azurerm_resource_group.rg.name
  route_table_name       = azurerm_route_table.vnet_route_tables["K8s_nodes"].name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = var.dut1["nic2"]["ip"]
}