# frozen_string_literal: true

#-- copyright
# OpenProject MS Graph Mail Module
# Copyright (C) 2025 Jan Hübener / DATAGROUP
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#++

require "net/http"
require "json"
require "base64"

module OpenProject
  module MsgraphMail
    # ActionMailer delivery method for Microsoft Graph API
    # Implements the Rails delivery method interface
    #
    # Usage:
    #   ActionMailer::Base.add_delivery_method(:msgraph, OpenProject::MsgraphMail::DeliveryMethod)
    #   ActionMailer::Base.delivery_method = :msgraph
    #   ActionMailer::Base.msgraph_settings = { tenant_id: ..., client_id: ..., ... }
    #
    class DeliveryMethod
      GRAPH_SEND_MAIL_URL = "https://graph.microsoft.com/v1.0/users/%<sender>/sendMail"

      class DeliveryError < StandardError; end

      attr_accessor :settings

      def initialize(settings = {})
        @settings = settings
      end

      # Required method for ActionMailer delivery methods
      # @param mail [Mail::Message] The mail message to deliver
      def deliver!(mail)
        config = build_config
        validate_config!(config)

        access_token = TokenManager.access_token(config)
        payload = build_graph_payload(mail, config)

        send_via_graph(config.sender_email, access_token, payload)

        Rails.logger.info do
          "MS Graph Mail: Successfully sent email to #{mail.to&.join(', ')}"
        end
      rescue StandardError => e
        Rails.logger.error "MS Graph Mail: Delivery failed: #{e.message}"
        raise DeliveryError, "MS Graph delivery failed: #{e.message}"
      end

      private

      def build_config
        # Merge settings from ActionMailer with module configuration
        config = OpenProject::MsgraphMail.configuration.dup

        settings.each do |key, value|
          config.send(:"#{key}=", value) if config.respond_to?(:"#{key}=") && value.present?
        end

        config
      end

      def validate_config!(config)
        raise DeliveryError, "MS Graph Mail not configured" unless config.valid?
      end

      # Build the MS Graph sendMail API payload from a Mail::Message
      def build_graph_payload(mail, config)
        {
          message: {
            subject: mail.subject,
            body: build_body(mail),
            from: build_address(config.sender_email, config.sender_name),
            toRecipients: build_recipients(mail.to),
            ccRecipients: build_recipients(mail.cc),
            bccRecipients: build_recipients(mail.bcc),
            replyTo: build_recipients(mail.reply_to),
            attachments: build_attachments(mail)
          }.compact,
          saveToSentItems: config.save_to_sent_items
        }
      end

      def build_body(mail)
        if mail.html_part
          {
            contentType: "HTML",
            content: mail.html_part.body.decoded
          }
        elsif mail.text_part
          {
            contentType: "Text",
            content: mail.text_part.body.decoded
          }
        elsif mail.body.decoded.present?
          # Single-part message, try to detect content type
          content_type = mail.content_type&.include?("html") ? "HTML" : "Text"
          {
            contentType: content_type,
            content: mail.body.decoded
          }
        end
      end

      def build_address(email, name = nil)
        result = { emailAddress: { address: email } }
        result[:emailAddress][:name] = name if name.present?
        result
      end

      def build_recipients(addresses)
        return [] if addresses.blank?

        Array(addresses).map do |addr|
          # Handle both string addresses and Mail::Address objects
          if addr.respond_to?(:address)
            build_address(addr.address, addr.display_name)
          else
            build_address(addr.to_s)
          end
        end
      end

      def build_attachments(mail)
        return [] if mail.attachments.blank?

        mail.attachments.map do |attachment|
          {
            "@odata.type": "#microsoft.graph.fileAttachment",
            name: attachment.filename,
            contentType: attachment.mime_type,
            contentBytes: Base64.strict_encode64(attachment.body.decoded)
          }
        end
      end

      def send_via_graph(sender_email, access_token, payload)
        uri = URI(format(GRAPH_SEND_MAIL_URL, sender: ERB::Util.url_encode(sender_email)))

        request = Net::HTTP::Post.new(uri)
        request["Authorization"] = "Bearer #{access_token}"
        request["Content-Type"] = "application/json"
        request.body = payload.to_json

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
          http.open_timeout = 10
          http.read_timeout = 60
          http.request(request)
        end

        handle_response(response)
      end

      def handle_response(response)
        case response
        when Net::HTTPAccepted, Net::HTTPSuccess, Net::HTTPNoContent
          # Success - sendMail returns 202 Accepted
          true
        when Net::HTTPUnauthorized
          # Token might have expired, clear cache for retry
          TokenManager.clear_cache!
          raise DeliveryError, "Authentication failed: #{parse_error(response)}"
        when Net::HTTPForbidden
          raise DeliveryError, "Permission denied. Ensure Mail.Send permission is granted: #{parse_error(response)}"
        when Net::HTTPBadRequest
          raise DeliveryError, "Invalid request: #{parse_error(response)}"
        else
          raise DeliveryError, "Unexpected response #{response.code}: #{parse_error(response)}"
        end
      end

      def parse_error(response)
        body = JSON.parse(response.body) rescue {}
        error = body.dig("error", "message") || body["error_description"] || response.body
        error.to_s.truncate(500)
      end
    end
  end
end
