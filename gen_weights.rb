

fHandle_ns = File.open(ARGV[0], 'r')
interval = ARGV[2].to_i


ns = {}

while(line = fHandle_ns.gets())
  arr = line.split()
  arr.each{ |a|
    a.chomp!
    a.strip!
  }
  ns[arr[0]] = {} unless ns[arr[0]] != nil
  ns[arr[0]][arr[1]] = true
end
fHandle_ns.close()


while(true)
  begin
    fHandle_ws = File.open(ARGV[1], 'w')
    ns.keys.each{ |s|
      ns[s].keys.each{ |d|
        v = rand(10) + 1
        
        fHandle_ws.puts "#{d},#{s},#{v}"
        fHandle_ws.puts "#{s},#{d},#{v}"
      }
    }
    fHandle_ws.close()
  rescue
    #no op
  end
  sleep(interval)
end

