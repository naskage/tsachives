
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
    attr['stream']['quesheet']['que'].each do |que|
      params = que.split(' ')
      if params.length == 3 && params[2].starts_with?("rtmp://")
        queues << params[2]
      end
    end
    
    @rtmp_url = attr['rtmp']['url']
    @player_ticket = attr['rtmp']['ticket']

    @raw_status = attr 
  end

end
