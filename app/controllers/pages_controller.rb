# Public, unauthenticated static pages (e.g. the privacy policy that the Google
# Play listing links to). Rendered without the app layout, so it needs no
# signed-in user context and is reachable by anyone (and by Play's crawler).
class PagesController < ApplicationController
  layout false
  skip_before_action :block_unsupported_browser, raise: false

  def privacy
    set_public_cache_headers(max_age: 1.hour.to_i, s_maxage: 1.day.to_i)
  end

  def delete_account
    set_public_cache_headers(max_age: 1.hour.to_i, s_maxage: 1.day.to_i)
  end
end
