# coding: utf-8

require 'differ'

module RedmineCmdEdit
  def edit args
    allyes = false

    OptionParser.new do |opts|
      opts.banner = "Usage: ticket edit [-options] id"
      opts.on("--all-yes") do
        allyes = true
      end
    end.order! args

    id = args[0]
    raise "issue #{id} not found" if @cacheData[id].nil?
    begin
      updateCacheIssue id
    rescue
      puts "updateCacheIssue failed, maybe connection is temporary unavailable now."
    end

    @issueOrigin = @cacheData[id]

    # TODO: キャッシュディレクトリは draft.rb 側で参照するように
    draftFile = "#{@options["cachedir"]}/edit/#{id}.#{@serverconf["format"]}"
    prepareDraft draftFile, draftData(id).join("\n")

    asyncUpdateMetaCache

    t1 = Time.now
    updated = false
    while true
      updated = editDraft draftFile
      uploadData, duration = parseDraftData draftFile

      if allyes == true
        break
      else
        puts "You really upload this change? (y/Y: yes, n/N: no, s/S: save draft, e/E: edit again): "
        input = STDIN.gets.chomp
        if input[0] == 'n' or input[0] == 'N'
          cleanupDraft draftFile
          puts "Draft file is moved to #{@options["cachedir"]}/deleted_drafts/#{id}.#{@serverconf["format"]}, if you accidentally cancel the edit, please restore your draft file from it."
          return
        elsif input[0] == 's' or input[0] == 'S'
          saveDraftDuration draftFile, ((Time.now - t1).to_i / 60)
          return
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
          f.puts "### CONFLICT ### YOU NEED TO CONFLICET THE BELOW DIFF MANUALLY"
          conflict.each do |k, v|
            if k != "description"
              f.puts "#+#{k}: #{v}"
            end
          end
          if conflict["description"]
            tmp = Differ.diff_by_char(uploadData["issue"]["description"], @issueOrigin["description"].tr("\r", ''))
            f.puts tmp.format_as(:ascii)
          end
        end
        next
      end

      uploadIssue id, uploadData
      break
    end
    t2 = Time.now

    duration = getDraftDuration(draftFile, ((t2 - t1).to_i / 60))
    createTimeEntry id, duration
    puts "created time_entry (#{duration} min) to ID #{id}"

    # update succeeded so clean up draft files
    cleanupDraft draftFile
  end

  def checkConflict id
    params = {
      "status_id" => "*",
      "include" => "relations,attachments",
      "key" => @serverconf["token"]
    }

    server = __get_response("#{@baseurl}/issues/#{id}.json", params)["issue"]
    conflict = {}

    [ "project", "tracker", "status", "priority", "author", "assigned_to", "subject", "description", "start_date", "due_date", "done_ratio", "is_private", "estimated_hours", "created_on", "updated_on", "closed_on", "attachments"].each do |elm|
      if server[elm] != @issueOrigin[elm]
        conflict[elm] = @issueOrigin[elm].tr("\r", '')
      end
    end

    @issueOrigin = server

    return conflict
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

  def draftData id
    tmp = @cacheData[id]

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
    editdata << "# OpenedOn: #{Time.now.strftime("%Y-%m-%d %H:%M")}"
    editdata << "@@@ lines from here to next '---' line is considered as note/comment"
    editdata << "---"
    editdata << description.gsub(/\r\n?/, "\n")
    editdata << ""
    return editdata
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
end
