#!/usr/bin/env ruby
require 'optparse'
require 'github_api'
require 'prawn'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: ruby main.rb [options]"

  opts.on("-o", "--output=PATH", "Output directory path") do |path|
    options[:output_path] = path
  end

  opts.on("-p", "--project=NAME", "Project name (GitHub repository)") do |name|
    options[:project_name] = name
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
  current_month = Time.now.month
  current_year = Time.now.year

  pull_requests = github.pull_requests.list(
    user, repo, state: 'all', sort: 'created', direction: 'desc'
  ).select do |pr|
    created_at = DateTime.parse(pr.created_at)
    created_at.month == current_month && created_at.year == current_year &&
      (pr.user.login == authenticated_user.login || pr.merged_by&.login == authenticated_user.login || (pr.reviews.present? && pr.reviews.any? { |review| review.user.login == authenticated_user.login }))
  end

  issues = github.issues.list(
    user, repo, state: 'all', sort: 'created', direction: 'desc'
  ).select do |issue|
    created_at = DateTime.parse(issue.created_at)
    created_at.month == current_month && created_at.year == current_year &&
      (issue.user.login == authenticated_user.login || issue.assignees.any? { |assignee| assignee.login == authenticated_user.login })
  end

  { pull_requests: pull_requests, issues: issues }
end

def generate_pdf(repo_name, contributor_name, data, output_path)
  month_name = Time.now.strftime('%B')
  file_name = "#{repo_name.tr('/', '_')}_#{month_name.downcase}_#{Time.now.year}_#{contributor_name}_rekap.pdf"
  output_file = File.join(output_path, file_name)

  Prawn::Document.generate(output_file) do |pdf|
    pdf.text "GitHub Repository: #{repo_name}", style: :bold
    pdf.text "Contributor: #{contributor_name}", style: :bold
    pdf.move_down 20

    data[:issues].each_with_index do |issue, index|
      pdf.start_new_page if index > 0 && index % 2 == 0

      pdf.bounding_box([0, pdf.cursor], width: pdf.bounds.width / 2) do
        pdf.text "Issue: #{issue.title} (#{issue.state})", style: :bold
        pdf.move_down 5
        pdf.text "Assignees: #{issue.assignees.map(&:login).join(', ')}"
        pdf.move_down 10
      end

      if corresponding_pr = data[:pull_requests].find { |pr| pr.body.present? && pr.body.include?(issue.html_url) }
        pdf.bounding_box([pdf.bounds.width / 2, pdf.cursor], width: pdf.bounds.width / 2) do
          pdf.text "Pull Request: #{corresponding_pr.title} (#{corresponding_pr.state})", style: :bold
          pdf.move_down 5
          pdf.text "Reviewer(s): #{corresponding_pr.reviews.to_a.map { |review| review.user.login }.join(', ')}"
          pdf.move_down 10
        end
      end

      pdf.move_down 20 unless index == data[:issues].length - 1
    end
  end
end

data = fetch_repo_data(github, options[:project_name], authenticated_user)
generate_pdf(options[:project_name], authenticated_user.name, data, options[:output_path] || '.')
