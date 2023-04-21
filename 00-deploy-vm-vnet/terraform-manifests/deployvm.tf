terraform {

   required_version = ">=0.12"

   required_providers {
     azurerm = {
       source = "hashicorp/azurerm"
       version = "~>2.0"
     }
   }
 }

 provider "azurerm" {
   features {}
 }


# Generate a random integer to create a globally unique name
resource "random_integer" "ri" {
  min = 10000
  max = 99999
}


 resource "azurerm_resource_group" "vnRG" {
   name     = "Network-RG-${random_integer.ri.result}"
   location = "East US"
   tags = {
     environment = "staging"
     Builder = "obalogun"
     CostCenter = "IT GSS"
     Owner = "ITGSS"
     OwnerEmail = "Iteng@AM.com"
     Application = "tf state"
   }
 }

 resource "azurerm_virtual_network" "VN" {
   name                = "Vnet-${random_integer.ri.result}"
   address_space       = ["10.0.0.0/16"]
   location            = azurerm_resource_group.vnRG.location
   resource_group_name = azurerm_resource_group.vnRG.name
   tags = {
     environment = "staging"
     Builder = "obalogun"
     CostCenter = "IT GSS"
     Owner = "ITGSS"
     OwnerEmail = "Iteng@AM.com"
     Application = "tf state"
   }
 }

 resource "azurerm_network_security_group" "NSG" {
  name = "NSG-${random_integer.ri.result}"
  location            = azurerm_resource_group.vnRG.location
   resource_group_name = azurerm_resource_group.vnRG.name
  tags = {
     environment = "staging"
     Builder = "obalogun"
     CostCenter = "IT GSS"
     Owner = "ITGSS"
     OwnerEmail = "Iteng@AM.com"
     Application = "tf state"
   }
 }

 resource "azurerm_subnet" "FESubnet" {
   name                 = "FEsubnet"
   resource_group_name  = azurerm_resource_group.vnRG.name
   virtual_network_name = azurerm_virtual_network.VN.name
   address_prefixes     = ["10.0.2.0/24"]
   service_endpoints    = ["Microsoft.Sql", "Microsoft.Storage", "Microsoft.Web"]
   
 }

  resource "azurerm_subnet" "MIDSubnet" {
   name                 = "Midsubnet"
   resource_group_name  = azurerm_resource_group.vnRG.name
   virtual_network_name = azurerm_virtual_network.VN.name
   address_prefixes     = ["10.0.3.0/24"]
   service_endpoints    = ["Microsoft.Sql", "Microsoft.Storage"]
   
 }

   resource "azurerm_subnet" "BESubnet" {
   name                 = "BEsubnet"
   resource_group_name  = azurerm_resource_group.vnRG.name
   virtual_network_name = azurerm_virtual_network.VN.name
   address_prefixes     = ["10.0.4.0/24"]
   service_endpoints    = ["Microsoft.Sql", "Microsoft.Storage"]
   
 }

 resource "azurerm_subnet_network_security_group_association" "FENSGAssign" {
  subnet_id                 = azurerm_subnet.FESubnet.id
  network_security_group_id = azurerm_network_security_group.NSG.id
}

 resource "azurerm_subnet_network_security_group_association" "MIDNSGAssign" {
  subnet_id                 = azurerm_subnet.MIDSubnet.id
  network_security_group_id = azurerm_network_security_group.NSG.id
}

 resource "azurerm_subnet_network_security_group_association" "NSGAssign3" {
  subnet_id                 = azurerm_subnet.BESubnet.id
  network_security_group_id = azurerm_network_security_group.NSG.id
}

resource "azurerm_storage_account" "SA" {
  name                = "uatsa${random_integer.ri.result}"
  resource_group_name = azurerm_resource_group.vnRG.name

  location                 = azurerm_resource_group.vnRG.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  network_rules {
    default_action             = "Deny"
    ip_rules                   = ["100.8.8.8"]
    virtual_network_subnet_ids = [azurerm_subnet.BESubnet.id]
  }

  tags = {
     environment = "staging"
     Builder = "obalogun"
     CostCenter = "IT GSS"
     Owner = "ITGSS"
     OwnerEmail = "Iteng@AM.com"
     Application = "tf state"
   }
}


 resource "azurerm_lb" "LB" {
   name                = "LB-${random_integer.ri.result}"
   location            = azurerm_resource_group.vnRG.location
   resource_group_name = azurerm_resource_group.vnRG.name
   sku = "Standard"
   frontend_ip_configuration {
     name                 = "UAT-LB-FE-IP-${random_integer.ri.result}"
     subnet_id = azurerm_subnet.BESubnet.id
     private_ip_address_version = "IPv4"
     private_ip_address_allocation = "Dynamic"
     
   }
   tags = {
     environment = "staging"
     Builder = "obalogun"
     CostCenter = "IT GSS"
     Owner = "ITGSS"
     OwnerEmail = "Iteng@AM.com"
     Application = "tf state"
   }
 }

 resource "azurerm_lb_backend_address_pool" "BEpool" {
   loadbalancer_id     = azurerm_lb.LB.id
   name                = "app-backend-${random_integer.ri.result}"
 }

