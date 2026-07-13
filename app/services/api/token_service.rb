module Api
  # Stateless JWT issuance/verification for the native-app /api/v1 layer.
  #
  # Two token types:
  #   access  — short-lived (30 min), carries the bearer identity for API calls.
  #   refresh — long-lived (30 days), exchanged for a fresh access token.
  #
  # Signing key is derived from secret_key_base (stable across restarts) unless
  # API_JWT_SECRET is set. Tokens are signed (HS256), NOT encrypted — do not put
  # secrets in the payload. Revocation is not modelled yet (see docs/native-handoff/12);
  # logout is client-side token discard. Password/role changes are honoured on the
  # next access-token expiry, and active/soft-delete is re-checked on every request.
  class TokenService
    ACCESS_TTL = 30.minutes
    REFRESH_TTL = 30.days
    ALGORITHM = "HS256".freeze

    class InvalidToken < StandardError; end

    class << self
      def issue_for(user)
        now = Time.current
        {
          access_token: encode_access(user, now:),
          refresh_token: encode_refresh(user, now:),
          token_type: "Bearer",
          expires_in: ACCESS_TTL.to_i,
        }
      end

      def encode_access(user, now: Time.current)
        encode(sub: user.id, role: user.role, type: "access",
               iat: now.to_i, exp: (now + ACCESS_TTL).to_i)
      end

      def encode_refresh(user, now: Time.current)
        encode(sub: user.id, type: "refresh",
               iat: now.to_i, exp: (now + REFRESH_TTL).to_i)
      end

      # Returns the User for a valid access token, or nil if the user is gone.
      # Raises InvalidToken for malformed/expired/wrong-type tokens.
      def user_from_access(token)
        user_from(token, expected_type: "access")
      end

      def user_from_refresh(token)
        user_from(token, expected_type: "refresh")
      end

      def decode(token, expected_type:)
        payload, = JWT.decode(token.to_s, secret, true, algorithm: ALGORITHM)
        unless payload["type"] == expected_type
          raise InvalidToken, "expected #{expected_type} token"
        end
        payload
      rescue JWT::DecodeError, JWT::ExpiredSignature => e
        raise InvalidToken, e.message
      end

      private

      def user_from(token, expected_type:)
        payload = decode(token, expected_type:)
        User.kept.find_by(id: payload["sub"])
      end

      def encode(**payload)
        JWT.encode(payload, secret, ALGORITHM)
      end

      def secret
        @secret ||= ENV["API_JWT_SECRET"].presence ||
          Rails.application.key_generator.generate_key("api/v1/jwt").unpack1("H*")
      end
    end
  end
end
