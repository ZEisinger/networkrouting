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
#TODO: Read file, figure out my IPs
#TODO: Read other file, figure out neighbors
#TODO: Read other other file, figure out my weights to neighbors
#TODO: Perform flood message algorithm
#TODO: Once flooding is done, use Djikstras
#TODO: Then we can 

message = Message.new("CNTRL", "KILL ME PLEASE")
puts message.build_message