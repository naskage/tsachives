class Upload < ActiveRecord::Base

  module Status
    UPLOADING = 40
    UPLOADED  = 41
    UPLOAD_FAILED = 49
  end

end
