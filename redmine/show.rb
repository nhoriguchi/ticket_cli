# coding: utf-8

require 'time'
require 'diffy'

module RedmineCmdShow
  def show args
    journal = false

    OptionParser.new do |opts|
      opts.banner = "Usage: #{$0} [-options] id"
      opts.on("-j", "--journal") do
        journal = true
      end
    end.order! args

    id = args[0]
    raise "issue #{id} not found" if @cacheData[id].nil?
    updateCacheIssue id

    puts draftIssueData(id)

    if journal == true
      @separator = '@' * 72
      puts @separator
      show_journals id
    end
  end

  def show_journals id
    params = {
      "status_id" => "*",
      "include" => "journals",
      "key" => @serverconf["token"]
    }
    journals = __get_response("#{@baseurl}/issues/#{id}.json", params)["issue"]["journals"]
    tmp = []
    journals.reverse.each do |j|
      tmp << get_journal(j)
    end
    puts tmp.join("\n" + @separator + "\n")
  end

  def get_journal j
    tmp = []
    tmp << "Journal ID: #{j["id"]}"
    tmp << "Date: #{Time.parse(j["created_on"]).getlocal}"
    tmp << "Author: #{j["user"]["name"]}"
    tmp << ""
    tmp << get_journal_detail(j["details"])
    if j["notes"] != ""
      tmp << j["notes"]
    end
    return tmp.join("\n")
  end

  def find_journal_attr details, name
    return details.find {|d| d["name"] == name}
  end

  def get_journal_detail details
    tmp = []

    if tmp2 = find_journal_attr(details, "subject")
      tmp << "Subject: '#{tmp2["old_value"]}' => '#{tmp2["new_value"]}'"
    end

    if tmp2 = find_journal_attr(details, "project_id")
      tmp << "Project: '#{project_name tmp2["old_value"]}' => '#{project_name tmp2["new_value"]}'"
    end

    if tmp2 = find_journal_attr(details, "parent_id")
      tmp << "Parent ID: '#{tmp2["old_value"]}' => '#{tmp2["new_value"]}'"
    end

    if tmp2 = find_journal_attr(details, "tracker_id")
      tmp << "Tracker: '#{tracker_name tmp2["old_value"].to_i}' => '#{tracker_name tmp2["new_value"].to_i}'"
    end

    if tmp2 = find_journal_attr(details, "status_id")
      tmp << "Status: '#{status_name tmp2["old_value"].to_i}' => '#{status_name tmp2["new_value"].to_i}'"
    end

    if tmp2 = find_journal_attr(details, "start_date")
      tmp << "Start Date: '#{tmp2["old_value"]}' => '#{tmp2["new_value"]}'"
    end

    if tmp2 = find_journal_attr(details, "due_date")
      tmp << "Due Date: '#{tmp2["old_value"]}' => '#{tmp2["new_value"]}'"
    end

    if tmp2 = find_journal_attr(details, "estimated_hours")
      tmp << "Estimated Hours: '#{tmp2["old_value"]}' => '#{tmp2["new_value"]}'"
    end

    if tmp2 = find_journal_attr(details, "done_ratio")
      tmp << "Progress: '#{tmp2["old_value"]}' => '#{tmp2["new_value"]}'"
    end

    if tmp2 = find_journal_attr(details, "assigned_to_id")
      tmp << "Assigned: '#{tmp2["old_value"]}' => '#{tmp2["new_value"]}'"
    end

    tmp = [tmp.map{|l| "  " + l}.join("\n")]

    if tmp2 = find_journal_attr(details, "description")
      tmp << ""
      tmp3 = Diffy::Diff.new(tmp2["old_value"], tmp2["new_value"], :context => 3).to_s.split("\n")
      tmp3.delete("\\ No newline at end of file")
      tmp << tmp3
    end

    return tmp.join("\n")
  end
end
