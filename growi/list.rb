require 'date'

module GrowiCmdList
  def list args
    puts "CreatedAt, UpdatedAt, Version, Path"
    @cacheData.each do |k,v|
      c = parse_date(v["createdAt"])
      u = parse_date(v["updatedAt"])
      puts "#{c}, #{u}, #{v["__v"]}, #{k}"
    end
  end

  def parse_date datespec
    return "" if datespec == ""
    if datespec =~ /^([\+\-]\d+)$/ or datespec == "0"
      return (Time.now + (datespec.to_i) * 86400).strftime("%Y-%m-%d")
    end
    tmp = DateTime.parse(datespec)
    tmp.strftime("%Y-%m-%d")
  end
end
