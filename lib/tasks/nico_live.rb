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
    @output_name = "output.flv"
  end

  def rtmp_command
    "rtmpdumpTS -vr \"#{@rtmp_url}\" -C S:\"#{player_ticket}\" -N \"#{que}\" -o \"#{output_name}\" -v -V"
  end
  
  def login
    @log.debug 'login...'

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
    PlayerStatus.new(hash)
  end
  
  private
  
  def get_player_status_hash(live_id)
    @log.debug 'get_player_status...'
     
    url = "http://live.nicovideo.jp/api/getplayerstatus?v=lv#{live_id}"
    parsed_uri = URI.parse(url)
    response = Net::HTTP.start(parsed_uri.host, parsed_uri.port) { |http|
      http.get url, { 'Cookie' => "user_session=#{@user_session}"}
    }

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
