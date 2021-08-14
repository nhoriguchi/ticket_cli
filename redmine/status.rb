# coding: utf-8

module RedmineCmdStatus
  def status args
    OptionParser.new do |opts|
      opts.banner = "Usage: #{$0} [-options]"
    end.order! args

    server = @options["servers"][@options[:server]]
    puts "Server Name: #{@options[:server]}"
    puts "Base URL: #{server["baseurl"]}:#{server["baseport"]}/#{server["baseapi"]}"
    puts "Cache Directory: #{@options["cachedir"]}"
    puts ""
    drafts = find_saved_draft
    puts "Saved drafts:" if not drafts.empty?
    drafts.each do |tid|
      puts "  #{tid}: #{@cacheData[tid]["subject"]}"
    end
  end

  def find_saved_draft
    Dir.glob("#{@options["cachedir"]}/edit/*.#{@serverconf["format"]}").map do |elm|
      File.basename(elm, ".#{@serverconf["format"]}")
    end
  end
end
