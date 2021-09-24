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
      :subproject => false,
    }

    listinput = {}

    OptionParser.new do |opts|
      opts.banner = "Usage: ticket list [-options] [<project>]"
      opts.on("-i", "--sort-id") do
        @config[:order] = "id"
      end
      opts.on("-u", "--sort-update-date") do
        @config[:order] = "date"
      end
      opts.on("-c", "--show-closed") do
        @config[:closed] = true
      end
      opts.on("-d", "--show-duedate") do
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
      opts.on("-s", "--subproject") do
        @config[:subproject] = true
      end
    end.order! args

    asyncUpdateMetaCache

    if @config[:closed] == false
      @cacheData.select! {|k, v| is_status_closed(v["status"]["name"]) == false}
    end

    if args.size > 0
      if @config[:subproject] == true
        pjtree = get_project_tree

        tmp1 = tmp2 = args.map {|arg| parse_projectspec(arg).to_i}
        count = 10
        while count > 0
          tmp1.each do |pjid|
            next if pjtree[pjid].nil?
            tmp2 += pjtree[pjid]
          end
          tmp2 = tmp2.uniq.sort
          break if tmp1 == tmp2
          tmp1 = tmp2
          count -= 1
        end

        @cacheData.select! do |k, v|
          tmp2.any? {|arg| arg == v["project"]["id"]}
        end
      else
        @cacheData.select! do |k, v|
          args.any? {|arg| parse_projectspec(arg).to_i == v["project"]["id"]}
        end
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
        raise "not implemented yet"
        # list_input @config[:listinput]
      elsif @config[:edit] == true
        edit_list
      elsif @config[:duedate] == true
        puts list_duedate
      elsif @config[:order] == "id"
        puts list_id
      else
        puts list_update_date
      end
    rescue
    end
  end

  def list_input input
    tmp = {}
    input.each do |line|
      if line =~ /^\+(\d+)\s+(\d+)\s+([\d\.\-]+)\s+(\w+)\s+(\w+)\s+([\d\-\/\+]+)\s+\(([^\)]+)\)\s+(.+)\s*$/
        id, done_ratio, estimatedhours, tracker, status, duedate, project, subject = $1, $2, $3, $4, $5, $6, $7, $8

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
        if estimatedhours != "-"
          tmp[id]["estimated_hours"] = estimatedhours.to_f
        end
      end
    end

    tmp.each do |id, data|
      thash = {"issue" => data}
      puts "update ticket #{id} with #{thash}"
      put_issue URI("#{@baseurl}/issues/#{id}.json"), thash
    end
  end

  def edit_list
    tmp = get_format_list("%-4d %3d %4s %-6s %-6s %-10s (%s) %s", ["id", "done_ratio", "estimated_hours", "tracker.name", "status.name", "due_date", "project.name", "subject"])
    draftFile = "#{@options["cachedir"]}/edit/listedit"
    draftFileOrig = "#{@options["cachedir"]}/edit/listedit.orig"

    prepareDraft draftFile, tmp
    ret = editDraft(draftFile)
    ret = `diff -U1 #{draftFileOrig} #{draftFile} | grep ^+ | grep -v '^+++ '`
    list_input ret.split("\n")
    cleanupDraft draftFile
  end

  def list_id
    get_format_list("%-4d %3d %-6s %-6s (%s) %s%s", ["id", "done_ratio", "tracker.name", "status.name", "project.name", "relations", "subject"])
  end

  def list_update_date
    get_format_list("%-4d %3d %-6s %-6s %s (%s) %s%s", ["id", "done_ratio", "tracker.name", "status.name", "updated_on", "project.name", "relations", "subject"])
  end

  def list_duedate
    get_format_list("%-4d %3d %-6s %-6s %-10s (%s) %s%s", ["id", "done_ratio", "tracker.name", "status.name", "due_date", "project.name", "relations", "subject"])
  end

  def accessHash h, elms
    tmp = h
    elms.each do |elm|
      tmp = tmp[elm]
    end
    return "-" if tmp.nil?
    return tmp
  end

  def rel_short_string id, rel
    if id.to_i == rel["issue_to_id"]
      return "#{rel["issue_id"]}#{get_short_relation(rel["relation_type"])}"
    else
      return "#{get_short_relation(rel["relation_type"])}#{rel["issue_to_id"]}"
    end
  end

  def get_format_list fmt, columns
    tmp = @keys.map do |k|
      fmt % columns.map do |cl|
        if cl == "updated_on"
          Time.parse(@cacheData[k][cl]).getlocal.strftime("%Y/%m/%d %H:%M")
        elsif cl == "relations"
          if @cacheData[k][cl].empty?
            ""
          else
            "[#{@cacheData[k][cl].map {|rel| rel_short_string(k, rel)}.join(",")}] "
          end
        else
          accessHash(@cacheData[k], cl.split("."))
        end
      end
    end
    return tmp.join("\n")
  end
end
