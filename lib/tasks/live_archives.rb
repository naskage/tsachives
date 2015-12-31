# -*- coding: utf-8 -*-

require 'open-uri'
require 'nokogiri'
require 'logger'

logger = Logger.new(STDOUT)
logger.level = Logger::DEBUG

puts "\"id\",\"date\",\"user\",\"title\",\"desc\",\"url\""
for i in 1..67
  charset = nil 
  url = "http://com.nicovideo.jp/live_archives/co2422599?page=#{i}&bias=0"
  html = open(url) do |f|
    charset = f.charset
    f.read
  end

  doc = Nokogiri::HTML.parse(html, nil, charset)
  records = doc.xpath('//table[@class="live_history"]//tr') #("//table[@class='live_history']/tbody/tr")
  records.shift
  records.each do |r| 
    date_str = r.css('td.date').text.strip.gsub(/開演：/, ' ')
    date = DateTime.parse(date_str)
    user = r.css('td.user').text.strip
    title = r.css('td.title').css('div').css('a')[0].text
    url = r.css('td.title').css('div').css('a')[0].attribute('href').value
    live_id = url.match(/lv(\d+)/)[1]
    
    desc = r.css('td.desc').text.strip
    
    puts "\"#{live_id}\",\"#{date}\",\"#{user}\",\"#{title}\",\"#{desc}\",\"#{url}\""
    
  end
end





