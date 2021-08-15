# coding: utf-8

module RedmineCmdProject
  def project args
    OptionParser.new do |opts|
      opts.banner = "Usage: ticket project"
      opts.on("-r", "--remove") do
      end
    end.order! args

    show_projects
  end

  def show_projects
    puts "ID\tProject Name"
    @metaCacheData["projects"].sort_by {|v| v["id"]}.each do |pj|
      puts "#{pj["id"]}\t#{pj["name"]}"
    end
  end
end
