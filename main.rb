Bundler.require()
require 'date'
require 'optparse'
require_relative 'lib/histogram'
require_relative 'lib/options'
require_relative 'lib/utils'
require_relative 'lib/git/github'
require_relative 'lib/git/local'
require_relative 'lib/pdf_generator'

def generate_pdf(repo_name, contributor_name, data, output_path, font_path, days_off, days_on, month_num, mode = "github")
  generator = PdfGenerator.new(
    repo_name, contributor_name, data, output_path,
    font_path, days_off, days_on, month_num, mode
  )
  generator.generate
end

def main
  options = Options.parse
  month = options[:month] || Date.today.prev_month.month

  if options[:mode] == "github"
    github = Github.new(oauth_token: options[:gh_token], auto_pagination: true)
    authenticated_user = github.users.get
    github_service = GithubService.new(github, authenticated_user)
    data = github_service.fetch_repo_data(options[:project_name], month)

    repo_name = options[:title] || options[:project_name]

    generate_pdf(
      repo_name,
      authenticated_user.name,
      data,
      options[:output_path] || '.',
      options[:font_path],
      options[:days_off] || [],
      options[:days_on] || [],
      month,
      "github"
    )
  else
    git_service = GitService.new(options[:email_author])
    data = git_service.fetch_repo_data(options[:repo1], options[:repo2], month)
    contributor_name = git_service.extract_author_name(options[:repo1])

    repo_name = if options[:title]
      options[:title]
    else
      repo1_name = File.basename(File.expand_path(options[:repo1]))
      if options[:repo2]
        repo2_name = File.basename(File.expand_path(options[:repo2]))
        "#{repo1_name}_#{repo2_name}"
      else
        repo1_name
      end
    end

    generate_pdf(
      repo_name,
      contributor_name,
      data,
      options[:output_path] || '.',
      options[:font_path],
      options[:days_off] || [],
      options[:days_on] || [],
      month,
      "local"
    )
  end
end

main if __FILE__ == $0
