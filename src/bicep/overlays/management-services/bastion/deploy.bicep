// ----------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. Licensed under the MIT license.
//
// THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, 
// EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES 
// OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
// ----------------------------------------------------------------------------------

/*
SUMMARY: Module to deploy a Bastion Host with Windows/Linux Jump Boxes to the Hub Network
DESCRIPTION: The following components will be options in this deployment
              Bastion Host
              Windows VM
              Lunix VM
AUTHOR/S: jspinella
VERSION: 1.x.x
*/

// REQUIRED PARAMETERS

@description('Prefix value which will be prepended to all resource names. Default: anoa')
param parOrgPrefix string = 'anoa'

@description('The region to deploy resources into. It defaults to the deployment location.')
param parLocation string = resourceGroup().location

@minLength(3)
@maxLength(15)
@description('A suffix, 3 to 15 characters in length, to append to resource names (e.g. "dev", "test", "prod", "platforms"). It defaults to "platforms".')
param parDeployEnvironment string = 'platforms'

// RESOURCE NAMING PARAMETERS

@description('A suffix to use for naming deployments uniquely. It defaults to the Bicep resolution of the "utcNow()" function.')
param parDeploymentNameSuffix string = utcNow()

@description('Tags')
param parTags object = {}

@description('The Hub Virtual Network Name')
param parHubVirtualNetworkName string

@description('The Hub Subnet Resource Id')
param parHubSubnetResourceId string

@description('The Hub Network Security Group Resource Id')
param parHubNetworkSecurityGroupResourceId string

@description('The SKU of this Bastion Host.')
param parBastionHostSku string

@description('The CIDR Subnet Address Prefix for the Azure Bastion Subnet. It must be in the Hub Virtual Network space "hubVirtualNetworkAddressPrefix" parameter value. It must be /27 or larger.')
param parBastionHostSubnetAddressPrefix string = '10.0.100.160/27'

@description('Optional. This property can be used by user in the request to enable or disable the Host Encryption for the virtual machine. This will enable the encryption for all the disks including Resource/Temp disk at host itself. For security reasons, it is recommended to set encryptionAtHost to True. Restrictions: Cannot be enabled if Azure Disk Encryption (guest-VM encryption using bitlocker/DM-Crypt) is enabled on your VMs.')
param parEncryptionAtHost bool = false

// Linux VIRTUAL MACHINE PARAMETERS

@description('Switch which allows Linux VM to be deployed. Default: true')
param parEnableLinux bool = true

param parLinuxNetworkInterfacePrivateIPAddressAllocationMethod string

@description('The name of the Linux Virtual Machine to Azure Bastion remote into.')
param parLinuxVmName string

@description('The size of the Linux Virtual Machine to Azure Bastion remote into. It defaults to "Standard_DS1_v2".')
param parLinuxVmSize string = 'Standard_DS1_v2'

@description('The disk creation option of the Linux Virtual Machine to Azure Bastion remote into. It defaults to "FromImage".')
param parLinuxVmOsDiskCreateOption string = 'FromImage'

@description('The disk type of the Linux Virtual Machine to Azure Bastion remote into. It defaults to "Standard_LRS".')
param parLinuxVmOsDiskType string = 'Standard_LRS'

@description('The image publisher of the Linux Virtual Machine to Azure Bastion remote into. It defaults to "Canonical".')
param parLinuxVmImagePublisher string = 'Canonical'

@description('The image offer of the Linux Virtual Machine to Azure Bastion remote into. It defaults to "UbuntuServer".')
param parLinuxVmImageOffer string = 'UbuntuServer'

@description('The image SKU of the Linux Virtual Machine to Azure Bastion remote into. It defaults to "18.04-LTS".')
param parLinuxVmImageSku string = '18.04-LTS'

@description('The image version of the Linux Virtual Machine to Azure Bastion remote into. It defaults to "latest".')
param parLinuxVmImageVersion string = 'latest'

