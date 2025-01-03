data "azurerm_resource_group" "rg" {
  name = "troypersonal-karaokfree"
}

module "karaokfree" {
  source = "../modules/karaokfree/v1"

  tenant_id                     = "11e4ca61-3247-4bf8-9569-503b774800ee"
  resource_group_name           = data.azurerm_resource_group.rg.name
  location                      = data.azurerm_resource_group.rg.location
  web_app_name                  = "troypersonal-karaokfree-webapp"
  web_application_insights_name = "troypersonal-karaokfree-webai"
}
