require "json"
require "net/http"
require "uri"

module Cdn
  class Purger
    PUBLIC_CACHE_PATHS = [
      "/loyalty",
      "/loyalty?source=pwa",
      "/manifest.json"
    ].freeze

    def self.call(paths: PUBLIC_CACHE_PATHS)
      new(paths: paths).call
    end

    def initialize(paths:, public_base_url: ENV["PUBLIC_BASE_URL"], zone_id: ENV["CLOUDFLARE_ZONE_ID"], api_token: ENV["CLOUDFLARE_API_TOKEN"], logger: Rails.logger)
      @paths = Array(paths)
      @public_base_url = public_base_url
      @zone_id = zone_id
      @api_token = api_token
      @logger = logger
    end

    def call
      return :skipped unless configured?
      return :skipped if files.empty?

      response = perform_request
      return :ok if successful_response?(response)

      logger&.warn("Cloudflare purge failed (#{response.code}): #{response.body}")
      :failed
    rescue StandardError => error
      logger&.warn("Cloudflare purge error: #{error.class}: #{error.message}")
      :failed
    end

    private

    attr_reader :api_token, :logger, :paths, :public_base_url, :zone_id

    def configured?
      public_base_url.present? && zone_id.present? && api_token.present?
    end

    def files
      @files ||= paths.filter_map do |path|
        normalized_path = path.to_s.strip
        next if normalized_path.empty?

        normalized_path = "/#{normalized_path}" unless normalized_path.start_with?("/")
        "#{public_base_url.to_s.sub(%r{/*\z}, "")}#{normalized_path}"
      end.uniq
    end

    def perform_request
      uri = URI("https://api.cloudflare.com/client/v4/zones/#{zone_id}/purge_cache")
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{api_token}"
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(files: files)

      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) do |http|
        http.request(request)
      end
    end

    def successful_response?(response)
      return false unless response.code.to_i.between?(200, 299)

      body = JSON.parse(response.body)
      body["success"] == true
    rescue JSON::ParserError
      false
    end
  end
end
