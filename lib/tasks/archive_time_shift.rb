# -*- coding: utf-8 -*-

require 'open-uri'
require 'nokogiri'
require 'logger'
require 'optparse'
require 'open3'
require 'fileutils'
require 'parallel'
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
  UPLOAD_DIR_FLV = "video" + SEP + "upload" + SEP + "flv"
  UPLOAD_DIR_MP4 = "video" + SEP + "upload" + SEP + "mp4"

  @@log = Logger.new('log/batch.log')
  @@log.level = Logger::DEBUG
  
  def self.execute

    @@log.info '========================================'
    @@log.info 'Tasks::ArchiveTimeShift'
    @@log.info '----------------------------------------'
     
    @@log.info 'updating live archives...'
    self.fetch_live_archives

    @@log.info '----------------------------------------'
    @@log.info 'updating program list to download...'
    list = self.update_live_programs
    if list == nil
      @@log.error "listing up player status to download... failed."
    elsif list.length == 0
      @@log.info "no time shift to add."
    else
      @@log.info '----------------------------------------'
      @@log.info 'enqueuing...'
      self.enqueue(list) if list.length > 0
    end

    @@log.info '----------------------------------------'
    @@log.info 'downloading...'
    self.download

    @@log.info '----------------------------------------'
    @@log.info 'converting...'
    #self.convert

    @@log.info '----------------------------------------'
    @@log.info 'uploading...'
    self.upload

    @@log.info '----------------------------------------'
    @@log.info 'Task finished.'
    @@log.info '========================================'

  end

