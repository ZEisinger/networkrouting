require "yaml"
require "socket"

class NeighborTable

  def initialize()
    @table_weight = Hash.new
    @sequnce_number = 0
  end

  def insertNeighbor(dest, weight)
    @table_weight[dest] = weight
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
    return YAML::dump(@table_weight)
  end
end

class Graph
  def initialize(my_name, neighbors)
    @my_name = my_name
    @graphs = Hash.new
    @graphs[my_name] = neighbors
    @closest_prev = Hash.new
  end

  def add_neighbor(name, obj_string)
    obj = YAML.load(obj_string)
    if (name == @my_name)
      return false
    end
    if (not @graphs.has_key?(name) or @graphs[name].sequence_number < obj.sequence_number)
      @graphs[name] = obj
      return true
    end
    return false
  end

  def build_closest()
    key_weight = hash.new
    keys_to_add = array.new
    @graphs.each do |name,value|
      key_weight[name] = 2**29 - 1
      @closest_prev[name] = nil
      keys_to_add << name
    end
    key_weight[@my_name] = 0
    
    while not keys_to_add.empty? do
      min = 2**30 - 1
      u = nil
      key_weight.each do |name,weight|
        if weight < min
          u = name
        end
      end
      keys_to_add.remove(u)

      @graphs[u].table_weights.each do |name,value|
        alt = key_weight[u] + value;
        if alt < key_weight[name]
          key_weight[name] = alt
          @closest_prev = u
        end
      end
    end 
  end

  def find_next(name)
    curr = @closest_prev[name]
    while curr != nil do
      name = curr
      curr = @closest_prev[name]
    end
    return name
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
		return @protocol_identifier + "#!" + @ip + "#!" + @total + "#!" + @message + "\000"
	end
	
	def self.protocol_identifier
		@protocol_identifier
	end
end

#Get command line arg to determine what node I am
node_name = ARGV[0]

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

#TODO: Read file, figure out my IPs
addrs = Array.new
file = File.new("nodes-to-addrs.txt", "r")
while (line = file.gets)
  a = line.split(" ")
  if (a[0] == node_name)
    addrs.push(a[1])
  end
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

graph = Graph.new(node_name,neighbor_table)

#TODO: Perform flood message algorithm
#Create message
#TODO: Once flooding is done
#TODO: Then we can start listening for command line messages 

server = TCPServer.open(2000)
Thread.new{
loop do
    Thread.fork(server.accept) do |client|
      content = client.recv($packet_size)
      a = content.split("#!")
      puts content
      puts "got here!"
      if(graph.add_neighbor(a[1], a[3]))
	#TODO: send flood message to other connections
      end
      client.puts "Hello from #{addrs[0]}"
      client.close
    end
end
}
sleep(5)

def sendFlood(from_ip, message_content)
$return_addrs.each{|key, value|
  message = Message.new("FLOOD", "#{from_ip}", "1", "#{message_content}")
  puts key
  puts message.build_message
  test = TCPSocket.open(key, 2000)
  test.write message.build_message
  puts "got back: " + test.recv($packet_size)
  test.close
}
end

$return_addrs.each{|key, value|
   sendFlood(value, "#{neighbor_table.to_s}")
}


