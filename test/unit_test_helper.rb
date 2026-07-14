# frozen_string_literal: true

# Lightweight harness for pure-Ruby units — services with no database, fixtures,
# or request cycle (e.g. VehiclePlateText). It boots the app so autoloading and
# ActiveSupport core extensions (blank?/present?) are available, but deliberately
# does NOT require "rails/test_help": that pulls in "rails/testing/maintain_test_schema",
# which calls ActiveRecord::Migration.maintain_test_schema! at load time and opens a
# database connection. Booting the environment stays lazy about the DB (same as
# `bin/rails runner`), so these tests run anywhere — CI, a bare checkout, no Postgres,
# no Docker Compose `db` host.
#
# Tests that need the database, fixtures, or the request stack must still
# require "test_helper" instead.
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"

require "active_support/test_case"
require "active_support/testing/autorun"
