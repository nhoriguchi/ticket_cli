# coding: utf-8

module RedmineCmdNew
  def new args
    allyes = false

    OptionParser.new do |opts|
      opts.banner = "Usage: #{$0} [-options]"
      opts.on("-p", "--project") do
      end
      opts.on("-P", "--parent") do
      end
      opts.on("-t", "--tracker") do
      end
      opts.on("-s", "--subject") do
      end
      # TODO: more options
    end.order! args

    draftFile = "#{@options["cachedir"]}/edit/new.#{@serverconf["format"]}"
    prepareDraft draftFile, draftNewData.join("\n")

    t1 = Time.now
    while true
      editDraft draftFile

      if allyes == true
        break
      else
        puts "You really upload this change? (y/Y: yes, n/N: no, s/S: save draft, e/E: edit again): "
        input = STDIN.gets.chomp
        if input[0] == 'n' or input[0] == 'N' or input[0] == 's' or input[0] == 'S'
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

    resbody = response.body.to_json
    @options[:logger].debug(resbody)
    newid = resbody["issue"]["id"]

    duration = ((t2 - t1).to_i / 60) if duration.nil?
    createTimeEntry newid, duration

    # update succeeded so clean up draft files
    cleanupDraft draftFile
  end

  def draftNewData
    editdata = []
    editdata << "---"
    editdata << "Project: "
    editdata << "Subject: "
    editdata << "Status: New" # TODO: set default state properly
    editdata << "Type: Task"  # TODO: set default tracker properly
    editdata << "EstimatedTime: 1"
    editdata << "StartDate: "
    editdata << "DueDate: "
    editdata << "Parent: null"
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

    case response
    when Net::HTTPSuccess, Net::HTTPRedirection
      puts "upload done"
    else
      raise response.value
    end
    return response
  end
end