# Create LB Probe
resource "azurerm_lb_probe" "app_lb_probe" {
  name                = "tcp-probe"
  protocol            = "Tcp"
  port                = 5999
  loadbalancer_id     = azurerm_lb.LB.id
  resource_group_name = azurerm_resource_group.vnRG.name
}


# Resource-5: Create LB Rule
resource "azurerm_lb_rule" "app_lb_rule_app1" {
  name                           = "app-app1-rule"
  protocol                       = "Tcp"
  frontend_port                  = 1433
  backend_port                   = 1433
  frontend_ip_configuration_name = azurerm_lb.LB.frontend_ip_configuration[0].name
  backend_address_pool_ids        = [azurerm_lb_backend_address_pool.BEpool.id ]
  probe_id                       = azurerm_lb_probe.app_lb_probe.id
  loadbalancer_id                = azurerm_lb.LB.id
  resource_group_name            = azurerm_resource_group.vnRG.name
}

 resource "azurerm_network_interface" "nic" {
   count               = 2
   name                = "nicUATVM${count.index}"
   location            = azurerm_resource_group.vnRG.location
   resource_group_name = azurerm_resource_group.vnRG.name

   ip_configuration {
     name                          = "IPConfigs"
     subnet_id                     = azurerm_subnet.BESubnet.id
     private_ip_address_allocation = "Dynamic"
   }
 }

 resource "azurerm_managed_disk" "Datadisk" {
   count                = 2
   name                 = "datadisk_existing_${count.index}"
   location            = azurerm_resource_group.vnRG.location
   resource_group_name = azurerm_resource_group.vnRG.name
   storage_account_type = "Standard_LRS"
   create_option        = "Empty"
   disk_size_gb         = "1023"
 }

 resource "azurerm_availability_set" "avset" {
   name                         = "avset-${random_integer.ri.result}"
   location                     = azurerm_resource_group.vnRG.location
   resource_group_name          = azurerm_resource_group.vnRG.name
   platform_fault_domain_count  = 2
   platform_update_domain_count = 2
   managed                      = true
   tags = {
     environment = "staging"
     Builder = "obalogun"
     CostCenter = "IT GSS"
     Owner = "ITGSS"
     OwnerEmail = "Iteng@AM.com"
     Application = "tf state"
   }
 }

# Generate random password
resource "random_password" "password" {
  length      = 20
  min_lower   = 1
  min_upper   = 1
  min_numeric = 1
  min_special = 1
  special     = true
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "my_storage_account" {
  name                     = "diag${random_integer.ri.result}"
  location                 = azurerm_resource_group.LogsRG.location
  resource_group_name      = azurerm_resource_group.LogsRG.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}


# Create virtual machine
resource "azurerm_windows_virtual_machine" "VM" {
   count                 = 2
   name                  = "UATVM${count.index}"
   location              = azurerm_resource_group.vnRG.location
   admin_username        = "VMadmin"
   admin_password        = random_password.password.result
   availability_set_id   = azurerm_availability_set.avset.id
   resource_group_name   = azurerm_resource_group.vnRG.name
   network_interface_ids = [element(azurerm_network_interface.nic.*.id, count.index)]
   size                  = "Standard_DS3_v2"

   source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }

   os_disk {
    name                 = "myOsDisk${random_integer.ri.result}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

   
  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.my_storage_account.primary_blob_endpoint
  }

   tags = {
     environment = "staging"
     Builder = "obalogun"
     CostCenter = "IT GSS"
     Owner = "ITGSS"
     OwnerEmail = "Iteng@AM.com"
     Application = "tf state"
   }
 }


data "azurerm_virtual_machine" "sqlvm" {
  count               = 2
  name                = "UATVM${count.index}"
  resource_group_name = azurerm_resource_group.vnRG.name
  depends_on = [
    azurerm_windows_virtual_machine.VM
  ]
}

