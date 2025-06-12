# lib/constraints/main_site_constraint.rb
class MainSiteConstraint
  def matches?(request)
    subdomain = extract_subdomain(request.host)

    puts "DEBUG MainSite: Host = #{request.host}"
    puts "DEBUG MainSite: Subdomain = #{subdomain}"

    # Main site has no subdomain or www subdomain
    result = subdomain.blank? || subdomain == 'www'
    puts "DEBUG MainSite: Matches = #{result}"
    result
  end

  private

  def extract_subdomain(host)
    parts = host.split('.')

    # For localhost development: demo.localhost -> 'demo'
    if host.include?('localhost')
      return parts.first if parts.length >= 2 && parts.first != 'localhost'
    end

    # For production: demo.photostudio.com -> 'demo'
    return parts.first if parts.length >= 3

    nil
  end
end
