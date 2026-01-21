require 'date'
require 'open3'
require 'shellwords'

class GitService
  Commit = Struct.new(:number, :title, :html_url, :created_at, :closed_at, keyword_init: true)

  def initialize(email_author)
    @email_author = email_author
  end

  def fetch_repo_data(repo1_path, repo2_path, month_num)
    current_year = Date.today.year
    target_month = month_num
    target_year = current_year

    repo1_commits = fetch_commits(repo1_path, target_month, target_year)
    repo1_name = File.basename(File.expand_path(repo1_path))

    if repo2_path
      repo2_commits = fetch_commits(repo2_path, target_month, target_year)
      repo2_name = File.basename(File.expand_path(repo2_path))
      {
        pull_requests: repo1_commits,
        issues: repo2_commits,
        pr_title: "> #{repo1_name} commits (#{repo1_commits.count})",
        issue_title: "> #{repo2_name} commits (#{repo2_commits.count})"
      }
    else
      mid = (repo1_commits.length / 2.0).ceil
      left_commits = repo1_commits[0...mid]
      right_commits = repo1_commits[mid..-1] || []
      {
        pull_requests: left_commits,
        issues: right_commits,
        pr_title: "> #{repo1_name} commits (#{left_commits.count})",
        issue_title: "> #{repo1_name} commits continued (#{right_commits.count})"
      }
    end
  end

  def extract_author_name(repo_path)
    stdout, stderr, status = Open3.capture3(
      'git', '-C', repo_path, 'log',
      "--author=#{@email_author}",
      '-1', '--format=%an'
    )

    if status.success? && !stdout.strip.empty?
      stdout.strip
    else
      @email_author.split('@').first
    end
  end

  private

  def fetch_commits(repo_path, target_month, target_year)
    start_date = Date.new(target_year, target_month, 1)
    end_date = Date.new(target_year, target_month, -1)

    stdout, stderr, status = Open3.capture3(
      'git', '-C', repo_path, 'log',
      "--author=#{@email_author}",
      "--since=#{start_date}",
      "--until=#{end_date}",
      '--format=%H|%s|%aI'
    )

    unless status.success?
      puts "Error: Failed to read git repository at #{repo_path}"
      puts stderr
      exit 1
    end

    commits = stdout.lines.map do |line|
      hash, subject, date = line.strip.split('|', 3)
      Commit.new(
        number: hash[0..6],
        title: subject,
        html_url: construct_commit_url(repo_path, hash),
        created_at: date,
        closed_at: nil
      )
    end

    commits
  end

  def construct_commit_url(repo_path, commit_hash)
    stdout, _, status = Open3.capture3('git', '-C', repo_path, 'config', '--get', 'remote.origin.url')

    if status.success?
      remote_url = stdout.strip
      if remote_url.match(/github\.com[\/:](.+?)(\.git)?$/)
        repo_path = $1
        return "https://github.com/#{repo_path}/commit/#{commit_hash}"
      end
    end

    commit_hash[0..6]
  rescue
    commit_hash[0..6]
  end
end
