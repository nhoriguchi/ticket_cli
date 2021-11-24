# coding: utf-8

module GrowiCmdStatus
  def status args
    OptionParser.new do |opts|
      opts.banner = "Usage: ticket status [-options]"
      opts.on("-d", "--diff") do
        @options[:showdiff] = true
      end
    end.order! args

    server = @options["servers"][@options[:server]]
    puts "Server Name: #{@options[:server]}"
    puts "Base URL: #{server["baseurl"]}:#{server["baseport"]}/#{server["baseapi"]}"
    puts "Cache Directory: #{@options["cachedir"]}"
    puts ""
    drafts = find_saved_draft
    puts "Saved drafts:" if not drafts.empty?

    if @options[:showdiff] == true
      diffDrafts drafts
      exit
    end

    drafts.each do |tid|
      tmp = @cacheData.select {|k,v| v["id"] == tid}
      next if tmp.empty?
      path = tmp.keys[0]
      puts "  #{tid}: #{path}"
    end
  end

  def find_saved_draft
    Dir.glob("#{@options["cachedir"]}/edit/*.#{@serverconf["format"]}").map do |elm|
      File.basename(elm, ".#{@serverconf["format"]}")
    end
  end
end
