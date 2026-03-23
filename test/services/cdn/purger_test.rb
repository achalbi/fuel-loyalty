require "test_helper"

class Cdn::PurgerTest < ActiveSupport::TestCase
  Response = Struct.new(:code, :body)

  test "skips purge when cloudflare credentials are missing" do
    purger = Cdn::Purger.new(
      paths: ["/loyalty"],
      public_base_url: nil,
      zone_id: nil,
      api_token: nil,
      logger: Logger.new(nil)
    )

    assert_equal :skipped, purger.call
  end

  test "sends the public cache urls to cloudflare" do
    captured = {}
    response = Response.new("200", JSON.generate(success: true))
    http_singleton = Net::HTTP.singleton_class
    original_start = http_singleton.instance_method(:start)

    http_singleton.define_method(:start) do |host, port, use_ssl:, open_timeout:, read_timeout:, &block|
      captured[:host] = host
      captured[:port] = port
      captured[:use_ssl] = use_ssl
      captured[:open_timeout] = open_timeout
      captured[:read_timeout] = read_timeout

      http = Object.new
      http.define_singleton_method(:request) do |request|
        captured[:authorization] = request["Authorization"]
        captured[:content_type] = request["Content-Type"]
        captured[:body] = request.body
        response
      end

      block.call(http)
    end

    begin
      result = Cdn::Purger.new(
        paths: ["/loyalty", "/manifest.json", "/loyalty?source=pwa"],
        public_base_url: "https://fuel.example.com/",
        zone_id: "zone-123",
        api_token: "token-456",
        logger: Logger.new(nil)
      ).call

      assert_equal :ok, result
    ensure
      http_singleton.define_method(:start, original_start)
    end

    assert_equal "api.cloudflare.com", captured[:host]
    assert_equal 443, captured[:port]
    assert_equal true, captured[:use_ssl]
    assert_equal 5, captured[:open_timeout]
    assert_equal 10, captured[:read_timeout]
    assert_equal "Bearer token-456", captured[:authorization]
    assert_equal "application/json", captured[:content_type]
    assert_equal(
      {
        "files" => [
          "https://fuel.example.com/loyalty",
          "https://fuel.example.com/manifest.json",
          "https://fuel.example.com/loyalty?source=pwa"
        ]
      },
      JSON.parse(captured[:body])
    )
  end
end
