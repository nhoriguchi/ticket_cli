# coding: utf-8

# TODO: sort in ascending/descending order
# TODO: colorize
# TODO: project specific
# TODO: hierarchy support
# TODO: progress support
# TODO: priority support
# TODO: relation support
# TODO: close filter
module RedmineCmdList
  def list args
    @config = {
      :order => "id",
      :closed => false,
      :duedate => false,
      :listinput => nil,
    }

    listinput = {}

    OptionParser.new do |opts|
      opts.banner = "Usage: ticket list [-options] [<project>]"
      opts.on("-i", "--sort-id") do
        @config[:order] = "id"
      end
      opts.on("-d", "--sort-update-date") do
        @config[:order] = "date"
      end
      opts.on("-c", "--show-closed") do
        @config[:closed] = true
      end
      opts.on("--show-duedate") do
        @config[:duedate] = true
      end
      opts.on("--show-metadata") do
        pp @metaCacheData
        exit
      end
      opts.on("--list-input file") do |f|
        @config[:closed] = true
        @config[:listinput] = f
      end
    end.order! args

    if @config[:closed] == false
      @cacheData.select! {|k, v| is_status_closed(v["status"]["name"]) == false}
    end

    if @config[:order] == "id"
      @keys = @cacheData.keys.sort {|a, b| b.to_i <=> a.to_i} 
    elsif @config[:order] == "date"
      @keys = @cacheData.keys.sort {|a, b| @cacheData[b]["updated_on"] <=> @cacheData[a]["updated_on"]}
    end

    if @config[:listinput]
      list_input
    elsif @config[:duedate] == true
      list_duedate
    elsif @config[:order] == "id"
      list_id
    else
      list_update_date
    end
  end

  def list_input
    tmp = {}
    File.read(@config[:listinput]).split("\n").each do |line|
      if line =~ /(\d+)\s+(\d+)\s+(\w+)\s+(\w+)\s+/
        id, done_ratio, tracker, status = $1, $2, $3, $4
        if @cacheData[id]["done_ratio"] != done_ratio.to_i or @cacheData[id]["tracker"]["name"] != tracker or @cacheData[id]["status"]["name"] != status
          tmp[id] = {
            "done_ratio" => done_ratio.to_i,
            "tracker_id" => tracker_name_to_id(tracker),
            "status_id" => status_name_to_id(status)
          }
          pp id
          pp tmp[id]
        end
      end
    end

    tmp.each do |id, data|
      thash = {"issue" => data}
      puts thash
      put_issue URI("#{@baseurl}/issues/#{id}.json"), thash
    end
  end

  def list_id
    @keys.each do |k|
      c = @cacheData[k]
      list_format1 k, c["done_ratio"], c["tracker"]["name"], c["status"]["name"], c["project"]["name"], c["subject"]
    end
  end

  def list_update_date
    @keys.each do |k|
      c = @cacheData[k]
      list_format2 c["id"], c["done_ratio"], c["tracker"]["name"], c["status"]["name"], c["updated_on"], c["project"]["name"], c["subject"]
    end
  end

  def list_duedate
    @keys.each do |k|
      c = @cacheData[k]
      duedate = c["due_date"]
      duedate = "-" if duedate == nil
      pp c
      list_format3 c["id"], c["done_ratio"], c["tracker"]["name"], c["status"]["name"], duedate, c["project"]["name"], c["subject"]
    end
  end

  def list_format1 id, ratio, tracker, status, project, subject
      printf "%-4d %3d %-6s %-6s (%s) %s\n", id, ratio, tracker[0..5], status[0..5], project, subject
  end

  def list_format2 id, ratio, tracker, status, updated, project, subject
      printf "%-4d %3d %-6s %-6s %s (%s) %s\n", id, ratio, tracker[0..5], status[0..5], updated, project, subject
  end

  def list_format3 id, ratio, tracker, status, duedate, project, subject
      printf "%-4d %3d %-6s %-6s %-10s (%s) %s\n", id, ratio, tracker[0..5], status[0..5], duedate, project, subject
  end
end
