# -*- coding: utf-8 -*-

require 'open-uri'
require 'nokogiri'
require 'logger'
require 'optparse'
require 'nico_live'

if RUBY_PLATFORM.downcase =~ /mswin(?!ce)|mingw|cygwin|bccwin/
  SEP = '\\'
else
  SEP = '/'
end


class Tasks::ArchiveTimeShift

  PAGE_LIMIT_FOR_CHECK = 10
  DOWNLOAD_DIR = "video" + SEP + "downloaded"
  FLV_DIR = "video" + SEP + "flv"
  MP4_DIR = "video" + SEP + "mp4"

  @@log = Logger.new(STDOUT)
  @@log.level = Logger::DEBUG
  
  def self.execute

    @@log.info 'Tasks::ArchiveTimeShift'
    @@log.info '----------------------------------------'
     
    @@log.info 'updating live archives...'
    self.update_live_archives
    
    @@log.info 'updating program list to download...'
    list = self.update_programs
    if list == nil
      @@log.error "listing up player status to download ... failed."
    elsif list.length == 0
      @@log.info "no time shift to download."
    else
      @@log.info 'enqueuing...'
      self.enqueue(list) if list.length > 0
    end
    
    @@log.info 'downloading...'
    self.download

    # @@log.info 'converting...'
    # self.convert

    @@log.info 'uploading...'
    self.upload
    
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

  def self.update_programs
     targets = LiveProgram.where(dl_status: LiveProgram::Status::REGISTERED).pluck(:live_id)

    @@log.debug "listed targets: #{targets}, length: #{targets.length}"

    if targets.length == 0
      return []
    end

    live = NicoLive.new
    unless live.login
      @@log.error "login failed."
      return
    end

    download_list = []
    targets.each do |t|
      status = live.get_player_status(t)
      download_list << status if status != nil
      LiveProgram.where(live_id: t).take.update(dl_status: LiveProgram::Status::QUEUED)
    end

    download_list
  end

  def self.enqueue(target_list)
    target_list.each do |target|
      divided = (2 <= target.queues.length)
      for i in 0..(target.queues.length - 1) do
        file_name = "lv#{target.live_id}_#{target.title}"
        file_name += ".#{i}" if divided
        file_name += ".flv"
        Job.create(
          live_id:       target.live_id,
          rtmp_url:      target.rtmp_url,
          player_ticket: target.player_ticket,
          divided:       divided,
          queue_no:      divided ? i : nil,
          queue:         target.queues[i],
          file_name:     file_name,
          status:        Job::Status::QUEUED
        )
      end
    end
  end

  def self.download
    list = Job.where(status: Job::Status::QUEUED)
    ids = list.ids
    list.update_all({status: Job::Status::DOWNLOADING})
    list = Job.find(ids)
    
    list.each do |job|
      command = "rtmpdumpTS" \
      " -vr \"#{job.rtmp_url}\"" \
      " -C S:\"#{job.player_ticket}\"" \
      " -N \"#{job.queue}\"" \
      " -o \"#{DOWNLOAD_DIR}#{SEP}#{job.file_name}\"" \
      " -v #{job.options}"
      command = "echo " + command + " > #{DOWNLOAD_DIR}#{SEP}#{job.file_name}"
      @@log.debug command
      succeeded = system(command)
      if succeeded
        job.update(status: Job::Status::DOWNLOADED)
      else
        job.update(status: Job::Status::DOWNLOAD_FAILED)
        @@log.error "rtmpdump failed. job id: #{job.id}, live_id: #{job.live_id}"
      end
    end
    
  end

  def self.convert
    
    ffmpeg_command = %(ffmpeg -y -i #{src_dir}#{SEP}$file -vcodec libx264 -b 230k -ac 2 -ar 44100 -ab 128k #{dst_dir}/`echo $file | sed -e 's/\(.*\)\.[^.]*$/\1.flv/g'`)
    command = "for file in `ls video#{SEP}downloaded`; do #{ffmpeg_command}; done"
    
    system(command)
  end

  def self.upload
    list = Job.where(status: Job::Status::DOWNLOADED)
    ids = list.ids
    list.update_all({status: Job::Status::UPLOADING})
    list = Job.find(ids)

    list.each do |job|
      command = "aws s3 mv" \
      " #{DOWNLOAD_DIR}#{SEP}#{job.file_name}" \
      " s3://naskage-tsarchives/flv/"
      command = "echo " + command
      succeeded = system(command)
      if succeeded
        job.update(status: Job::Status::UPLOADED)
      else
        job.update(status: Job::Status::UPLOAD_FAILED)
        @@log.error "upload to s3 failed. job id: #{job.id}, live_id: #{job.live_id}"
      end
    end
  end
  
  private

  def self.is_ready_for_download?(live_id)
    LiveProgram.where(live_id: live_id).take.dl_status == LiveProgram::Status::QUEUED
  end

  def self.is_ready_for_convert(live_id)
    LiveProgram.where(live_id: live_id).take.dl_status == LiveProgram::Status::DOWNLOADED
  end
   
end
