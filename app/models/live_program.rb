class LiveProgram < ActiveRecord::Base

  module Status
    UNAVAILABLE = "unavailable"
    REGISTERED  = "registered"
    QUEUED      = "queued"
    DOWNLOADING = "downloading"
    DOWNLOADED  = "downloaded"
    CONVERTED   = "converted"
  end

end