@description('The administrator username for the Linux Virtual Machine to Azure Bastion remote into. It defaults to "azureuser".')
param parLinuxVmAdminUsername string

@description('Optional. Specifies whether password authentication should be disabled.')
#disable-next-line secure-secrets-in-params
param parDisableLinuxVmPasswordAuthentication bool = false

@secure()
@description('The administrator password or public SSH key for the Linux Virtual Machine to Azure Bastion remote into. See https://docs.microsoft.com/en-us/azure/virtual-machines/linux/faq#what-are-the-password-requirements-when-creating-a-vm- for password requirements.')
param parLinuxVmAdminPasswordOrKey string = parDisableLinuxVmPasswordAuthentication ? '' : newGuid()

// WINDOWS VIRTUAL MACHINE PARAMETERS

@description('Switch which allows Windows VM to be deployed. Default: true')
param parEnableWindows bool = true

@description('The name for the Windows Virtual Machine to Azure Bastion remote into.')
param parWindowsVmName string

@description('The administrator username for the Windows Virtual Machine to Azure Bastion remote into. It defaults to "azureuser".')
param parWindowsVmAdminUsername string = 'azureuser'

@description('The administrator password the Windows Virtual Machine to Azure Bastion remote into. It must be > 12 characters in length. See https://docs.microsoft.com/en-us/azure/virtual-machines/windows/faq#what-are-the-password-requirements-when-creating-a-vm- for password requirements.')
@secure()
@minLength(12)
param parWindowsVmAdminPassword string

@description('The size of the Windows Virtual Machine to Azure Bastion remote into. It defaults to "Standard_DS1_v2".')
param parWindowsVmSize string = 'Standard_DS1_v2'

@description('The publisher of the Windows Virtual Machine to Azure Bastion remote into. It defaults to "MicrosoftWindowsServer".')
param parWindowsVmPublisher string = 'MicrosoftWindowsServer'

@description('The offer of the Windows Virtual Machine to Azure Bastion remote into. It defaults to "WindowsServer".')
param parWindowsVmOffer string = 'WindowsServer'

@description('The SKU of the Windows Virtual Machine to Azure Bastion remote into. It defaults to "2019-datacenter".')
param parWindowsVmSku string = '2019-datacenter'

@description('The version of the Windows Virtual Machine to Azure Bastion remote into. It defaults to "latest".')
param parWindowsVmVersion string = 'latest'

@description('The disk creation option of the Windows Virtual Machine to Azure Bastion remote into. It defaults to "FromImage".')
param parWindowsVmCreateOption string = 'FromImage'

@description('The storage account type of the Windows Virtual Machine to Azure Bastion remote into. It defaults to "StandardSSD_LRS".')
param parWindowsVmStorageAccountType string = 'StandardSSD_LRS'

@allowed([
  'Static'
  'Dynamic'
])
@description('[Static/Dynamic] The public IP Address allocation method for the Windows virtual machine. It defaults to "Dynamic".')
param parWindowsNetworkInterfacePrivateIPAddressAllocationMethod string = 'Dynamic'

param parLogAnalyticsWorkspaceId string

/*
  NAMING CONVENTION
  Here we define a naming conventions for resources.
  First, we take `parDeployEnvironment` and `parDeployEnvironment` by params.
  Then, using string interpolation "${}", we insert those values into a naming convention.
*/

var varResourceToken = 'resource_token'
var varNameToken = 'name_token'
var varNamingConvention = '${toLower(parOrgPrefix)}-${toLower(parLocation)}-${toLower(parDeployEnvironment)}-${varNameToken}-${toLower(varResourceToken)}'

// RESOURCE NAME CONVENTIONS WITH ABBREVIATIONS

var varBastionHostNamingConvention = replace(varNamingConvention, varResourceToken, 'bas')
var varPublicIpAddressNamingConvention = replace(varNamingConvention, varResourceToken, 'pip')
var varIpConfigurationNamingConvention = replace(varNamingConvention, varResourceToken, 'ipconf')
var varNetworkInterfaceNamingConvention = replace(varNamingConvention, varResourceToken, 'nic')

