# frozen_string_literal: true

#-- copyright
# OpenProject MS Graph Mail Module
# Copyright (C) 2025 Jan Hübener / DATAGROUP
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#++

require "open_project/msgraph_mail/engine"
require "open_project/msgraph_mail/delivery_method"
require "open_project/msgraph_mail/token_manager"

module OpenProject
  module MsgraphMail
    class << self
      def configuration
        @configuration ||= Configuration.new
      end

      def configure
        yield(configuration) if block_given?
      end

      def reset_configuration!
        @configuration = Configuration.new
      end
    end

    class Configuration
      attr_accessor :tenant_id,
                    :client_id,
                    :client_secret,
                    :sender_email,
                    :sender_name,
                    :save_to_sent_items

      def initialize
        @tenant_id = ENV.fetch("MSGRAPH_TENANT_ID", nil)
        @client_id = ENV.fetch("MSGRAPH_CLIENT_ID", nil)
        @client_secret = ENV.fetch("MSGRAPH_CLIENT_SECRET", nil)
        @sender_email = ENV.fetch("MSGRAPH_SENDER_EMAIL", nil)
        @sender_name = ENV.fetch("MSGRAPH_SENDER_NAME", "OpenProject")
        @save_to_sent_items = ENV.fetch("MSGRAPH_SAVE_TO_SENT_ITEMS", "true") == "true"
      end

      def valid?
        [tenant_id, client_id, client_secret, sender_email].all?(&:present?)
      end

      def to_h
        {
          tenant_id: tenant_id,
          client_id: client_id,
          client_secret: client_secret,
          sender_email: sender_email,
          sender_name: sender_name,
          save_to_sent_items: save_to_sent_items
        }
      end
    end
  end
end
