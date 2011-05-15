#!/usr/bin/ruby1.8

#$:.delete('.') # TODO: vratit!
require 'find'
require 'date'
require 'ftools'
require 'optparse'
require 'filesystem'
require 'logger'
require 'time'

## PROBLEM:
# I, [2007-05-08T23:23:37.860327 #29510]  INFO -- : creating bootable mirror localhost at /dev/sda1 mounted as /mnt/backup
# E, [2007-05-08T23:33:07.682416 #29510] ERROR -- : error (1) in: '/sbin/lilo -r /mnt/backup -b /dev/sda' --> system not bootable
# E, [2007-05-08T23:33:07.698583 #29510] ERROR -- :       stdout: 
# E, [2007-05-08T23:33:07.698812 #29510] ERROR -- :       stderr: Fatal: stat /dev/sda: No such file or directory
# 
# E, [2007-05-08T23:33:07.699029 #29510] ERROR -- : Mirror 'localhost' failed.
# I, [2007-05-08T23:33:07.699290 #29510]  INFO -- : Status information follows
#
# vypada to, ze se nezkopiruje obsah /dev/ ale neni jasne, proc

begin
  require 'acl'
  $HAVE_ACL = true
rescue LoadError
  $HAVE_ACL = false
end

#  :fs_type     => :all, :local, :single,
#  :all      prida do zalohy vsechno a rekurzivne, vcetne sitoveho disku
#  :local    prida do zalohy tento adresar, pokud je mistni jeho podadresare, pokud jsou mistni
#  :single   prida do zalohy tento adresar at je mistni, ci vzdaleny, nerekurzivne

### TODO ###
# require 'dl/import'
# 
# module LIBC
#   extend DL::Importable
# 
#   dlload 'libc.so.6'
# 
#   extern 'int mkfifo(char*, uint)'
#   extern 'void perror(char*)'
#   extern 'int mknod(const char *, mode_t, dev_t)'
# end
# 
# if -1 == LIBC.mkfifo('foo', 007)
#     LIBC.perror("mkfifo")
# end
#
# hardlinky
# vytvareni devices, hardlinkovani nezmenenych devices 
# pocitat spotrebu inodu
# lnstat -- vypise statistiku o volnem mistu, ...
# nalezeni verzi souboru

class File
  TOO_BIG = 1024 * 1024 * 2  # 2MB
  # varianta syscopy, ktera propaguje vyjimku Errno::ENOSPC 
  # a osetruje vice chybovych stavu
  def File.syscopy2 from, to
    to = catname(from, to)
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

class SysCopyFailure < StandardError
end

class MakeSpaceFailure < StandardError
  attr_accessor :code
  def initialize(code)
    @code = code
    super
  end
end

class Object
  def edump
    $stderr.puts(self.inspect)
    self
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
  
  # kompatibilita 1.6 <--> 1.8
  if not Hash.instance_methods.index('values_at')
    alias values_at indices
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


###########################################################################################

