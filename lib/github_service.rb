require 'date'

class GithubService
  def initialize(github_client, authenticated_user)
    @github = github_client
    @authenticated_user = authenticated_user
  end

  def fetch_repo_data(repo_name)
    user, repo = repo_name.split('/')
    last_month = Time.now.month - 1
    current_year = Time.now.year

    {
      pull_requests: fetch_pull_requests(user, repo, last_month, current_year),
      issues: fetch_issues(user, repo, last_month, current_year)
    }
  end

  private

  def fetch_pull_requests(user, repo, last_month, current_year)
    @github.pull_requests.list(
      user, repo, state: 'all', sort: 'created', direction: 'desc'
    ).select do |pr|
      created_at = DateTime.parse(pr.created_at)
      created_at.month == last_month && created_at.year == current_year &&
        user_involved_in_pr?(pr)
    end
  end

  def fetch_issues(user, repo, last_month, current_year)
    @github.issues.list(
      user, repo, state: 'all', sort: 'created', direction: 'desc'
    ).select do |issue|
      created_at = DateTime.parse(issue.created_at)
      created_at.month == last_month && created_at.year == current_year &&
        user_involved_in_issue?(issue)
    end
  end

  def user_involved_in_pr?(pr)
    pr.user.login == @authenticated_user.login ||
    pr.merged_by&.login == @authenticated_user.login ||
    (pr.reviews.present? && pr.reviews.any? { |review| review.user.login == @authenticated_user.login })
  end

  def user_involved_in_issue?(issue)
    issue.user.login == @authenticated_user.login ||
    issue.assignees.any? { |assignee| assignee.login == @authenticated_user.login }
  end
end
