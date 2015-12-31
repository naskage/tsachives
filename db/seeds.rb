
require 'csv'
require 'date'

reader = CSV.open('db/seeds/live_programs.csv', 'r')
reader.shift

data_array = []

reader.each do |row|
  data_array.unshift(LiveProgram.new(:live_id => row[0], :started_at => DateTime.parse(row[1]), :user => row[2], :title => row[3], :desc => row[4], :url => row[5], :dl_status => "downloaded"))
end

data_array.reverse

data_array.each do |d|
  d.save
end
