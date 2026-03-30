class VehiclePlateText
  STANDARD_REGEX = /\A[A-Z]{2}[0-9]{1,2}[A-Z]{0,3}[0-9]{1,4}\z/
  BH_REGEX = /\A[0-9]{2}BH[0-9]{4}[A-Z]{2}\z/
  MAX_SAFE_OCR_REPLACEMENTS = 3

  LETTER_SUBSTITUTIONS = {
    "0" => "O",
    "1" => "I",
    "2" => "Z",
    "5" => "S",
    "6" => "G",
    "8" => "B"
  }.freeze

  DIGIT_SUBSTITUTIONS = {
    "O" => "0",
    "Q" => "0",
    "D" => "0",
    "I" => "1",
    "L" => "1",
    "T" => "1",
    "Z" => "2",
    "S" => "5",
    "B" => "8",
    "G" => "6"
  }.freeze

  class << self
    def normalize(value)
      value.to_s.upcase.gsub(/[^A-Z0-9]/, "")
    end

    def valid?(value)
      candidate = normalize(value)
      candidate.match?(STANDARD_REGEX) || candidate.match?(BH_REGEX)
    end

    def normalize_detected(value)
      candidate = normalize(value)
      return candidate if candidate.blank? || valid?(candidate)

      detected_candidate(candidate) || candidate
    end

    private

    def detected_candidate(candidate)
      standard_candidate(candidate) || bh_candidate(candidate)
    end

    def standard_candidate(candidate)
      return unless candidate.length.between?(4, 11)

      best_candidate = nil

      (1..2).each do |district_length|
        (0..3).each do |series_length|
          number_length = candidate.length - 2 - district_length - series_length
          next unless number_length.between?(1, 4)

          state = normalize_alpha_segment(candidate[0, 2])
          district = normalize_digit_segment(candidate[2, district_length])
          series = normalize_alpha_segment(candidate[2 + district_length, series_length])
          number = normalize_digit_segment(candidate[-number_length, number_length])
          normalized_candidate = "#{state}#{district}#{series}#{number}"
          next unless normalized_candidate.match?(STANDARD_REGEX)

          replacements = replacement_count(candidate, normalized_candidate)
          best_candidate = [replacements, normalized_candidate] if best_candidate.blank? || replacements < best_candidate.first
        end
      end

      return unless best_candidate.present?
      return if best_candidate.first > MAX_SAFE_OCR_REPLACEMENTS

      best_candidate.last
    end

    def bh_candidate(candidate)
      return unless candidate.length == 10

      normalized_candidate = [
        normalize_digit_segment(candidate[0, 2]),
        normalize_alpha_segment(candidate[2, 2]),
        normalize_digit_segment(candidate[4, 4]),
        normalize_alpha_segment(candidate[8, 2])
      ].join

      return unless normalized_candidate.match?(BH_REGEX)
      return unless normalized_candidate[2, 2] == "BH"
      return if replacement_count(candidate, normalized_candidate) > MAX_SAFE_OCR_REPLACEMENTS

      normalized_candidate
    end

    def normalize_alpha_segment(value)
      value.to_s.each_char.map { |character| LETTER_SUBSTITUTIONS.fetch(character, character) }.join
    end

    def normalize_digit_segment(value)
      value.to_s.each_char.map { |character| DIGIT_SUBSTITUTIONS.fetch(character, character) }.join
    end

    def replacement_count(original, candidate)
      original.each_char.zip(candidate.each_char).count { |left, right| left != right }
    end
  end
end
