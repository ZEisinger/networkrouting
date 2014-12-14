require "yaml"
require "socket"
require "thread"

class NeighborTable

  def initialize()
    @table_weight = Hash.new
    @sequence_number = 0
  end

  def insertNeighbor(dest, weight)
    @table_weight[dest] = weight.to_i
  end

  def incrementSequence()
    @sequence_number = @sequence_number + 1
  end

  def table_weight
    return @table_weight
  end

  def sequence_number
    return @sequence_number
  end

  def to_s()
    return YAML::dump(self)
  end
end

class Graph
  def initialize(my_name, neighbors, addrs_to_nodes)
    @my_name = my_name
    @graphs = Hash.new
    @graphs[@my_name] = neighbors
    @closest_prev = Hash.new
    @addrs_to_nodes = addrs_to_nodes
    @built = false
  end

  def add_neighbor(ip, obj_string)
    obj = YAML::load(obj_string)
    if (@my_name == @addrs_to_nodes[ip])
      return false
    end
    $semaphore.synchronize {
	#puts "Obtained lock for add"
      if ((not @graphs.has_key?(@addrs_to_nodes[ip])) or @graphs[@addrs_to_nodes[ip]].sequence_number < obj.sequence_number)
        @graphs[@addrs_to_nodes[ip]] = obj
	#puts "Added and now returning"
        build_closest
        return true
      end
    }
	#puts "didn't add now returning"
    return false
  end

  def build_closest()
    key_weight = Hash.new
    keys_to_add = Array.new
    #semaphore.synchronize {
      @graphs.each do |name,value|
        key_weight[name] = 2**29 - 1
        @closest_prev[name] = nil
        keys_to_add << name
      end
      key_weight[@my_name] = 0

    #puts @graphs.keys
    #puts @addrs_to_nodes.values.uniq
      if @graphs.keys.sort == @addrs_to_nodes.values.uniq.sort

      while not keys_to_add.empty? do
        min = 2**30 - 1
        u = nil
	keys_to_add.each do |name|
	   if key_weight[name] < min
	      u = name
	   end
	end
        keys_to_add.delete(u)
        
        @graphs[u].table_weight.each do |ip,value|
          alt = key_weight[u] + value;
          if alt < key_weight[@addrs_to_nodes[ip]]
            key_weight[@addrs_to_nodes[ip]] = alt
            @closest_prev[@addrs_to_nodes[ip]] = u
          end
        end
      end
      @built = true
      end
    #}
  end

  def built
    return @built
  end

  def find_next(name)
    if(name == @my_name)
	return nil
    end
    $semaphore.synchronize{
      curr = @closest_prev[name]
	puts "Curr: #{curr} Name: #{name}"
      while curr != @my_name do
        name = curr
        curr = @closest_prev[name]
      end
      @graphs[@my_name].table_weight.each do |key, value|
        if @addrs_to_nodes[key] == name
          return key
        end
      end
      return nil
    }
  end

  def to_s()
    return YAML::dump(@closest_prev)
  end

end

#This will have an identifier to determine which type of message it is
#If it is CTRL, then the message will be a control text
#If it is a message, the message will be a payload
#Delimited by "#!"
class Message
	def initialize(protocol_identifier, ip, total,  message)
		@protocol_identifier = protocol_identifier
		@ip = ip
		@total = total
		@message = message
	end

	def build_message
		return @protocol_identifier + "#!" + @ip + "#!" + @total + "#!" + @message
	end
	
	def self.protocol_identifier
		@protocol_identifier
	end
end

#Get command line arg to determine what node I am
node_name = ARGV[0]

#initialize mutex
$semaphore = Mutex.new

#Read in config file
config = File.new("global.config", "r")
line = config.gets
a = line.split(",")
$packet_size = a[0].to_i
weights = a[1]
interval = a[2]

config.close

#Set up NeighborTable
neighbor_table = NeighborTable.new
addrs_to_nodes = Hash.new