resource "azurerm_mssql_virtual_machine" "sqlvm" {
  count                            = 2
  virtual_machine_id               = data.azurerm_virtual_machine.sqlvm[count.index].id
  sql_license_type                 = "AHUB"
  r_services_enabled               = true
  sql_connectivity_port            = 1433
  sql_connectivity_type            = "PRIVATE"
  sql_connectivity_update_password = "Password1234!"
  sql_connectivity_update_username = "sqllogin"

  auto_patching {
    day_of_week                            = "Sunday"
    maintenance_window_duration_in_minutes = 60
    maintenance_window_starting_hour       = 2
  }

 tags = {
     environment = "staging"
     Builder = "obalogun"
     CostCenter = "IT GSS"
     Owner = "ITGSS"
     OwnerEmail = "Iteng@AM.com"
     Application = "tf state"
   }

  depends_on = [
    azurerm_windows_virtual_machine.VM
  ]
}



resource "azurerm_resource_group" "APPRG" {
  name     = "APP-UAT-RG-${random_integer.ri.result}"
  location = "East US"
  tags = {
     environment = "staging"
     Builder = "obalogun"
     CostCenter = "IT GSS"
     Owner = "ITGSS"
     OwnerEmail = "Iteng@AM.com"
     Application = "tf state"
   }
}

resource "azurerm_app_service_plan" "Appplan" {
  name                = "Appplan-${random_integer.ri.result}"
  location            = azurerm_resource_group.APPRG.location
  resource_group_name = azurerm_resource_group.APPRG.name

  sku {
    tier = "Standard"
    size = "S1"
  }
  tags = {
     environment = "staging"
     Builder = "obalogun"
     CostCenter = "IT GSS"
     Owner = "ITGSS"
     OwnerEmail = "Iteng@AM.com"
     Application = "tf state"
   }
}

resource "azurerm_app_service" "webapp" {
  name                = "App-service-${random_integer.ri.result}"
  location            = azurerm_resource_group.APPRG.location
  resource_group_name = azurerm_resource_group.APPRG.name
  app_service_plan_id = azurerm_app_service_plan.Appplan.id
  https_only            = true
  site_config { 
    dotnet_framework_version = "v4.0"
    scm_type                 = "LocalGit"
  }

  app_settings = {
    "SOME_KEY" = "some-value"
  }
  tags = {
     environment = "staging"
     Builder = "obalogun"
     CostCenter = "IT GSS"
     Owner = "ITGSS"
     OwnerEmail = "Iteng@AM.com"
     Application = "tf state"
   }
   depends_on = [
     azurerm_app_service_plan.Appplan ,
     azurerm_resource_group.APPRG
   ]

}


resource "azurerm_resource_group" "LogsRG" {
  name     = "Logs-RG-${random_integer.ri.result}"
  location = "East US"
  tags = {
     environment = "staging"
     Builder = "obalogun"
     CostCenter = "IT GSS"
     Owner = "ITGSS"
     OwnerEmail = "Iteng@AM.com"
     Application = "tf state"
   }
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-${random_integer.ri.result}"
  location            = azurerm_resource_group.LogsRG.location
  resource_group_name = azurerm_resource_group.LogsRG.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  depends_on = [
    azurerm_app_service.webapp
  ]
  tags = {
     environment = "staging"
     Builder = "obalogun"
     CostCenter = "IT GSS"
     Owner = "ITGSS"
     OwnerEmail = "Iteng@AM.com"
     Application = "tf state"
   }
}

resource "azurerm_application_insights" "appins" {
  name                = "appinsights-${random_integer.ri.result}"
  location            = azurerm_resource_group.LogsRG.location
  resource_group_name = azurerm_resource_group.LogsRG.name
  workspace_id        = azurerm_log_analytics_workspace.law.id
  application_type    = "web"
}

output "instrumentation_key" {
  sensitive = true
  value = azurerm_application_insights.appins.instrumentation_key
}

output "app_id" {
  sensitive = false
  value = azurerm_application_insights.appins.app_id
}

resource "azurerm_monitor_diagnostic_setting" "diag_settings" {
  name               = "dgs-${random_integer.ri.result}"
  target_resource_id = azurerm_app_service.webapp.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  
  log {
    category = "AppServiceHTTPLogs"
    enabled  = true

    retention_policy {
      enabled = false
    }
  }

    log {
    category = "AppServiceConsoleLogs"
    enabled  = true

    retention_policy {
      enabled = false
    }
  }

    log {
    category = "AppServiceAppLogs"
    enabled  = true

    retention_policy {
      enabled = false
    }
  }

    log {
    category = "AppServiceAuditLogs"
    enabled  = true

    retention_policy {
      enabled = false
    }
  }

    log {
    category = "AppServiceIPSecAuditLogs"
    enabled  = true

    retention_policy {
      enabled = false
    }
  }

     log {
    category = "AppServicePlatformLogs"
    enabled  = true

    retention_policy {
      enabled = false
    }
  }

  metric {
    category = "AllMetrics"

    retention_policy {
      enabled = false
      days = 30
    }
  }
  depends_on = [
    azurerm_log_analytics_workspace.law
  ]
}