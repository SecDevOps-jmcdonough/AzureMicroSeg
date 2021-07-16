
output "virtual_machine_identities" {
  value = data.azurerm_virtual_machine.vm.identity.*.principal_id
  
}
