require "pio"

class LoadBalancer < Controller
 def start
  @fdb = {}
  @server_list = {}
  @i=0
  @flag=true
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
   if @flag==true
    get_server_list(dpid) 
    @flag=false
   end
  end
 end

 def flow_removed(dpid, message)

 end

 private

 def get_server_list(dpid)
   for i in 0..4
     last_number = 250 + i
     target_ip_addr = "192.168.0." + last_number.to_s
      arp_request_message = Pio::Arp::Request.new(
        :source_mac => '00:00:00:00:00:00',
        :sender_protocol_address => '192.168.0.127',
        :target_protocol_address => target_ip_addr
      )
      send_packet_out(
        dpid,
        :data => arp_request_message.to_binary,
        :actions => Trema::SendOutPort.new(OFPP_FLOOD)
      )
   end
 end

 def handle_arp_request(dpid, message)
    packet_out(dpid, message, OFPP_FLOOD)
 end

 def handle_arp_reply(dpid, message)
  if @server_list[message.arp_spa.to_s]==nil
   @server_list[message.arp_spa.to_s] = message.arp_sha
   else
   packet_out(dpid, message, OFPP_FLOOD)
  end
 end

 def handle_ipv4(dpid, message, port)
  if port
    add_flow(dpid, message, port)
  else
    packet_out(dpid, message, OFPP_FLOOD)
  end
 end

 def add_flow(dpid, message, port)
  saddr = message.ipv4_saddr
  daddr = message.ipv4_daddr
  @i=@i+1
  if @i > 4 
	@i = 0 
  end
  n_ip = "192.168.0.25" + @i.to_s
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
  send_packet_out(dpid,:packet_in => message,
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
   packet_out(dpid, message, port)
  end 
 end
 def packet_out(dpid, message, port)
   send_packet_out(
     dpid,
     :packet_in => message,
     :actions => Trema::SendOutPort.new(port)
     )
 end
end

