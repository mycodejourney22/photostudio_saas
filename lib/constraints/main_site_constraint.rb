# lib/constraints/main_site_constraint.rb
class MainSiteConstraint
  def matches?(request)
    subdomain = extract_subdomain(request.host)

    puts "DEBUG MainSite: Host = #{request.host}"
    puts "DEBUG MainSite: Subdomain = #{subdomain}"

    # Main site conditions:
    # 1. No subdomain (localhost:3000, photostudio.com)
    # 2. www subdomain (www.photostudio.com)
    # 3. Direct Heroku app domain (shuttersuites-638880348a66.herokuapp.com)

    result = subdomain.blank? ||
             subdomain == 'www' ||
             is_main_heroku_domain?(request.host)

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

    # For Heroku: demo.shuttersuites-638880348a66.herokuapp.com -> 'demo'
    # But if it's the main app domain, return nil
    if host.include?('herokuapp.com')
      if is_main_heroku_domain?(host)
        return nil  # This is the main domain, no subdomain
      else
        return parts.first if parts.length >= 2
      end
    end

    # For production: demo.photostudio.com -> 'demo'
    return parts.first if parts.length >= 3

    nil
  end

  def is_main_heroku_domain?(host)
    # Check if this is the main Heroku app domain (no subdomain)
    host.match?(/^[a-z0-9-]+\.herokuapp\.com$/) &&
    !host.match?(/^[^.]+\.[a-z0-9-]+\.herokuapp\.com$/)
  end
end
