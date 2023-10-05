provider "azuread" {

}

provider "azurerm" {
  features {

  }
}

resource "azurerm_resource_group" "example" {
  name     = "example-resources"
  location = "West Europe"

  tags = {
    cost-center = "placeholder"
    legal-unit  = "placeholder"
  }
}

#data "azurerm_resource_group" "example" {
#  name = azurerm_resource_group.example.name
#}

data "azuread_client_config" "current" {}

resource "azuread_application" "example" {
  display_name = "example"
  owners       = [data.azuread_client_config.current.object_id]
}

resource "azuread_application_password" "name" {
  display_name          = "example"
  application_object_id = azuread_application.example.object_id
}

resource "azuread_service_principal" "example" {
  application_id               = azuread_application.example.application_id
  app_role_assignment_required = false
  owners                       = [data.azuread_client_config.current.object_id]
}

resource "azurerm_kubernetes_cluster" "example" {
  name                = "example-aks1"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  dns_prefix          = "exampleaks1"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_D2_v2"
  }
  #service_principal {
  #  client_id     = azuread_application.example.application_id
  #  client_secret = azuread_application_password.name.value
  #}
  identity {
    type = "SystemAssigned"
  }
  tags = azurerm_resource_group.example.tags
}

resource "azurerm_kubernetes_cluster_extension" "example" {
  name              = "example-ext"
  cluster_id        = azurerm_kubernetes_cluster.example.id
  extension_type    = "microsoft.flux"
  release_train     = "Stable"
  release_namespace = "flux-system"

  configuration_settings = {
    "helm-controller.enabled" : "true"
    "source-controller.enabled" : "true"
    "kustomize-controller.enabled" : "true"
    "notification-controller.enabled" : "true"
    "image-automation-controller.enabled" : "true"
    "image-reflector-controller.enabled" : "true"
  }

  depends_on = [
    azurerm_kubernetes_cluster.example
  ]
}

resource "azurerm_kubernetes_flux_configuration" "example" {
  name       = "example-fc"
  cluster_id = azurerm_kubernetes_cluster.example.id
  namespace  = "flux-config"
  scope      = "cluster"

  kustomizations {
    name                     = azurerm_kubernetes_cluster.example.name
    path                     = "./"
    sync_interval_in_seconds = 60
    timeout_in_seconds       = 60
  }

  depends_on = [
    azurerm_kubernetes_cluster_extension.example
  ]

  git_repository {
    url                      = "https://github.com/Glembitskij/helm_reales"
    reference_type           = "branch"
    reference_value          = "main"
    sync_interval_in_seconds = 60
    timeout_in_seconds       = 60
  }
}
