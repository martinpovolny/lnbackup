spec = Gem::Specification.new do |s|
  s.name        = 'lnbackup'
  s.version     = '2.0'
  s.summary     = "Hardlink backup system for hard drives."
  s.description = %{
Lnbackup is a hardlink backup system for hard drives. 

Lnbackup operates in a way similar to the '--link-dest' switch in rsync.

It creates incremental backups using hardlinks so that each backup seems like a full backup. Additionaly it can make (using hardlinks) bootable mirror from the latest backup.

Obviously the target filesystem of lnbackup needs to support hardlinks.

It's run on ~200 servers for several years and it is considered stable.

Read the man page for more information.}
  s.files               = Dir['lib/**/*.rb'] + Dir['bin/*'] #+ Dir['test/**/*.rb']
  s.require_path        = 'lib'
  #s.autorequire         = 'builder'
  s.has_rdoc            = true
  #s.extra_rdoc_files    = Dir['[A-Z]*']
  s.rdoc_options        << '--title' <<  'Lnbackup -- hardlink backup system for hard drives.'
  s.author              = "Martin Povolny"
  s.email               = "martin.povolny@solnet.cz"
  s.homepage            = "https://github.com/martinpovolny/lnbackup"
end
