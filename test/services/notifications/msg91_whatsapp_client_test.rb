require "test_helper"

module Notifications
  class Msg91WhatsappClientTest < ActiveSupport::TestCase
    def client(**overrides)
      Msg91WhatsappClient.new(
        **{ authkey: "K", integrated_number: "919000000000", template: "offer_generic",
            namespace: "ns1", language: "en", country_code: "91" }.merge(overrides)
      )
    end

    test "build_payload matches MSG91's template-send shape and formats the number" do
      payload = client.build_payload("9876543210", "20% off today")
      assert_equal "919000000000", payload[:integrated_number]
      assert_equal "template", payload[:content_type]
      template = payload.dig(:payload, :template)
      assert_equal "offer_generic", template[:name]
      assert_equal "ns1", template[:namespace]
      assert_equal "en", template.dig(:language, :code)
      row = template[:to_and_components].first
      assert_equal ["919876543210"], row[:to], "a bare 10-digit number gets the country code"
      assert_equal "20% off today", row.dig(:components, :body_1, :value)
    end

    test "an already-prefixed number is left as digits" do
      assert_equal "919876543210", client.format_number("+91 98765-43210")
    end

    test "deliver returns a sent outcome via the injected transport" do
      transport = ->(_payload) { Msg91WhatsappClient::Outcome.new(ok: true, provider_message_id: "req-1") }
      outcome = client(transport: transport).deliver(to: "9876543210", body: "hi")
      assert outcome.ok
      assert_equal "req-1", outcome.provider_message_id
    end

    test "a transport error surfaces as a failed outcome, never raising" do
      transport = ->(_payload) { raise "boom" }
      outcome = client(transport: transport).deliver(to: "9876543210", body: "hi")
      assert_not outcome.ok
      assert_equal "boom", outcome.error
    end
  end
end
