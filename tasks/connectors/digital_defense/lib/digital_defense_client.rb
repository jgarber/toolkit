# frozen_string_literal: true

module Kenna
  module Toolkit
    module DigitalDefense
      class Client
        class ApiError < StandardError; end

        attr_accessor :endpoint, :headers

        def initialize(host, api_token)
          @endpoint = "#{host}/api/"
          @headers = { "content-type": "application/json", "Authorization": "Token #{api_token}" }
        end

        def get_vulnerabilities(page: 1, count: 25)
          url = URI("https://#{endpoint}scanresults/active/vulnerabilities/")
          payload = { page: page, count: count }

          url.query = URI.encode_www_form(payload)
          response = http_get(url.to_s, headers)
          raise ApiError, "Unable to retrieve last scheduled scan, please check credentials" unless response

          JSON.parse(response)
        end

        def get_vulndictionary(page)
          url = URI("https://#{endpoint}vulndictionary")
          payload = { include_details: true, page: page, count: 5000 }

          url.query = URI.encode_www_form(payload)

          print_debug url.to_s
          response = http_get(url.to_s, headers)
          raise ApiError, "Unable to retrieve scan." unless response

          JSON.parse(response)
        end
      end
    end
  end
end
