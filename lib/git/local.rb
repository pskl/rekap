require 'date'
require 'open3'
require 'shellwords'

class GitService
  TICKET_ID_PATTERN = /\b[A-Z]+-\d+\b/

  Commit = Struct.new(:number, :title, :html_url, :created_at, :closed_at, keyword_init: true)

  def initialize(email_author)
    @email_authors = email_author.split(',').map(&:strip).reject(&:empty?)
  end

  def fetch_repo_data(repo1_path, repo2_path, month_num, repo3_path = nil, repo4_path = nil)
    current_year = Date.today.year
    target_month = month_num
    target_year = current_year

    if repo3_path || repo4_path
      sections = [repo1_path, repo2_path, repo3_path, repo4_path].map do |repo_path|
        next unless repo_path

        commits = fetch_commits(repo_path, target_month, target_year)
        repo_name = File.basename(File.expand_path(repo_path))
        {
          title: "> #{repo_name} commits (#{commits.count})",
          items: commits
        }
      end
      sections = sections.each_slice(2).flat_map do |row|
        sorted_row = row.compact
          .each_with_index
          .sort_by { |(section, index)| [-section[:items].count, index] }
          .map(&:first)
        sorted_row + Array.new(2 - sorted_row.length)
      end

      return add_ticket_evidence({
        sections: sections,
        pull_requests: sections[0][:items],
        issues: sections[1]&.fetch(:items, []) || [],
        pr_title: sections[0][:title],
        issue_title: sections[1]&.fetch(:title, nil)
      }, [repo1_path, repo2_path, repo3_path, repo4_path])
    end

    repo1_commits = fetch_commits(repo1_path, target_month, target_year)
    repo1_name = File.basename(File.expand_path(repo1_path))

    if repo2_path
      repo2_commits = fetch_commits(repo2_path, target_month, target_year)
      repo2_name = File.basename(File.expand_path(repo2_path))

      left, right = [[repo1_name, repo1_commits], [repo2_name, repo2_commits]]
        .each_with_index
        .sort_by { |(_name, commits), index| [-commits.count, index] }
        .map(&:first)
      left_name, left_commits = left
      right_name, right_commits = right

      add_ticket_evidence({
        pull_requests: left_commits,
        issues: right_commits,
        pr_title: "> #{left_name} commits (#{left_commits.count})",
        issue_title: "> #{right_name} commits (#{right_commits.count})"
      }, [repo1_path, repo2_path])
    else
      mid = (repo1_commits.length / 2.0).ceil
      left_commits = repo1_commits[0...mid]
      right_commits = repo1_commits[mid..-1] || []
      add_ticket_evidence({
        pull_requests: left_commits,
        issues: right_commits,
        pr_title: "> #{repo1_name} commits (#{left_commits.count})",
        issue_title: "> #{repo1_name} commits continued (#{right_commits.count})"
      }, [repo1_path])
    end
  end

  def extract_author_name(repo_path)
    stdout, stderr, status = Open3.capture3(
      'git', '-C', repo_path, 'log',
      *author_filters,
      '-1', '--format=%an'
    )

    if status.success? && !stdout.strip.empty?
      stdout.strip
    else
      @email_authors.first.split('@').first
    end
  end

  private

  def add_ticket_evidence(data, repo_paths)
    evidence = repo_paths.compact.flat_map { |repo_path| fetch_branch_ticket_evidence(repo_path) }
    data.merge(ticket_evidence: evidence)
  end

  def fetch_branch_ticket_evidence(repo_path)
    stdout, _, status = Open3.capture3(
      'git', '-C', repo_path, 'for-each-ref',
      '--format=%(refname:short)|%(committerdate:iso8601-strict)',
      'refs/heads', 'refs/remotes'
    )
    return [] unless status.success?

    stdout.lines.flat_map do |line|
      branch_name, occurred_at = line.strip.split('|', 2)
      next [] unless occurred_at

      branch_name.scan(TICKET_ID_PATTERN).uniq.map do |ticket_id|
        { ticket_id: ticket_id, occurred_at: occurred_at }
      end
    end
  end

  def fetch_commits(repo_path, target_month, target_year)
    start_date = Date.new(target_year, target_month, 1)
    end_date = Date.new(target_year, target_month, -1)

    stdout, stderr, status = Open3.capture3(
      'git', '-C', repo_path, 'log',
      '--branches',
      *author_filters,
      '--format=%H|%s|%aI'
    )

    unless status.success?
      puts "Error: Failed to read git repository at #{repo_path}"
      puts stderr
      exit 1
    end

    commits = stdout.lines.filter_map do |line|
      hash, subject, date = line.strip.split('|', 3)
      authored_on = Date.parse(date)
      next if authored_on < start_date || authored_on > end_date

      Commit.new(
        number: hash[0..6],
        title: subject,
        html_url: construct_commit_url(repo_path, hash),
        created_at: date,
        closed_at: nil
      )
    end

    commits.sort_by { |commit| DateTime.parse(commit.created_at) }
  end

  def author_filters
    @email_authors.map { |email| "--author=#{email}" }
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
