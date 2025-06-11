class MainSiteConstraint
  def matches?(request)
    subdomain = request.subdomains.first

    # Main site has no subdomain or www subdomain
    subdomain.blank? || subdomain == 'www'
  end
end
