# coding: utf-8

# TODO: sort in ascending/descending order
# TODO: colorize
# TODO: project specific
# TODO: hierarchy support
# TODO: progress support
# TODO: priority support
# TODO: relation support
# TODO: close filter
module RedmineCmdList
  def list args
    @config = {
      :order => "id"
    }

    OptionParser.new do |opts|
      opts.banner = "Usage: ticket list [-options] [<project>]"
      opts.on("-i", "--sort-id") do
        @config[:order] = "id"
      end
      opts.on("-d", "--sort-update-date") do
        @config[:order] = "date"
      end
    end.order! args

    if @config[:order] == "id"
      list_id
    else
      list_update_date
    end
  end

  def list_id
    keys = @cacheData.keys.sort {|a, b| b.to_i <=> a.to_i}
    keys.each do |k|
      c = @cacheData[k]
      printf "%-4d %3d %-10s %-14s (%s) %s\n", k, c["done_ratio"], c["tracker"]["name"], c["status"]["name"], c["project"]["name"], c["subject"]
    end
  end

  def list_update_date
    values = @cacheData.values.sort {|a, b| b["updated_on"] <=> a["updated_on"]}
    values.each do |c|
      printf "%-4d %3d %-10s %-14s %s (%s) %s\n", c["id"], c["done_ratio"], c["tracker"]["name"], c["status"]["name"], c["updated_on"], c["project"]["name"], c["subject"]
    end
  end
end
