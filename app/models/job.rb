class Job < ActiveRecord::Base

  module Status
    QUEUED          = 10
    DOWNLOADING     = 20
    DOWNLOADED      = 21
    DOWNLOAD_FAILED = 29
    CONVERTING      = 30
    CONVERTED       = 31
    CONVERT_FAILED  = 39
    UPLOAD_READY    = 40
    UPLOADING       = 41
    UPLOADED        = 42
    UPLOAD_FAILED   = 49
  end

end
