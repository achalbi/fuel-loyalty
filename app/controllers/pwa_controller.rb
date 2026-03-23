class PwaController < ApplicationController
  layout false
  skip_forgery_protection only: :service_worker

  def manifest
    @theme_setting = ThemeSetting.current

    set_public_cache_headers(max_age: 300, s_maxage: 300, stale_while_revalidate: 30)
    response.set_header("Content-Type", "application/manifest+json")
  end

  def service_worker
    @cache_version = ENV.fetch("RELEASE_SHA", Rails.application.config.assets.version)

    response.set_header("Cache-Control", "no-cache")
    response.set_header("Service-Worker-Allowed", "/")
  end
end
