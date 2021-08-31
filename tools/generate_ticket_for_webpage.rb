require 'open-uri'
require 'nokogiri'

class GenerateTicketForWebsite
  def self.run url
    page_content = open(url).read
    doc = Nokogiri::HTML(page_content)
    return doc.at_css('title').text
  end
end

url = ARGV[0]
proj = ARGV[1]
title = GenerateTicketForWebsite.run url

raise if proj == ""

template = "
---
Project: #{proj}
Subject: #{title}
Status: 
Type: 
EstimatedTime: 1
StartDate:
DueDate:
Parent: null
Assigned: null
Duration:
Progress: 0
---
#{url}
"

require_relative '../main.rb'
File.write("/tmp/.upload.md", template)
MainCommand.cmd ["new", "-f", "/tmp/.upload.md"]
