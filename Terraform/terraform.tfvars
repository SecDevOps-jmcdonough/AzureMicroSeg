azsubscriptionid = "cc0d730a-9395-4c66-8a74-efdfc1b05670" // APAC-CSE

project = "microseg"
TAG     = "k8s"

vnetloc  = "eastus"
vnetcidr = ["10.33.0.0/16"]


vnetsubnets = {
  "fgt_public"  = { name = "fgt_public", cidr = "10.33.0.0/24" },
  "fgt_private" = { name = "fgt_private", cidr = "10.33.1.0/24" },
  "k8s_master"  = { name = "k8s_master", cidr = "10.33.2.0/24" },
  "K8s_nodes"   = { name = "K8s_nodes", cidr = "10.33.3.0/24" },
}


dut_vmsize    = "Standard_F2s_v2"
FGT_IMAGE_SKU = "fortinet_fg-vm_payg_20190624"
FGT_VERSION   = "7.0.0"
FGT_OFFER     = "fortinet_fortigate-vm_v5"

dut1 = {
  "nic1" = { vmname = "fgt1", name = "port1", subnet = "fgt_public", ip = "10.33.0.4" },
  "nic2" = { vmname = "fgt1", name = "port2", subnet = "fgt_private", ip = "10.33.1.4" },
}


username = "mremini"
password = "Fortinet20217"