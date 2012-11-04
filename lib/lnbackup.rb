require 'lnbackup/backup.rb'
require 'lnbackup/freespace.rb'
require 'lnbackup/util.rb'
require 'lnbackup/version.rb'

require 'find'
require 'date'
#require 'ftools'
require 'fileutils'
begin 
  require 'filesystem'
rescue LoadError
  require 'sys/filesystem'
  include Sys
  FileSystem = Filesystem
end


require 'logger'
require 'time'

