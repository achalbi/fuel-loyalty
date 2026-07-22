require "net/http"

module Notifications
  # F4 — live WhatsApp delivery via MSG91's WhatsApp Business API (template send).
  # Credentials + template come from the environment / Secret Manager; nothing
  # secret lives in the repo. WhatsApp requires a PRE-APPROVED template with a
  # single body variable — the notification text is passed as that variable.
  #
  # ENV: WHATSAPP_PROVIDER=msg91, MSG91_AUTHKEY, MSG91_WHATSAPP_NUMBER
  #      (the integrated number), MSG91_WHATSAPP_TEMPLATE, and optionally
  #      MSG91_WHATSAPP_NAMESPACE / MSG91_WHATSAPP_LANG (default "en") /
  #      MSG91_WHATSAPP_COUNTRY_CODE (default "91").
  class Msg91WhatsappClient
    ENDPOINT = "https://control.msg91.com/api/v5/whatsapp/whatsapp-outbound-message/bulk/".freeze
    Outcome = Struct.new(:ok, :provider_message_id, :error, keyword_init: true)

    def initialize(authkey:, integrated_number:, template:, namespace: nil, language: "en", country_code: "91", transport: nil)
      @authkey = authkey
      @integrated_number = integrated_number
      @template = template
      @namespace = namespace
      @language = language.presence || "en"
      @country_code = country_code.presence || "91"
      @transport = transport # injectable for tests; defaults to a real HTTP POST
    end

    # Send `body` to a single recipient phone. Returns an Outcome.
    def deliver(to:, body:)
      payload = build_payload(to, body)
      (@transport || method(:perform_post)).call(payload)
    rescue StandardError => error
      Outcome.new(ok: false, error: error.message)
    end

    # MSG91's template-send shape. Exposed so specs can assert it without a network call.
    def build_payload(to, body)
      template = { name: @template, language: { code: @language, policy: "deterministic" },
                   to_and_components: [{ to: [format_number(to)], components: { body_1: { type: "text", value: body.to_s } } }] }
      template[:namespace] = @namespace if @namespace.present?

      {
        integrated_number: @integrated_number,
        content_type: "template",
        payload: { messaging_product: "whatsapp", type: "template", template: template },
      }
    end

    # E.164-ish: digits only, prefixed with the country code when a bare 10-digit
    # national number is given.
    def format_number(phone)
      digits = phone.to_s.gsub(/\D/, "")
      digits.length == 10 ? "#{@country_code}#{digits}" : digits
    end

    private

    def perform_post(payload)
      uri = URI.parse(ENDPOINT)
      request = Net::HTTP::Post.new(uri)
      request["authkey"] = @authkey
      request["Content-Type"] = "application/json"
      request["accept"] = "application/json"
      request.body = payload.to_json

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 10) do |http|
        http.request(request)
      end

      if response.is_a?(Net::HTTPSuccess)
        parsed = parse(response.body)
        Outcome.new(ok: true, provider_message_id: parsed["request_id"] || parsed.dig("data", "request_id"))
      else
        parsed = parse(response.body)
        Outcome.new(ok: false, error: parsed["message"].presence || "MSG91 error #{response.code}")
      end
    end

    def parse(body)
      JSON.parse(body.to_s)
    rescue JSON::ParserError
      {}
    end
  end
end