// BASTION NAMES

var varBastionHostName = replace(varBastionHostNamingConvention, varNameToken, 'hub')
var varBastionHostPublicIPAddressName = replace(varPublicIpAddressNamingConvention, varNameToken, 'bas')
var varLinuxNetworkInterfaceName = replace(varNetworkInterfaceNamingConvention, varNameToken, 'bas-linux')
var varLinuxNetworkInterfaceIpConfigurationName = replace(varIpConfigurationNamingConvention, varNameToken, 'bas-linux')
var varWindowsNetworkInterfaceName = replace(varNetworkInterfaceNamingConvention, varNameToken, 'bas-windows')
var varWindowsNetworkInterfaceIpConfigurationName = replace(varIpConfigurationNamingConvention, varNameToken, 'bas-windows')

// BASTION VALUES

var varBastionHostPublicIPAddressSkuName = 'Standard'
var varBastionHostPublicIPAddressAllocationMethod = 'Static'

@description('Resource group tags')
module modTags '../../../azresources/Modules/Microsoft.Resources/tags/az.resources.tags.bicep' = if (empty(parTags)) {
  name: 'deploy-ra-tags--${parLocation}-${parDeploymentNameSuffix}'
  scope: subscription()
  params: {
    tags: parTags
  }
}

resource resHubVirtualNetwork 'Microsoft.Network/virtualNetworks@2021-02-01' existing = {
  name: parHubVirtualNetworkName
}

resource resBastionSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' = {
  name: '${parHubVirtualNetworkName}/AzureBastionSubnet'

  properties: {
    addressPrefix: parBastionHostSubnetAddressPrefix
  }
}

module modBastionHost '../../../azresources/Modules/Microsoft.Network/bastionHost/az.net.bastion.host.bicep' = {
  name: 'deploy-ra-bastionHost-${parLocation}-${parDeploymentNameSuffix}'
  params: {
    // Required parameters
    name: varBastionHostName
    location: parLocation
    tags: (empty(parTags)) ? modTags : parTags
    vNetId: resHubVirtualNetwork.id

    // Non-required parameters
    isCreateDefaultPublicIP: true
    publicIPAddressObject: {
      diagnosticLogCategoriesToEnable: [
        'DDoSMitigationFlowLogs'
        'DDoSMitigationReports'
        'DDoSProtectionNotifications'
      ]
      diagnosticMetricsToEnable: [
        'AllMetrics'
      ]
      name: varBastionHostPublicIPAddressName
      publicIPAllocationMethod: varBastionHostPublicIPAddressAllocationMethod     
      skuName: varBastionHostPublicIPAddressSkuName
      skuTier: 'Regional'
    }
    skuType: parBastionHostSku    
  }
  dependsOn: [
    resBastionSubnet
  ]
}

module modLinuxNetworkInterface '../../../azresources/Modules/Microsoft.Network/networkInterfaces/az.net.network.interface.bicep' = if (parEnableLinux) {
  name: 'deploy-ra-linux-net-interface-${parLocation}-${parDeploymentNameSuffix}'
  params: {
    name: varLinuxNetworkInterfaceName
    location: parLocation
    tags: (empty(parTags)) ? modTags : parTags
    networkSecurityGroupResourceId: parHubNetworkSecurityGroupResourceId
    ipConfigurations: [
      {
        name: varLinuxNetworkInterfaceIpConfigurationName
        subnetResourceId: parHubSubnetResourceId
        privateIPAllocationMethod: parLinuxNetworkInterfacePrivateIPAddressAllocationMethod
      }
    ]
  }
}

