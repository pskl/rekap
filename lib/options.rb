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

      opts.on('--days-on=DATES', 'Comma-separated list of dates worked (YYYY-MM-DD format)') do |dates|
        options[:days_on] = dates.split(',').map { |date| Date.parse(date) }
      end

      opts.on('--repo1=PATH', 'Path to first local git repository') do |path|
        options[:repo1] = path
      end

      opts.on('--repo2=PATH', 'Path to second local git repository (optional)') do |path|
        options[:repo2] = path
      end

      opts.on('--email-author=EMAIL', 'Email address of commit author (for local mode)') do |email|
        options[:email_author] = email
      end

      opts.on('--title=TITLE', 'Custom title to use in PDF and filename (overrides project/repo name)') do |title|
        options[:title] = title
      end

      opts.on("-m", "--month=NUMBER", "Month number (1-12, defaults to previous month)") do |month|
        month_num = month.to_i
        if month_num < 1 || month_num > 12
          puts "Error: Month must be between 1 and 12."
          exit 1
        end
        options[:month] = month_num
      end

    end.parse!

    local_params = options[:repo1] || options[:email_author]
    github_params = options[:project_name] || options[:gh_token]

    if local_params && github_params
      puts "Error: Cannot mix GitHub mode (--project, --gh-token) with local mode (--repo1, --email-author)"
      exit 1
    end

    if local_params
      unless options[:repo1] && options[:email_author]
        puts "Error: Local mode requires --repo1 and --email-author"
        exit 1
      end
      options[:mode] = "local"
    else
      unless options[:project_name] && options[:gh_token]
        puts "Error: GitHub mode requires --project and --gh-token"
        exit 1
      end
      options[:mode] = "github"
    end

    options
  end
end
