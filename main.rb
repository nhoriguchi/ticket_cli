#! /usr/bin/env ruby
# coding: utf-8

# 基本的に、どの外部システムを使うにしても、やりたい作業は「読む」「リストする」「書く」
# であり、これに対応していれば最低限の作業は可能である。
# 想定対象としては redmine, openproject, gist, rocketchat, teams など。

# TODO
# - draft 関連のハンドリングの部分はサーバー非依存にしたい。

require 'pp'
require 'yaml'
require 'optparse'
require 'logger'

class MainCommand
  @@config = "#{ENV['HOME']}/.ticket/config"
  @@config = ENV['TICKET_CONFIG'] if ENV['TICKET_CONFIG']

  def self.cmd args
    tmp = YAML.load_file(@@config)

    @options = {
      :server => tmp['defaultserver'],
      :insecure => false,
      :logger => Logger.new(STDOUT, level: Logger::Severity::INFO),
      :debug => false,
    }
    @options.merge! tmp

    @options[:server] = ENV['TICKET_SERVER'] if ENV['TICKET_SERVER']
    @options[:insecure] = true if ENV['INSECURE']
    @options[:debug] = true if ENV['DEBUG']

    args << '-h' if args.empty?
    OptionParser.new do |opts|
      opts.banner = "Usage: ticket [-options] <subcommand>

  Subcommand for Redmine (see `ticket <subcommand> -h` for more details):

    - list
    - project
    - show
    - edit
    - new
    - status
    - relation
    - wiki

"
      opts.on("-s <server>", "--server") do |s|
        @options[:server] = s
      end
      opts.on("-l <loglevel>", "--loglevel") do |l|
        case l
        when "info"
          @options[:logger].level = Logger::INFO
        when "debug"
          @options[:logger].level = Logger::DEBUG
        else
          puts "supported log level: info, debug"
          exit
        end
      end
      opts.on("-S", "--insecure") do
        @options[:insecure] = true
      end
      opts.on("-D", "--debug") do
        @options[:debug] = true
      end

      opts.on_tail("-h", "--help", "Show this message") do
        puts opts
        exit
      end
    end.order! args

    cmd = args.shift

    # global command
    case cmd
    when "server"
      run_server
      exit
    when "config"
      run_config
      exit
    end

    @options["cachedir"] += "/#{@options[:server]}"
    case tmp["servers"][@options[:server]]["type"]
    when "redmine"
      require_relative "./redmine.rb"

      redmine = Redmine.new @options, cmd, args
    else
      raise "invalid config #{tmp}"
    end
  end

  def self.run_server
    puts ["Name", "Type", "Description"].join("\t")
    @options["servers"].each do |k, v|
      puts [k, v["type"], v["name"]].join("\t")
    end
  end

  def self.run_config
  end
end

MainCommand.cmd ARGV
