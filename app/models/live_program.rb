class LiveProgram < ActiveRecord::Base

  module Status
    UNAVAILABLE = "unavailable"
    REGISTERED  = "registered"
    QUEUED      = "queued"
    DOWNLOADING = "downloading"
    DOWNLOADED  = "downloaded"
    CONVERTED   = "converted"
    UPLOADED    = "uploaded"
  end

end
