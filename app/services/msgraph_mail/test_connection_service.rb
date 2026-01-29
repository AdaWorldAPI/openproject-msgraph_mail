# frozen_string_literal: true

#-- copyright
# OpenProject MS Graph Mail Module
# Copyright (C) 2025 Jan Hübener / DATAGROUP
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#++

module MsgraphMail
  class TestConnectionService
    Result = Struct.new(:success?, :error, keyword_init: true)

    def initialize(config)
      @config = config
    end

    def call
      token_manager = OpenProject::MsgraphMail::TokenManager.new(
        tenant_id: @config.tenant_id,
        client_id: @config.client_id,
        client_secret: @config.client_secret
      )

      # Try to get a token - this validates credentials
      token = token_manager.access_token

      if token.present?
        Result.new(success?: true)
      else
        Result.new(success?: false, error: "Failed to obtain access token")
      end
    rescue StandardError => e
      Result.new(success?: false, error: e.message)
    end
  end
end
