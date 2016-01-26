# Be sure to restart your server when you modify this file

# Uncomment below to force Rails into production mode when
# you don't control web/app server and can't set it the proper way
# ENV['RAILS_ENV'] ||= 'production'

# Specifies gem version of Rails to use when vendor/rails is not present
RAILS_GEM_VERSION = '2.3.4' unless defined? RAILS_GEM_VERSION

# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')
require File.join([RAILS_ROOT, 'vendor', 'libs', 'ruby-uuid', 'uuid'])

if Gem::VERSION >= "1.3.6"
  module Rails
    class GemDependency
      def requirement
        r = super
        (r == Gem::Requirement.default) ? nil : r
      end
    end
  end
end

Rails::Initializer.run do |config|
  # Settings in config/environments/* take precedence over those specified here.
  # Application configuration should go into files in config/initializers
  # -- all .rb files in that directory are automatically loaded.
  # See Rails::Configuration for more options.

  # Skip frameworks you're not going to use (only works if using vendor/rails).
  # To use Rails without a database, you must remove the Active Record framework
  # config.frameworks -= [ :active_record, :active_resource, :action_mailer ]

  # Only load the plugins named here, in the order given. By default, all plugins
  # in vendor/plugins are loaded in alphabetical order.
  # :all can be used as a placeholder for all plugins not explicitly named
  # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

  # Add additional load paths for your own custom dirs
  # config.load_paths += %W( #{RAILS_ROOT}/extras )

  # Force all environments to use the same logger level
  # (by default production uses :info, the others :debug)
  # config.log_level = :debug

  # Your secret key for verifying cookie session data integrity.
  # If you change this key, all old sessions will become invalid!
  # Make sure the secret is at least 30 characters and all random,
  # no regular words or you'll be exposed to dictionary attacks.
  config.action_controller.session = {
    :session_key => '_gni_session',
    :secret      => '0d4586e4b250c1dd1926097a57ef3a3ef8c142ca6552c8a5704128338be295dc38617de2bd3bc3b55e57e4fa58f3be3553dbbf74b630de1a44042488a5dae927'
  }

  # Use the database for sessions instead of the cookie-based default,
  # which shouldn't be used to store highly confidential information
  # (create the session table with 'rake db:sessions:create')
  # config.action_controller.session_store = :active_record_store

  # Use SQL instead of Active Record's schema dumper when creating the test database.
  # This is necessary if your schema can't be completely dumped by the schema dumper,
  # like if you have constraints or database-specific column types
  config.active_record.schema_format = :sql

  # Activate observers that should always be running
  # config.active_record.observers = :cacher, :garbage_collector

  # Make Active Record use UTC-base instead of local time
  config.active_record.default_timezone = :utc

  #config.gem 'hpricot'
  # config.gem 'nokogiri'
  # config.gem 'haml'
  # config.gem 'will_paginate', :version => '>= 2.3.2', :lib => 'will_paginate'
  # config.gem 'json'
  # config.gem "rspec", :lib => false, :version => ">= 1.2.0"
  # config.gem "rspec-rails", :lib => false, :version => ">= 1.2.0"
  # config.gem "newrelic_rpm"
  #
  # config.gem 'biodiversity', :version => '>= 0.5.16', :lib => 'biodiversity'
  # config.gem 'taxamatch_rb', :lib => 'taxamatch_rb', :version => '>= 0.6.4'
  config.gem 'sass' # to shut up a warning


end

unless defined? ENV_CONSTANTS_ARE_DEFINED
  ENV_CONSTANTS_ARE_DEFINED = true
  APP_VERSION = "N/A" #version info is changed to deployment tag by capistrano script
  SCHEMA_VERSION = "0.1"
  PER_PAGE_MAX = 1000
  PROGRAM_NAME = "Global Names Index"
  GOOGLE_ANALYTICS = ''
  NOREPLY_EMAIL = "noreply@example.org"
  FEEDBACK_EMAIL = 'customer_service@example.com'
  LSID_PREFIX = "urn:lsid:globalnames.org:index:"
  GNA_NAMESPACE = UUID.create_v5("globalnames.org", UUID::NameSpace_DNS)
end

#load GNI namespace
require 'gni'
