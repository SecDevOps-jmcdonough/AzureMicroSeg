output "fortigate_public_ip" {
    value = azurerm_public_ip.FGTPublicIp.ip_address
}