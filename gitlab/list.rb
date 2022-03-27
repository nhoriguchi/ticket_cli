# coding: utf-8

require "date"

module GitLabCmdList
  def list args

    projs = args

    @cacheData.each do |pjid, issues|
      next if (not projs.empty?) and (not projs.include? pjid)
      # pp issues
      issues.each do |iid, issue|
        tstamp = Time.parse(issue["updated_at"]).strftime("%Y-%m-%d %H:%M:%S")
        printf "#{pjid}-#{iid}\t#{issue["state"]}\t#{tstamp}\t#{issue["title"]}\n"
      end
    end
  end
end
