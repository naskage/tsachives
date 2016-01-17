class Job < ActiveRecord::Base

  module Status
    QUEUED           = 10
    DOWNLOADING      = 20
    DOWNLOADED       = 21
    DOWNLOAD_FAILED  = 29
    CONVERTING       = 30
    CONVERTED        = 31
    CONVERT_FAILED   = 39
    UPLOAD_READY_MP4 = 41
    UPLOAD_READY_FLV = 42
    UPLOAD_READY     = 43
    UPLOADING        = 44
    UPLOADED         = 45
    UPLOAD_FAILED    = 49
    DISAPPEARED      = 59
  end

end
