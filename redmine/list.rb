# coding: utf-8

require "date"

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
      :edit => false,
      :reversed => false,
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
        @config[:order] = "duedate"
      end
      opts.on("-e", "--edit") do
        @config[:edit] = true
        @config[:order] = "duedate"
      end
      opts.on("--show-metadata") do
        pp @metaCacheData
        exit
      end
      opts.on("--list-input file") do |f|
        @config[:closed] = true
        @config[:listinput] = f
      end
      opts.on("-r", "--reverse", "逆順で表示") do |f|
        @config[:reversed] = true
      end
    end.order! args

    asyncUpdateMetaCache

    if @config[:closed] == false
      @cacheData.select! {|k, v| is_status_closed(v["status"]["name"]) == false}
    end

    if args.size > 0
      @cacheData.select! do |k, v|
        args.any? {|arg| parse_projectspec(arg) == v["project"]["id"]}
      end
    end

    if @config[:order] == "id"
      @keys = @cacheData.keys.sort {|a, b| b.to_i <=> a.to_i}
    elsif @config[:order] == "date"
      @keys = @cacheData.keys.sort {|a, b| @cacheData[b]["updated_on"] <=> @cacheData[a]["updated_on"]}
    elsif @config[:order] == "duedate"
      @keys = @cacheData.keys.sort do |a, b|
        tmpa = @cacheData[a]["due_date"]
        tmpb = @cacheData[b]["due_date"]
        tmpa = "0000-00-00" if tmpa.nil?
        tmpb = "0000-00-00" if tmpb.nil?
        tmpb <=> tmpa
      end
    end

    if @config[:reversed] == true
      @keys.reverse!
      # @cacheData = @cacheData.sort_by{|k, _| k.to_i}.to_h
    end

    begin
      if @config[:listinput]
        raise
        # list_input @config[:listinput]
      elsif @config[:edit] == true
        edit_list
      elsif @config[:duedate] == true
        puts list_duedate
      elsif @config[:order] == "id"
        list_id
      else
        list_update_date
      end
    rescue
    end
  end

  def list_input input
    tmp = {}
    input.each do |line|
      if line =~ /^\+(\d+)\s+(\d+)\s+(\w+)\s+(\w+)\s+([\d\-\/\+]+)\s+\(([^\)]+)\)\s+(.+)\s*$/
        id, done_ratio, tracker, status, duedate, project, subject = $1, $2, $3, $4, $5, $6, $7

        if duedate == "-"
          duedate = nil
        else
          duedate = parse_date(duedate)
        end

        tmp[id] = {
          "done_ratio" => done_ratio.to_i,
          "tracker_id" => parse_trackerspec(tracker),
          "status_id" => parse_statusspec(status),
          "due_date" => duedate,
          "project_id" => parse_projectspec(project),
          "subject" => subject,
        }
      end
    end

    tmp.each do |id, data|
      thash = {"issue" => data}
      puts "update ticket with #{thash}"
      put_issue URI("#{@baseurl}/issues/#{id}.json"), thash
    end
  end

  def edit_list
    tmp = list_duedate
    draftFile = "#{@options["cachedir"]}/edit/listedit"
    draftFileOrig = "#{@options["cachedir"]}/edit/listedit.orig"

    prepareDraft draftFile, tmp
    ret = editDraft(draftFile)
    ret = `diff -U1 #{draftFileOrig} #{draftFile} | grep ^+ | grep -v '^+++ '`
    list_input ret.split("\n")
    cleanupDraft draftFile
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
    tmp = @keys.map do |k|
      c = @cacheData[k]
      duedate = c["due_date"]
      duedate = "-" if duedate == nil
      list_format3 c["id"], c["done_ratio"], c["tracker"]["name"], c["status"]["name"], duedate, c["project"]["name"], c["subject"]
    end
    tmp.join("\n")
  end

  def list_format1 id, ratio, tracker, status, project, subject
    printf "%-4d %3d %-6s %-6s (%s) %s\n", id, ratio, tracker[0..5], status[0..5], project, subject
  end

  def list_format2 id, ratio, tracker, status, updated, project, subject
    printf "%-4d %3d %-6s %-6s %s (%s) %s\n", id, ratio, tracker[0..5], status[0..5], updated, project, subject
  end

  def list_format3 id, ratio, tracker, status, duedate, project, subject
    tmp = "%-4d %3d %-6s %-6s %-10s (%s) %s" % [id, ratio, tracker[0..5], status[0..5], duedate, project, subject]
    return tmp
  end
end
