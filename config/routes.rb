# frozen_string_literal: true

#-- copyright
# OpenProject MS Graph Mail Module
# Copyright (C) 2025 Jan Hübener / DATAGROUP
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#++

OpenProject::Application.routes.draw do
  scope "admin" do
    namespace :msgraph_mail do
      resource :settings, only: [:show] do
        # For singular resources, use collection instead of member
        post :test_connection, on: :collection
        post :send_test_email, on: :collection
        post :activate, on: :collection
        post :deactivate, on: :collection
      end
    end
  end
end
