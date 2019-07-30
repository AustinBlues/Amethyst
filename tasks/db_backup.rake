require 'find'
require 'fileutils'

namespace :db do
  desc "Backup database."
  task :backup => :environment do
    datestamp = Time.now.strftime("%Y-%m-%d_%H-%M-%S")
    base_path = ENV["DIR"] || "db" 
    backup_base = File.join(base_path, 'backup')
    backup_folder = File.join(backup_base, datestamp)
    backup_file = File.join(backup_folder, "#{RACK_ENV}_dump.sql.gz")    
    FileUtils.makedirs(backup_folder)
    uri = Sequel::Model.db.uri
    db_config = {database: uri[/\w+$/], username: uri.match(%r{//(\w+):})[1], password: uri.match(%r{:(\w+)@})[1]}
    sh "mysqldump -u #{db_config[:username]} -p#{db_config[:password]} -Q --add-drop-table --add-locks=FALSE --lock-tables=FALSE #{db_config[:database]} | gzip -c > #{backup_file}"     
    puts "Created backup: #{backup_file}"

    all_backups = Dir.glob("#{backup_base}/[0-9]*")
    all_backups.sort!
    max_backups = (ENV["MAX"] || 20).to_i
    if all_backups.size <= max_backups
      puts "#{all_backups.size} backups available" 
    else
      unwanted_backups = all_backups.first(all_backups.size - max_backups)
      unwanted_backups.each do |unwanted_backup|
        FileUtils.rm_rf(unwanted_backup)
        puts "deleted #{unwanted_backup}" 
      end
      puts "Deleted #{unwanted_backups.length} backups, #{all_backups.length - unwanted_backups.length} backups available" 
    end
  end
end

