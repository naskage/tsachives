# -*- coding: utf-8 -*-

require 'net/http'
require 'nokogiri'
require 'logger'
require 'active_support/core_ext'

OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

class NicoPlayerStatus

  attr_accessor :output_name
  attr_reader :player_ticket, :rtmp_url, :que
 
  def initialize(loglevel = Logger::INFO)
    @log = Logger.new(STDOUT)
    @log.level = loglevel
    @output_name = "output.flv"
  end

  def rtmp_command
    # "rtmpdump -vr \"#{@rtmp_url.sub(/\,\//, ',mp4:/').split('?')[0]}\" -C S:\"#{@player_ticket}\" -N \"#{que}\"-o #{@output_name} -v -V"
    # "rtmpdump -vr \"#{@rtmp_url}\" -C S:\"#{@player_ticket}\" -N \"#{que.sub(/\,\//, ',mp4:/')}\"-o #{@output_name} -v -V"
    "rtmpdumpTS -vr \"#{@rtmp_url}\" -C S:\"#{player_ticket}\" -N \"#{que}\" -o \"#{output_name}\" -v -V"
  end

  def cookie_container
    @log.debug 'cookie_container...'
    url = "https://secure.nicovideo.jp/secure/login?site=nicolive"

    params = {
      "next_url" => "",
      "mail" => ENV['NICO_EMAIL'],
      "password" => ENV['NICO_PASSWORD']
    } 
    
    response = Net::HTTP.post_form(URI.parse(url), params)

    @log.debug response.header
    @log.debug response.body
    
    @user_session = get_user_session(response)
    @log.debug "user_session: #{@user_session}"

  end 
  
  def login
    @log.debug 'login...'
    #url = "https://secure.nicovideo.jp/secure/login?site=nicolive_antenna"
    url = "https://secure.nicovideo.jp/secure/login?site=nicolive"

    params = {
      "next_url" => "",
      "mail" => ENV['NICO_EMAIL'],
      "password" => ENV['NICO_PASSWORD']
    } 
    

    response = Net::HTTP.post_form(URI.parse(url), params)

    @log.debug response.header
    @log.debug response.body

    @user_session = get_user_session(response)

    @log.debug "user_session: #{@user_session}"
    @log.debug "login succeeded."
    
    # case response
    # when Net::HTTPSuccess
    #   response
    # when Net::HTTPRedirection
    #   response = fetch(response['location'])
    # end

    # user_response = Nokogiri::XML.parse(response.body, nil, 'utf-8')
    # status = user_response.xpath('/nicovideo_user_response').attribute('status').value
    # if status != 'ok'
    #   @log.error 'login failed.'
    #   return
    #   #exit(1);
    # end

    # @ticket = user_response.xpath('//ticket').text

    # @log.debug "login succeeded."
    # @log.debug "ticket: " + @ticket
    
  end

  def alert_status
    @log.debug 'alert_status'

    url = "http://live.nicovideo.jp/api/getalertstatus?ticket=#{@ticket}" 
    response = Net::HTTP.get_response(URI.parse(url))

    @log.debug response.header
    @log.debug response.body

    get_alert_status = Nokogiri::XML.parse(response.body, nil, 'utf-8')
    status = get_alert_status.xpath('/getalertstatus').attribute('status').value
    if status != 'ok'
      @log.error 'could not get getalertstatus.'
      return
      #exit(1);
    end

    @addr = get_alert_status.xpath('//addr').text
    @port = get_alert_status.xpath('//port').text
    @thread = get_alert_status.xpath('//thread').text

    @log.debug "alert_status succeeded."
    @log.debug "addr: #{@addr}"
    @log.debug "port: #{@port}" 
    @log.debug "thread: #{@thread}"
    
  end

  def player_status(live_id)
    @log.debug 'player_status'
    
    url = "http://live.nicovideo.jp/api/getplayerstatus?v=lv#{live_id}"
    parsed_uri = URI.parse(url)
    response = Net::HTTP.start(parsed_uri.host, parsed_uri.port) { |http|
      http.get url, { 'Cookie' => "user_session=#{@user_session}"}
    }
    #response = Net::HTTP.get_response(URI.parse(url))

    @log.debug response.header
    @log.debug response.body

    status =  Hash.from_xml(response.body)['getplayerstatus']

    # if status['status'] != 'ok'
    #   @log.error 'could not get getplayerstatus.'
    #   return
    #   #exit(1);
    # end
    
    # player_status = Nokogiri::XML.parse(response.body, nil, 'utf-8')
#     status = player_status.xpath('/getplayerstatus').attribute('status').value
#     if status != 'ok'
#       @log.error 'could not get getplayerstatus.'
#       exit(1);
#     end

#     title = player_status.xpath('//stream/title').text
#     @output_name = "lv#{live_id}_#{title}.flv"

#     @rtmp_url = player_status.xpath('//rtmp/url').text
# #    @contents = player_status.xpath('//contents_list/contents').text
#     queues = player_status.xpath('//quesheet/que')
#     queues.each do |que|
#       arry = que.text.split(' ')
#       if arry[0] == '/publish'
#         @que = arry[2]
#         break
#       end
#    end
#    @player_ticket = player_status.xpath('//ticket').text

    @log.debug "player_status succeeded."
    # @log.debug "rtmp_url: #{status[rtmp][url]}"
    # @log.debug "que: #{@que}"
    # @log.debug "player_ticket: #{status[rtmp][ticket]}"
    
    status
  end
  
  def fetch(uri_str, limit = 10) 
    # You should choose better exception.
    raise ArgumentError, 'HTTP redirect too deep' if limit == 0
    
    response = Net::HTTP.get_response(URI.parse(uri_str))

    case response
    when Net::HTTPSuccess
      response
    when Net::HTTPRedirection
      fetch(response['location'], limit - 1)
    else
      response.value
    end
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

# status = NicoPlayerStatus.new(Logger::INFO)

# # login
# status.cookie_container
# status.login
# status.alert_status

# grandia = 246843477
# ikaruga = 247139683
# status.player_status(grandia)

# puts status.rtmp_command
