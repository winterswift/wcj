
VERSIONS[__FILE__] = "$Id: spell_controller.rb 871 2007-03-14 12:42:47Z alex $"

require 'net/https'
require 'uri'

class SpellController < ApplicationController
  def check
    @lang = params['lang'] || 'en'
    @errors = request.raw_post
    url = URI.parse('https://www.google.com/tbproxy/spell')
    http = Net::HTTP.new(url.host, 443)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    response = http.request_post("#{url.path}?lang=" + @lang, @errors)
    render :xml => response.body
  end
end
