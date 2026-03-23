class ApplicationController < ActionController::Base
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :set_private_cache_headers

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def set_private_cache_headers
    response.set_header("Cache-Control", "private, no-store")
  end

  def set_public_cache_headers(max_age:, s_maxage: nil, stale_while_revalidate: nil, stale_if_error: nil, immutable: false)
    directives = ["public", "max-age=#{max_age}"]
    directives << "s-maxage=#{s_maxage}" if s_maxage
    directives << "stale-while-revalidate=#{stale_while_revalidate}" if stale_while_revalidate
    directives << "stale-if-error=#{stale_if_error}" if stale_if_error
    directives << "immutable" if immutable

    response.set_header("Cache-Control", directives.join(", "))
  end

  def user_not_authorized
    redirect_to root_path, alert: "You are not authorized to perform that action."
  end
end
