# coding: utf-8

module RedmineCmdNew
  def new args
    allyes = false
    inputfile = nil
    draftFile = nil
    cliinput = {
      :tracker => @serverconf["setting"]["defaulttracker"],
      :parent => "null",
    }

    OptionParser.new do |opts|
      opts.banner = "Usage: #{$0} [-options]"
      opts.on("-p project_spec", "--project") do |pjspec|
        cliinput[:project] = pjspec
      end
      opts.on("-s 'subject'", "--subject") do |subject|
        cliinput[:subject] = subject
      end
      opts.on("-D 'description'", "--description") do |description|
        cliinput[:description] = description
      end
      opts.on("-t tracker_spec", "--tracker") do |trspeck|
        cliinput[:tracker] = trspeck
      end
      opts.on("-P parent_ticket_id", "--parent") do |pid|
        cliinput[:parent] = pid
      end
      opts.on("-f file", "--file", "upload given draft file directly to Redmine server.") do |f|
        inputfile = f
      end
      opts.on("-d draftFile", "--draftfile", "restart editing with given draft.") do |f|
        draftFile = f
      end
      # TODO: more options
    end.order! args

    if cliinput[:project] and cliinput[:subject]
      generateDraftFromParams cliinput
      return
    end

    if inputfile
      uploadNewInputfile inputfile
      return
    end

    # TODO: if you find multiple draft (whose name starts with "new.XXXX"
    # ask which to use or not use anything.
    if draftFile.nil?
      draftFile = "#{@options["cachedir"]}/edit/new.#{@serverconf["format"]}"
      prepareDraft draftFile, draftNewData.join("\n")
    else
      draftFile = "#{@options["cachedir"]}/edit/#{draftFile}.#{@serverconf["format"]}"
      draftData = File.read(draftFile).split("\n")
      if draftData[0] != "---"
        draftData = draftNewData + draftData
        File.write(draftFile, draftData.join("\n"))
      end
    end

    asyncUpdateMetaCache

    t1 = Time.now
    while true
      editDraft draftFile

      if allyes == true
        break
      else
        puts "You really upload this change? (y/Y: yes, n/N: no, s/S: save draft, e/E: edit again): "
        input = STDIN.gets.chomp
        if input[0] == 'n' or input[0] == 'N'
          cleanupDraft draftFile
          puts "Draft file is moved to #{@options["cachedir"]}/deleted_drafts/new.#{@serverconf["format"]}, if you accidentally cancel the edit, please restore your draft file from it."
          return
        elsif input[0] == 's' or input[0] == 'S'
          if draftFile == "#{@options["cachedir"]}/edit/new.#{@serverconf["format"]}"
            puts "Rename draft file? (empty if no): "
            rename = STDIN.gets.chomp
            if ! rename.empty?
              FileUtils.mv("#{@options["cachedir"]}/edit/new.#{@serverconf["format"]}", "#{@options["cachedir"]}/edit/new.#{rename}.#{@serverconf["format"]}")
            end
          end
          return
        elsif input[0] == 'y' or input[0] == 'Y'
          true
        else
          next
        end
      end

      uploadData, duration = parseDraftData draftFile
      response = uploadNewIssue uploadData
      break
    end
    t2 = Time.now

    # TODO: response ??? json ???????????????????????????????????????????????????
    # "\\xE3" from ASCII-8BIT to UTF-8 (Encoding::UndefinedConversionError)
    begin
      resbody = response.body.to_json
      # @options[:logger].debug(resbody)
      puts resbody
      newid = resbody["issue"]["id"]

      duration = ((t2 - t1).to_i / 60) if duration.nil?
      createTimeEntry newid, duration
    rescue
    end

    # update succeeded so clean up draft files
    cleanupDraft draftFile
  end

  def draftNewData
    editdata = []
    editdata << "---"
    editdata << "Project: "
    editdata << "Subject: "
    editdata << "Status: " # TODO: set default state properly
    type = @serverconf["setting"]["defaulttracker"] if @serverconf["setting"]["defaulttracker"]
    editdata << "Type: #{type}"  # TODO: set default tracker properly
    editdata << "EstimatedTime: 1"
    editdata << "StartDate: "
    editdata << "DueDate: "
    editdata << "Parent: null"
    # editdata << "Assigned: null" if @serverconf["setting"]["userlist"] == true
    editdata << "Duration:"
    editdata << "Progress: 0"
    editdata << "---"
    editdata << ""

    return editdata
  end

  def uploadNewIssue draftData
    uri = URI("#{@baseurl}/issues.json")
    @options[:logger].debug(draftData)
    response = post_issue uri, draftData
    # pp response.body.to_json
    case response
    when Net::HTTPSuccess, Net::HTTPRedirection
      puts "upload done"
    else
      raise response.value
    end
    return response
  end

  def uploadNewInputfile inputfile
    uploadData, duration = parseDraftData inputfile
    response = uploadNewIssue uploadData
    if duration
      begin
        resbody = response.body.to_json
        newid = resbody["issue"]["id"]
        createTimeEntry newid, duration
        puts "created time_entry (#{duration} min) to ID #{id}"
      rescue
      end
    end
  end

  def generateDraftFromParams params
    tmp = ["---"]
    tmp << "Project: #{params[:project]}"
    tmp << "Subject: #{params[:subject]}"
    tmp << "Type: #{params[:tracker]}"
    tmp << "Parent: #{params[:parent]}"
    tmp << "EstimatedTime: 1"
    tmp << "Status:"
    tmp << "StartDate:"
    tmp << "DueDate:"
    # tmp << "Assigned:"
    tmp << "---"
    tmp << "#{params[:description]}"
    tmp << ""
    draftFile = "/tmp/.new.#{@serverconf["format"]}"
    File.write(draftFile, tmp.join("\n"))
    uploadNewInputfile draftFile
  end
end
