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
        post :test_connection, on: :member
        post :send_test_email, on: :member
        post :activate, on: :member
        post :deactivate, on: :member
      end
    end
  end
end
