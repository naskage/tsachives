class Upload < ActiveRecord::Base

  module Status
    READY     = 40
    UPLOADING = 41
    UPLOADED  = 42
    UPLOAD_FAILED = 49
  end

end
