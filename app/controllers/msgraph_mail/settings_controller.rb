# frozen_string_literal: true

#-- copyright
# OpenProject MS Graph Mail Module
# Copyright (C) 2025 Jan Hübener / DATAGROUP
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#++

module MsgraphMail
  class SettingsController < ApplicationController
    layout "admin"
    menu_item :msgraph_mail_settings

    before_action :require_admin

    def show
      @config = OpenProject::MsgraphMail.configuration
      @current_delivery_method = Setting.email_delivery_method
      @is_active = @current_delivery_method == :msgraph
    end

    def test_connection
      @config = OpenProject::MsgraphMail.configuration

      unless @config.valid?
        flash[:error] = I18n.t("msgraph_mail.settings.configuration_invalid")
        return redirect_to msgraph_mail_settings_path
      end

      begin
        service = MsgraphMail::TestConnectionService.new(@config)
        result = service.call

        if result.success?
          flash[:notice] = I18n.t("msgraph_mail.settings.test_connection_success")
        else
          flash[:error] = I18n.t("msgraph_mail.settings.test_connection_failed", error: result.error)
        end
      rescue StandardError => e
        flash[:error] = I18n.t("msgraph_mail.settings.test_connection_failed", error: e.message)
      end

      redirect_to msgraph_mail_settings_path
    end

    def send_test_email
      @config = OpenProject::MsgraphMail.configuration

      unless @config.valid?
        flash[:error] = I18n.t("msgraph_mail.settings.configuration_invalid")
        return redirect_to msgraph_mail_settings_path
      end

      begin
        # Temporarily configure msgraph for this test
        original_method = ActionMailer::Base.delivery_method
        original_settings = ActionMailer::Base.try(:msgraph_settings)

        ActionMailer::Base.delivery_method = :msgraph
        ActionMailer::Base.msgraph_settings = @config.to_h

        # Send test email to current admin user
        UserMailer.test_mail(User.current).deliver_now

        flash[:notice] = I18n.t("msgraph_mail.settings.test_email_sent", email: User.current.mail)
      rescue StandardError => e
        flash[:error] = I18n.t("msgraph_mail.settings.test_email_failed", error: e.message)
      ensure
        # Restore original settings
        ActionMailer::Base.delivery_method = original_method
        ActionMailer::Base.msgraph_settings = original_settings if original_settings
      end

      redirect_to msgraph_mail_settings_path
    end

    def activate
      @config = OpenProject::MsgraphMail.configuration

      unless @config.valid?
        flash[:error] = I18n.t("msgraph_mail.settings.cannot_activate_invalid")
        return redirect_to msgraph_mail_settings_path
      end

      begin
        # Set the delivery method to msgraph
        Setting.email_delivery_method = :msgraph

        # Configure ActionMailer
        ActionMailer::Base.delivery_method = :msgraph
        ActionMailer::Base.msgraph_settings = @config.to_h

        flash[:notice] = I18n.t("msgraph_mail.settings.activated")
      rescue StandardError => e
        flash[:error] = I18n.t("msgraph_mail.settings.activation_failed", error: e.message)
      end

      redirect_to msgraph_mail_settings_path
    end

    def deactivate
      begin
        # Reset to smtp (default)
        Setting.email_delivery_method = :smtp
        Setting.reload_mailer_settings!

        flash[:notice] = I18n.t("msgraph_mail.settings.deactivated")
      rescue StandardError => e
        flash[:error] = I18n.t("msgraph_mail.settings.deactivation_failed", error: e.message)
      end

      redirect_to msgraph_mail_settings_path
    end
  end
end
