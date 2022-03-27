# coding: utf-8

require 'time'

module GitLabCmdShow
  def show args
    id = args[0]
    pjid, iid = id.split("-")

    issue = @cacheData[pjid][iid]

    puts "Title: #{issue["title"]}"
    puts "State: #{issue["state"]}"
    puts "Web URL: #{issue["web_url"]}"
    created = Time.parse(issue["created_at"]).strftime("%Y-%m-%d %H:%M:%S")
    puts "Created at #{created}"
    updated = Time.parse(issue["created_at"]).strftime("%Y-%m-%d %H:%M:%S")
    puts "Updated at #{updated}"
    puts "Description:"
    puts issue["description"]
    puts "-" * 72

    updateSingleNoteCache id

    return if @noteCacheData[pjid].nil? or @noteCacheData[pjid][iid].nil?

    notes = @noteCacheData[pjid][iid]
    notes.each do |note|
      if note["system"] == false
        tstamp = Time.parse(note["created_at"]).strftime("%Y-%m-%d %H:%M:%S")
        puts "#{pjid}-#{iid}-#{note["id"]} by #{note["author"]["username"]} at #{tstamp}"
        puts "#{note["body"]}"
      end
    end
  end
end
