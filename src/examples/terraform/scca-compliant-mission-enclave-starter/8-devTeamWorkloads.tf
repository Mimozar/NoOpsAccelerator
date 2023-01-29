# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

/*
SUMMARY: Module to deploy the Development Workload Environent Network 
DESCRIPTION: The following components will be options in this deployment
              Development Team Environent Spoke Virtual Network (Vnet)
              Subnets
              Route Table
              Network Security Group
              Log Storage 
              Azure Key Vault
              Azure Kubernetes Service (AKS)
              Azure Container Registry (ACR)                          
              Private DNS Zones - Details of all the Azure Private DNS zones can be found here --> https://docs.microsoft.com/en-us/azure/private-link/private-endpoint-dns#azure-services-dns-zone-configuration
AUTHOR/S: jspinella
*/

#################################################
### STAGE 7: Dev Teams Network Configuations ###
#################################################

# Dev Team Environment Spokes Network (Optional). 
# This is the network for the Dev Team 1 environment. 
# This is a spoke network that is peered to the hub network. 
# This could be updated to use a object to create multiple spoke networks.
module "mod_dev_team_env_spoke_network" {
  //count  = var.dev_team_instances_count >= 1 ? var.dev_team_instances_count : 0 # for each needs a set, cannot work with a list
  source = "../../../terraform/core/overlays/hubSpokeLandingZone/virtualNetworkSpoke"

  # Global Settings
  location      = module.mod_azure_region.location
  environment   = var.environment
  org_prefix    = var.required.org_prefix
  workload_name = local.devTeamName


  # By default, this module should not create a network watcher. If you want to enable this, set this to true
  create_network_watcher = false

  # Operations Spoke Configuration
  virtual_network_name          = local.devTeamVirtualNetworkName
  virtual_network_address_space = var.devTeam_vnet_address_space

  # Operations Spoke Subnets
  subnet_name                                = local.devTeamSubnetName
  subnet_address_prefixes                    = var.dev_team_vnet_subnet_address_prefixes
  subnet_service_endpoints                   = var.dev_team_vnet_subnet_service_endpoints
  private_endpoint_network_policies_enabled  = false
  private_endpoint_service_endpoints_enabled = true

  # Operations Spoke Network Security Group
  network_security_group_name           = local.devTeamNetworkSecurityGroupName
  network_security_group_inbound_rules  = var.dev_team_network_security_group_inbound_rules
  network_security_group_outbound_rules = var.dev_team_network_security_group_outbound_rules

  // Operations Spoke Route Table
  route_table_name = local.devTeamRouteTableName
  route_table_routes = {
    "default_devTeam_route" = {
      name                   = "RouteToAzureFirewall"
      address_prefix         = "0.0.0.0/0"
      next_hop_type          = "VirtualAppliance"
      next_hop_in_ip_address = module.mod_hub_network.firewall_private_ip
    }
  }

  // Loggging Settings
  storage_account_name = local.devTeamLogStorageAccountName

  // Locks
  enable_resource_locks = var.enable_services.enable_resource_locks
  lock_level            = var.lock_level

  // Tags
  tags = merge(var.tags, {
    DeployedBy = format("AzureNoOpsTF [%s]", terraform.workspace)
  }) # Tags to be applied to all resources
}

######################################
## STAGE 7.1: Networking Peering   ###
######################################

module "mod_hub_to_dev_team_networking_peering" {
  depends_on = [
    module.mod_hub_network,
    module.mod_dev_team_env_spoke_network
  ]
  source = "../../../terraform/core/overlays/hubSpokeLandingZone/virtualNetworkPeering"

  count = var.peer_to_hub_virtual_network ? 1 : 0

  // Hub Networking Peering Settings
  peering_name_1_to_2 = "${module.mod_hub_network.virtual_network_name}-to-${module.mod_dev_team_env_spoke_network.virtual_network_name}"
  vnet_1_id           = module.mod_hub_network.virtual_network_id
  vnet_1_name         = module.mod_hub_network.virtual_network_name
  vnet_1_rg           = module.mod_hub_network.resource_group_name

