require "router-utils"
require "counter"
require "logger"
require "rubygems"
require "pio"

class MyLoadBalancer < Controller
include RouterUtils
 def start
  @fdb = {}
  @server_list = {}
  @counter = Counter.new
  i=0
  t=0
  @log = Logger.new('test.log', 7)
  @log.level = Logger::DEBUG
 end

 def switch_ready(dpid)

 end

 def packet_in(dpid, message)
    @fdb[message.macsa] = message.in_port
    port = @fdb[message.macda]
  if message.arp_request?
   handle_arp_request(dpid, message)
  elsif message.arp_reply?
   handle_arp_reply(dpid, message)
  elsif message.ipv4?
   handle_ipv4(dpid, message, port)
    else
get_server_list( dpid ) 
  end
    @counter.add message.macsa, 1 , message.total_len

end

 def flow_removed(dpid, message)
   @counter.add message.match.dl_src, message.packet_count, message.byte_count
 end

 private

 def get_server_list( dpid )
   for i in 0..4
     last_number = 250 + i
     target_ip_addr = "192.168.0." + last_number.to_s
     arp_request = create_arp_request_from(
       Mac.new("00:00:00:00:00:00"),
       IPAddr.new(target_ip_addr), 
       IPAddr.new("192.168.0.127") 
     )
     send_packet_out(
       dpid,
       :data => arp_request,
       :actions => Trema::SendOutPort.new( OFPP_FLOOD )
     )
   end
 end

 def handle_arp_request(dpid, message)
    packet_out(dpid, message, OFPP_FLOOD)
 end

 def handle_arp_reply(dpid, message)
   if @server_list[message.arp_spa.to_s]
   @server_list[message.arp_spa.to_s] = message.arp_sha
   else
   flood(dpid, message)
  end
 end

 def handle_ipv4(dpid, message, port)
  if port
    add_flow(dpid, message, port)
  else
    flood(dpid, message)
  end
 end

 def add_flow(dpid, message, port)
  saddr = message.ipv4_saddr
  daddr = message.ipv4_daddr
  i=i+1
  if i > 4 
	i = 0 
  end
  n_ip = "192.168.0.25" + i.to_s
  n_mac = @server_list[n_ip].to_s
  n_port = @fdb[@server_list[n_ip]]
  if daddr.to_s == "192.168.0.250"
      send_flow_mod_add(
      dpid,
      :hard_timeout => 1,
      :match => ExactMatch.from(message),
      :actions => [
         Trema::SetIpDstAddr.new(n_ip),
         Trema::SetEthDstAddr.new(n_mac),
         Trema::SendOutPort.new(n_port)
                  ]
  )
send_packet_out(dpid,:data => message,
:actions => [
         Trema::SetIpDstAddr.new(n_ip),
         Trema::SetEthDstAddr.new(n_mac),
         Trema::SendOutPort.new(n_port)
                  ] )
  else 
  send_flow_mod_add(
      dpid,
      :hard_timeout => 1,
      :match => ExactMatch.from(message),
      :actions => Trema::SendOutPort.new(port)
     )
   packet_out(dpid,message,port)
  end 
end

 def packet_out(dpid, message, port)
   send_packet_out(
     dpid,
     :data => message,
     :actions => Trema::SendOutPort.new(port)
     )
 end

 def flood(dpid, message)
   send_packet_out(
     dpid,
     :data => message,
     :actions => Trema::SendOutPort.new(OFPP_FLOOD)
   )

 end

 def create_action_from( macsa, macda, port )
   [
   SetEthSrcAddr.new( macsa ),
   SetEthDstAddr.new( macda ),
   SendOutPort.new( port )
   ]
 end

end

