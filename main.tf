resource "azurerm_network_interface" "dyanmicnic" {
  count               = "${var.resource_count}"
  name                = "${var.group_prefix}${format("%02d", count.index)}-${local.suffix_nic}"
  location            = "${var.region}"
  resource_group_name = "${var.resource_group_name}"

  ip_configuration {
    name                          = "${var.group_prefix}${format("%02d", count.index)}-${local.suffix_ipconfig}"
    subnet_id                     = "${var.subnet_id}"
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "nic" {
  count               = "${var.resource_count}"
  name                = "${var.group_prefix}${format("%02d", count.index)}-${local.suffix_nic}"
  location            = "${var.region}"
  resource_group_name = "${var.resource_group_name}"

  ip_configuration {
    name                          = "${var.group_prefix}${format("%02d", count.index)}-${local.suffix_ipconfig}"
    subnet_id                     = "${var.subnet_id}"
    private_ip_address_allocation = "Static"
    private_ip_address            = "${azurerm_network_interface.dyanmicnic.*.private_ip_address[count.index]}"
  }

  tags = "${local.tags}"

  lifecycle {
    ignore_changes = ["ip_configuration"]
  }
}

### Storage
data "azurerm_storage_account" "diagsa" {
  name                = "${var.location}prodshrdrgdiag"
  resource_group_name = "${var.location}RG"
}

resource "azurerm_managed_disk" "datadisk" {
  count                = "${var.resource_count}"
  name                 = "${var.group_prefix}${format("%02d", count.index)}-${local.suffix_data_disk}"
  location             = "${var.region}"
  resource_group_name  = "${var.resource_group_name}"
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = "${var.datadisk_size}"
  tags                 = "${local.tags}"
}

resource "azurerm_managed_disk" "extra-datadisk" {
  count                = "${var.resource_count * length(var.extra_disks)}"
  name                 = "${var.group_prefix}${format("%02d", count.index / length(var.extra_disks))}-${local.suffix_data_disk}-${element(keys(var.extra_disks), count.index % length(var.extra_disks))}"
  location             = "${var.region}"
  resource_group_name  = "${var.resource_group_name}"
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = "${element(values(var.extra_disks), count.index % length(var.extra_disks))}"
  tags                 = "${local.tags}"
}