#TODO: Read file, figure out my IPs
addrs = Array.new
file = File.new("nodes-to-addrs.txt", "r")
while (line = file.gets)
  a = line.split(" ")
  if (a[0] == node_name)
    addrs.push(a[1])
  end
  addrs_to_nodes["#{a[1]}"] =  "#{a[0]}"
end
file.close
puts "My IPs"
addrs.each { |a| puts a }


#Read weights file, figure out neighbors
links = File.new(weights, "r")
$return_addrs = Hash.new

while (line = links.gets)
	a = line.split(",")
	if (addrs.include?(a[0]))
		#map of destination to source address
		$return_addrs[a[1]] = a[0]
		neighbor_table.insertNeighbor(a[1], a[2])
		puts "My neighbor: #{a[1]} Weight: #{a[2]}"
	end
end
links.close

graph = Graph.new(node_name,neighbor_table,addrs_to_nodes)


#TODO: Perform flood message algorithm
#Create message
#TODO: Once flooding is done
#TODO: Then we can start listening for command line messages 

server = TCPServer.open(2000)
server_thread = Thread.new{
  loop do
    Thread.fork(server.accept) do |client|
      content = client.recv($packet_size)
      a = content.split("#!")   
      if (a[0] == "FLOOD") 
         #puts content
         #puts "got here!"
         client.puts "Hello from #{addrs[0]}"
         client.close
         if(graph.add_neighbor(a[1], a[3]))
           sendFlood(a[1], a[3])
         end
	 begin
           #puts "Building the closest"
           #graph.build_closest
	   #puts "THIS IS THE YAML"
	   #puts "#{graph.to_s}"
	 rescue Exception => e
	   puts e.message
	   puts e.backtrace.inspect
  	 end
      elsif (a[0] == "CTRL")
	puts "CONTROL MESSAGE"	
	 #Destination address/name

	 dest_node = addrs_to_nodes[a[3].rstrip]
	puts "DestNode: #{dest_node}"
	 nextNode = graph.find_next(dest_node)
	puts "Next Node: #{nextNode}"
	 #This is the destination
	 if (nextNode == nil)
		puts "I am the destination!" 
	    #Send an acknowledgement
	    client.puts(Message.new("ACK", "", "1","").build_message)
	puts "Message sent!"
	    total = 1
	    num_received = 0
	    full_message = ""
	    begin
              puts "Waiting for client..."
              recv = select([client],nil,nil,5)
              if recv == nil
                break
              end
              
              content = client.recv($packet_size)
              
              puts "Got content: #{content}"
              a = content.split("#!")
              total = a[2].to_i
              num_received = num_received + 1
              puts full_message
              full_message = full_message + a[3]
              puts full_message
              puts "#{num_received} / #{total}"
	    end while (num_received < total)
               puts "exited loop"
	    puts full_message
	    client.close
	 else
		puts "Not the destination"
	    #Will need to translate nextNode to ip
	    
	    nextSock = TCPSocket.open(nextNode, 2000)
	    #Send the message along
	    nextSock.puts(content)
            recv = select([nextSock],nil,nil,5)
            if recv != nil
              content = nextSock.recv($packet_size)
              client.puts(content)
              total = 1
              num_received = 0
              begin
		content = client.recv($packet_size)
		a = content.split("#!")
		total = a[2].to_i
		num_received = num_received + 1
		nextSock.puts(content)
              end while (num_received < total)
              nextSock.close
              client.close
            end
	 end
      elsif a[0] == "PING"
	client.puts "Hello from me"
	client.close
      elsif a[0] == "TRACEROUTE"
	puts "Traceroute"
	client.puts "Hello from me"
	if a[3].rstrip != node_name 
	   puts "Doing traceroute"
	   if not graph.built
              puts "TRACEROUTE ERROR: DESTINATION UNREACHABLE"
           else
             client.puts traceroute_to(a[3].rstrip,graph)
           end
	else
	   puts "dest reached"
	   client.puts "Destination Reached"
        end
	client.close
      end
    end
  end

}

