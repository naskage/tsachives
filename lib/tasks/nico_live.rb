# -*- coding: utf-8 -*-

require 'net/http'
require 'nokogiri'
require 'logger'
require 'active_support/core_ext'
require 'player_status'

OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

class NicoLive

  attr_reader :player_ticket, :rtmp_url, :que
 
  def initialize(loglevel = Logger::INFO)
    @log = Logger.new(STDOUT)
    @log.level = loglevel
  end

  def login
    url = "https://secure.nicovideo.jp/secure/login?site=nicolive"
    params = {
      "next_url" => "",
      "mail" => ENV['NICO_EMAIL'],
      "password" => ENV['NICO_PASSWORD']
    } 
    response = Net::HTTP.post_form(URI.parse(url), params)
    @user_session = get_user_session(response)
  end
  
  def get_player_status(live_id)
    hash = get_player_status_hash(live_id)
    
    if hash['status'] != 'fail'
      PlayerStatus.new(hash)
    else
      @log.error "could not get status. live_id: #{live_id}"
      nil
    end
  end

  def get_player_status_with_login(live_id)
    unless login
      @log.error " login failed. live_id: #{live_id}"
      nil
    end

    get_player_status(live_id)
  end
  
  private
  
  def get_player_status_hash(live_id)
    url = "http://live.nicovideo.jp/api/getplayerstatus?v=lv#{live_id}"
    parsed_uri = URI.parse(url)
    response = Net::HTTP.start(parsed_uri.host, parsed_uri.port) { |http|
      http.get url, { 'Cookie' => "user_session=#{@user_session}"}
    }

    @log.debug "get_player_status_hash, live_id: #{live_id}, response.body: #{response.body}"

    status = Hash.from_xml(response.body)['getplayerstatus']
  end

  def get_user_session(response)
    #set-cookieには複数のcookieが設定されている。
    #user_sessionがdeletedでない最初のcookieを探す。
    user_session = nil
    response.get_fields('set-cookie').each {|cookie|
      cookie.split('; ').each {|param|
        pair = param.split('=')
        if pair[0] == 'user_session' then
          user_session = pair[1] if pair[1] != 'deleted'
          break
        end
      }
      break unless user_session.nil?
    }
    return user_session
  end

end
