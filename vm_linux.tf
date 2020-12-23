# jrk <jonathan@thoughtwave.com>
resource "azurerm_virtual_machine" "vm_linux" {
  count                 = "${local.is_vm_linux ? var.resource_count : 0}"
  name                  = "${var.group_prefix}${format("%02d", count.index)}"
  location              = "${var.region}"
  resource_group_name   = "${var.resource_group_name}"
  vm_size               = "${local.map_tshirt_size[var.tshirt_size]}"
  network_interface_ids = ["${azurerm_network_interface.nic.*.id[count.index]}"]
  availability_set_id   = "${var.availabilityset}"
  tags                  = "${local.tags}"

  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "${local.map_publisher[var.sku_osversion]}"                       # Operating System
    offer     = "${local.map_offer[var.sku_osversion]}"
    sku       = "${local.map_sku_osversion[var.sku_osversion]}"
    version   = "${var.rhel_sku_version}"
  }

  storage_os_disk {
    # System "OS" disk
    name              = "${var.group_prefix}${format("%02d", count.index)}-${local.suffix_os_disk}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }

  os_profile {
    # comupter name admin uid/pwd
    computer_name  = "${var.group_prefix}${format("%02d", count.index)}"
    admin_username = "${data.vault_generic_secret.localadmin.data["username"]}"
    admin_password = "${data.vault_generic_secret.localadmin.data["password"]}"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  boot_diagnostics {
    enabled     = true
    storage_uri = "${data.azurerm_storage_account.diagsa.primary_blob_endpoint}"

    # storage_uri = "${azurerm_storage_account.vm_sa.*.primary_blob_endpoint[count.index]}
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_virtual_machine_data_disk_attachment" "linux_datadisk" {
  count              = "${local.is_vm_linux ? var.resource_count : 0 }"
  managed_disk_id    = "${azurerm_managed_disk.datadisk.*.id[count.index]}"
  virtual_machine_id = "${azurerm_virtual_machine.vm_linux.*.id[count.index]}"
  lun                = "1"
  caching            = "ReadWrite"
}

resource "azurerm_virtual_machine_data_disk_attachment" "linux_extradatadisk" {
  count              = "${local.is_vm_linux ? var.resource_count * length(var.extra_disks) : 0}"
  managed_disk_id    = "${azurerm_managed_disk.extra-datadisk.*.id[count.index]}"
  virtual_machine_id = "${azurerm_virtual_machine.vm_linux.*.id[count.index / length(var.extra_disks)]}"
  lun                = "${element(keys(var.extra_disks), count.index % length(var.extra_disks))}"
  caching            = "ReadWrite"
}

#####  Chef Agent Installation
resource "azurerm_virtual_machine_extension" "chef_agent_linux" {
  count                = "${local.is_vm_linux ? var.resource_count : 0 }"
  name                 = "chefagent"
  virtual_machine_id   = "${azurerm_virtual_machine.vm_linux.*.id[count.index]}"
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  # CustomVMExtension Documetnation: https://docs.microsoft.com/en-us/azure/virtual-machines/extensions/custom-script-windows
  settings = "${local.linux["settings"]}"

  protected_settings = "${local.linux["protected_settings"]}"

  tags = "${local.tags}"

  lifecycle {
    ignore_changes = ["protected_settings"]
  }
}

resource "azurerm_virtual_machine_extension" "ntw_linux" {
  count                      = "${local.is_vm_linux ? var.resource_count : 0 }"
  name                       = "networkwatcher_agent"
  virtual_machine_id         = "${azurerm_virtual_machine.vm_linux.*.id[count.index]}"
  publisher                  = "Microsoft.Azure.NetworkWatcher"
  type                       = "NetworkWatcherAgentLinux"
  type_handler_version       = "1.4"
  auto_upgrade_minor_version = true
  tags = "${local.tags}"
}
