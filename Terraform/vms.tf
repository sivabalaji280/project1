

locals {
  my_vms = flatten([
    for vmname, vmdata in var.my_vm : {
      name                 = vmdata.name
      sku                  = vmdata.sku
      username             = vmdata.username
      password             = vmdata.password
      storage_account_type = vmdata.storage_account_type
      offer                = vmdata.offer
      os_sku               = vmdata.os_sku
      publisher            = vmdata.publisher
      my_nic = vmdata.my_nic
    }
  ])
}

locals {
  my_networks_vm = flatten([
    for vnet_key, vnet_value in var.my_vnet : [
      for subnet_key, subnet_value in vnet_value.subnet : {
        name           = vnet_key
        address_space  = vnet_value.address_space
        subnet_name    = subnet_key
        address_prefix = subnet_value.address_prefix
      }
    ]
  ])
}

data "azurerm_subnet" "subnet" {
  for_each = tomap({
    for subnet in local.my_networks : subnet.subnet_name => subnet
  })


  name                 = each.value.subnet_name
  virtual_network_name = each.value.name
  resource_group_name  = azurerm_resource_group.myrg.name
  depends_on = [ azurerm_virtual_network.vnet ]
}





data "azurerm_network_interface" "my_nic" {
  for_each = tomap({
    for my_nic in local.my_vms : my_nic.name => my_nic
  })

  name                = each.value.my_nic
  resource_group_name = azurerm_resource_group.myrg.name
  depends_on = [ azurerm_network_interface.nic]
}



resource "azurerm_network_interface" "nic" {
  for_each = tomap({
    for vmname, vmdata in local.my_vms : vmname => vmdata
  })

  

  name                = each.value.my_nic
  location            = azurerm_resource_group.myrg.location
  resource_group_name = azurerm_resource_group.myrg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.subnet["tf-subnet01"].id
    private_ip_address_allocation = "Dynamic"
  }
}
# local.my_networks_vm[each.key].name

resource "azurerm_linux_virtual_machine" "vm" {
  for_each = tomap({
    for vmname, vmdata in local.my_vms : vmname => vmdata
  })

  name                            = each.value.name
  resource_group_name             = azurerm_resource_group.myrg.name
  location                        = azurerm_resource_group.myrg.location
  size                            = each.value.sku
  admin_username                  = each.value.username
  admin_password                  = each.value.password
  disable_password_authentication = false
  network_interface_ids           = [data.azurerm_network_interface.my_nic[each.value.name].id]
  depends_on                      = [azurerm_network_interface.nic]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = each.value.storage_account_type
  }

  source_image_reference {
    publisher = each.value.publisher
    offer     = each.value.offer
    sku       = each.value.os_sku
    version   = "latest"
  }
}
