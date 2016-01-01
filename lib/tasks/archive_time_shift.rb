# -*- coding: utf-8 -*-

require 'open-uri'
require 'nokogiri'
require 'logger'
require 'optparse'
require 'nico_live'

class Tasks::ArchiveTimeShift

  PAGE_LIMIT_FOR_CHECK = 10

  @@log = Logger.new(STDOUT)
  @@log.level = Logger::DEBUG
  
  def self.execute

    option = {}
    OptionParser.new do |opt|
      opt.on('--test', 'rtmpdump および ffmpeg を実行せず，コマンドを echo する') { |v| option[:test] = v }
      opt.parse!(ARGV)
    end

    if option[:test]
      @@test_echo = "echo "
    end
    
    @@log.info 'Tasks::ArchiveTimeShift'
    @@log.info '----------------------------------------'
     
    @@log.info 'updating live archives...'
    #self.update_live_archives
    
    @@log.info 'listing up player status to download...'
    list = self.listup_player_status_to_dl

    unless list
      @@log.error "listing up player status to download ... failed."
      return
    end

    @@log.info 'downloading...'
    self.download(list)

    @@log.info 'converting...'
    self.convert
    
    @@log.info '----------------------------------------'

    # todo
    # rtmpdump 分離
    # statusカラム 更新
    # ffmpegコマンド実行
    # aws s3 コマンド実行
     
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
          dl_status = r.css('td.title').css('div') .css('a')[1] ? LiveProgram::Status::REGISTERED : LiveProgram::Status::UNAVAILABLE
          
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

  def self.listup_player_status_to_dl
    download_list = []
    
    targets = LiveProgram.where(dl_status: LiveProgram::Status::REGISTERED).pluck(:live_id)

    @@log.debug "listed targets: #{targets}, length: #{targets.length}"

    if targets.length == 0
      return
    end

    live = NicoLive.new
    unless live.login
      @@log.error "login failed."
      return
    end

    targets.each do |t|
      download_list << live.get_player_status(t)
      LiveProgram.where(live_id: t).take.update(dl_status: LiveProgram::Status::QUEUED)
    end

    download_list
  end

  def self.download(target_list)
    target_list.each do |target|
      rtmp_url      = target.rtmp_url
      player_ticket = target.player_ticket
      queues        = target.queues
      dir           = "video/downloaded"
      file_name     = "lv#{target.live_id}_#{target.title}"
      ext           = ".flv"
      options       = "-V"

      next unless self.is_ready_for_download?(target.live_id)
      LiveProgram.where(live_id: target.live_id).first.update(dl_status: LiveProgram::Status::DOWNLOADING)

      failed = false
      for i in 0..(queues.length-1) do
        que = queues[i]
        file_path = dir + "/" + file_name
        file_path += ".#{i}" if queues.length >= 2 
        file_path += ext
        unless system("#{@@test_echo}rtmpdumpTS -vr \"#{rtmp_url}\" -C S:\"#{player_ticket}\" -N \"#{que}\" -o \"#{file_path}\" -v #{options}")
          @@log.error "rtmpdump failed. live_id: #{target.live_id}"
          failed = true
        end
      end

      unless failed
        LiveProgram.where(live_id: target.live_id).take.update(dl_status: LiveProgram::Status::DOWNLOADED)
      end
    end
  end

  public
  
  def self.convert
    src_dir = "video/downloaded"
    dst_dir = "video/mp4"
    
    ffmpeg_command = %(ffmpeg -y -i #{src_dir}/$file -vcodec libx264 -b 230k -ac 2 -ar 44100 -ab 128k #{dst_dir}/`echo $file | sed -e 's/\(.*\)\.[^.]*$/\1.flv/g'`)
    command = "for file in `ls video/downloaded`; do #{@@test_echo}#{ffmpeg_command}; done"
    
    system(command)
  end
  
  private

  def self.is_ready_for_download?(live_id)
    LiveProgram.where(live_id: live_id).take.dl_status == LiveProgram::Status::QUEUED
  end

  def self.is_ready_for_convert(live_id)
    LiveProgram.where(live_id: live_id).take.dl_status == LiveProgram::Status::DOWNLOADED
  end
   
end
