# encoding: UTF-8
class FreeSpaceCalc
  def initialize( path, free_files=0, free_blocks=10, log=nil )
    @log = log
    @stat = FileSystem.stat(path)

    if (free_blocks.class == String) and (free_blocks =~ /^(\d+)%$/)
      free_blocks = @stat.blocks * $1.to_i / 100
    else
      free_blocks = free_blocks.to_i rescue 100
    end
    # vzdy nechame alespon 100 volnych bloku (typicky blok=4kB)
    @free_blocks = free_blocks < 100 ? 100 : free_blocks

    if (free_files.class == String) and (free_files =~ /^(\d+)%$/)
      free_files = @stat.files * $1.to_i / 100
    else
      free_files = free_files.to_i rescue 100
    end
    # vzdy nechame alespon 100 volnych inodu (pokud dojdou, fs se umi prekne 
    # podelat a ani fsck z toho nema radost)
    @free_files = free_files < 100 ? 100 : free_files
  end

  def much_used?
    @stat = FileSystem.stat(@stat.path)
    if Process.euid == 0
      if (@stat.blocks_free < @free_blocks) or (@stat.files_free  < @free_files)
        @log.debug { "FreeSpaceCalc: much used (euid=#{Process.euid}) (#{@stat.blocks_free} < #{@free_blocks}) or (#{@stat.files_free} < #{@free_files})" }
        return true
      end
    else
      if (@stat.blocks_avail < @free_blocks) or (@stat.files_avail  < @free_files)
        @log.debug { "FreeSpaceCalc: much used (euid=#{Process.euid}) (#{@stat.blocks_avail} < #{@free_blocks}) or (#{@stat.files_avail} < #{@free_files})" }
        return true
      end
    end
    return false
  end

  def get_free
    @stat = FileSystem.stat(@stat.path)
    return [ @stat.blocks_free, @stat.files_free ]
  end

  def can_backup?( path )
    begin
      @stat = FileSystem.stat(@stat.path)
      if Process.euid == 0
        if (@stat.blocks_free < @free_blocks) or (@stat.files_free  < @free_files) or 
           (File.size(path) >= ( @stat.block_size * (@stat.blocks_free-@free_blocks) ))

          @log.debug { "FreeSpaceCalc: (euid=#{Process.euid}) can't backup #{path} size #{File.size(path)}" }
          @log.debug { "FreeSpaceCalc: blocks avail: #{@stat.blocks_free} should have: #{@free_blocks}" }
          @log.debug { "FreeSpaceCalc: files  avail: #{@stat.files_free}  should have: #{@free_files}" }
          return false
        end
      else
        if (@stat.blocks_avail < @free_blocks) or (@stat.files_avail  < @free_files) or
           (File.size(path) >= ( @stat.block_size * (@stat.blocks_avail-@free_blocks) ))

          @log.debug { "FreeSpaceCalc: (euid=#{Process.euid}) can't backup #{path} size #{File.size(path)}" }
          @log.debug { "FreeSpaceCalc: blocks avail: #{@stat.blocks_avail} should have: #{@free_blocks}" }
          @log.debug { "FreeSpaceCalc: files  avail: #{@stat.files_avail}  should have: #{@free_files}" }
          return false
        end
      end
      return true
    rescue Errno::ENOENT # pokud soubor, ktery kontrolujeme prestal existovat, 
                         # podminka je trivialne splnena 
      return true
    end
  end
end
