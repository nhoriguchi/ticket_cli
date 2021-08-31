# coding: utf-8

module RedmineCmdStatus
  def status args
    OptionParser.new do |opts|
      opts.banner = "Usage: ticket [-options]"
    end.order! args

    server = @options["servers"][@options[:server]]
    puts "Server Name: #{@options[:server]}"
    puts "Base URL: #{server["baseurl"]}:#{server["baseport"]}/#{server["baseapi"]}"
    puts "Cache Directory: #{@options["cachedir"]}"
    puts ""
    drafts = find_saved_draft
    puts "Saved drafts:" if not drafts.empty?
    drafts.each do |tid|
      if @cacheData[tid]
        puts "  #{tid}: #{@cacheData[tid]["subject"]}"
      else
        case tid
        when /^\d+-\d+$/
          # draft for wiki pages
          load_wiki_pages

          tmp = @wiki_pages.find {|a| a["wpid"] == tid}
          next if tmp.nil?
          wikiname = tmp["title"]
          puts "  #{tid}: #{wikiname}"
        when "new"
          # draft for new ticket
          draftFile = "#{@options["cachedir"]}/edit/new.#{@serverconf["format"]}"
          uploadData, duration = parseDraftData draftFile
          puts "  #{tid}: #{uploadData["issue"]["subject"]}"
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
