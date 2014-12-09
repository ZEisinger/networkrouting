require "yaml"
require 'socket'

class NeighborTable

  def initialize()
    @table_weight = Hash.new
    @table_next = Hash.new
  end

  def insertNeighbor(dest, weight)
    @table_weight[dest] = weight
    @table_next[dest] = dest
  end

  def updateTables(string_obj, prior)
    obj = YAML::load(string_obj)
    obj.each { |a,b| checkNeighbor(a, prior, b) }
  end

  def checkNeighbor(dest, prior, prior_weight)
    if (@table_weight.has_key?(dest))
      if (@table_weight[dest] > prior_weight + @table_weight[prior])
        @table_weight[dest] = prior_weight + @table_weight[prior]
        @table_next[dest] = prior
      end
    else
      @table_weight[dest] = prior_weight + @table_weight[prior]
      @table_next[dest] = prior
    end
  end

  def table_weight
	return @table_weight
  end

  def table_next
	return @table_next
  end

  def to_s()
	return YAML::dump(@table_weight)
  end
end

#This will have an identifier to determine which type of message it is
#If it is CTRL, then the message will be a control text
#If it is a message, the message will be a payload
#Delimited by "#!"
class Message
	def initialize(protocol_identifier, ip, sequence_number, total,  message)
		@protocol_identifier = protocol_identifier
		@ip = ip
		@sequence_number = sequence_number
		@total = total
		@message = message
	end

	def build_message
		return @protocol_identifier + "#!" + @ip + "#!" +  @sequence_number + "#!" + @total + "#!" + @message + "\000"
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
packet_size = a[0].to_i
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
return_addrs = Hash.new

while (line = links.gets)
	a = line.split(",")
	if (addrs.include?(a[0]))
		#map of destination to source address
		return_addrs[a[1]] = a[0]
		neighbor_table.insertNeighbor(a[1], a[2])
		puts "My neighbor: #{a[1]} Weight: #{a[2]}"
	end
end
links.close

#TODO: Perform flood message algorithm
#Create message
#TODO: Once flooding is done
#TODO: Then we can start listening for command line messages 

server = TCPServer.open(2000)
Thread.new{
loop do
	Thread.fork(server.accept) do |client|
		content = client.recv(packet_size)
		a = content.split("#!")
		puts "got here!"
		neighbor_table.updateTables(a[4], a[1])
		puts "My New Neighbor Table: " + neighbor_table.to_s
		client.puts "Hello from #{addrs[0]}"
		client.close
	end
end
}
sleep(5)

return_addrs.each{|key, value|
message = Message.new("FLOOD", "1", value, "1", "#{neighbor_table.to_s}")
test = TCPSocket.open(key, 2000)
test.write message.build_message
puts "got back: " + test.recv(packet_size)
test.close
}