class LnBackup
  CONFIG_D         = '/etc/lnbackup.d/'
  LOG_FILE         = '/var/log/lnbackup'
  STATUS_FILE_PREF = '/var/log/lnbackup.status'
  PCS_STATUS       = '/var/log/lnbackup-pcs.status'
  LILO_PATH        = '/sbin/lilo'

  #### return codes ####
  BACKUP_OK             = 0    # 0     -- ok
  BACKUP_EXISTS         = 1    # 1     -- warning
  FAILED_TO_FREE_SPACE  = 12   # 12... -- error codes
  NO_BACKUP_DIR         = 13
  MOUNT_FAILED          = 14
  INVALID_BACKUP        = 15
  PRE_COMMAND_FAILED    = 16
  POST_COMMAND_FAILED   = 17
  FSCK_FAILED           = 18
  SMBMOUNT_FAILED       = 19
  LNBACKUP_RUNNING      = 20
  DEVICE_NOT_FOUND      = 21
  PIDFILE_FAILED        = 22
  DEVICE_FULL           = 100  # when running in --no-delete mode and we run out of disk space

  MESSAGES = {
    BACKUP_EXISTS         => 'backup already exists',
    FAILED_TO_FREE_SPACE  => 'failed to free space',
    NO_BACKUP_DIR         => 'no backup dir',
    MOUNT_FAILED          => 'mount failed',
    INVALID_BACKUP        => 'invalid backup name',
    PRE_COMMAND_FAILED    => 'pre backup cmd failed',
    POST_COMMAND_FAILED   => 'post backup cmd failed',
    FSCK_FAILED           => 'fsck failed',
    LNBACKUP_RUNNING      => 'lnbackup already running',
    DEVICE_NOT_FOUND      => 'backup device not found',
    DEVICE_FULL           => 'device full',
    PIDFILE_FAILED        => 'failed to create pid/lock file'
  }

  attr :stats

  def conf_val(key)
    raise "no @cur_config!" unless @cur_config
    @cur_config[key] || @config[key]
  end

  #### inicializace a konfigurace ####
  def load_config
    @config = {}
    @log.debug { "config dir: #{@config_dir}" }
    Dir[(@config_dir+File::SEPARATOR).squeeze('/')+'*'].sort { |a,b| 
      a.split(File::SEPARATOR)[-1][1..2].to_i <=> b.split(File::SEPARATOR)[-1][1..2].to_i 
    }.each do |conf|
      next if conf =~ /\/[^\/]*\.[^\/]*$/
      if FileTest.file?(conf)
        @log.debug { "\tadding config file: #{conf}" }
        @config.append( eval( File.open(conf).read ) )
      end
    end
    @pcb = @config[:pcb]
    @config[:mount_point].gsub!(%r{(.)/$},'\1')
  end

  def initialize( args={  :log_level   => Logger::INFO, 
                          :test_mode   => false, 
                          :config_dir  => CONFIG_D,
                          :log_file    => LOG_FILE,
                          :status_file_pref => STATUS_FILE_PREF,
                          :source_prefix => '',
                          :target_dir_name  => nil,
                          :delay       => nil,
                          :delay_denom => nil,
                          :no_delete   => false,
                          :no_acl      => false,
                          :max_iter    => 5,
                      } )
    log_level, @test_mode, config_dir, log_file, 
        @status_file_pref, @source_prefix, @target_dir_name, @delay, @delay_denom,
            @no_delete, @no_acl, @max_iter = 
          args.values_at( :log_level, :test_mode, :config_dir, :log_file, 
            :status_file_pref, :source_prefix, :target_dir_name, :delay, :delay_denom,
              :no_delete, :no_acl, :max_iter )

    @log = nil
    begin
      @log = Logger.new( log_file == '-' ? STDOUT : log_file )
    rescue => e #Errno::EACCES, Errno::EROFS
      $stderr.puts "Exception #{e.class.to_s}: #{e.message}."
      $stderr.puts "\tUsing STDERR for logging."
      @log = Logger.new( STDERR )
    end
    @log.level = log_level
    @log.info { "Running in test mode." } if @test_mode

    @exclude_list = []
    @last_file = nil
    @config_dir = config_dir
    load_config
  end

  def config_init( name )
    @backup_name = name
    name = name.intern if name.class==String

    @status_file = @status_file_pref + '-' + @backup_name

    # otestujeme, jestli je definovana vybrana zaloha zadaneho jmena
    if not @config.has_key?(name)
      @log.fatal { "No config for backup '#{@backup_name}', exiting!" }
      return INVALID_BACKUP 
    end
    @log.debug{ $HAVE_ACL ? "ACL support" : "no ACL support" }

    # @cur_config bude obsahovat konfiguraci vybrane zalohy
    @cur_config = @config[name]
    @cur_config[:mount_point].gsub!(%r{(.)/$},'\1') if @cur_config.key?(:mount_point)
    
    # find partition by label if necessary
    if conf_val(:device_label) or conf_val(:device_uuid)
      label = conf_val(:device_label) ? conf_val(:device_label) : conf_val(:device_uuid)
      device = find_dev_by( conf_val(:device), label,
                            conf_val(:device_label) ? :label : :uuid )
      disk = disk_for_device( device )
      @log.debug { "label/uuid: #{label.inspect}, device: #{device}, disk: #{disk}" }
      @log.error { "no device with given label/uuid #{label.inspect}" } unless device

      return DEVICE_NOT_FOUND if device.nil? or disk.nil?
      @cur_config[:device], @cur_config[:disk] = [device, disk]
    end
    return 0
  end
  
  #### hledani starych backupu ####
  def find_backups( name=nil, any=false )               # TODO --- pripravit na moznost hodinovych zaloh
    dest = nil
    hourly = nil
    # budto mame zadano jmeno zalohy, na kterou se ptame, nebo se pouzije ta,
    # s kterou bylo spusteno run_backup
    if name
      name_s = name.class==String ? name.intern : name
      if !@config.has_key?(name_s)
        @log.fatal { "No config for backup '#{name_s.to_s}'" }
        return []
      end
      dest   = @config[name_s].has_key?(:target_dir) ? @config[name_s][:target_dir] : conf_val(:mount_point)
      hourly = @config[name_s][:hourly]
    else
      name   = @target_dir_name
      dest   = @cur_config.has_key?(:target_dir) ? @cur_config[:target_dir] : conf_val(:mount_point)
      hourly = @cur_config[:hourly]
    end
    if any
      return Dir["#{dest}/backup/*/*/*"].sort
    else
      return Dir["#{dest}/backup/*/*/*/#{name}"].sort
    end
  end

  #### kopirovaci rutiny ####
  def do_cp_a( src, dest )
    find_exclude?(src)

    @log.debug { "cp -a #{src} #{dest}" }

    if !@test_mode
      ret, out, err = system_catch_stdin_stderr('/bin/cp', '-a', src, dest)
      if ret != 0 
        @log.info { "/bin/cp failed: '#{err}' (#{src}), making space..." }

        make_some_space if @space_calc.much_used?
  
        ret, out, err = system_catch_stdin_stderr('/bin/cp', '-a', src, dest)
        if ret != 0
          @log.error { "do_cp_a: file copy failed ( '/bin/cp', '-a', #{src}, #{dest} ), out: #{out}, error: #{err}" }
          @log.error { "\t #{src} not copied" }
        end
      end
    end
  end
  
  def do_cp_dir(src, dest)
    find_exclude?(src + '/')

    @log.debug { "File.mkpath #{dest}" }

    if !@test_mode
      begin
        File.mkpath(dest)
      rescue Errno::ENOSPC
        @log.info { "File.mkpath: Errno::ENOSPC (#{src}), making space..." }
        make_some_space and retry
      end
    end
  end
  
  def do_hardlink(last, src, dest)
    find_exclude?(src)

    @log.debug { "File.link #{last}, #{dest}" }
    if !@test_mode
      begin
        File.link(last, dest)
      rescue Errno::ENOSPC
        @log.info { "File.link: Errno::ENOSPC (#{src}), making space..." }
        make_some_space and retry
      rescue => err
        @log.error { "File.link (#{last} -> #{dest}) error: #{err.message} --> skipping from backup" }        # TODO: nastavit indikator chyby!
      end
    end
  end

  def do_copy(src,dest)
    find_exclude?(src)

    @log.debug { "do_copy( #{src}, #{dest})" }

    begin
      # nejdrive udelame misto
      make_space_for(src)
      # pak kopirujeme
      copy_preserve( src, dest ) if !@test_mode

    rescue Errno::ENOSPC    # behem kopirovani nastala vyjimka -- doslo misto
      @log.info { "copy_preserve: Errno::ENOSPC (#{src}), making space..." }
      make_some_space and   # nejdriv udelame nejake misto, protoze make_space_for
                            # nemusi nic smazat, napriklad pokud je mezitim zdroj
                            # soubor smazan
      make_space_for(src) and retry
                            # pak udelame misto pro dany soubor (muze byl
                            # veliky) a zkusime to znovu
    rescue SysCopyFailure => err
      # syscopy selhal
      @log.info { "copy_preserve: SysCopyFailure (#{src}), checking space..." }
      # muze se stat, ze selze, protoze nema misto, nebo z neznameho duvodu (treba Errno::EIO)
      begin
        if @space_calc.can_backup?(src)
          # mistem to nebylo --> chyba
          @log.error { "copy_preserve: SysCopyFailure (#{src}), enough space --> skipping file" }
          return false
        else
          # TODO: sem by se vubec nemelo dojit (na dojiti mista je samostatna vyjimka ENOSPC)
          # asi nam nekdo pod rukama zabral misto, zkusime znovu
          @log.info { "copy_preserve: Making space (#{src})..." }
          make_space_for(src) and retry
        end
      rescue => e
        @log.error { "do_copy: exception #{e.class}: #{e.message} when handling exception" }
        @log.error { "skipping file #{src}" }
        return false
      end
    rescue Errno::EOVERFLOW
      # soubor je moc velky, neni zazalohovan
      @log.error { "copy_preserve: Errno::EOVERFLOW (#{src}), file too large --> skipping file" }
      return false
    rescue Errno::ENOENT
      # soubor nam zmizel pod rukama behem zalohovani
      @log.warn { "copy_preserve: Errno::ENOENT (#{src}), file deleted during backup" }
      return false
    end
    return true
  end
  
  def realpath(file)
    if not File.respond_to?(:readlink) then
      return file
    end

    file = File.expand_path(file)
    return file if file == '/'

    total = ''
    file.split(File::SEPARATOR).each do |piece|
      next if piece == ""
      total << File::SEPARATOR + piece
      if File.symlink?(total) then
        begin
          total =  File.expand_path( File.readlink(total), File.dirname(total) )
        end while File.symlink?(total)
      end
    end

    return total
  end

  #### uvolnovani mista ####
  def make_space_for( path )
    while not @space_calc.can_backup?(path) do 
      @log.debug { "make_space_for: Not enough space for #{path}, removing oldest." }
      remove_oldest
    end
  end

  def make_some_space
    remove_oldest
    while @space_calc.much_used?
      remove_oldest
    end
  end

  def remove_oldest
    if @no_delete
      @log.fatal { "backup device is full, terminating..." }
      raise MakeSpaceFailure.new(DEVICE_FULL)
    end
    backups = find_backups(nil,true)

    oldest = nil
    # hledame nejstarsi zalohu, ktera neni na seznamu chranenych
    backups.each do |backup|
      if not @dont_delete.index(backup)
        oldest = backup
        break
      end
      @log.debug { "not deleting #{backup}" }
    end
    
    if oldest
      oldest.sub!("/#{@backup_name}$",'') 
      if FileTest.directory?(oldest)
        @log.info { "free blocks: %s files: %s" % @space_calc.get_free }
        @log.info { "removing oldest: '#{oldest}'" }

        if not @test_mode
          if Process.euid != 0
            @log.debug { "/bin/chmod -R u+rwX #{oldest}" }
            system('/bin/chmod', '-R', 'u+rwX', oldest)
          end
          @log.debug { "/bin/rm -rf #{oldest}" } or raise MakeSpaceFailure.new(FAILED_TO_FREE_SPACE)
          system('/bin/rm', '-rf', oldest) or raise MakeSpaceFailure.new(FAILED_TO_FREE_SPACE)

          # mazeme prazdne adresare
          begin
            oldest.sub!(%r'/\d\d$','')
            Dir.rmdir(oldest)               # mazeme mesic
            oldest.sub!(%r'/\d\d$','')
            Dir.rmdir(oldest)               # mazeme rok
          rescue 
            # odchytávame výjimku mazání neprázdného adresáře
          end
        end
        @log.info { "removing oldest done" }
        @log.info { "free blocks: %s files: %s" % @space_calc.get_free }
        return true
      end
      @log.fatal { "remove_oldest: FileTest.directory?(#{oldest}) failed, not removing (processing file: #{@last_file})" }
    else
      @log.fatal { "remove_oldest: No backup to be removed found (processing file: #{@last_file})." }
    end

    @log.fatal { "remove_oldest failed" }
    raise MakeSpaceFailure.new(FAILED_TO_FREE_SPACE)
  end

  #### spusteni programu se zachycenim stdout a stderr ####
  def _system_catch_stdin_stderr(*args)
    args.unshift( nil )
    system_catch_stdin_stderr_with_input( args )
  end

  def system_catch_stdin_stderr(*args)
    args = args.collect {|a| a.to_s}
  
    pipe_peer_in, pipe_me_out = IO.pipe
    pipe_me_in, pipe_peer_out = IO.pipe
    pipe_me_error_in, pipe_peer_error_out = IO.pipe
  
    pid = nil
    begin
      Thread.critical = true
      STDOUT.flush
      STDERR.flush
  
      pid = fork {
        STDIN.reopen(pipe_peer_in)
        STDOUT.reopen(pipe_peer_out)
        STDERR.reopen(pipe_peer_error_out)
        pipe_me_out.close
        pipe_me_in.close
        pipe_me_error_in.close
  
        begin
          exec(*args)
        rescue
          exit!(255)
        end
      }
    ensure
      Thread.critical = false
    end
  
    pipe_peer_in.close
    pipe_peer_out.close
    pipe_peer_error_out.close
    pipe_me_out.sync = true
  
    pipe_me_out.close
    got_stdin = pipe_me_in.read
    pipe_me_in.close unless pipe_me_in.closed?
    got_stderr = pipe_me_error_in.read
    pipe_me_error_in.close unless pipe_me_error_in.closed?
  
    p, status = Process.waitpid2(pid)
    return [status >> 8, got_stdin, got_stderr]
  end

  def system_catch_stdin_stderr_with_input(input, *args)
    args = args.collect {|a| a.to_s}
  
    pipe_peer_in, pipe_me_out = IO.pipe
    pipe_me_in, pipe_peer_out = IO.pipe
    pipe_me_error_in, pipe_peer_error_out = IO.pipe
  
    pid = nil
    begin
      Thread.critical = true
      STDOUT.flush
      STDERR.flush
  
      pid = fork {
        STDIN.reopen(pipe_peer_in)
        STDOUT.reopen(pipe_peer_out)
        STDERR.reopen(pipe_peer_error_out)
        pipe_me_out.close
        pipe_me_in.close
        pipe_me_error_in.close
  
        begin
          exec(*args)
        rescue
          exit!(255)
        end
      }
    ensure
      Thread.critical = false
    end
  
    pipe_peer_in.close
    pipe_peer_out.close
    pipe_peer_error_out.close
  
    pipe_me_out.sync = true
    pipe_me_out.print( input ) if input != nil
    pipe_me_out.close
    
    got_stdin = pipe_me_in.read
    pipe_me_in.close unless pipe_me_in.closed?
    got_stderr = pipe_me_error_in.read
    pipe_me_error_in.close unless pipe_me_error_in.closed?
  
    p, status = Process.waitpid2(pid)
    return [status >> 8, got_stdin, got_stderr]
  end

  # volani tune2fs
  def tune2fs(dev)
    @log.debug { "calling tune2fs on #{dev}" }
    if Process.euid != 0
        ret, out, err = system_catch_stdin_stderr( '/usr/bin/sudo', '/sbin/tune2fs', '-l', dev )
    else
        ret, out, err = system_catch_stdin_stderr( '/sbin/tune2fs', '-l', dev )
    end
    if ret != 0
      @log.error { "tune2fs failed with exit code: '#{ret}'" }
      @log.error { "\tstdout: #{out}" }
      @log.error { "\tstderr: #{err}" }
      return {}
    end
    results = {}
    out.split("\n").each do |line|
      if line =~ /^([^:]+):\s*(.*)$/
        results[$1] = $2
      end
    end
    return results
  end

  # resetovani pocitadla mountu
  def reset_mount_count( dev ) # TODO error handling
    @log.info { "reseting mount count on #{dev}" }
    ret, out, err = system_catch_stdin_stderr( '/sbin/tune2fs', '-C', '0', dev )
    if ret != 0
      @log.error { "tune2fs failed with exit code: '#{ret}'" }
      @log.error { "\tstdout: #{out}" }
      @log.error { "\tstderr: #{err}" }
      return false
    end
    return true
  end

  def disk_for_device( device )
    # TODO: udelat poradne
    if device =~ %r{^(/dev/[hs]d[a-z])[0-9]$}
      return $1
    elsif device =~ %r{^(/dev/.*?)p[0-9]$}
      return $1
    end
    return nil
  end

  # nastavovani labelu: tune2fs -L MUFF2 /dev/sdb1
  def find_dev_by( device_mask, label, by=:label )
    found = false
    device = nil
    if Array === device_mask
        devices = device_mask
    else
        devices = Dir[ device_mask ]
    end

    File.readlines('/proc/partitions')[2..-1].each do |line|
      major, minor, blocks, name = line.sub(/^\s+/,'').split(/\s+/)

      dev = File.join('/dev', name)
      # test na masku
      next unless devices.index( dev )
      
      if FileTest.blockdev?( dev )
        @log.debug( "find_dev_by: checking #{dev}" )
        dump = tune2fs( dev )
        if (
             ((by == :label) && (String === label) && ( dump['Filesystem volume name'] =~ /^#{label}$/ )) ||
             ((by == :label) && (Array  === label) && ( label.index(dump['Filesystem volume name'] ))) ||
             ((by == :uuid)  && (String === label) && ( dump['Filesystem UUID'] == label )) ||
             ((by == :uuid)  && (Array  === label) && ( label.index(dump['Filesystem UUID'] )))
           )
          if found
            @log.error{ "found at least two devices with given label #{label.inspect}: #{dev} and #{device}" }
            return nil
          else
            found  = true
            device = dev
          end
        end
      end
    end
    return device
  end
  
  #### pomocne rutiny pro praci s crypto loop ####
  def find_loop(max=8)
    ret, out, err = system_catch_stdin_stderr('/sbin/losetup', '-a')
    return nil if ret != 0

    loops = out.collect do |l| 
      (dev,x) = l.split(':',2)
      dev.sub(%r|^/dev/loop|,'').to_i 
    end
  
    for i in 0..max
      if not loops.index(i)
        return "/dev/loop#{i}"
      end
    end
    return nil
  end
  
  def mk_loop( dev, passwd, size=0, crypto='aes-256' )
    if dev !~ %r|/dev/|
      system_catch_stdin_stderr( '/bin/dd', 'if=/dev/zero', "of=#{dev}", 'bs=1M', "count=#{size}" )
    end
  
    loop_dev = find_loop
    system_catch_stdin_stderr_with_input( passwd+"\n", '/sbin/losetup', '-p', '0', '-e', crypto, loop_dev, dev )
    system_catch_stdin_stderr( 'mkfs.ext3', loop_dev )
    system_catch_stdin_stderr( '/sbin/losetup', '-d', loop_dev )
  end

  #### pomocne File rutiny ####
  def restore_dir_attributes(dirs,depth=0)
    #@log.debug { "restore_dir_attributes: depth=#{depth}" }
    return dirs.find_all do |dir, stat, access_acl, default_acl, d|
      next true if d<depth
      
      @log.debug { "chown, utime, chmod #{dir}" } 
      if not @test_mode
        begin 
          File.chown(stat.uid, stat.gid, dir)
        rescue => error
          @log.warn { "restore_attributes: chown #{dir} got error and didn't restore owner': #{error.message}\n" }
        end
        begin 
          File.chmod(stat.mode, dir)
        rescue => error
          @log.warn { "restore_attributes: chmod #{dir} got error and didn't restore rights': #{error.message}\n" }
        end
        if $HAVE_ACL and not @no_acl
          begin
            access_acl.set_file(dir) if access_acl
            default_acl.set_default(dir) if default_acl
          rescue => error
            @log.warn { "restore_attributes: couldn't restore ACLs: #{error.message}\n" }
          end
        end
        begin 
          File.utime(stat.atime, stat.mtime, dir)
        rescue => error
          @log.warn { "restore_attributes: utime #{dir} got error and didn't restore times': #{error.message}\n" }
        end
      end
      false
    end
  end

  def copy_preserve( from, to )
    to = File.catname( from, to )
    begin
      if not File.syscopy2( from, to )            # Errno::ENOSPC se siri ven
        File.unlink( to )
        raise SysCopyFailure.new( "syscopy2 returned false when copying #{from} --> #{to}" )
      end
    rescue Errno::EIO => e      # tak tohle znamena poradnej pruser....
      msg = "i/o error copying #{from} : #{e.message}"
      @log.error {  msg  }
      raise SysCopyFailure( msg )
    rescue Errno::ETXTBSY => e  # (windows) maji zamklej soubor?
      msg = "text file busy #{from} : #{e.message}"
      @log.error { msg }
      raise SysCopyFailure.new( msg )
    end     

    st = nil
    begin
      st = File.stat( from )
    rescue => error
      @log.warn { "copy_preserve: File.stat #{from} got error and failed: #{error.message}\n" }
      @log.warn { "copy_preserve: NOT restoring owner, rights, times and ACLs on #{to}\n" }
    end
    
    if st
      begin 
        File.chown( st.uid,   st.gid,   to )
      rescue => error
        @log.warn { "copy_preserve: chown #{to} got error and didn't restore owner: #{error.message}\n" }
      end
      begin 
        File.chmod( st.mode,  to )
      rescue => error
        @log.warn { "copy_preserve: chmod #{to} got error and didn't restore rights: #{error.message}\n" }
      end
      if $HAVE_ACL and not @no_acl
        begin
          acl = get_access_acl( from )
          acl.set_file( to ) if acl
        rescue => error
          @log.warn { "copy_preserve: setfacl #{to} got error and didn't restore ACLs: #{error.message}\n" }
        end
      end
      begin 
        File.utime( st.atime, st.mtime, to )
      rescue => error
        @log.warn { "copy_preserve: utime #{to} got error and didn't restore times: #{error.message}\n" }
      end
    end
  end

  def same_file?(f1, f2)
    begin
      result = ( !File.symlink?(f1) and
                 !File.symlink?(f2) and
                 File.file?(f1) and
                 File.file?(f2) and
                 (s1 = File.stat(f1)).size == (s2 = File.stat(f2)).size and
                 ( (s1.mtime - s2.mtime) <= 1 ) and
                 s1.uid == s2.uid and
                 s1.gid == s2.gid and
                 s1.mode == s2.mode )

      return result unless result

      if $HAVE_ACL and not @no_acl
        return false unless ACL.from_file(f1).to_text == ACL.from_file(f2).to_text
        # default ACL neresime, protoze tady mame jen soubory
        #return false unless ACL.default(f1).to_text   == ACL.default(f2).to_text
      end
      return true
    rescue => error
      @log.warn { "same_file?(#{f1}, #{f2}) got error and returned false: #{error.message}\n" }
      return false
    end
  end

  #### rizeni chodu Find ####

  # hledame 1. match a podle neho se ridime, cili pod klicem :exclude ZALEZI NA PORADI
  # a na predni mista davame konkretnejsi pravidla a az na ne pravidla obecnejsi
  def find_exclude?( path )
    return if @skip_excludes
    # spocteme si relativni cestu
    rel_path = path.dup
    if rel_path.index( @exclude_root ) == 0
      if @exclude_root == '/'
        rel_path[0,1] = ''
      else
        rel_path[0,@exclude_root.length+1] = '' # odmazeme vcetne lomitka
      end
    else
      rel_path = nil # muzeme nastavit nil, protoze nil =~ /cokoliv/ je false
    end
    # matchujeme
    @exclude_list.each do |a|
      if (a[2] ? path : rel_path) =~ a[1] 
        if a[0]
          @log.debug { "excluding(#{a[1].source}): #{path}" }
          Find.prune
        else
          return
        end
      end
    end
  end

  # absolute=>true   bude se matchovat absolutni (cela cesta)
  # absolute=>false  bude se matchovat cesta relativni ke klici :dir
  def set_exclude(str, absolute=false)
    if str == '!'
      @exclude_list = []
      return
    end
    exclude_pattern = true
    if str =~ /^\+\s*(.*)$/   
      exclude_pattern = false
      str = $1
    elsif str =~ /^-\s*(.*)$/
      exclude_pattern = true
      str = $1
    end
    @exclude_list << [exclude_pattern, Regexp.new('^'+str), absolute]
  end

  def umount_fsck_mount
    if umount_backup
      check_fsck or return print_error_stats( LnBackup::FSCK_FAILED )
    end
    mount_backup or return print_error_stats( LnBackup::MOUNT_FAILED )
    return 0
  end
  
  #### zalohovani se vsim vsudy ####
  def go_backup( name, no_mirror )
    if ((res = config_init(name)) != 0) || ((res = umount_fsck_mount) != 0) 
      return res
    end

    res = run_backup
    if (res == LnBackup::BACKUP_OK)
      # pokud probehla v poradku 1. faze muzeme pokracovat mirrorem
      if not no_mirror
        mirror_res = create_mirror
        res = mirror_res unless mirror_res == nil
      end
    else
      print_error_stats( res )
    end
    
    umount_backup(true)
    return res
  end
  
  def detect_running(lock_file_name)
    if FileTest.exists?(lock_file_name)
      @log.debug { "detect_running: lock file #{lock_file_name} exists" }
      pid = File.open(lock_file_name).read(nil).chomp.to_i rescue nil
      if pid == nil
        @log.error { "detect_running: invalid PID in #{lock_file_name}" }
        @log.warn { "detect_running: assuming lnbackup not running" }
        return false
      end
      if FileTest.exists?(cmd_file="/proc/#{pid}/cmdline")
        cmd_line = File.open(cmd_file).read(nil) rescue ''
        @log.debug { "detect_running: process ##{pid}' command line: #{cmd_line}" }
        if (cmd_line =~ /\/lnbackup/)
          @log.error { "lnbackup already running, pid: #{pid}, command line: #{cmd_line}" }
          return true
        else
          @log.warn { "lnbackup probably not running lock_file_name: #{lock_file_name}" }
          @log.warn { "\t\tpid: #{pid}, command line: #{cmd_line}" }
          return false
        end
      else
        @log.debug { "detect_running: #{lock_file_name} does not exist" }
        return false
      end
    else
      return false
    end
  end

  # Hledame v predchozich zalohach soubor jmena podle tmp_src.
  # Divame, jestli nalezeny souboj je "stejny" jako ten, ktery 
  # mame zalohovat.
  # Pokud ano, vratime ho, jinak vratime nil.
  # Hledani zarazime, pokud najdeme soubor na stejne ceste, 
  # ktery neni "stejny"
  #
  # TODO: hledani by se melo take zastavit, kdyz se podivame do posledni 
  # dokoncene zalohy -- na to potrebujeme strojive zpracovatelny status 
  # file pro predchozi zalohy --> ukol k reseni
  def find_same_prev_backup( src, tmp_src, all_backups )
    max_iter = @max_iter
    all_backups.reverse.each do |prev_backup|
      last = File.expand_path(tmp_src, prev_backup)
      return last if same_file?(src,last)
      return false if FileTest.exists?(last)

      max_iter -= 1
      return false if max_iter == 0
    end
    return nil
  end

  def get_access_acl(file)  ($HAVE_ACL and not @no_acl) ? (ACL::from_file(file) rescue nil) : nil; end
  def get_default_acl(file) ($HAVE_ACL and not @no_acl) ? (ACL::default(file) rescue nil)   : nil; end
 
  #### hlavni zalohovaci rutina ####
  def run_backup
    begin
      @log.info { "running backup #{@backup_name}" }
      
      @skip_excludes = false
      lock_file = nil
      pre_command_ok = true

      @backup_start = Time.now

      @stats = {
        :size   => 0, :total_size => 0, :blocks  => 0,
        :f_same => 0, :f_changed  => 0, :f_new   => 0,
        :file   => 0, :dir        => 0, :symlink => 0, :blockdev => 0, :chardev  => 0, :socket   => 0, :pipe     => 0,
      }

      # cilovy adresar pro zalohy je budto gobalni mount_point nebo target_dir
      # vybrane zalohy + datum + (hodina) + nazev zalohy
      pre_dest_tmp = @cur_config.has_key?(:target_dir) ? @cur_config[:target_dir] : conf_val(:mount_point)
      if not File.directory?(pre_dest_tmp)
        @log.fatal { "backup root '#{pre_dest_tmp}' does not exist" }
        return NO_BACKUP_DIR
      end
      begin
        lock_file_name = File.join(pre_dest_tmp,'LNBACKUP_RUNNING')
        return LNBACKUP_RUNNING if detect_running(lock_file_name)
        lock_file = File.open( lock_file_name, 'w' )
        lock_file.puts($$)
        lock_file.flush
      rescue
        return PIDFILE_FAILED
      end
      
      # podivame se po pripadnem prikazu, ktery bychom meli udelat pred zalohovanim
      if @cur_config.has_key?(:pre_command)
        ret, out, err = system_catch_stdin_stderr(@cur_config[:pre_command])
        if ret != 0
          @log.fatal { "pre command failed: '#{@cur_config[:pre_command]}" }
          @log.fatal { "\texit code: '#{ret}'" }
          @log.fatal { "\tstdout: #{out}" }
          @log.fatal { "\tstderr: #{err}" }
          pre_command_ok = false
          return PRE_COMMAND_FAILED
        end
      end

      # udaj o rezervovanem miste bereme prednosti z konkretni zalohy, 
      # pokud neni nakonfigurovan, tak globalne
      files_reserved = (@cur_config.has_key?(:files_reserved) ? @cur_config[:files_reserved] : @config[:files_reserved])
      blocks_reserved = (@cur_config.has_key?(:blocks_reserved) ? @cur_config[:blocks_reserved] : @config[:blocks_reserved])
      @space_calc = FreeSpaceCalc.new( pre_dest_tmp, files_reserved, blocks_reserved, @log )

      dest_tmp = File.join( pre_dest_tmp, 'backup').squeeze('/')
      @log.debug { "dest_tmp: #{dest_tmp}" }

      # nemazeme posledni backup
      @dont_delete = []
      prev_backup = ( all_backups = find_backups() )[-1]
      if prev_backup
        @dont_delete << prev_backup.gsub(/\/[^\/]*$/,'')
      end

      @dest = File.join( dest_tmp, 
                         Date.today.backup_dir(@cur_config[:hourly]), 
                         @target_dir_name ).squeeze('/')
      # a nemazeme ani to, co zrovna zalohujeme
      @dont_delete << @dest.gsub(/\/[^\/]*$/,'')

      if File.directory?(@dest)
        @log.fatal { "today's/this hour's backup (#{@dest}) already exists --> exiting" }
        return BACKUP_EXISTS
      else
        begin
          begin
            File.mkpath(@dest) unless @test_mode
          rescue Errno::ENOSPC
            make_some_space and retry
          end
        rescue
          @log.fatal { "can't make backup dir '#{@dest}'" }
          return NO_BACKUP_DIR
        end
      end

      @log.debug { "previous backup: #{prev_backup}" }
      @log.debug { "dont_delete: #{@dont_delete.join(',')}" }
      
      # adresare je nutno vyrobit, nez do nich nasypeme soubory,
      # ale nastavit jejich atributy musime az po souborech, 
      dirs_to_restore = []

      dirs = Array.new
      dirs_hash = Hash.new
      @cur_config[:dirs].each do |dir|
        tmp_dir = @source_prefix ? File.join( @source_prefix, dir[:dir] ) : dir[:dir]
        dirs << [ rp = realpath(tmp_dir).gsub(/(.)\/+$/,'\1') , dir[:fs_type], dir[:exclude] ]
        dirs_hash[rp] = true
      end

      dirs.each do |path,fs_type,exclude|
        path = File.expand_path(path)

        # inicializace excludes
        @exclude_root = path
        @exclude_list = []
        exclude.each { |ex| set_exclude(ex) } if exclude
        #@log.debug { "Excluding: ^#{Regexp.escape(dest_tmp)}\/." }
        @exclude_list.unshift( [true, /^#{Regexp.escape(dest_tmp)}\/./, true] )
        @exclude_list.unshift( [true, /^#{Regexp.escape(lock_file_name)}$/, true] )
        @log.debug { "Excluding: #{@exclude_list.to_s}" }
        @log.debug { "exclude_root: #{@exclude_root}" }

        # overime, ze zdroj existuje
        begin
          File.stat(path)
        rescue Errno::ENOENT
          @log.error { "path #{path} not found --> skipping from backup" }
          next
        rescue Errno::EACCES
          @log.error { "path #{path} no rights to access file --> skipping from backup" }
          next
        rescue => error
          @log.error { "path #{path} : File.stat got error #{error.class} : #{error.message} --> skipping from backup" }
          next
        end

        # projit cestu, udelat linky a adresare
        @log.debug { "resolving links for #{path}" }
        if path != '/'
          file = path

          total = ''
          file.split(File::SEPARATOR).each do |piece|
            next if piece == ""
            total << File::SEPARATOR + piece
            if File.symlink?(total) then
              begin
                # dokud se jedna o symlink, tak musime linkovat
                do_cp_a(total, File.join(@dest,total))

                total = File.expand_path( File.readlink(total), File.dirname(total) )
              end while File.symlink?(total)
              # a nakonec udelame adresar
            else
              # pokud se nejedna o symlink, udelame adresar
              tgt = File.join(@dest,total).squeeze('/')
              do_cp_dir( total, tgt )
              # ulozime si ho do seznamu pro pozdejsi nastaveni vlastnosti
              dirs_to_restore << [ tgt, File.stat(total), get_access_acl(total), get_default_acl(total), 0 ]
            end
          end
          path = total
        end

        # overime, ze existuje i cesta, kam nas zavedly odkazy a 
        # ulozime si device pro budouci porovnavani
        dev = nil
        begin
          dev = File.stat(path).dev 
        rescue Errno::ENOENT
          @log.error { "path #{path} not found --> skipping from backup" }
          next
        end

        # overime si, ze mame tento adresar zalohovat (napr. home pres nfs)
        @log.debug { "checking fs_type for #{path}" }
        if (fs_type == :local) and (dev <= 700)               # HRUBY ODHAD --> TODO: poradne
          @log.info { "#{path} is not local (dev=#{dev}), skipping" }
          next
        end

        @log.debug { "running on directory #{path}" }
        last_depth = 0
        Find.find3( path ) do |src,depth|
          if @delay_denom
            if @delay and (rand(@delay_denom) == 0)
              sleep(@delay)
            end
          elsif @delay
            sleep(@delay)
          end
          dirs_to_restore = restore_dir_attributes(dirs_to_restore, depth+1) if last_depth>depth
          last_depth = depth
          
          @last_file = src
          src = File.expand_path('./'+src, '/')
          tmp_src = './' + src
          dest = File.expand_path(tmp_src, @dest)

          begin
            file_stat = File.lstat(src)
          rescue => error
            @log.error { "can not stat #{src}: #{error.class}: #{error.message} --> skipping from backup" }
            Find.prune
          end
          
          # POZOR !! 
          # nelze volat file_stat.readable?, protoze:
          # irb(main):016:0* File.lstat('/etc/asterisk/cdr_manager.conf').readable?
          # => false
          # irb(main):017:0>
          # irb(main):018:0*
          # irb(main):019:0* File.readable?('/etc/asterisk/cdr_manager.conf')
          # => true
          # irb(main):020:0> system('ls -l /etc/asterisk/cdr_manager.conf')
          # -rw-rw----  1 asterisk asterisk 59 2005-12-08 00:58 /etc/asterisk/cdr_manager.conf
          # => true
          
          # if not file_stat.readable? and not file_stat.symlink?
          if not File.readable?(src) and not file_stat.symlink?
            @log.error { "can not read #{src} --> skipping from backup" }
            Find.prune
          end

          if file_stat.symlink? or file_stat.blockdev? or file_stat.chardev? or 
             file_stat.socket? or file_stat.pipe?
            # symlink, blockdev, chardev, socket, pipe zalohujeme pomoci 'cp -a'
            do_cp_a(src, dest)
            if file_stat.symlink? 
              @stats[:symlink] += 1
            elsif file_stat.blockdev? 
              @stats[:blockdev] += 1
            elsif file_stat.chardev? 
              @stats[:chardev] += 1
            elsif file_stat.socket? 
              @stats[:socket] += 1
            elsif file_stat.pipe?
              @stats[:pipe] += 1
            end
          elsif file_stat.directory?
            # adresar

            # preskocime koren, protoze uz je vytvoren
            if src != path
              # preskocime v pripade vicenasobneho dosazeni stejneho adresare
              Find.prune if dirs_hash.has_key?(src)
              @stats[:dir] += 1

              do_cp_dir(src, dest)
              # ulozime si ho do seznamu pro pozdejsi nastaveni vlastnosti
              dirs_to_restore << [dest, file_stat, get_access_acl(src), get_default_acl(src), depth]
            end

            # kontrola zastaveni noreni pri zmene device
            if dev != (new_dev = file_stat.dev)
              @log.debug { "filesystem border: #{src} old=#{dev}, new=#{new_dev}" }
              case fs_type
              when :local
                # pri zmene device otestujeme, ze je lokalni
                # konec pokud device neni lokalni
                if new_dev <= 700 # HRUBY ODHAD --> TODO: poradne
                  @log.info { "#{src} is not local (dev=#{new_dev}), skipping" }
                  Find.prune
                end
                # 0x300 ---> ide
                # 2304  ---> md0
                # 26625 ---> hwraid
                # 9 --> autofs
                # 7 --> pts 
                # 2 --> proc
                # 0xa --> nfs
              when :single
                # single --> koncime, jakmile je podadresar z jineho device
                Find.prune
              when :all
                # all --> bereme vsechno
              end
            end
          else # normalni soubor
            @stats[:file] += 1
            @stats[:total_size] += file_stat.size
            # overime, jestli mame drivejsi zalohu souboru a jestli nebyl zmenen
            backuped = false
            new      = false
            last     = nil
            if prev_backup 
              # hledat file i v predchozich zalohach: viz. TODO OTESTOVAT!!
              #last = File.expand_path(tmp_src, prev_backup)
              #if same_file?(src,last)
              
              # hledame v drivejsich zalohach ...
              last = find_same_prev_backup(src, tmp_src, all_backups)
              if last # last neni ani 'nil', ano 'false'
                do_hardlink(last, src, dest)
                backuped = true
                @stats[:f_same] += 1
              end
            end
            if not backuped
              # pokud jsme prosli az sem, budeme soubor kopirovat
              if do_copy(src,dest)
                if prev_backup
                  if last.nil? # nil   --> vubec jsme nenasli
                    @stats[:f_new] += 1
                    @log.debug { "new file: #{src}" }
                  else         # false --> nasli jsme, ale byl zmenen
                    @stats[:f_changed] += 1
                    @log.debug { "changed file: #{src}" }
                  end
                else
                  # nehlasime 'new file' u 1. zaloh
                  @stats[:f_new] += 1
                end

                if @test_mode
                  # v test modu odhadujeme velikost podle zdroje
                  @stats[:size] += file_stat.size
                  @stats[:blocks] += file_stat.blocks
                else
                  @stats[:size] += File.size(dest)
                  @stats[:blocks] += File.stat(dest).blocks
                end
              end
            end
          end
        end
      end
      restore_dir_attributes(dirs_to_restore)

      over_all_status = BACKUP_OK
      
      @log.info { "Backup '#{@target_dir_name}' complete succesfully." }
      print_stats( over_all_status )
    rescue MakeSpaceFailure => e
      return e.code # in this case we return the error code given by exception 
                    # ( possibly ignoring status code from post_command )
    ensure
      if lock_file
        begin
          lock_file.close
        ensure
          File.delete( lock_file_name )
        end
      end

      if pre_command_ok and @cur_config.has_key?(:post_command)
        ret, out, err = system_catch_stdin_stderr(@cur_config[:post_command])
        if ret != 0
          @log.error { "post command failed: '#{@cur_config[:post_command]}" }
          @log.error { "\texit code: '#{ret}'" }
          @log.error { "\tstdout: #{out}" }
          @log.error { "\tstderr: #{err}" }
          over_all_status = POST_COMMAND_FAILED
        end
      end
    end
    return over_all_status
  end

  def print_stats( code )
    sum = 0
    [:file, :dir, :symlink, :blockdev, :chardev, :socket, :pipe].each { |s| sum += @stats[s] }

    status = []
    status << "lnbackup statistics for: #{@target_dir_name}"
    status << "backup config:           #{@backup_name}"
    status << "overall status code:     #{code}"
    status << "overall status message:  #{MESSAGES[code]}"
    status << "running in: TEST MODE" if @test_mode
    status << ""
    status << "backup start:  #{@backup_start}"
    status << "backup end:    #{Time.now}"
    status << "total size:    #{@stats[:total_size]}"
    status << "backup size:   #{@stats[:size]}"
    status << "backup blocks: #{@stats[:blocks]}"
    status << ""
    status << "files unmodified: #{@stats[:f_same]}"
    status << "files changed:    #{@stats[:f_changed]}"
    status << "files new:        #{@stats[:f_new]}"
    status << ""
    status << "total objects: #{sum}"
    status << "files:         #{@stats[:file]}"
    status << "dirs:          #{@stats[:dir]}"
    status << "symlinks:      #{@stats[:symlink]}"
    status << "blockdevs:     #{@stats[:blockdev]}"
    status << "chardevs:      #{@stats[:chardev]}"
    status << "sockets:       #{@stats[:socket]}"
    status << "pipes:         #{@stats[:pipe]}"
    print_status_array(status)
  end

  def print_error_stats(err)
    status = []
    status << "error code: #{err}" 
    status << "message: #{MESSAGES[err]}"
    print_status_array(status)
    return err
  end

  # prints status information to log file, stdout and to status file
  def print_status_array( status, mode='w' )
    @log.info { "Status information follows" }
    status_hash = {}
    status.each do |line|
      puts line
      @log << line + "\n"

      key, value = line.chomp.split(':',2).collect{ |a| a.strip }
      status_hash[key] = value
    end
    status_hash['uuid']  = @part_uuid
    status_hash['label'] = @part_label
    begin
      File.open(@status_file,mode) do |f|
        status.each { |line| f.puts line }
      end
    rescue => error
      @log.error { "error writing status file #{@status}: #{error.message}" }
    end
    # binary status file
    begin
      # read the status array
      status_array = Marshal.restore( File.open(@status_file+'.bin').read(nil) ) rescue []

      # adding to last status information -- take the last status info, modify it and write back
      if mode == 'a'
        status_array[0] ||= {}
        status_array[0].update( status_hash )

      # writing new status information -- add new element to the beginning
      else 
        status_array.unshift( status_hash )
      end

      # write the status array
      File.open(@status_file+'.bin','w') { |f| f << Marshal.dump( status_array ) }
    rescue => error
      @log.error { "error writing binary status file #{@status}: #{error.message}" }
    end
  end

  def parse_stats
    stats = {}
    File.open(@status_file,'r').readlines.each do |line|
      key, value = line.chomp.split(':',2).collect{ |a| a.strip }
      stats[key] = value
    end
    return stats
  end

  def size2str (size)
    size = size.to_i
    if size < 1024
      "#{size} "
    elsif size < 1048576
      "%.1fK" % (size / 1024.0)
    elsif size < 1073741824
      "%.1fM" % (size / 1048576.0)
    else
      "%.1fG" % (size / 1073741824.0)
    end
  end

  def backup_partitions
    devices = Dir[ @config[:device] ]
    backups = @config.keys.find_all {|k| Hash===@config[k] and @config[k].key?(:dirs) and not @config[k][:dont_check] }
    out_backup_devices = []
    devs = {}
    for backup in backups
        devs[backup] = devices
        if @config[backup][:device]
            devs[backup] = Dir[ @config[backup][:device] ]
        end
        if @config[backup][:device_label]
            devs[backup] = [ find_dev_by(devs[backup], @config[backup][:device_label], :label) ]
        end
        if @config[backup][:device_uuid]
            devs[backup] = [ find_dev_by(devs[backup], @config[backup][:device_uuid], :uuid) ]
        end
        out_backup_devices |= devs[backup]
    end
    return out_backup_devices
  end

  def backup_partition?(partition)
    return backup_partitions.include?(partition)
  end

  def nagios_check_all
    #backups = @config[:check_backups] || [:localhost]
    total_message = ''
    total_message_bad = ''
    worst_result = 0
    for backup in @config.keys.find_all {|k| Hash===@config[k] and @config[k].key?(:dirs) and not @config[k][:dont_check] }
      result, message = nagios_check( backup.to_s )
      total_message << '[' << message << '] '
      total_message_bad << '[' << message << '] ' if result != 0
      worst_result = result > worst_result ? result : worst_result
    end
    total_message = total_message_bad if worst_result != 0
    return [worst_result, total_message]
  end
  
  def nagios_check( backup_name = 'localhost' )
    @status_file = @status_file_pref + '-' + backup_name
    conf_key = backup_name.intern

    if not @config.has_key?(conf_key)
        return [ 2, "backup '#{backup_name}' not configured" ]
    end

    no_mirror_warn = false
    warn_t  = 26  # implicitni hodnoty pro warning a error (v hodinach)
    error_t = 30
    if @config[conf_key].has_key?(:monitor)
      warn_t  = @config[conf_key][:monitor][:warn] || warn_t
      error_t = @config[conf_key][:monitor][:error] || error_t
      no_mirror_warn = @config[conf_key][:monitor][:no_mirror_warn] || false
    end

    stats = {}
    message = ''
    status = 0

    if File.readable?(@status_file)
      stats = parse_stats
    else
      return [ 2, "backup status file #{@status_file} not found" ]
    end

    if stats.has_key?('backup end')
      message  = stats['lnbackup statistics for'] + ': '

      delta = ((Time.now() - Time.parse( stats['backup end'] ))/3600).to_i
      if delta > error_t
        status = 2
        message << "backup age: #{delta}h > #{error_t} ->ERR"
      elsif delta > warn_t
        status = 1
        message << "backup age: #{delta}h > #{warn_t} ->WARN"
      else
        if stats.has_key?('mirror end')
          message << (Time.parse( stats['mirror end'] ).strftime( '%H:%M:%S %d/%m/%y' ) rescue 'parse error')
          message << ' : ' << size2str(stats['backup size'].to_i) << '/' << size2str(stats['total size']) << 'B '
          message << '(bootable)'
        else
          message << stats['backup end']
          message << ' : ' << size2str(stats['backup size'].to_i) << '/' << size2str(stats['total size']) << 'B '
          if @config[backup_name.intern][:mirror]
            if no_mirror_warn
              message << '(not bootable ->warning canceled by config)'
            else
              message << '(not bootable ->WARN)'
              status = 1 if status < 1
            end
          end
        end
      end

    else
      message  = backup_name.to_s + ' : '
      if stats.has_key?("error code")
        status  = (s = stats['error code'].to_i) > status ? s : status
        message << stats['message']
      else
        message << "Unknown error"
        stats = 2
      end
    end

    return [ status<2 ? status : 2, message ]
  rescue
    raise
    return [ 2, "can't parse status file #{@status_file}" ]
  end

  def do_mirror_only(name)
    if (res = config_init(name)) != 0
      return res 
    end
    
    @status_file = '/dev/null'
    @dest = find_backups[-1]
    create_mirror
  end
  
  #### vytvoreni mirroru
  # pousti se po run_backup, takze muze pocitat s pripravenym prostredim...
  def create_mirror
    # pokud nema vybrana konfigurace v konfiguraci povoleno mirrorovani,
    # vratime nil
    return nil unless @cur_config[:mirror] == true

    # pokud nemame device, nebo mount_point, nebo jsou prazdne, tak to rozhodne zabalime
    return nil if conf_val(:device).to_s.empty? or conf_val(:mount_point).to_s.empty?

    # taky to zabalime, jestlize mame zadano crypto (neumime bootovat z sifrovane zalohy)
    return nil if @config.has_key?(:crypto)

    mnt  = conf_val(:mount_point)
    part = conf_val(:device)
    disk = conf_val(:disk)

    lock_file_name = File.join(mnt,'LNBACKUP_RUNNING')
    return LNBACKUP_RUNNING if detect_running(lock_file_name)
    lock_file = File.open( lock_file_name, 'w' )
    lock_file.puts($$)
    lock_file.flush

    @log.info { "creating bootable mirror #{@backup_name} at #{part} mounted as #{mnt}" }

    # smazat stary mirror
    command = [ 'find', "#{mnt}", '-xdev',
                    '-maxdepth', '1', '-mindepth', '1', 
                    '!', '-name', 'backup',
                    '!', '-name', 'LNBACKUP_RUNNING',
                    '!', '-name', 'lost+found', 
                    '-exec', 'rm', '-fr', '{}', ';' ]
    @log.debug { 'running: ' + command.join(' ')  }
    system( *command ) unless @test_mode

    @exclude_list = []
    @skip_excludes = true
                    
    @dont_delete = [@dest]
    latest_mirror = @dest
    latest_mirror_len = latest_mirror.size
    target_dir = conf_val(:mount_point)

    # vytvorit novy mirror
    dirs_to_restore = []
    last_depth = 0
    Find.find3(latest_mirror + '/') do |src,depth| 
      if @delay_denom
        if @delay and (rand(@delay_denom) == 0)
            sleep(@delay)
        end
      elsif @delay
        sleep(@delay)
      end
      dirs_to_restore = restore_dir_attributes(dirs_to_restore, depth+1) if last_depth>depth
      last_depth = depth

      src = File.expand_path('./' + src, '/')
      tmp_dst = './' + src[latest_mirror_len..-1]
      dest = File.expand_path(tmp_dst, target_dir)

      next if src==latest_mirror

      begin
        if File.symlink?(src) or File.blockdev?(src) or File.chardev?(src) or File.socket?(src) or File.pipe?(src)
          # symlink, blockdev, chardev, socket, pipe zalohujeme pomoci 'cp -a'
          do_cp_a(src, dest)
        elsif File.directory?(src)
          # adresar
          # preskocime koren, protoze uz je vytvoren
          next if src == latest_mirror
          do_cp_dir(src, dest)
          # ulozime si ho do seznamu pro pozdejsi nastaveni vlastnosti
          dirs_to_restore << [ dest, File.stat(src), get_access_acl(src), get_default_acl(src), depth ] ### TODO: CHYBA?
        else # normalni soubor --> hard link
          do_hardlink(src, src, dest)
        end
      end
    end
    restore_dir_attributes(dirs_to_restore)

    # vypnout lnbackup na zazalohovane kopii
    # mv "$MNT"/etc/cron.daily/lnbackup{,.disabled}                                                                                                                               
    # ucinit system bootovatelnym, pokud mame zadan i disk
    ret = true
    if disk
      if not @test_mode
        ret = create_fstab( mnt, part, disk )

        if ret and not @cur_config[:skip_lilo]
          if FileTest.executable?(LILO_PATH)
            ret = create_lilo_conf( mnt, part, disk )
          else
            @log.warn { "LILO binary '#{LILO_PATH}' not found, skipping LILO" }
          end
        else
          @log.info { "skipping LILO as requested in config" }
        end
      end
    else
      @log.error { "'disk' not defined, skipping LILO and fstab ..." }
      ret = false
    end

    status = [""]
    if ret
      @log.info { "Mirror '#{@backup_name}' finished." }
      status << "mirror end:    #{Time.now}"
    else
      @log.error { "Mirror '#{@backup_name}' failed." }
      status << "mirror failed: #{Time.now}"
    end

    print_status_array(status,'a')
    return BACKUP_OK
  ensure
    if lock_file
      begin
        lock_file.close
      ensure
        File.delete( lock_file_name )
      end
    end
  end

  #### generovani souboru
  # TODO: pokud je zaloha udelana pres label, generovat fstab na label
  #       i swap lze nalezt pres label v /dev/disk/by-uuid/
  #
  # priklad /etc/fstab
  #     UUID=ad71a12d-9cdf-460e-beab-969533237a36 none swap defaults 0 0
  #     UUID=b76083c3-2871-4719-a670-26848043686d /    ext3 defaults 0 0

  def create_fstab( mnt, part, disk )
    swap_line = `/sbin/fdisk -l #{disk} | grep 'Linux swap'`.chomp
    swap_n    = ( ( swap_line =~ /^#{disk}(\d+).*$/ ) ? $1 : nil ).to_s
    part_n    = ( ( part =~ /^#{disk}(\d+)$/ ) ? $1 : nil ).to_s
    fstab     = "#{mnt}/etc/fstab"
  
    # check fstab
    if part_n == ''
      @log.error { "Cannot find correct part_n='#{part_n}'!" }
      @log.error { "The file '#{fstab}' was not generated." }
      @log.error { "Backup not bootable!" }
      return false
    end
    if swap_n == ''
      @log.warn { "Cannot find correct swap_n='#{swap_n}" }
      @log.warn { "The file '#{fstab}' was generated WITHOUT SWAP partition." }
      @log.warn { "Backuped system may have problems !" }
    end

    ext3_options = 'noatime,defaults,errors=remount-ro'
    ext3_options << ',acl,user_xattr' if $HAVE_ACL and not @no_acl
    
    # create fstab
    File.unlink(fstab)
    File.open(fstab,'w') do |f|             # TODO: generate fstab based of filesystem LABELs (if possible, swap?)
                                            #       otherwise we don't boot system from SATA/SCSI disks
      f.puts '#<file system> <mount point>   <type>  <options>           <dump>  <pass>'
      f.puts "/dev/hda#{part_n} /            ext3     #{ext3_options}    0       1"
      f.puts "/dev/hda#{swap_n} none         swap     sw                 0       0" if swap_n != ''
      f.puts "proc              /proc        proc     defaults           0       0"
    end
  
    return true
  end
  
  def create_lilo_conf( mnt, part, disk )
    # run lilo
    sys_lilo_cfg = "/etc/lilo.conf"             # TODO relativni k necemu?
    lilo_cfg = File.join( mnt, sys_lilo_cfg )
  
  
    File.unlink( lilo_cfg  )
    File.open( lilo_cfg, 'w' ) do |f|
      f.puts "disk=#{disk}\nbios=0x80"
      content = File.open( sys_lilo_cfg ).read(nil)
      f.print content.gsub(/^((raid-extra-boot|disk|bios)[[:space:]]*=)/, '#\1')
    end

    lilo_ret, lilo_out, lilo_err = system_catch_stdin_stderr( LILO_PATH, '-r', mnt, '-b', disk )
    if lilo_ret != 0 # check lilo
      @log.error { "error (#{lilo_ret}) in: '/sbin/lilo -r #{mnt} -b #{disk}' --> system not bootable" }
      @log.error { "\tstdout: #{lilo_out}" }
      @log.error { "\tstderr: #{lilo_err}" }
      return false
    else
      return true
    end
  end
  
  #### kontrola disku a spousteni fsck ####
  def check_fsck
    part        = nil
    crypto      = @config[:crypto]
    password    = @config[:password]
    loop_dev    = nil

    begin
      part = conf_val(:device)
      if (crypto)
        loop_dev = find_loop
        system_catch_stdin_stderr_with_input( password+"\n", '/sbin/losetup', 
                                              '-p', '0', '-e', crypto, loop_dev, part )
        part = loop_dev
      end

      if (part!=nil) and (part!='')
        @log.debug { "running: /sbin/tune2fs -l #{part}" }
        fs_params = {}
        
        ret, out, err = system_catch_stdin_stderr('/sbin/tune2fs', '-l', part)
        if ret == 0
          out.split("\n").each do |l|
            k,v = l.split(/\s*:\s*/)
            fs_params[k] = v
          end
        else
          @log.error { "tune2fs failed with exit code: '#{ret}'" }
          @log.error { "\tstdout: #{out}" }
          @log.error { "\tstderr: #{err}" }
          return false
        end

        if (mount_count = fs_params['Mount count'].to_i)+5 >= 
              (max_mount_count = fs_params['Maximum mount count'].to_i)
          @log.info { "Disk #{part} has reached mount_count: #{mount_count} (max: #{max_mount_count}), running fsck" }
          if not @test_mode
            ret, out, err = system_catch_stdin_stderr( '/sbin/fsck.ext3', '-y', part )
            if ret == 0
              @log.info { "fsck found no errors" }
              return reset_mount_count( part )
            elsif ret == 1
              @log.info { "fsck corrected some errors" }
              @log.debug { "\tstdout: #{out}" }
              @log.debug { "\tstderr: #{err}" }
              return reset_mount_count( part )
            else
              @log.error { "fsck failed with exit code: '#{ret}'" }
              @log.error { "\tstdout: #{out}" }
              @log.error { "\tstderr: #{err}" }
              return false
            end
          end
        else
          @log.debug { "Disk #{part}: mount_count: #{mount_count} (max: #{max_mount_count}), not running fsck" }
        end
        @part_uuid  = fs_params['Filesystem UUID']
        @part_label = fs_params['Filesystem volume name']
        @log.info { "Disk: #{part}, UUID: #{@part_uuid}, Label: #{@part_label}" }
      end
    ensure
      if crypto and loop_dev
        system_catch_stdin_stderr( '/sbin/losetup', '-d', loop_dev )
      end
    end

    return true
  end
  
  #### vypsani stavu zalohy ####
  def backup_status( backup_name, status_file_pref = nil )
    @status_file_pref = status_file_pref if status_file_pref
    res = nil
    return res if (res = config_init(backup_name)) != 0

    if File.readable?(@status_file)
      puts File.open(@status_file).read(nil)
      puts
    end
    mount_backup
    backups = find_backups( backup_name )
    backups.each do |backup|
      puts backup
    end
    umount_backup(true)
  end

  #### mount/umount ####
  # :none - not mounted, :ro - mounted ro, :rw - mounted rw
  def check_mounted
    File.open('/proc/mounts').read(nil).each_line do |line|
      what, where, type, opts, dump, pass = line.split(/\s+/)
      return [ opts.split(',').index('rw') ? :rw : :ro, what ] if where == conf_val(:mount_point)
    end
    return [ :none, nil ]
  end
  
  def mount_backup(rw = true)
    device      = conf_val(:device)
    mount_point = conf_val(:mount_point)
    crypto      = @config[:crypto]
    password    = @config[:password]
    remount     = false

    if (device!=nil) and (device!='') and 
       (mount_point!=nil) and (mount_point!='')

      mount_status, mount_dev = check_mounted
      @log.debug { "mount status before mount: device: #{mount_dev}, status: #{mount_status}" }

      # pokud je na nasem mountpointu namountovano cokoliv jineho, nez co ma byt, koncime 
      if (mount_status != :none) and (mount_dev != device)
        @log.fatal { "wrong device mounted as #{mount_point}: have #{mount_dev}, need #{device}"}
        return false
      end

      if mount_status != :none
        if (mount_status == :ro) and rw
          # mame namontovano, ale jen ro, musime remountovat
          remount = true
        else 
          # mame namontovano rw, ale neudelali jsme si to sami, preskocime mounting
          @log.warn { "disk not remounted, using previously mounted disk!" }
          return true
        end
      end
      
      # try mount
      @log.debug { "mounting #{device} --> #{mount_point} " + 
                      (rw ? (remount ? 'remount,RW' : 'RW') : 'RO') + 
                      (crypto ? '[crypto]':'') }

      cmd = [ 'mount', device, mount_point ]
      if rw
        if remount
          cmd << '-o' << 'remount,rw'
        end
        cmd << '-o' << 'noatime'
      else
        cmd << '-o' << 'ro'
      end
      cmd << '-o' << 'acl,user_xattr' if $HAVE_ACL and not @no_acl

      ret, out, err = 
          crypto ? system_catch_stdin_stderr_with_input( 
                      *( [password+"\n"] + cmd + ["-oencryption=#{crypto}", '-p', '0'] ) ) :
                   system_catch_stdin_stderr( *cmd )
      if ret != 0
        @log.fatal { "mount #{device} --> #{mount_point} failed" }
        @log.warn { "\tstdout: #{out}" }
        @log.warn { "\tstderr: #{err}" }
        return false
      end
    end
    return true
  end

  # unmount backup
  # return true on success (not mounted or succesfull unmount)
  def umount_backup(try_ro=false)
    device      = conf_val(:device)
    mount_point = conf_val(:mount_point)

    if (device!=nil) and (device!='') and 
       (mount_point!=nil) and (mount_point!='')

      mount_status, mount_dev = check_mounted
      if mount_status != :none
        @log.debug { "mount status before umount: device: #{mount_dev}, status: #{mount_status}" }
        @log.debug { "unmounting #{mount_point}" }

        ret, out, err = system_catch_stdin_stderr( '/bin/umount', mount_point )
        if ret != 0
          @log.warn { "umount #{mount_point} failed" }
          @log.warn { "\tstdout: #{out}" }
          @log.warn { "\tstderr: #{err}" }

          if not try_ro
            return false
          else
            # jeste se pokusime o remount,ro
            ret, out, err = system_catch_stdin_stderr( '/bin/mount', '-o', 'remount,rw', mount_point )
            if ret != 0
              @log.warn { "mount -o remount,ro #{mount_point} failed" }
              @log.warn { "\tstdout: #{out}" }
              @log.warn { "\tstderr: #{err}" }
              @log.warn { "backup remained mounted!" }
            end
          end
        end
      end
    end
    return true
  end

  def mirror_only( backup_name )
    return LnBackup::MOUNT_FAILED unless mount_backup
  
    mirror_res = do_mirror_only( backup_name )
    res = mirror_res unless mirror_res == nil
  
    umount_backup
    return 0
  end

  def backup_pcs( pcs_status_f, no_delete )
    @log.info { "starting PCs backup" }

    if (ret = umount_fsck_mount) != 0
      return ret
    end

    pc_status = Marshal.restore( File.open( pcs_status_f ).read( nil ) ) rescue {}
    
    @pcb[:backup_hosts].each do |host|
      @log.info { "mounting #{host}" }
      mount_to = "#{@pcb[:mounts_root]}/#{host}"
      system_catch_stdin_stderr('umount', mount_to )
      File.mkpath( mount_to )

      pc_status[host] = Hash.new unless pc_status.has_key?(host)
      pc_status[host][:tried] = Time.now
      pc_status[host][:status] = -1
      
      cmd = [ "/bin/mount", "-t", "smbfs", "-o", 
              "username=#{@pcb[:backup_user]},"+
              "password=#{@pcb[:backup_password]},"+
              "workgroup=#{@pcb[:backup_workgroup]}", 
              "//#{host}/#{@pcb[:backup_share]}", mount_to ]
      @log.debug { "running '" + cmd.join("' '") + "'" }
      ret, out, err = system_catch_stdin_stderr( *cmd )

      if ret == 0
        begin
          @log.debug { "host #{host} mount passed" }
          
          # run backup
          bk2 = LnBackup.new( 
            :log_level         => @log.level,
            :log_file          => "#{@pcb[:log_dir]}/lnbackup-#{host}.log",
            :test_mode         => @test_mode,
            :config_dir        => @config_dir,
            :status_file_pref  => "#{@pcb[:status_dir]}/lnbackup-#{host}.status",
            :source_prefix     => mount_to,
            :target_dir_name   => "#{@pcb[:backup_config]}/#{host}",
            :no_delete         => no_delete
            )

          bk2.config_init( @pcb[:backup_config] ) # TODO: error handling ?!
          res = bk2.run_backup

          pc_status[host][:status] = res
          pc_status[host][:stats]  = bk2.stats
          if res == BACKUP_OK
            pc_status[host][:success] = Time.now
          end
        rescue => e
          @log.fatal { "host #{host} raised exception #{e.class}:'#{e.message}'" }
          @log.fatal { e.backtrace.join("\n") }
          @log.fatal { "skipping to next host" }
        ensure
          system_catch_stdin_stderr("/bin/umount", mount_to )
        end
        @log.debug { "host #{host} finished" }
      else
        @log.error { "#{host} failed: \n\tout:#{out}\n\terr:#{err}" }
        pc_status[host][:status] = SMBMOUNT_FAILED
      end
    end

    begin
      File.open( pcs_status_f, 'w' ) do |f|
        f.print Marshal.dump( pc_status )
      end
    rescue => e
      @log.error { "cannot write pc_status: #{pcs_status_f}: #{e.message}" }
    end

    umount_backup(true)
    @log.info { "finished PCs backup" }
  end

  def backup_pcs_status( pcs_status_f )
    pc_status = Hash.new
    begin
      pc_status = Marshal.restore( File.open( pcs_status_f ).read( nil ) )
    rescue
    end

    print "Content-type: text/html\r\n\r\n"
    puts "<html><table>"

    @pcb[:backup_hosts].each do |host|
      puts "<tr><td>#{host}<td>"

      if not pc_status.has_key?(host)
        puts "\t\thas no backup"
      else
        st = pc_status[host]
        if st.has_key?(:status) and (st[:status] == BACKUP_OK)
          puts "\t\t(OK) " + st[:success].to_s + ' ' + size2str( st[:stats][:size].to_i ) << 'B '
        else
          if st.has_key?(:success)
            puts "\t\t(WARN) Last success: " + st[:success].to_s
          else
            puts "\t\t(ERROR) Last tried: " + st[:tried].to_s
          end
        end
      end
    end
    
    puts "</table></html>"
  end

  def backup_pcs_test
    @log.info { "starting PCs backup test" }

    @pcb[:backup_hosts].each do |host|
      @log.debug { "trying #{host} ... " }
      #echo smbclient -c "''" -W $BACKUP_WORKGROUP //$HOST/$BACKUP_SHARE -U $BACKUP_USER%$BACKUP_PASSWORD
      cmd = [ '/usr/bin/smbclient', '-c', '', '-W', @pcb[:backup_workgroup],
          "//#{host}/#{@pcb[:backup_share]}", '-U', 
          "#{@pcb[:backup_user]}%#{@pcb[:backup_password]}" ]
      @log.debug { "running '" + cmd.join("' '") + "'" }

      ret, out, err = system_catch_stdin_stderr( *cmd )
      if ret == 0
        @log.info { "#{host} passed" }
      else
        @log.error { "#{host} failed: ret:#{ret}\n\tout:#{out}\n\terr:#{err}" }
      end
    end

    @log.info { "finished PCs backup test" }
  end

  def crypto_init(size)
    device   = conf_val(:device)
    crypto   = @config[:crypto]
    password = @config[:password]

    if crypto and password and device
      mk_loop( device, password, size, crypto )
    else
      @log.fatal { "crypto_init: must specify device, crypto and password in config file" }
    end
  end
end



############################### Hlavní program ###############################

def go
  debug_levels = {
    :debug => Logger::DEBUG,
    :info  => Logger::INFO,
    :warn  => Logger::WARN,
    :error => Logger::ERROR,
    :fatal => Logger::FATAL,
  }
  backup_name       = 'localhost'
  log_level         =  Logger::INFO
  test_mode         =  false
  config_dir        =  LnBackup::CONFIG_D
  log_file          =  LnBackup::LOG_FILE
  status_file_pref  =  LnBackup::STATUS_FILE_PREF
  status            =  false
  mount             =  false
  mountrw           =  false
  umount            =  false
  no_mirror         =  false
  nagios            =  false
  nagios_all        =  false
  source_prefix     =  nil
  target_dir_name   =  nil
  mirror_only       =  nil
  backup            =  nil
  pc_test           =  nil
  pc_backup         =  nil
  init_crypto       =  nil
  crypto_size       =  0
  pcs_status_f      =  LnBackup::PCS_STATUS
  pcs_status        =  nil
  delay             =  nil
  delay_denom       =  nil
  no_delete         =  nil
  no_acl            =  nil
  bin_log           =  nil
  max_iter          =  5
  
  ARGV.options do |p|
    p.banner = "Usage: #{$0} [options]\n"
    p.on('--backup-name=NAME'       ,String, "name of backup configuration (#{backup_name})") { |backup_name|}
    p.on('-l', '--log-file=FILE'    ,String, "file for logging (#{log_file})") { |log_file| }
    p.on(      '--status-file-pref=FILE' ,String, "prefix for file to store backup status (#{status_file_pref}), backup name will be added") { |status_file_pref| }
    p.on('-v', '--log-level=LEVEL'  ,String, 'set log level: debug,[info],warn,error,fatal') { |log_level| 
      symb = log_level.downcase.intern
      if debug_levels.has_key?(symb)
        log_level = debug_levels[symb]
      else
        puts p
        puts "Invalid log level #{log_level}"
        exit(1)
      end
    } 
    p.on('-c', '--config-dir=PATH'  ,String, 'configuration directory') { |config_dir| }
    p.on('-t', '--test'             , 'dry run (test mode)')  { |test_mode| }
    p.on('-m', '--no-mirror'        , 'skip creation of bootable mirror after backup') { |no_mirror| }
    p.on('-s', '--status'           , 'display lnbackup status information including list of available backups') { |status| }
    p.on('--backup'                 , 'run backup')                 { |backup| }
    p.on('--mount'                  , 'mount backup device ro')     { |mount| }
    p.on('--mountrw'                , 'mount backup device rw')     { |mountrw| }
    p.on('--umount'                 , 'umount backup device')       { |umount| }
    p.on('--nagios'                 , 'run as nagios plugin')       { |nagios| }
    p.on('--dump-log=FILE'          , 'parse bin. log and dump to STDOUT') { |bin_log| }
    p.on('--nagios-all'             , 'run as nagios plugin for all backups config directory') { |nagios_all| }
    p.on('--source-prefix=DIR'      , 'prefix the source directory given by configuration') { |source_prefix| }
    p.on('--target-dir-name=NAME'   , 'set backup target directory under backup root ([backup-name] if not given)') { |target_dir_name| }
    p.on('--mirror-only'            , 'only create bootable mirror from last backup')       { |mirror_only| }

    p.on('--pc-backup'              , 'run backup of PCs')                                  { |pc_backup| }
    p.on('--pc-mount-test'          , 'test if PCs configured for backup are accessible')   { |pc_test| }
    p.on('--pc-status'              , 'display PCs backup status')   { |pcs_status| }
    p.on('--pc-status-file=FILE'    , 'PCs backup status file') { |pcs_status_f| }

    p.on('--init-crypto[=SIZE]'     , 'initialize crypto loop device, optional SIZE in MB (ignored if block device)') { |crypto_size| 
      init_crypto = true 
    } 
    p.on('--delay=FLOAT'            , 'delay (sec) between processing objects') { |delay| delay = delay.to_f }
    p.on('--delay-denom=N'          , 'apply delay every N objects') { |delay_denom| delay_denom = delay_denom.to_i }
    p.on('--no-delete'              , 'don\'t remove old backups, return error when out of space') { |no_delete| no_delete = true }
    p.on('--no-acl'                 , 'don\'t restore ACL, don\'t generate fstab with ACL options') { |no_acl| no_acl = true }
    p.on('--version'                , 'display help') { puts p; exit(1) }
    p.on('--help'                   , 'display help') { puts p; exit(1) }
    p.on('--search-iter=NUMBER'     , 'number of backups to search for files not contained in the last backup (0 for unlimited, default 5)') { |mi| max_iter = mi.to_i }
    begin
      p.parse!(ARGV)
    rescue
      puts p
      exit(1)
    end
    if ( not status and not backup and not mount and not mountrw and not umount and not nagios and not nagios_all and
         not pc_test and not pc_backup and not init_crypto and not pcs_status and not mirror_only and not bin_log )
      puts p
      exit(1)
    end
  end

  if bin_log
    Marshal.restore( File.read(bin_log) ).each { |st| st.each_pair { |k,v| puts "#{k+' '*(30-k.length)}:\t#{v}" if k }; puts }
    exit
  end

  target_dir_name = backup_name unless target_dir_name
  
  lnbackup = LnBackup.new( :log_level         => log_level,
                           :log_file          => log_file,
                           :test_mode         => test_mode,
                           :config_dir        => config_dir,
                           :status_file_pref  => status_file_pref,
                           :source_prefix     => source_prefix,
                           :target_dir_name   => target_dir_name,
                           :delay             => delay,
                           :delay_denom       => delay_denom,
                           :no_delete         => no_delete,
                           :no_acl            => no_acl,
                           :max_iter          => max_iter
                       )

  res = 0
  if status
    # display status
    lnbackup.backup_status( backup_name, status_file_pref )

  elsif nagios
    # run nagios check
    res, message = lnbackup.nagios_check( backup_name )
    puts message

  elsif nagios_all
    # run nagios check
    res, message = lnbackup.nagios_check_all
    puts message

  elsif mount
    # mount backup ro
    return res if (res = lnbackup.config_init(backup_name)) != 0
    lnbackup.mount_backup(false)

  elsif mountrw
    # mount backup rw
    return res if (res = lnbackup.config_init(backup_name)) != 0
    lnbackup.mount_backup

  elsif umount
    # umount backup
    return res if (res = lnbackup.config_init(backup_name)) != 0
    lnbackup.umount_backup(true)
    
  elsif mirror_only
    # create only bootable mirror
    return res if (res = lnbackup.config_init(backup_name)) != 0
    return lnbackup.mirror_only( backup_name )

  elsif backup
    # run backup
    res = lnbackup.go_backup( backup_name, no_mirror )

  elsif pc_backup
    # run PCs backup -- backup PCs over cifs
    lnbackup.backup_pcs( pcs_status_f, no_delete )

  elsif pc_test
    # run PCs backup test -- test if shares for backup are accessible
    lnbackup.backup_pcs_test

  elsif init_crypto
    # initialize crypto device
    lnbackup.crypto_init(crypto_size)

  elsif pcs_status
    lnbackup.backup_pcs_status( pcs_status_f )
    
  else
    puts "Upps, we should never get here!"
    exit(1)
  end

  return res
end

if $0 == __FILE__
  exit go
end

