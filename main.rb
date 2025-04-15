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
    max_ruler_size = 4

    pdf.text "> Activity summary for #{contributor_name} on #{repo_name} in #{month_name} #{Time.now.year}:", size: 13
    pdf.move_down default_spacing / 3

    ruler(max_ruler_size, pdf)

    pdf.move_down default_spacing * 1.5
    half_width = pdf.bounds.width * 0.5
    top = pdf.cursor

    left_data, right_data = if data[:pull_requests].length >= data[:issues].length
      [{title: "PULL REQUESTS", items: data[:pull_requests]}, {title: "TICKETS", items: data[:issues]}]
    else
      [{title: "TICKETS", items: data[:issues]}, {title: "PULL REQUESTS", items: data[:pull_requests]}]
    end

    pdf.bounding_box([0, pdf.cursor], :width => half_width) do
      pdf.text left_data[:title], size: pdf.font_size * 1.2
      ruler(max_ruler_size * 0.375, pdf)
      pdf.move_down default_spacing/2

      left_data[:items].sort_by { |item| item.number }.each do |item|
        pdf.formatted_text [
          { text: "#{item.title.split.join(" ")}", link: "#{item.html_url}", color: '0000FF' }
        ]
        ruler(max_ruler_size * 0.25, pdf)
        pdf.move_down default_spacing/2

        if item.respond_to?(:assignees)
          pdf.text "number: #{item.number}"
          pdf.text "state: #{item.state}"
          pdf.text "assignees: #{item.assignees.map(&:login).join(', ')}"
        else
          pdf.text "number: #{item.number}"
          pdf.text "date of opening: #{DateTime.parse(item.created_at).to_date}"
          if item.closed_at.present?
            pdf.text "date of closing: #{DateTime.parse(item.closed_at).to_date}"
            pdf.text "time stayed open: #{(DateTime.parse(item.closed_at) - DateTime.parse(item.created_at)).to_i} days"
          end
        end

        pdf.move_down default_spacing * 2.2
      end
    end

    pdf.go_to_page(1)
    pdf.move_cursor_to(top)

    pdf.bounding_box([half_width + default_spacing*2, pdf.cursor], :width => half_width) do
      pdf.text right_data[:title], size: pdf.font_size * 1.2
      ruler(max_ruler_size * 0.375, pdf)
      pdf.move_down default_spacing / 2

      right_data[:items].sort_by { |item| item.number }.each do |item|
        pdf.formatted_text [
          { text: "#{item.title.split.join(" ")}", link: "#{item.html_url}", color: '0000FF' }
        ]
        ruler(max_ruler_size * 0.25, pdf)
        pdf.move_down default_spacing/2

        if item.respond_to?(:assignees)
          pdf.text "number: #{item.number}"
          pdf.text "state: #{item.state}"
          pdf.text "assignees: #{item.assignees.map(&:login).join(', ')}"
        else
          pdf.text "number: #{item.number}"
          pdf.text "date of opening: #{DateTime.parse(item.created_at).to_date}"
          if item.closed_at.present?
            pdf.text "date of closing: #{DateTime.parse(item.closed_at).to_date}"
            pdf.text "time stayed open: #{(DateTime.parse(item.closed_at) - DateTime.parse(item.created_at)).to_i} days"
          end
        end

        pdf.move_down default_spacing * 2.2
      end
    end
  end
  puts "rekap generated: #{file_name}"
end

def ruler(size, pdf)
  pdf.line_width = size
  pdf.stroke_horizontal_rule
end

data = fetch_repo_data(github, options[:project_name], authenticated_user)
generate_pdf(options[:project_name], authenticated_user.name, data, options[:output_path] || '.', options[:font_path])
