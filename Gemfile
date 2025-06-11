source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.3.5'

# Core Rails
gem 'rails', '~> 7.1.0'  # Latest Rails 7 works with Ruby 3.3.5
gem 'pg', '~> 1.1'
gem 'puma', '~> 6.0'
gem 'redis', '~> 5.0'

# Multi-tenancy (Column-based approach, simpler and more reliable)
gem 'acts_as_tenant', '~> 1.0'

# Authentication & Authorization
gem 'devise', '~> 4.9'
gem 'cancancan', '~> 3.5'

# API & Serialization
gem 'jsonapi-serializer', '~> 2.2'
gem 'rack-cors', '~> 2.0'
gem 'jbuilder', '~> 2.7'

# Background Jobs
gem 'sidekiq', '~> 7.2'

# File Uploads & Processing
gem 'image_processing', '~> 1.2'
gem 'aws-sdk-s3', '~> 1.0'

# Payments - Paystack
gem 'paystack', '~> 0.1.6'
gem 'httparty', '~> 0.21'
gem 'money-rails', '~> 1.15'

# UI & Frontend
gem 'importmap-rails', '~> 1.2'  # Modern Rails 7 approach
gem 'turbo-rails', '~> 1.5'
gem 'stimulus-rails', '~> 1.3'
gem 'tailwindcss-rails', '~> 2.0'

# Utilities
gem 'bootsnap', '>= 1.16.0', require: false
gem 'friendly_id', '~> 5.5'
gem 'kaminari', '~> 1.2'
gem 'validate_url', '~> 1.0'  # Using the more common gem

# Environment variables
gem 'dotenv-rails', '~> 2.8'

group :development, :test do
  gem 'debug', platforms: %i[ mri windows ]  # Ruby 3.3 compatible debugger
  gem 'rspec-rails', '~> 6.0'
  gem 'factory_bot_rails', '~> 6.4'
  gem 'faker', '~> 3.2'
  gem 'database_cleaner-active_record', '~> 2.1'
end

group :development do
  gem 'web-console'
  gem 'error_highlight', '>= 0.4.0', platforms: [:ruby]
end

group :test do
  gem 'capybara'
  gem 'selenium-webdriver'
  gem 'shoulda-matchers', '~> 5.0'
end

gem 'ostruct'  # Fix the Ruby 3.3.5 warning
gem 'sprockets-rails'  # Required for assets:precompile
gem 'cssbundling-rails'  # For CSS bundling
gem 'jsbundling-rails'
