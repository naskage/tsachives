# -*- coding: utf-8 -*-

require 'open-uri'
require 'nokogiri'
require 'logger'
require 'nico_player_status'

class Tasks::ArchiveTimeShift

  PAGE_LIMIT_FOR_CHECK = 10

  @@log = Logger.new(STDOUT)
  @@log.level = Logger::DEBUG
  
  def self.execute
    @@log.info 'Tasks::ArchiveTimeShift'
    @@log.info '----------------------------------------'
     
    @@log.info 'start update live archives.'
    #self.update_live_archives
    @@log.info 'end update live archives.'
    
    @@log.info '----------------------------------------'
    
    @@log.info 'start get player status'
    self.get_player_status
    @@log.info 'end get player status'
    
    @@log.info '----------------------------------------'
    
  end

  private

  Reading = Struct.new(:live_id, :started_at, :user, :title, :desc, :url, :dl_status)
  
  def self.update_live_archives

    readings = []
    
    catch(:fin_reading) do
    
      for i in 1..PAGE_LIMIT_FOR_CHECK
        charset = nil 
        url = "http://com.nicovideo.jp/live_archives/co2422599?page=#{i}&bias=0"
        html = open(url) do |f|
          charset = f.charset
          f.read
        end
        
        doc = Nokogiri::HTML.parse(html, nil, charset)
        records = doc.xpath('//table[@class="live_history"]//tr')
        records.shift
        records.each do |r| 
          date_str = r.css('td.date').text.strip.gsub(/開演：/, ' ')
          started_at = DateTime.parse(date_str)
          user = r.css('td.user').text.strip
          title = r.css('td.title').css('div').css('a')[0].text
          desc = r.css('td.desc').text.strip
          url = r.css('td.title').css('div').css('a')[0].attribute('href').value
          live_id = url.match(/lv(\d+)/)[1]
          dl_status = r.css('td.title').css('div') .css('a')[1] ? "registered" : "unavailable"
          
          if LiveProgram.exists?(:live_id => live_id)
            throw :fin_reading
          else
            readings.unshift(Reading.new(live_id, started_at, user, title, desc, url, dl_status))
          end
          
        end 
      end
      
    end #fin_reading

    readings.each do |r|
      LiveProgram.create(
        live_id:    r.live_id,
        started_at: r.started_at,
        user:       r.user,
        title:      r.title,
        desc:       r.desc,
        url:        r.url,
        dl_status:  r.dl_status)
    end
  end

  def self.get_player_status
    
    targets = LiveProgram.where(dl_status: "registered").pluck(:live_id)

    @@log.debug "targets: #{targets}, length: #{targets.length}"

    if targets.length == 0
      return
    end
    
    status = NicoPlayerStatus.new(Logger::INFO)
    status.cookie_container
    status.login

    targets.each do |t|
      @@log.info "  downloading lv#{t}"
      status.player_status(t)
      unless system("#{status.rtmp_command}")
        @@log.error "Rtmpdump failed. live_id: #{t}"
      end
    end
    
  end
  
end