module modLinuxVirtualMachine '../../../azresources/Modules/Microsoft.Compute/virtualmachines/az.com.virtual.machine.bicep' = if (parEnableLinux) {
  name: 'deploy-ra-linux-vm-${parLocation}-${parDeploymentNameSuffix}'
  params: {
    name: parLinuxVmName
    location: parLocation
    tags: (empty(parTags)) ? modTags : parTags

    disablePasswordAuthentication: parDisableLinuxVmPasswordAuthentication
    adminUsername: parLinuxVmAdminUsername    
    adminPassword: parLinuxVmAdminPasswordOrKey

    diagnosticWorkspaceId: parLogAnalyticsWorkspaceId
    availabilitySetResourceId:modAvSet.outputs.resourceId
    encryptionAtHost: parEncryptionAtHost
    imageReference: {
      offer: parLinuxVmImageOffer
      publisher: parLinuxVmImagePublisher
      sku: parLinuxVmImageSku
      version: parLinuxVmImageVersion
    }
    nicConfigurations: [
      {
        ipConfigurations: [
          {
            name: 'linux-ipconfig01'
            subnetResourceId: parHubSubnetResourceId
          }
        ]
        nicSuffix: '-nic-01'
        enableAcceleratedNetworking: false
      }
    ]
    osDisk: {
      diskSizeGB: '128'
      createOption: parLinuxVmOsDiskCreateOption
      managedDisk: {
        storageAccountType: parLinuxVmOsDiskType
      }
    }
    osType: 'Linux'
    vmSize: parLinuxVmSize
  }
}

module modWindowsNetworkInterface '../../../azresources/Modules/Microsoft.Network/networkInterfaces/az.net.network.interface.bicep' = if (parEnableWindows) {
  name: 'deploy-ra-win-net-interface-${parLocation}-${parDeploymentNameSuffix}'
  params: {
    name: varWindowsNetworkInterfaceName
    location: parLocation
    tags: (empty(parTags)) ? modTags : parTags

    networkSecurityGroupResourceId: parHubNetworkSecurityGroupResourceId
    ipConfigurations: [
      {
        name: varWindowsNetworkInterfaceIpConfigurationName
        subnetResourceId: parHubSubnetResourceId
        privateIPAllocationMethod: parWindowsNetworkInterfacePrivateIPAddressAllocationMethod
      }
    ]

  }
}

module modAvSet '../../../azresources/Modules/Microsoft.Compute/availabilitySets/az.com.availabilty.set.bicep' = {
  name: 'deploy-ra-win-avset-${parLocation}-${parDeploymentNameSuffix}'
  params: {
    name: '${parWindowsVmName}-avset'
    location: parLocation
    availabilitySetSku: 'Aligned'
  }
}

module windowsVirtualMachine '../../../azresources/Modules/Microsoft.Compute/virtualmachines/az.com.virtual.machine.bicep' = if (parEnableWindows) {
  name: 'deploy-ra-windows-vm-${parLocation}-${parDeploymentNameSuffix}'
  params: {
    name: parWindowsVmName
    location: parLocation
    tags: (empty(parTags)) ? modTags : parTags

    adminUsername: parWindowsVmAdminUsername
    adminPassword: parWindowsVmAdminPassword //kv.getSecret('WindowsVmAdminPassword')
    diagnosticWorkspaceId: parLogAnalyticsWorkspaceId
    availabilitySetResourceId:modAvSet.outputs.resourceId
    encryptionAtHost: parEncryptionAtHost
    imageReference: {
      offer: parWindowsVmOffer
      publisher: parWindowsVmPublisher
      sku: parWindowsVmSku
      version: parWindowsVmVersion
    }
    nicConfigurations: [
      {
        ipConfigurations: [
          {
            name: 'win-ipconfig01'
            subnetResourceId: parHubSubnetResourceId
          }
        ]
        nicSuffix: '-nic-01'
      }
    ]
    osDisk: {
      diskSizeGB: '128'
      createOption: parWindowsVmCreateOption
      managedDisk: {
        storageAccountType: parWindowsVmStorageAccountType
      }
    }
    osType: 'Windows'
    vmSize: parWindowsVmSize
  }
}

output linuxVMName string = modLinuxVirtualMachine.outputs.name
