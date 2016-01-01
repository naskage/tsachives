
class PlayerStatus
  attr_reader :live_id, :title, :desc, :provider_type, :community, :queues
  attr_reader :rtmp_url, :player_ticket
  attr_reader :raw_status

  def initialize(attr)
    @live_id = attr['stream']['id'].match(/lv(\d+)$/)[1]
    @title = attr['stream']['title']
    @desc = attr['stream']['description']
    @provider_type = attr['stream']['provider_type']
    @community = attr['stream']['default_community']
    @queues = []

    obj = attr['stream']['quesheet']['que']
    if obj.is_a?(String)
      url = strip_rtmp_url(obj)
      queues << url if url
    elsif obj.kind_of?(Array)
      obj.each do |que|
        url = strip_rtmp_url(que)
        queues << url if url
      end
    end
    
    @rtmp_url = attr['rtmp']['url']
    @player_ticket = attr['rtmp']['ticket']

    @raw_status = attr 
  end

  private

  def strip_rtmp_url(str)
    params = str.split(' ')
    if params.length == 3 && params[2].starts_with?("rtmp://")
      params[2]
    else
      nil
    end
  end

end
