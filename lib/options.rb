require 'optparse'

class Options
  def self.parse
    options = { output_path: '.' }

    OptionParser.new do |opts|
      opts.banner = "Usage: ruby main.rb [options]"

      opts.on("-o", "--output=PATH", "Output directory path") do |path|
        options[:output_path] = path
      end

      opts.on("-p", "--project=NAME", "Project name (GitHub repository)") do |name|
        options[:project_name] = name
      end

      opts.on("-f", "--font=PATH", "Font file path") do |path|
        options[:font_path] = path
      end

      opts.on("-t", "--gh-token=TOKEN", "GitHub personal access token") do |token|
        options[:gh_token] = token
      end

      opts.on('--days-off=DATES', 'Comma-separated list of dates to exclude (YYYY-MM-DD format)') do |dates|
        options[:days_off] = dates.split(',').map { |date| Date.parse(date) }
      end

    end.parse!

    unless options[:project_name] && options[:gh_token]
      puts "Error: Project name and GitHub token are required."
      puts "Usage: see README.md for usage"
      exit 1
    end

    options
  end
end
