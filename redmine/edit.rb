# coding: utf-8

module RedmineCmdEdit
  def edit args
    @options[:allyes] = false
    @options[:inputfile] = nil

    OptionParser.new do |opts|
      opts.banner = "Usage: ticket edit [-options] <TicketID|WikiID> [...]"
      opts.on("--all-yes") do
        @options[:allyes] = true
      end
      opts.on("-f file", "--file") do |f|
        raise "File #{f} not found." if not File.exist? f
        @options[:inputfile] = f
      end
    end.order! args

    if args.size == 0
      raise "no ID given"
    elsif @options[:inputfile]
      if args.size != 1
        raise "When input file is given, you have to specify exactly one ID to be updated."
      end
      id = args[0]

      case id_type id
      when "wiki"
        project = id.split("-")[0]
        wikiname = get_wikiname id
        puts "Wiki ID: #{id}, project: #{project}, wikiname: #{wikiname}"
        uploadData = parseWikiDraftData @options[:inputfile]
        uploadNewWiki project, wikiname, uploadData
      when "ticket"
        raise "issue #{id} not found" if @cacheData[id].nil?
        begin
          @cacheData[id] = updateCacheIssue id
        rescue
          puts "updateCacheIssue failed, maybe connection is temporary unavailable now."
        end
        uploadInputfile id, @options[:inputfile]
        return
      else
        raise "invalid ID #{id}"
      end
    else
      # prepare drafts for each input
      args.each do |id|
        case id_type id
        when "wiki"
          puts "Wiki ID: #{id}"
          project = id.split("-")[0]
          begin
            wikiname = get_wikiname id
          rescue
            puts "Failed to get wiki data from server maybe due to network connection."
          end
          # TODO: no connection
          next if wikiname.nil?

          # TODO: need refactoring
          uri = URI.encode("#{@baseurl}/projects/#{project}/wiki/#{wikiname}.json")
          params = {"key" => @serverconf["token"]}
          response = __get_response(uri, params)["wiki_page"]
          # puts ">>> prepareDraft #{draftFile}, [#{response["text"]}]"
          prepareDraft draftPath(id), draftWikiData(wikiname, response["text"].gsub(/\r\n?/, "\n"))
        when "ticket"
          raise "issue #{id} not found" if @cacheData[id].nil?
          draftFile = "#{@options["cachedir"]}/edit/#{id}.#{@serverconf["format"]}"
          prepareDraft draftFile, draftIssueData(id, @cacheData[id])
        else
          raise
        end
      end

      asyncUpdateMetaCache

      t1 = Time.now
      while true
        editDrafts args
        diffDrafts args
        action = ask_action
        case action
        when "upload"
          uploadDrafts args, t1
          break
        when "cancel"
          puts "Moved draft file(s) to #{@options["cachedir"]}/deleted_drafts"
          cancelDrafts args
          break
        when "save"
          saveDrafts args, t1
          break
        end
      end
    end
  end

  # 一部だけアップロードに失敗するケース、コンフリクトを検出したケースでは、
  # 無理にリトライはせずドラフトのまま終了する。
  def uploadDrafts ids, t1
    t2 = Time.now
    ids.each do |id|
      if id_type(id) == "wiki"
        __uploadWikiDraft id
      elsif id_type(id) == "ticket"
        __uploadTicketDraft id, ((t2 - t1).to_i / 60)
      end
    end
  end

  def __uploadTicketDraft id, elapsed
    uploadData, duration = parseDraftData draftPath(id)
    ret = system("diff -U3 #{draftOrigPath(id)} #{draftPath(id)} > /dev/null")
    if ret == true
      puts "no change on draft file."
      return
    end
    apply_ticket_rules uploadData
    basediff = checkConflict id
    if not basediff.empty?
      open(draftPath(id), 'a') do |f|
        f.puts ""
        f.puts "### CONFLICT ### YOU NEED TO CONFLICET THE BELOW DIFF MANUALLY"
        f.puts basediff
      end
      puts "conflict detected (#{id}), edit it again."
      return
    end
    uploadIssue id, uploadData

    # createTimeEntry (TODO: 複数チケットをオープンしている場合分割する?)
    duration = getDraftDuration(draftPath(id), elapsed)
    @options[:logger].debug("duration #{duration}, diff #{elapsed}")
    createTimeEntry id, duration
    puts "created time_entry (#{duration} min) to ID #{id}"

    # update succeeded so clean up draft files
    cleanupDraft draftPath(id)
  end

  def __uploadWikiDraft id
    project = id.split("-")[0]
    wikiname = get_wikiname(id)
    uploadData = parseWikiDraftData draftPath(id)
    @options[:logger].debug(uploadData)
    response = uploadNewWiki project, wikiname, uploadData
    cleanupDraft draftPath(id)
  end

  # この条件はかなり雑
  def id_type str
    if str =~ /-/
      return "wiki"
    else
      return "ticket"
    end
  end

  def edit_single_ticket id
    # TODO: キャッシュディレクトリは draft.rb 側で参照するように
    draftFile = "#{@options["cachedir"]}/edit/#{id}.#{@serverconf["format"]}"
    prepareDraft draftFile, draftIssueData(id, @cacheData[id])

    asyncUpdateMetaCache

    t1 = Time.now
    ret = ask_ticket_upload id, draftFile, t1
    return if ret == false
    t2 = Time.now

    duration = getDraftDuration(draftFile, ((t2 - t1).to_i / 60))
    @options[:logger].debug("duration #{duration}, diff #{((t2 - t1).to_i / 60)}")
    createTimeEntry id, duration
    puts "created time_entry (#{duration} min) to ID #{id}"

    # update succeeded so clean up draft files
    cleanupDraft draftFile
  end

  def ask_ticket_upload id, draftFile, t1
    updated = false
    while true
      updated = editDraft draftFile
      uploadData, duration = parseDraftData draftFile

      if @options[:allyes] == true
        break
      else
        puts "Current server target is #{@options[:server]}"
        puts "You really upload this change? (y/Y: yes, n/N: no, s/S: save draft, e/E: edit again): "
        input = STDIN.gets.chomp
        if input[0] == 'n' or input[0] == 'N'
          cleanupDraft draftFile
          puts "Draft file is moved to #{@options["cachedir"]}/deleted_drafts/#{id}.#{@serverconf["format"]}, if you accidentally cancel the edit, please restore your draft file from it."
          return false
        elsif input[0] == 's' or input[0] == 'S'
          saveDraftDuration draftFile, ((Time.now - t1).to_i / 60)
          return false
        elsif input[0] == 'y' or input[0] == 'Y'
          true
        else
          next
        end
      end

      begin
        apply_ticket_rules uploadData
      rescue
      end

      break if updated == false

      conflict = checkConflict id
      if not conflict.empty?
        open(draftFile, 'a') do |f|
          f.puts ""
          f.puts "### CONFLICT ### YOU NEED TO CONFLICET THE BELOW DIFF MANUALLY"
          f.puts conflict
        end
        next
      end

      uploadIssue id, uploadData
      break
    end
    return true
  end

  def ask_action
    if @options[:allyes] == true
      return "upload"
    else
      puts "Current server target is #{@options[:server]}"
      puts "You really upload this change? (y/Y: yes, n/N: no, s/S: save draft, e/E: edit again): "
      input = STDIN.gets.chomp
      if input[0] == 'n' or input[0] == 'N'
        return "cancel"
      elsif input[0] == 's' or input[0] == 'S'
        return "save"
      elsif input[0] == 'y' or input[0] == 'Y'
        return "upload"
      else
        return "editagain"
      end
    end
  end

  def checkConflict id
    draftFileOrig = "#{@options["cachedir"]}/edit/#{id}.#{@serverconf["format"]}.orig"
    conflictFile = "#{@options["cachedir"]}/edit/#{id}.#{@serverconf["format"]}.conflictcheck"
    prepareDraft conflictFile, draftIssueData(id, updateCacheIssue(id))

    ret = `diff -U3 #{draftFileOrig} #{conflictFile}`
    system "mv #{conflictFile} #{draftFileOrig}"
    return ret
  end

  def uploadIssue id, draftData
    uri = URI("#{@baseurl}/issues/#{id}.json")
    response = put_issue uri, draftData

    case response
    when Net::HTTPSuccess, Net::HTTPRedirection
      puts "upload done"
    else
      raise response.value
    end
  end

  private

  def draftIssueData id, data
    tmp = data

    type = tmp["tracker"]["name"]
    priority = tmp["priority"]["name"]
    project = tmp["project"]["name"]
    status = tmp["status"]["name"]
    subject = tmp["subject"]
    description = tmp["description"]
    progress = tmp["done_ratio"]
    estimatedTime = tmp["estimated_hours"]
    startDate = tmp["start_date"]
    dueDate = tmp["due_date"]
    parent = tmp["parent"].nil? ? "null" : tmp["parent"]["id"]
    assignedTo = tmp["assigned_to"].nil? ? "null" : tmp["assigned_to"]["name"]

    if @options[:onlyDescription] == true
      return description.gsub(/\r\n?/, "\n")
    end

    editdata = []
    editdata << "---"
    editdata << "ID: #{id}"
    editdata << "Progress: #{progress}"
    editdata << "Status: #{status}"
    editdata << "Subject: #{subject}"
    editdata << "Project: #{project}"
    editdata << "Type: #{type}"
    editdata << "Priority: #{priority}"
    editdata << "EstimatedTime: #{estimatedTime}"
    editdata << "StartDate: #{startDate}"
    editdata << "DueDate: #{dueDate}"
    editdata << "Parent: #{parent}"
    begin
      editdata << "Assigned: #{assignedTo}" if @serverconf["setting"]["userlist"] == true
    rescue
    end
    editdata << "Duration:"
    # editdata << "# OpenedOn: #{Time.now.strftime("%Y-%m-%d %H:%M")}"
    editdata << "@@@ lines from here to next '---' line is considered as note/comment"
    editdata << "---"
    editdata << description.gsub(/\r\n?/, "\n")
    editdata << ""
    return editdata.join("\n")
  end

  def apply_ticket_rules uploadData
    updated = false
    rules = @serverconf["setting"]["issuerules"]

    if rules["autowip"]
      if uploadData["issue"]["done_ratio"] > 0 and
        uploadData["issue"]["status_id"] == default_state(uploadData["issue"]["tracker_id"])
        uploadData["issue"]["status_id"] = parse_statusspec(rules["autowip"])
        updated = true
      end
    end

    if rules["autostartdate"]
      if uploadData["issue"]["start_date"] == "" and
        uploadData["issue"]["status_id"] != default_state(uploadData["issue"]["tracker_id"])
        uploadData["issue"]["start_date"] = parse_date("0")
        updated = true
      end
    end

    if rules["closeclearpriority"]
      if is_status_closed uploadData["issue"]["status_id"]
        uploadData["issue"]["priority_id"] = default_priority
        updated = true
      end
    end

    if rules["setduedateonclose"]
      if uploadData["issue"]["due_date"] == "" and is_status_closed uploadData["issue"]["status_id"]
        uploadData["issue"]["due_date"] = parse_date("0")
        updated = true
      end
    end

    return updated
  end

  # TODO: 配置再検討、共通関数
  def default_state tracker
    tmp = @metaCacheData["trackers"].find {|t| t["id"] == tracker}
    return tmp["default_status"]["id"]
  end

  def uploadInputfile id, inputfile
    uploadData, duration = parseDraftData inputfile
    begin
      apply_ticket_rules uploadData
    rescue
    end
    uploadIssue id, uploadData
    if duration
      createTimeEntry id, duration
      puts "created time_entry (#{duration} min) to ID #{id}"
    end
  end
end
