# coding: utf-8

require 'time'

module GitHubCmdShow
  def show args
    projname = args[0]
    pjid = @metaCacheData["reposname"][projname]
    iid = args[1]

    updateSingleMetaCache projname
    updateSingleCache projname

    issue = @cacheData[pjid][iid]

    puts "Title: #{issue["title"]}"
    puts "State: #{issue["state"]}"
    puts "Web URL: #{issue["html_url"]}"
    created = Time.parse(issue["created_at"]).strftime("%Y-%m-%d %H:%M:%S")
    puts "Created at #{created}"
    updated = Time.parse(issue["created_at"]).strftime("%Y-%m-%d %H:%M:%S")
    puts "Updated at #{updated}"
    puts "Description:"
    puts issue["body"]
    puts "-" * 72

    updateSingleNoteCache pjid, iid

    return if @noteCacheData[pjid].nil? or @noteCacheData[pjid][iid].nil?

    notes = @noteCacheData[pjid][iid]
    puts "--- #{notes.size}"
    notes.each do |note|
      # if note["system"] == false
        tstamp = Time.parse(note["created_at"]).strftime("%Y-%m-%d %H:%M:%S")
        puts "#{iid}-#{note["id"]} by #{note["user"]["login"]} at #{tstamp}"
        puts "#{note["body"]}"
      # end
    end
  end
end
