# coding: utf-8

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

    # borrowed from RedmineCmdEdit
    puts draftIssueData(id)

    if journal == true
      puts "=========== TODO: JOURNAL SHOULD BE DISPLAYED ============"
    end
  end
end