#  private

  Reading = Struct.new(:live_id, :started_at, :user, :title, :desc, :url, :dl_status)
    
  def self.fetch_live_archives

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

  def self.update_live_programs
    target_live_ids = LiveProgram.where(dl_status: [
        LiveProgram::Status::REGISTERED,
      ]).pluck(:live_id)

     @@log.info "candidates to download: #{target_live_ids}, length: #{target_live_ids.length}"

    return [] if target_live_ids.length == 0
    
    live = NicoLive.new
    unless live.login
      @@log.error "#{__LINE__}: login failed."
      []
    end
    
    download_list = []
    download_ids = []
    target_live_ids.each do |id|
      status = live.get_player_status(id)
      if status != nil && 1 <= status.queues.length
        download_list << status
        download_ids << id
        LiveProgram.where(live_id: id).take.update(dl_status: LiveProgram::Status::QUEUED)
      end
    end

    @@log.info "added download list: #{download_ids}"
    
    download_list
  end
  
  def self.enqueue(status_list)
    status_list.each do |status|
      job = Job.find_or_initialize_by(live_id: status.live_id)
      job.update({
          divided: (2 <= status.queues.length),
          division_num: (status.queues.length if 2 <= status.queues.length),
          status: Job::Status::QUEUED
        })
    end
  end
  
  def self.download
    list = Job.where(status: [Job::Status::QUEUED, Job::Status::DOWNLOAD_FAILED])
    ids = list.ids
    list.update_all({status: Job::Status::DOWNLOADING})
    
    ActiveRecord::Base.clear_active_connections!
    Parallel.each(Job.find(ids), in_threads: 16) do |job|
      @@log.debug "thread started. job.id: #{job.id}, live_id: #{job.live_id}"
      ActiveRecord::Base.connection_pool.with_connection do
        @@log.info "download job started. live_id: [#{job.live_id}]"
        
        # 1 ループの最後にtrueだったら成功
        job_completed = true
        
        status = NicoLive.new.get_player_status_with_login_thread_safe(job.live_id)
        job_completed = false unless status
        
        # 分割数分ループ
        for i in 0..(status.queues.length - 1) do
          # 分割なし: lv9999999_タイトル.flv
          # 分割あり: lv9999999_タイトル.0.flv, lv9999999_タイトル.1.flv, ...
          file_name = "lv#{status.live_id}_#{status.title}" + (2 <= status.queues.length ? ".#{i}.flv" : ".flv")
          
          command = "rtmpdumpTS" \
          " -vr \"#{status.rtmp_url}\"" \
          " -C S:\"#{status.player_ticket}\"" \
          " -N \"#{status.queues[i]}\"" \
          " -o \"#{DOWNLOAD_DIR}#{SEP}#{file_name}\""
          # command = "~/Developer/niconico/wine/bin/wine ~/Developer/niconico/rtmpdump/rtmpdumpTS "\
          command = "echo " + command + " > #{DOWNLOAD_DIR}#{SEP}#{file_name}" if DEBUG_ECHO
          
          # execute rtmpdump
          o, e, s = Open3.capture3(command)
          
          job_completed = false unless self.rtmp_succeeded?(e)
        end if status
        
        if job_completed
          # move downloaded flv files from downloaded/ to flv/
           for i in 0..(status.queues.length - 1) do
            file_name = "lv#{status.live_id}_#{status.title}" + (2 <= status.queues.length ? ".#{i}.flv" : ".flv")
            move_from = "#{DOWNLOAD_DIR}#{SEP}#{file_name}"
            move_to = "#{FLV_DIR}#{SEP}"
            FileUtils.mv(move_from, move_to)
          end
          
          # create upload task
          Upload.find_or_create_by(live_id: status.live_id,
            src: "#{FLV_DIR}#{SEP}#{file_name}",
            dst: "s3://naskage-tsarchives/flv/",
            status: Upload::Status::UPLOADING
          )
          
          # update status
          job.update(status: Job::Status::DOWNLOADED)
          LiveProgram.where(live_id: status.live_id).take.update(dl_status: Job::Status::DOWNLOADED)
        else          
          job.update(status: Job::Status::DOWNLOAD_FAILED)
          @@log.error "rtmpdump failed. job id: #{job.id}, live_id: #{job.live_id}.#{i}"
        end

      end
    end
  end
  
  def self.rtmp_succeeded?(stderr)
    last_line = stderr.split("\n").last
    
    progress = last_line.match(/(\d+\.\d+)%/) if last_line
    error = last_line.start_with?("ERROR:") if last_line
    
    @@log.debug "rtmp last_line: #{last_line}"
    
    succeeded = (error || (progress && progress[1].to_f < 99.0)) ? false : true
  end
  
  def self.convert
    list = Job.where(status: Job::Status::DOWNLOADED)
    ids = list.ids
    list.update_all({status: Job::Status::CONVERTING})
    
    Job.find(ids).each do |job|
      live = LiveProgram.where(live_id: job.live_id).take
      
      file_name_base = "lv#{live.live_id}_#{live.title}"
      
      command = "ffmpeg"
      if job.divided
        for i in 0..job.division_num do
          command += " -i #{FLV_DIR}#{SEP}#{file_name_base}.#{i}.flv"
        end
        command += " -filter_complex \"concat=n=#{job.division_num}:v=1:a=1\""
      else
        command += " -i #{FLV_DIR}#{SEP}#{file_name_base}.flv"
      end
      command += " -vcodec libx264 -b 230k -ac 2 -ar 44100 -ab 128k -y"
      command += " #{MP4_DIR}#{SEP}#{file_name_base}.mp4"
      
      @@log.debug command
      command = "touch #{MP4_DIR}#{SEP}#{file_name_base}.mp4" if DEBUG_ECHO
      succeeded = system(command)
      
      if succeeded
        job.update(status: Job::Status::CONVERTED)
        LiveProgram.where(live_id: job.live_id).take.update(dl_status: LiveProgram::Status::CONVERTED)
      else
        job.update(status: Job::Status::CONVERT_FAILED)
        @@log.error "convert failed. job: #{job.id}, live_id: #{job.live_id}"
      end
    end
  end
  
  def self.upload
    
    FileUtils.mkdir_p(UPLOAD_DIR_FLV)
    FileUtils.mkdir_p(UPLOAD_DIR_MP4)
      
    Job.where(status: Job::Status::CONVERTED).each do |job|
      live = LiveProgram.where(live_id: job.live_id).take

      file_name_base = "lv#{live.live_id}_#{live.title}"

      move_from = Dir.glob("#{MP4_DIR}#{SEP}#{file_name_base}*")
      move_to = "#{UPLOAD_DIR_MP4}#{SEP}"
      @@log.debug "move mp4 from: #{move_from} to: #{move_to}"
      FileUtils.mv(move_from, move_to)
      
      move_from = Dir.glob("#{FLV_DIR}#{SEP}#{file_name_base}*")
      move_to = "#{UPLOAD_DIR_FLV}#{SEP}"
      @@log.debug "move flv from: #{move_from} to: #{move_to}"
      FileUtils.mv(move_from, move_to)
    end
    
    succeeded = system("aws s3 mv #{UPLOAD_DIR_MP4} s3://naskage-tsarchives/mp4/ --exclude \"*\" --include \"*.mp4\" --recursive")
    @@log.error "upload(mp4) failed." unless succeeded
    
    succeeded = system("aws s3 mv #{UPLOAD_DIR_FLV} s3://naskage-tsarchives/flv/ --exclude \"*\" --include \"*.flv\" --recursive")
    @@log.error "upload(flv) failed." unless succeeded
  end
end
