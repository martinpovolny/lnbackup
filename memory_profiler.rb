include ObjectSpace

MEMORY_PROFILE_BAD_SIZE_METHOD = {FileTest => true, File => true, File::Stat => true}

class Object
  def memory_profile_size_of_object(seen={})
    return 0 if seen.has_key? object_id
    seen[object_id] = true
    count = 1
    if kind_of? Hash
      each_pair do |key,value|
        count += key.memory_profile_size_of_object(seen)
        count += value.memory_profile_size_of_object(seen)
      end
    elsif kind_of? Array
      count += size
      each do |element|
        count += element.memory_profile_size_of_object(seen)
      end
    end

    count += instance_variables.size
    instance_variables.each do |var|
      count += instance_variable_get(var.to_sym).memory_profile_size_of_object(seen)
    end

    count
  end

  def memory_profile_inspect(seen={},level=0)
    return object_id.to_s if seen.has_key? object_id
    seen[object_id] = true
    result = ' '*level
    if kind_of? Hash
      result += "{\n" + ' '*level
      each_pair do |key,value|
        result += key.memory_profile_inspect(seen,level+1) + "=>\n"
        result += value.memory_profile_inspect(seen,level+2) + ",\n" + ' '*level
      end
      result += "}\n" + ' '*level
    elsif kind_of? Array
      result += "[\n" + ' '*level
      each do |element|
        result += element.memory_profile_inspect(seen,level+1) + ",\n" + ' '*level
      end
      result += "]\n" + ' '*level
    elsif kind_of? String
      result += self
    elsif kind_of? Numeric
      result += self.to_s
    elsif kind_of? Class
      result += to_s
    else
      result += "---"+self.class.to_s + "---\n" + ' '*level
    end


    instance_variables.each do |var|
      result += var + "=" + instance_variable_get(var.to_sym).memory_profile_inspect(seen,level+1) + "\n" + ' '*level
    end

    result
  end

end

module MemoryProfile
  LOG_FILE = "/tmp/memory_profile.log"

  def MemoryProfile::report
    Dir.chdir "/tmp"
    ObjectSpace::garbage_collect
    sleep 10 # Give the GC thread a chance
    all = []
    ObjectSpace.each_object do |obj|
      next if obj.object_id == all.object_id 
        
      all << obj
    end
    
    tally = Hash.new(0)
    max_obj = nil
    max_count = 0
    all.each do |obj|
      count = obj.memory_profile_size_of_object
      if max_count < count
        max_obj = obj
        max_count = count
      end
      
      tally[obj.class]+=count
    end
    
    open( LOG_FILE, 'a') do |outf|
      outf.puts '+'*70
      tally.keys.sort{|a,b| 
        if tally[a] == tally[b]
          a.to_s <=> b.to_s
        else
          -1*(tally[a]<=>tally[b])
        end
      }.each do |klass|
        outf.puts "#{klass}\t#{tally[klass]}"
      end
      
      outf.puts '-'*70
      outf.puts "Max obj was #{max_obj.class} at #{max_count}"
      outf.puts "Maximum object is..."
      outf.puts max_obj.memory_profile_inspect
    end
  end

  def MemoryProfile::simple_count
    Dir.chdir "/tmp"
    ObjectSpace::garbage_collect
    sleep 10 # Give the GC thread a chance

    tally = Hash.new(0)
    ObjectSpace.each_object do |obj|
      next if obj.object_id == tally.object_id
      tally[obj.class]+=1
    end
    
    open( LOG_FILE, 'a') do |outf|
      outf.puts '='*70
      outf.puts "MemoryProfile report for #{$0}"
      outf.puts `cat /proc/#{Process.pid}/status`
      
      tally.keys.sort{|a,b| 
        if tally[a] == tally[b]
          a.to_s <=> b.to_s
        else
          -1*(tally[a]<=>tally[b])
        end
      }.each do |klass|
        outf.puts "#{klass}\t#{tally[klass]}"
      end
    end
  end
end

if $0 == __FILE__ then
  File.unlink MemoryProfile::LOG_FILE if FileTest.exist? MemoryProfile::LOG_FILE

  at_exit{ system("cat #{MemoryProfile::LOG_FILE}")}
end

at_exit{
  MemoryProfile::simple_count;
  MemoryProfile::report;
}

