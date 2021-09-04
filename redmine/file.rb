# coding: utf-8

module RedmineCmdFile
  def file args
    @config = {
      :list => nil,
      :upload => nil,
      :remove => nil,
    }

    OptionParser.new do |opts|
      opts.banner = "Usage: ticket file"
      opts.on("-l", "--list") do
        @config[:list] = true
      end
      opts.on("-u id", "--upload id") do |id|
        @config[:upload] = id
      end
      opts.on("-r", "--remove") do
        @config[:remove] = true
      end
    end.order! args

    if @config[:list]
      list_files
    elsif @config[:upload]
      upload_files @config[:upload], args
    elsif @config[:remove]
      remove_files args
    end
  end

  def list_files
    @attachments = []
    @cacheData.each do |k, v|
      v["attachments"].each do |a|
        tmp = a.merge({"issue" => k})
        tmp["content_url"] = "/" + tmp["content_url"].split("/")[3..-1].join("/")
        @attachments << tmp
      end
    end

    @attachments.sort_by {|v| v["id"]}.each do |a|
      puts "#{a["id"]}\t#{a["issue"]}\t#{a["content_url"]}"
    end
  end

  def upload_files id, files
    files.each do |f|
      uri = URI("#{@baseurl}/uploads.json?filename=#{f}")
      attach_file_to_issue uri, f
    end
  end

  def attach_file_to_issue uri, file
    raise "not implemented. please use web browser to attach files on issues/wikis"
  end

  def remove_files fileids
  end
end