def traceroute_to (destination, graph)
   message = Message.new("TRACEROUTE", "", "1", "#{destination}")

   next_n = graph.find_next(destination)
puts "found next #{next_n}"
   t1 = Time.now
   test = TCPSocket.open(next_n, 2000)
   test.write message.build_message
   #get back "ping"
puts "waiting for ping"
   message = test.recv($packet_size)
   t2 = Time.now
puts "got ping"
   #get back actual traceroute
   message = test.recv($packet_size)

   message = "#{t2-t1} secs for transmission to #{next_n}\n#{message}"

   test.close
   return message
end

stdin_thread = Thread.new{
  loop do
    message = STDIN.gets
    message_arr = message.split(" ")
    if message_arr[0] == "SENDMSG"
      if not graph.built
	puts "SENDMSG ERROR: HOST UNREACHABLE"
      else
        destination = message_arr[1]
        i = message.index(message_arr[2]) - 1
        message.slice!(0..i)
        myMessage = Message.new("CTRL", "", "1", "#{destination}")
        dest_node = addrs_to_nodes[destination]
	puts "Dest Node: #{dest_node}"
        dest_node = graph.find_next(dest_node)
        puts "Opening socket..."
        sock = TCPSocket.open(dest_node, 2000)
	puts "Sending message...."
        sock.puts(myMessage.build_message)
        ack = select([sock],nil,nil,5)
        if ack == nil
          puts "SENDMSG ERROR: No acknowledgement of pipe build"
        else
          puts "Got message!"
          myMessage = Message.new("MSG", "", "1", message)
          puts "Sending actual message!"
          sock.puts(myMessage.build_message)
          ack = select([sock],nil,nil,5)
          if ack == nil
            puts "SENDMSG ERROR: No acknowledgement of message sent"
          end
        end
        sock.close
      end
    elsif message_arr[0] == "PING"
      destination = message_arr[1]
      num_of_pings = message_arr[2]
      delay = message_arr[3]
      i = 0
      while i < num_of_pings.to_i do
        message = Message.new("PING", "", "1", "")
        
	t1 = Time.now
        test = TCPSocket.open(destination, 2000)
        test.write message.build_message
       
        message = test.gets
        
        test.close
        t2 = Time.now
 	puts "From: #{destination} Count: #{i} Time: #{t2 - t1}"
        i = i + 1
        sleep(delay.to_i)
      end
    elsif message_arr[0] == "TRACEROUTE"
      if not graph.built
	puts "TRACEROUTE ERROR: DESTINATION UNREACHABLE"
      else
        destination = message_arr[1].rstrip
        puts traceroute_to(addrs_to_nodes[destination], graph)
      end
    elsif message_arr[0] == "PRINTPREV"
      puts "#{graph.to_s}"
    end
  end
  
}
#sleep to allow us to set everything up
sleep(5)

def sendFlood(from_ip, message_content)
$return_addrs.each{|key, value|
  message = Message.new("FLOOD", "#{from_ip}", "1", "#{message_content}")
#  puts key
#  puts message.build_message
  begin
    test = TCPSocket.open(key, 2000)
    test.write message.build_message
    puts "got back: " + test.recv($packet_size)
    test.close
  rescue Exception => e
    puts e.message
  end
}
end

#Flood sending thread, reads file every interval time
Thread.new {
  while true
    links = File.new(weights, "r")

    while (line = links.gets)
        a = line.split(",")
        if (addrs.include?(a[0]))
                #map of destination to source address
                neighbor_table.insertNeighbor(a[1], a[2])
                puts "My neighbor: #{a[1]} Weight: #{a[2]}"
        end
    end
    links.close
    $return_addrs.each{|key, value|
      sendFlood(value, "#{neighbor_table.to_s}")
    }
    neighbor_table.incrementSequence
    sleep(interval.to_i)
  end
}
stdin_thread.join()
