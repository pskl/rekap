Bundler.require()
require 'date'
require 'optparse'

options = {}
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
end.parse!

unless options[:project_name] && options[:gh_token]
  puts "Error: Project name and GitHub token are required."
  puts "Usage: see README.md for usage"
  exit 1
end

github = Github.new(oauth_token: options[:gh_token], auto_pagination: true)
authenticated_user = github.users.get

class Object
  def present?
    !nil? && !empty?
  end
end

def fetch_repo_data(github, repo_name, authenticated_user)
  user, repo = repo_name.split('/')
  last_month = Time.now.month - 1
  current_year = Time.now.year

  pull_requests = github.pull_requests.list(
    user, repo, state: 'all', sort: 'created', direction: 'desc'
  ).select do |pr|
    created_at = DateTime.parse(pr.created_at)
    created_at.month == last_month && created_at.year == current_year &&
      (pr.user.login == authenticated_user.login || pr.merged_by&.login == authenticated_user.login || (pr.reviews.present? && pr.reviews.any? { |review| review.user.login == authenticated_user.login }))
  end

  issues = github.issues.list(
    user, repo, state: 'all', sort: 'created', direction: 'desc'
  ).select do |issue|
    created_at = DateTime.parse(issue.created_at)
    created_at.month == last_month && created_at.year == current_year &&
      (issue.user.login == authenticated_user.login || issue.assignees.any? { |assignee| assignee.login == authenticated_user.login })
  end

  { pull_requests: pull_requests, issues: issues }
end

def generate_pdf(repo_name, contributor_name, data, output_path, font_path)
  month_name = (Time.now - 2592000).strftime('%B')
  file_name = "#{repo_name.tr('/', '_')}_#{month_name.downcase}_#{Time.now.year}_#{contributor_name}_rekap.pdf"
  output_file = File.join(output_path, file_name)

  Prawn::Document.generate(output_file) do |pdf|
    pdf.font font_path if font_path
    pdf.default_leading = 0.5
    pdf.font_size 12
    default_spacing = pdf.font_size / 2

    pdf.text "> Activity summary for #{contributor_name} on #{repo_name} in #{month_name} #{Time.now.year}:", size: 13
    pdf.move_down default_spacing / 3

    ruler(8, pdf)

    pdf.move_down default_spacing * 1.5
    half_width = pdf.bounds.width * 0.5
    top = pdf.cursor

    pdf.bounding_box([0, pdf.cursor], :width => half_width) do
      pdf.text "TICKETS", size: pdf.font_size * 1.2
      ruler(3, pdf)
      pdf.move_down default_spacing/2

      data[:issues].sort_by { |i| i.number }.each do |issue|
        pdf.formatted_text [
          { text: "#{issue.title.split.join(" ")}", link: "#{issue.html_url}", color: '0000FF' }
        ]
        ruler(2, pdf)
        pdf.move_down default_spacing/2

        pdf.text "number: #{issue.number}"
        pdf.text "state: #{issue.state}"
        pdf.text "assignees: #{issue.assignees.map(&:login).join(', ')}"

        pdf.move_down default_spacing * 2.2
      end
    end

    pdf.go_to_page(1)
    pdf.move_cursor_to(top)

    pdf.bounding_box([half_width + default_spacing*2, pdf.cursor], :width => half_width) do
      pdf.text "PULL REQUESTS", size: pdf.font_size * 1.2
      ruler(3, pdf)
      pdf.move_down default_spacing / 2

      data[:pull_requests].sort_by { |pr| pr.number }.each do |pr|
        pdf.formatted_text [
          { text: "#{pr.title.split.join(" ")}", link: "#{pr.html_url}", color: '0000FF' }
        ]
        ruler(2, pdf)
        pdf.move_down default_spacing/2

        pdf.text "number: #{pr.number}"
        pdf.text "date of opening: #{DateTime.parse(pr.created_at).to_date}"

        if pr.closed_at.present?
          pdf.text "date of closing: #{DateTime.parse(pr.closed_at).to_date}"
          pdf.text "time stayed open: #{(DateTime.parse(pr.closed_at) - DateTime.parse(pr.created_at)).to_i} days"
        end
        pdf.move_down default_spacing * 2.2
      end
    end
  end
end

def ruler(size, pdf)
  pdf.line_width = size
  pdf.stroke_horizontal_rule
end

data = fetch_repo_data(github, options[:project_name], authenticated_user)
generate_pdf(options[:project_name], authenticated_user.name, data, options[:output_path] || '.', options[:font_path])
