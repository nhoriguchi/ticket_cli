# coding: utf-8

module RedmineCmdStatus
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
      if @cacheData[tid]
        puts "  #{tid}: (#{@cacheData[tid]["project"]["name"]}) #{@cacheData[tid]["subject"]}"
      else
        case tid
        when /^\d+-\d+$/
          updateWikiCache
          wikiname = @wikiCacheData[tid]["title"]
          pjid = @wikiCacheData[tid]["project_id"]
          # project?
          puts "  #{tid}: (#{project_name(pjid.to_s)}) #{wikiname}"
        when /^new/
          # draft for new ticket
          draftFile = "#{@options["cachedir"]}/edit/#{tid}.#{@serverconf["format"]}"
          begin
            uploadData, duration = parseDraftData draftFile
            puts "  #{tid}: #{uploadData["issue"]["subject"]}"
          rescue
            puts "  #{tid}: ..."
          end
        end
      end
    end
  end

  def find_saved_draft
    Dir.glob("#{@options["cachedir"]}/edit/*.#{@serverconf["format"]}").map do |elm|
      File.basename(elm, ".#{@serverconf["format"]}")
    end
  end
end
