# frozen_string_literal: true

#-- copyright
# OpenProject MS Graph Mail Module
# Copyright (C) 2025 Jan Hübener / DATAGROUP
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#++

require "json"
require "net/http"

module OpenProject
  module MsgraphMail
    # Manages OAuth2 client credentials flow for MS Graph API
    # Thread-safe token caching with automatic refresh
    class TokenManager
      TOKEN_URL = "https://login.microsoftonline.com/%<tenant_id>s/oauth2/v2.0/token"
      GRAPH_SCOPE = "https://graph.microsoft.com/.default"

      # Buffer before expiry to ensure token is refreshed ahead of time
      EXPIRY_BUFFER_SECONDS = 300

      class TokenError < StandardError; end

      def initialize(tenant_id:, client_id:, client_secret:)
        @tenant_id = tenant_id
        @client_id = client_id
        @client_secret = client_secret
        # Use ::Mutex to explicitly reference Ruby's built-in Mutex class
        # (OpenProject has a module called OpenProject::Mutex which shadows it)
        @mutex = ::Mutex.new
        @cached_token = nil
        @token_expires_at = nil
      end

      # Get a valid access token, refreshing if necessary
      # @return [String] Access token
      def access_token
        @mutex.synchronize do
          if @cached_token && !token_expired?
            Rails.logger.debug { "MS Graph Mail: Using cached token" }
            return @cached_token
          end

          Rails.logger.info "MS Graph Mail: Fetching new access token"
          fetch_token
          @cached_token
        end
      end

      def clear_cache!
        @mutex.synchronize do
          @cached_token = nil
          @token_expires_at = nil
        end
      end

      private

      def token_expired?
        return true unless @token_expires_at

        Time.now.to_i >= (@token_expires_at - EXPIRY_BUFFER_SECONDS)
      end

      def fetch_token
        validate_config!

        uri = URI(format(TOKEN_URL, tenant_id: @tenant_id))

        request = Net::HTTP::Post.new(uri)
        request["Content-Type"] = "application/x-www-form-urlencoded"
        request.body = URI.encode_www_form(
          client_id: @client_id,
          client_secret: @client_secret,
          scope: GRAPH_SCOPE,
          grant_type: "client_credentials"
        )

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
          http.open_timeout = 10
          http.read_timeout = 30
          http.request(request)
        end

        handle_token_response(response)
      rescue StandardError => e
        raise TokenError, "Failed to obtain access token: #{e.message}"
      end

      def validate_config!
        missing = []
        missing << "tenant_id" if @tenant_id.blank?
        missing << "client_id" if @client_id.blank?
        missing << "client_secret" if @client_secret.blank?

        raise TokenError, "Missing configuration: #{missing.join(', ')}" if missing.any?
      end

      def handle_token_response(response)
        body = JSON.parse(response.body)

        unless response.is_a?(Net::HTTPSuccess)
          error = body["error_description"] || body["error"] || "Unknown error"
          raise TokenError, "Token request failed: #{error}"
        end

        @cached_token = body["access_token"]
        @token_expires_at = Time.now.to_i + body["expires_in"].to_i
      end
    end
  end
end
