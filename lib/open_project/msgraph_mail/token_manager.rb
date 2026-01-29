# frozen_string_literal: true

#-- copyright
# OpenProject MS Graph Mail Module
# Copyright (C) 2025 Jan Hübener / DATAGROUP
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#++

require "oauth2"
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

      class << self
        def instance
          @instance ||= new
        end

        # Delegate methods to instance
        def access_token(config)
          instance.access_token(config)
        end

        def clear_cache!
          instance.clear_cache!
        end
      end

      def initialize
        @mutex = Mutex.new
        @tokens = {}
      end

      # Get a valid access token, refreshing if necessary
      # @param config [Configuration] MS Graph configuration
      # @return [String] Access token
      def access_token(config)
        cache_key = cache_key_for(config)

        @mutex.synchronize do
          cached = @tokens[cache_key]

          if cached && !token_expired?(cached)
            Rails.logger.debug { "MS Graph Mail: Using cached token" }
            return cached[:access_token]
          end

          Rails.logger.info "MS Graph Mail: Fetching new access token"
          token_data = fetch_token(config)
          @tokens[cache_key] = token_data
          token_data[:access_token]
        end
      end

      def clear_cache!
        @mutex.synchronize { @tokens.clear }
      end

      private

      def cache_key_for(config)
        "#{config.tenant_id}:#{config.client_id}"
      end

      def token_expired?(token_data)
        return true unless token_data[:expires_at]

        Time.now.to_i >= (token_data[:expires_at] - EXPIRY_BUFFER_SECONDS)
      end

      def fetch_token(config)
        validate_config!(config)

        uri = URI(format(TOKEN_URL, tenant_id: config.tenant_id))

        request = Net::HTTP::Post.new(uri)
        request["Content-Type"] = "application/x-www-form-urlencoded"
        request.body = URI.encode_www_form(
          client_id: config.client_id,
          client_secret: config.client_secret,
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

      def validate_config!(config)
        missing = []
        missing << "tenant_id" if config.tenant_id.blank?
        missing << "client_id" if config.client_id.blank?
        missing << "client_secret" if config.client_secret.blank?

        raise TokenError, "Missing configuration: #{missing.join(', ')}" if missing.any?
      end

      def handle_token_response(response)
        body = JSON.parse(response.body)

        unless response.is_a?(Net::HTTPSuccess)
          error = body["error_description"] || body["error"] || "Unknown error"
          raise TokenError, "Token request failed: #{error}"
        end

        {
          access_token: body["access_token"],
          expires_at: Time.now.to_i + body["expires_in"].to_i
        }
      end
    end
  end
end
