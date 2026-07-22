module Notifications
  # F4 — resolves the configured live WhatsApp provider from the environment, or
  # nil when none is set (so the channel records `skipped` rather than sending).
  # Adding another vendor (Twilio/Meta) is a new branch here.
  module WhatsappProvider
    module_function

    def configured
      case ENV["WHATSAPP_PROVIDER"].to_s.strip.downcase
      when "msg91" then msg91
      end
    end

    def msg91
      authkey = ENV["MSG91_AUTHKEY"]
      number = ENV["MSG91_WHATSAPP_NUMBER"]
      template = ENV["MSG91_WHATSAPP_TEMPLATE"]
      return nil if authkey.blank? || number.blank? || template.blank?

      Msg91WhatsappClient.new(
        authkey: authkey, integrated_number: number, template: template,
        namespace: ENV["MSG91_WHATSAPP_NAMESPACE"], language: ENV["MSG91_WHATSAPP_LANG"],
        country_code: ENV["MSG91_WHATSAPP_COUNTRY_CODE"]
      )
    end
  end
end
