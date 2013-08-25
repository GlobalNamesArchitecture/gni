
module GNI::Spec
  module Helpers
  end
end

# truncates all tables
def truncate_all_tables options = { }
  options[:verboze] ||= false
  ActiveRecord::Base.connection.tables.each  do |table|
    unless table == 'schema_migrations'
      puts "[#{conn.instance_eval { @config[:database] }}].`#{table}`" if options[:verbose]
      ActiveRecord::Base.connection.execute "delete from #{table}" #"TRUNCATE TABLE`#{table}`"
    end
  end
end

def login_as options = { }
  page.driver.post(session_path, { 
      'login' => options[:login], 
      'password' => options[:password] })
end

class ActiveRecord::Base

# truncate's this model's table
  def self.truncate
    connection.execute "delete from #{table_name}"#"TRUNCATE TABLE #{ table_name }"
  rescue => ex
    puts "#{ self.name }.truncate failed ... does the table exist?  #{ ex }"
  end
end