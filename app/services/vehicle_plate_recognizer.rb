require "base64"
require "json"
require "net/http"
require "stringio"
require "uri"

class VehiclePlateRecognizer
  DEFAULT_ENDPOINT = "https://api.platerecognizer.com/v1/plate-reader/".freeze
  DEFAULT_REGION = "in".freeze
  OPEN_TIMEOUT_SECONDS = 5
  READ_TIMEOUT_SECONDS = 20

  Result = Struct.new(:found, :plate, :raw, :confidence, :valid, :corrected, :provider, :candidates, keyword_init: true) do
    def as_json(*)
      {
        found: found,
        plate: plate,
        raw: raw,
        confidence: confidence,
        valid: valid,
        corrected: corrected,
        provider: provider,
        candidates: candidates
      }
    end
  end

  class ConfigurationError < StandardError; end
  class RecognitionError < StandardError; end

  def self.available?(api_token: ENV["PLATE_RECOGNIZER_API_TOKEN"])
    api_token.present?
  end

  def self.call(image_data:, api_token: ENV["PLATE_RECOGNIZER_API_TOKEN"], endpoint: ENV["PLATE_RECOGNIZER_API_URL"].presence || DEFAULT_ENDPOINT, region: ENV["PLATE_RECOGNIZER_REGION"].presence || DEFAULT_REGION, logger: Rails.logger)
    new(image_data: image_data, api_token: api_token, endpoint: endpoint, region: region, logger: logger).call
  end

  def initialize(image_data:, api_token: ENV["PLATE_RECOGNIZER_API_TOKEN"], endpoint: ENV["PLATE_RECOGNIZER_API_URL"].presence || DEFAULT_ENDPOINT, region: ENV["PLATE_RECOGNIZER_REGION"].presence || DEFAULT_REGION, logger: Rails.logger)
    @image_data = image_data
    @api_token = api_token
    @endpoint = endpoint
    @region = region
    @logger = logger
  end

  def call
    raise ConfigurationError, "Plate recognition service is not configured." unless self.class.available?(api_token: api_token)
    raise RecognitionError, "Capture a plate image first." if encoded_image.blank?

    payload = JSON.parse(perform_request.body)
    build_result(payload)
  rescue JSON::ParserError => error
    raise RecognitionError, "Plate recognition returned an unreadable response: #{error.message}"
  rescue RecognitionError, ConfigurationError
    raise
  rescue StandardError => error
    logger&.warn("VehiclePlateRecognizer error: #{error.class}: #{error.message}")
    raise RecognitionError, "Plate recognition could not be completed right now."
  end

  private

  attr_reader :api_token, :endpoint, :image_data, :logger, :region

  def encoded_image
    @encoded_image ||= image_data.to_s.split(",", 2).last.to_s.strip
  end

  def decoded_image
    @decoded_image ||= Base64.strict_decode64(encoded_image)
  rescue ArgumentError => error
    raise RecognitionError, "The captured plate image could not be read: #{error.message}"
  end

  def upload_content_type
    @upload_content_type ||= image_data.to_s[/\Adata:([^;,]+)[;,]/, 1].presence || "image/jpeg"
  end

  def upload_filename
    @upload_filename ||= "plate-scan#{upload_extension}"
  end

  def upload_extension
    case upload_content_type
    when "image/png" then ".png"
    when "image/webp" then ".webp"
    else ".jpg"
    end
  end

  def perform_request
    uri = URI.parse(endpoint)
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Token #{api_token}"
    request["Accept"] = "application/json"
    request.set_form(
      [
        ["upload", StringIO.new(decoded_image), { filename: upload_filename, content_type: upload_content_type }],
        ["regions", region]
      ],
      "multipart/form-data"
    )

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: OPEN_TIMEOUT_SECONDS, read_timeout: READ_TIMEOUT_SECONDS) do |http|
      http.request(request)
    end

    return response if response.code.to_i.between?(200, 299)

    raise RecognitionError, error_message_for(response)
  end

  def build_result(payload)
    choices = candidate_choices(payload)
    best_choice = choices.max_by { |choice| [choice[:valid] ? 1 : 0, choice[:score], choice[:normalized].length] }

    return Result.new(found: false, provider: "plate_recognizer", candidates: []) if best_choice.blank?

    Result.new(
      found: true,
      plate: best_choice[:normalized],
      raw: Vehicle.normalize_vehicle_number(best_choice[:raw]),
      confidence: normalize_confidence(best_choice[:score]),
      valid: best_choice[:valid],
      corrected: best_choice[:corrected],
      provider: "plate_recognizer",
      candidates: choices.first(3).map do |choice|
        {
          plate: choice[:normalized],
          raw: Vehicle.normalize_vehicle_number(choice[:raw]),
          confidence: normalize_confidence(choice[:score]),
          valid: choice[:valid]
        }
      end
    )
  end

  def candidate_choices(payload)
    Array(payload["results"]).flat_map do |result|
      raw_candidates = [{ "plate" => result["plate"], "score" => result["score"] }] + Array(result["candidates"])

      raw_candidates.filter_map do |candidate|
        raw_plate = candidate["plate"].to_s
        next if raw_plate.blank?

        normalized_plate = Vehicle.normalize_detected_vehicle_number(raw_plate)

        {
          raw: raw_plate,
          normalized: normalized_plate,
          score: candidate["score"].to_f,
          valid: Vehicle.valid_vehicle_number?(normalized_plate),
          corrected: normalized_plate != Vehicle.normalize_vehicle_number(raw_plate)
        }
      end
    end.uniq { |choice| [choice[:normalized], choice[:raw]] }
  end

  def normalize_confidence(score)
    value = score.to_f
    value = value * 100 if value <= 1
    value.round
  end

  def error_message_for(response)
    parsed = JSON.parse(response.body)
    parsed["detail"].presence ||
      parsed["message"].presence ||
      parsed.dig("error", "message").presence ||
      "Plate recognition failed with status #{response.code}."
  rescue JSON::ParserError, TypeError
    "Plate recognition failed with status #{response.code}."
  end
end
