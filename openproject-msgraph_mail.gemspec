# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = "openproject-msgraph_mail"
  spec.version       = "1.0.0"
  spec.authors       = ["Jan Hübener"]
  spec.email         = ["jan.huebener@datagroup.de"]

  spec.summary       = "Microsoft Graph Mail delivery method for OpenProject"
  spec.description   = "Send emails via Microsoft Graph API instead of SMTP. Ideal for Microsoft 365 / Azure AD environments."
  spec.homepage      = "https://github.com/AdaWorldAPI/openproject-msgraph_mail"
  spec.license       = "GPL-3.0"

  spec.files         = Dir["{app,config,lib}/**/*", "README.md", "LICENSE"]
  spec.require_paths = ["lib"]

  spec.add_dependency "oauth2", "~> 2.0"
end
