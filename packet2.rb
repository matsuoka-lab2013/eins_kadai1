require "pp"
class Packet < Controller
  
  def start
    @fdbs = Hash.new do | hash, dpid |
      hash[dpid] = {}
    end
  end

  def packet_in dpid, message
    fdb = @fdbs[dpid] 	
    fdb[message.macsa] = message.in_port	#FDBに記録
    port = fdb[message.macda] 			#宛先からポート番号をひく
    if port
      send_flow_mod_add(
      dpid,
      :macth => ExactMatch.from(message),
      :actions => Trema::SendOutPort.new(port)
      )#フロー(message->port) をスイッチに書き込む

      send_packet_out(
      dpid,
      :packet_in => message,
      :actions => Trema::SendOutPort.new(port)
      )#メッセージをポートに出力
    else
      send_packet_out(
      dpid,
      :packet_in => message,
      :actions => Trema::SendOutPort.new(OFPP_FLOOD)
      )#パケットをflood
    end
  end

end

