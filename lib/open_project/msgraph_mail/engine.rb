# frozen_string_literal: true

#-- copyright
# OpenProject MS Graph Mail Module
# Copyright (C) 2025 Jan Hübener / DATAGROUP
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#++

require "open_project/plugins"

module OpenProject
  module MsgraphMail
    class Engine < ::Rails::Engine
      engine_name :openproject_msgraph_mail

      include OpenProject::Plugins::ActsAsOpEngine

      register "openproject-msgraph_mail",
               bundled: true,
               author_url: "https://github.com/AdaWorldAPI/openproject" do
        # Add menu item under "Emails and notifications"
        menu :admin_menu,
             :msgraph_mail_settings,
             { controller: "/msgraph_mail/settings", action: :show },
             parent: :mail_and_notifications,
             after: :mail_notifications,
             caption: :"msgraph_mail.menu_title",
             if: ->(_) { User.current.admin? }
      end

      # Register the delivery method with ActionMailer
      initializer "msgraph_mail.register_delivery_method" do
        ActiveSupport.on_load(:action_mailer) do
          ActionMailer::Base.add_delivery_method(:msgraph, OpenProject::MsgraphMail::DeliveryMethod)
        end
      end

      # Configure from environment variables
      initializer "msgraph_mail.configure", after: "openproject.configuration" do
        OpenProject::MsgraphMail.configure do |config|
          config.tenant_id = ENV.fetch("MSGRAPH_TENANT_ID", nil)
          config.client_id = ENV.fetch("MSGRAPH_CLIENT_ID", nil)
          config.client_secret = ENV.fetch("MSGRAPH_CLIENT_SECRET", nil)
          config.sender_email = ENV.fetch("MSGRAPH_SENDER_EMAIL", nil)
          config.sender_name = ENV.fetch("MSGRAPH_SENDER_NAME", "OpenProject")
          config.save_to_sent_items = ENV.fetch("MSGRAPH_SAVE_TO_SENT_ITEMS", "true") == "true"
        end
      rescue StandardError => e
        Rails.logger.warn "MS Graph Mail: Could not load configuration: #{e.message}"
      end

      # Auto-configure mailer if EMAIL_DELIVERY_METHOD=msgraph is set
      initializer "msgraph_mail.auto_configure", after: "msgraph_mail.configure" do
        next unless ENV["EMAIL_DELIVERY_METHOD"] == "msgraph"
        next unless OpenProject::MsgraphMail.configuration.valid?

        Rails.application.config.after_initialize do
          ActionMailer::Base.delivery_method = :msgraph
          ActionMailer::Base.msgraph_settings = OpenProject::MsgraphMail.configuration.to_h
          Rails.logger.info "MS Graph Mail: Auto-configured as delivery method via EMAIL_DELIVERY_METHOD env"
        end
      end

      # Extend Setting class to handle msgraph delivery method
      config.to_prepare do
        Setting.singleton_class.prepend(OpenProject::MsgraphMail::MailSettingsExtension)
      end
    end

    # Extension to handle msgraph delivery method in Setting::MailSettings
    module MailSettingsExtension
      def reload_mailer_settings!
        super

        return unless Setting.email_delivery_method == :msgraph

        Rails.logger.info "MS Graph Mail: Configuring msgraph delivery method"

        ActionMailer::Base.delivery_method = :msgraph
        ActionMailer::Base.msgraph_settings = OpenProject::MsgraphMail.configuration.to_h
      end
    end
  end
end