  // Operations Networking Peering Settings
  peering_name_2_to_1 = "${module.mod_dev_team_env_spoke_network.virtual_network_name}-to-${module.mod_hub_network.virtual_network_name}"
  vnet_2_id           = module.mod_dev_team_env_spoke_network.virtual_network_id
  vnet_2_name         = module.mod_dev_team_env_spoke_network.virtual_network_name
  vnet_2_rg           = module.mod_dev_team_env_spoke_network.resource_group_name

  // Settings
  allow_virtual_network_access = var.allow_virtual_network_access
  use_remote_gateways          = var.use_remote_gateways
}

########################################################################
### STAGE 7.2: Build out Azure Kubernetes Service with ACR & Jumpbox ###
########################################################################

module "dev_env_acr_aks_cluster" {
  depends_on = [
    module.mod_dev_env_aks_workload_spoke_resource_group,
    module.mod_dev_env_aks_workload_spoke_network,
    module.mod_hub_to_spoke_networking_peering
  ]
  providers = { azurerm = azurerm.dev_team }
  source    = "../../../terraform/core/overlays/kubernetesClusters"
  // Global Settings
  org_prefix          = var.required.org_prefix
  deploy_environment  = var.required.deploy_environment
  location            = var.location
  resource_group_name = module.mod_dev_env_aks_workload_spoke_resource_group.name

  // ACR Settings  
  enable_container_pull = var.enable_container_pull
  acr_pe_vnet_subnet_id = module.mod_dev_env_aks_workload_spoke_network.subnet_ids["privatelinks-snet"]
  acr_name              = var.acr_name
  acr_sku               = var.acr_sku
  acr_admin_enabled     = var.acr_admin_enabled
  acr_dns_virtual_networks_to_link = {
    ("privatelinks-snet") = {
      subscription_id      = data.azurerm_client_config.current.subscription_id
      resource_group_name  = module.mod_dev_env_aks_workload_spoke_resource_group.name
      virtual_network_name = module.mod_dev_env_aks_workload_spoke_network.virtual_network_name
    }
  }

  // AKS Cluster Settings
  aks_name                         = var.aks_prefix_name
  aks_node_pool_vnet_subnet_id     = module.mod_dev_env_aks_workload_spoke_network.subnet_ids["clusternodes-snet"]
  control_plane_kubernetes_version = var.control_plane_kubernetes_version
  sla_sku                          = var.sku_tier
  network_plugin                   = var.network_plugin
  net_profile_dns_service_ip       = var.net_profile_dns_service_ip
  net_profile_docker_bridge_cidr   = var.net_profile_docker_bridge_cidr
  net_profile_service_cidr         = var.net_profile_service_cidr
  net_profile_pod_cidr             = var.net_profile_pod_cidr
  agents_max_count                 = var.agents_max_count
  agents_min_count                 = var.agents_min_count
  private_cluster_enabled          = var.private_cluster_enabled
  identity_type                    = var.use_user_defined_identity ? "UserAssigned" : "SystemAssigned"

  // AKS Jumpbox Settings
  create_jumpbox              = true
  size_linux_jumpbox          = var.vm_size
  vm_os_disk_image            = var.vm_os_disk_image
  virtual_network_name        = module.mod_dev_env_aks_workload_spoke_network.virtual_network_name
  vm_subnet_id                = "default-snet"
  network_security_group_name = module.mod_dev_env_aks_workload_spoke_network.network_security_group_name

  // Tags
  tags = merge(var.tags, {
    DeployedBy = format("AzureNoOpsTF [%s]", terraform.workspace)
  })
}

######################################
### STAGE 7.3: Build out ComosDB   ###
######################################

/* module "dev_env_comosdb" {
} */

#########################################
### STAGE 7.4: Build out Resis Cache  ###
#########################################

/* module "dev_env_redis_cache" {
} */
