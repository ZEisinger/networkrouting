class Node
	
	
	
	
end

#This will have an identifier to determine which type of message it is
#If it is CTRL, then the message will be a control text
#If it is a message, the message will be a payload
#Delimited by "#!"
class Message
	def initialize(protocol_identifier, message)
		@protocol_identifier = protocol_identifier
		@message = message
	end

	def build_message
		return @protocol_identifier + "#!" + @message + "\000"
	end
	
	def self.protocol_identifier
		@protocol_identifier
	end
end

#TODO: Get command line args to determine what node I am

node_name = ARGV[0]
weights = ARGV[1]

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

#TODO: Read other file, figure out neighbors
links = File.new(weights, "r")

while (line = links.gets)
	a = line.split(",")
	if (addrs.include?(a[0]))
		puts "My neighbor: #{a[1]} Weight: #{a[2]}"
	end
end
links.close

#TODO: Read other other file, figure out my weights to neighbors
#TODO: Perform flood message algorithm
#TODO: Once flooding is done
#TODO: Then we can start listening for command line messages 



message = Message.new("CNTRL", "KILL ME PLEASE")
puts message.build_message
