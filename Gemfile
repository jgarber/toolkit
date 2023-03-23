# frozen_string_literal: true

source "https://rubygems.org"

ruby ">= 3.0.0"
# git_source(:github) do |repo_name|
#  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?("/")
#  "https://github.com/#{repo_name}.git"
# end

# Only required for file upload types (Guardium and Qualys to Kenna Direct), comment out if unneeded:
# gem 'nokogiri'

gem "activesupport"
gem "addressable"
gem "aws-sdk-guardduty"
gem "aws-sdk-inspector"
gem "httparty"
gem "ipaddress"
gem "rest-client"
gem "rexml", ">= 3.2.5"
gem "sanitize"
gem "tty-pager"
gem "ruby-limiter"

group :development, :test do
  gem "pry"
  gem "pry-byebug"
  gem "rspec"
  gem "rubocop", require: false
  gem "solargraph", require: false
  gem "timecop"
end
