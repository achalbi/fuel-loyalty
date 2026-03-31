require "test_helper"

class VehiclePlateRecognizerTest < ActiveSupport::TestCase
  Response = Struct.new(:code, :body)

  test "reports unavailable when api token is missing" do
    assert_equal false, VehiclePlateRecognizer.available?(api_token: nil)
  end

  test "sends the image to plate recognizer and normalizes the best plate" do
    captured = {}
    response = Response.new(
      "200",
      JSON.generate(
        results: [
          {
            plate: "tn01aa1234",
            score: 0.91,
            candidates: [
              { plate: "tn01aa1234", score: 0.91 },
              { plate: "tn01ab1234", score: 0.43 }
            ]
          }
        ]
      )
    )

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
        captured[:accept] = request["Accept"]
        captured[:content_type] = request.content_type
        body_data = request.instance_variable_get(:@body_data)
        upload = body_data.find { |entry| entry.first == "upload" }
        captured[:upload_filename] = upload.dig(2, :filename)
        captured[:upload_content_type] = upload.dig(2, :content_type)
        captured[:upload_data] = upload[1].read
        upload[1].rewind if upload[1].respond_to?(:rewind)
        captured[:region] = body_data.find { |entry| entry.first == "regions" }&.last
        response
      end

      block.call(http)
    end

    begin
      result = VehiclePlateRecognizer.call(
        image_data: "data:image/jpeg;base64,ZmFrZQ==",
        api_token: "token-123",
        endpoint: "https://api.platerecognizer.com/v1/plate-reader/",
        region: "in",
        logger: Logger.new(nil)
      )
    ensure
      http_singleton.define_method(:start, original_start)
    end

    assert_equal true, result.found
    assert_equal "TN01AA1234", result.plate
    assert_equal "TN01AA1234", result.raw
    assert_equal 91, result.confidence
    assert_equal true, result.valid
    assert_equal false, result.corrected
    assert_equal "plate_recognizer", result.provider
    assert_equal "api.platerecognizer.com", captured[:host]
    assert_equal 443, captured[:port]
    assert_equal true, captured[:use_ssl]
    assert_equal 5, captured[:open_timeout]
    assert_equal 20, captured[:read_timeout]
    assert_equal "Token token-123", captured[:authorization]
    assert_equal "application/json", captured[:accept]
    assert_match(/multipart\/form-data/, captured[:content_type])
    assert_equal "plate-scan.jpg", captured[:upload_filename]
    assert_equal "image/jpeg", captured[:upload_content_type]
    assert_equal "fake", captured[:upload_data]
    assert_equal "in", captured[:region]
  end
end
