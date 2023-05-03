# frozen_string_literal: true

require_relative 'lib/client'

module Kenna
  module Toolkit
    class CyleraTask < Kenna::Toolkit::BaseTask
      CVE_PREFIX = 'CVE'
      NO_SOLUTION_TEXT = 'No solution provided by vendor'
      SCANNER_TYPE = 'Cylera'
      SEVERITY_VALUES = {
        'Low' => 3,
        'Medium' => 6,
        'High' => 8,
        'Critical' => 10
      }.freeze

      def self.metadata
        {
          id: 'cylera',
          name: 'Cylera',
          description: 'Pulls assets and vulnerabilitiies from Cylera',
          options: [
            {
              name: 'cylera_api_host',
              type: 'hostname',
              required: true,
              default: nil,
              description: 'Cylera instance hostname, e.g. https://partner.us1.cylera.com'
            },
            {
              name: 'cylera_api_user',
              type: 'api_key',
              required: true,
              default: nil,
              description: 'Cylera API user email'
            },
            {
              name: 'cylera_api_password',
              type: 'api_key',
              required: true,
              default: nil,
              description: 'Cylera API user password'
            },
            {
              name: 'cylera_severity',
              type: 'string',
              required: false,
              default: nil,
              description: 'Vulnerability severity. One of [LOW, MEDIUM, HIGH, CRITICAL]'
            },
            {
              name: 'cylera_status',
              type: 'string',
              required: false,
              default: nil,
              description: 'Vulnerability status. One of [OPEN, IN_PROGRESS, RESOLVED, SUPPRESSED]'
            },
            {
              name: 'cylera_name',
              type: 'string',
              required: false,
              default: nil,
              description: 'Name of the vulnerability (complete or partial)'
            },
            {
              name: 'cylera_mac_address',
              type: 'string',
              required: false,
              default: nil,
              description: 'MAC address of device'
            },
            { name: 'batch_size',
              type: 'integer',
              required: false,
              default: 100,
              description: 'Maximum number of vulnerabilities to retrieve in batches' },
            {
              name: 'kenna_api_key',
              type: 'api_key',
              required: false,
              default: nil,
              description: 'Kenna API Key'
            },
            {
              name: 'kenna_api_host',
              type: 'hostname',
              required: false,
              default: 'api.kennasecurity.com',
              description: 'Kenna API Hostname'
            },
            {
              name: 'kenna_connector_id',
              type: 'integer',
              required: false,
              default: nil,
              description: 'If set, we\'ll try to upload to this connector'
            },
            {
              name: 'output_directory',
              type: 'filename',
              required: false,
              default: 'output/cylera',
              description: "If set, will write a file upon completion. Path is relative to #{$basedir}"
            }
          ]
        }
      end

      def run(opts)
        super

        initialize_options

        client = Kenna::Toolkit::Cylera::Client.new(@api_host, @api_user, @api_password)

        risk_vulnerabilities = client.get_risk_vulnerabilities(@risk_vulnerabilities_params)
        risk_mitigations = {}
        pages = risk_vulnerabilities['total'] / @options[:batch_size]

        pages.times do |page|
          risk_vulnerabilities = client.get_risk_vulnerabilities(@risk_vulnerabilities_params.merge(page: page)) unless page.zero?

          risk_vulnerabilities['vulnerabilities'].each do |vulnerability|
            risk_mitigations[vulnerability['vulnerability_name']] ||= client.get_risk_mitigations(vulnerability['vulnerability_name'])['mitigations']

            asset = extract_asset(vulnerability)
            vuln = extract_vuln(vulnerability)
            vuln_def = extract_vuln_def(vulnerability, risk_mitigations[vulnerability['vulnerability_name']])

            create_kdi_asset_vuln(asset, vuln)
            create_kdi_vuln_def(vuln_def)
          end

          kdi_upload(@output_directory, "cylera_#{risk_vulnerabilities['page']}.json", @kenna_connector_id, @kenna_api_host, @kenna_api_key, @skip_autoclose, @retries, @kdi_version)
        end

        kdi_connector_kickoff(@kenna_connector_id, @kenna_api_host, @kenna_api_key)
      rescue Kenna::Toolkit::Cylera::Client::ApiError => e
        fail_task e.message
      end

      private

      def initialize_options
        @api_host = @options[:cylera_api_host]
        @api_user = @options[:cylera_api_user]
        @api_password = @options[:cylera_api_password]
        @risk_vulnerabilities_params = {
          severity: @options[:cylera_severity],
          status: @options[:cylera_status],
          name: @options[:cylera_name],
          mac_address: @options[:cylera_mac_address],
          page_size: @options[:batch_size]
        }
        @output_directory = @options[:output_directory]
        @kenna_api_host = @options[:kenna_api_host]
        @kenna_api_key = @options[:kenna_api_key]
        @kenna_connector_id = @options[:kenna_connector_id]
        @skip_autoclose = false
        @retries = 3
        @kdi_version = 2
      end

      def extract_asset(vulnerability)
        {
          'ip_address' => vulnerability['ip_address'],
          'mac_address' => vulnerability['mac_address'],
          'tags' => tags(vulnerability)
        }.compact
      end

      def extract_vuln(vulnerability)
        {
          'scanner_identifier' => vulnerability['vulnerability_name'],
          'scanner_type' => SCANNER_TYPE,
          'scanner_score' => SEVERITY_VALUES[vulnerability['severity']],
          'created_at' => Time.at(vulnerability['first_seen']),
          'last_seen_at' => Time.at(vulnerability['last_seen']),
          'status' => vulnerability['status'],
          'vuln_def_name' => vulnerability['vulnerability_name']
        }.compact
      end

      def extract_vuln_def(vulnerability, mitigations)
        {
          'scanner_type' => SCANNER_TYPE,
          'cve_identifiers' => cve_id(vulnerability['vulnerability_name']),
          'name' => vulnerability['vulnerability_name'],
          'solution' => remove_html_tags(solution(mitigations))
        }.compact
      end

      def tags(vulnerability)
        tags = []
        tags.push("Vendor:#{vulnerability['vendor']}") if vulnerability['vendor']
        tags.push("Type:#{vulnerability['type']}") if vulnerability['type']
        tags.push("Model:#{vulnerability['model']}") if vulnerability['model']
        tags.push("Class:#{vulnerability['class']}") if vulnerability['class']
        tags
      end

      def cve_id(vulnerability_name)
        vulnerability_name if vulnerability_name.start_with?(CVE_PREFIX)
      end

      def solution(mitigations)
        return NO_SOLUTION_TEXT if mitigations.empty?

        mitigations.map do |mitigation|
          "#{mitigation['name']} - #{mitigation['items'].pluck('description').join('; ')}"
        end.join("\n")
      end
    end
  end
end
