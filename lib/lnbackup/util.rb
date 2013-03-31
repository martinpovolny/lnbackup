# encoding: UTF-8
class File
  TOO_BIG = 1024 * 1024 * 2  # 2MB

  # a variant of syscopy, that propagates exception Errno::ENOSPC 
  # and handles some extra error states
  #
  def File.syscopy2 from, to
    fsize = size(from)
    fsize = 1024 if fsize < 512
    fsize = TOO_BIG if fsize > TOO_BIG
    fmode = stat(from).mode
    tpath = to
    not_exist = !exist?(tpath)
    begin
      from = open(from, "r")
      from.binmode
      to = open(to, "w")
      to.binmode

      while true
        r = from.sysread(fsize)
        rsize = r.size
        w = 0
        while w < rsize
          t = to.syswrite(r[w, rsize - w])
          w += t
        end
      end
    rescue EOFError
      ret = true
    rescue Errno::ENOSPC
      raise
    rescue
      ret = false
    ensure
      begin; to.close; rescue; end
      begin; from.close; rescue; end
    end
    chmod(fmode, tpath) if not_exist
    ret
  end
end

class Hash
  # "aktualizace" hashe jinou hashi: existujici klice jsou prepsany,
  # neexistujici pridany a to cele rekurzivne po hashich
  def append( hash )
    hash.each_pair do |k,v|
      if self.has_key?(k)
        case v
        when Hash
          self[k].append(v)
        else
          self[k] = v
        end
      else
        self[k] = v
      end
    end
  end
end

class SysCopyFailure < StandardError
end

class MakeSpaceFailure < StandardError
  attr_accessor :code
  def initialize(code)
    @code = code
    super
  end
end

class Date
  # formatovani data do cesty pro zalohu
  def backup_dir(hourly)
    if hourly
        "%d/%02d/%02d-%02d" % [year, month, day, Time.now.hour]
    else
        "%d/%02d/%02d" % [year, month, day]
    end
  end
end

module Find
  #
  # reimplementace funkce "find" s osetrenim vyjimky Errno::EOVERFLOW, ktera minimalne
  # na ruby1.6 nastava pri zachazeni (napr. stat) se souborem o velikosti >2GB
  #
  # pruchod je udelan pomoci zasobniku s hloubkou, aby bylo mozne usetrit pamet
  #
  def Find.find3(*path)
    path.collect!{|d| [d.dup,0]}
    while temp = path.shift
      catch(:prune) do
        (file, depth) = temp
        yield [file, depth]
        begin
          if File.lstat(file).directory? then
            d = Dir.open(file)
            begin
              for f in d
                next if f == "." or f == ".."
                if File::ALT_SEPARATOR and file =~ /^(?:[\/\\]|[A-Za-z]:[\/\\]?)$/ then
                  f = file + f
                elsif file == "/" then
                  f = "/" + f
                else
                  f = File.join(file, f)
                end
                path.unshift [f, depth+1]
              end
            ensure
              d.close
            end
          end
        rescue Errno::ENOENT, Errno::EACCES, Errno::EOVERFLOW
        end
      end
    end
  end
end

