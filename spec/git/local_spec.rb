require_relative '../../lib/git/local'

RSpec.describe GitService do
  let(:email) { 'test@example.com' }
  let(:service) { GitService.new(email) }
  let(:repo_path) { '/path/to/repo' }
  let(:month) { 6 }

  describe '#fetch_commits' do
    it 'parses git log output correctly' do
      git_output = "abc1234567890|Initial commit|2025-06-15T10:00:00Z\ndef5678901234|Fix bug|2025-06-20T14:30:00Z\n"
      allow(Open3).to receive(:capture3).and_return([git_output, '', double(success?: true)])

      commits = service.send(:fetch_commits, repo_path, month, 2025)

      expect(commits.length).to eq(2)
      expect(commits.first.number).to eq('abc1234')
      expect(commits.first.title).to eq('Initial commit')
      expect(commits.first.created_at).to eq('2025-06-15T10:00:00Z')
      expect(commits.first.closed_at).to be_nil
    end

    it 'handles empty git log output' do
      allow(Open3).to receive(:capture3).and_return(['', '', double(success?: true)])

      commits = service.send(:fetch_commits, repo_path, month, 2025)

      expect(commits).to be_empty
    end

    it 'handles git command failure' do
      allow(Open3).to receive(:capture3).and_return(['', 'fatal: not a git repository', double(success?: false)])

      expect { service.send(:fetch_commits, repo_path, month, 2025) }.to raise_error(SystemExit)
    end
  end

  describe '#fetch_repo_data' do
    context 'with single repo' do
      it 'splits commits across both columns' do
        commits = [
          double(number: 1),
          double(number: 2),
          double(number: 3)
        ]
        allow(service).to receive(:fetch_commits).and_return(commits)

        data = service.fetch_repo_data(repo_path, nil, month)

        expect(data[:pull_requests].length).to eq(2)
        expect(data[:issues].length).to eq(1)
        expect(data[:pr_title]).to eq('> repo commits (2)')
        expect(data[:issue_title]).to eq('> repo commits continued (1)')
      end

      it 'handles single commit' do
        commits = [double(number: 1)]
        allow(service).to receive(:fetch_commits).and_return(commits)

        data = service.fetch_repo_data(repo_path, nil, month)

        expect(data[:pull_requests].length).to eq(1)
        expect(data[:issues].length).to eq(0)
      end

      it 'handles empty commits' do
        allow(service).to receive(:fetch_commits).and_return([])

        data = service.fetch_repo_data(repo_path, nil, month)

        expect(data[:pull_requests]).to be_empty
        expect(data[:issues]).to be_empty
      end
    end

    context 'with two repos' do
      let(:repo2_path) { '/path/to/repo2' }

      it 'assigns commits to separate columns' do
        repo1_commits = [double(number: 1), double(number: 2)]
        repo2_commits = [double(number: 3), double(number: 4), double(number: 5)]

        allow(service).to receive(:fetch_commits).with(repo_path, month, anything).and_return(repo1_commits)
        allow(service).to receive(:fetch_commits).with(repo2_path, month, anything).and_return(repo2_commits)

        data = service.fetch_repo_data(repo_path, repo2_path, month)

        expect(data[:pull_requests]).to eq(repo1_commits)
        expect(data[:issues]).to eq(repo2_commits)
        expect(data[:pr_title]).to eq('> repo commits (2)')
        expect(data[:issue_title]).to eq('> repo2 commits (3)')
      end
    end
  end

  describe '#extract_author_name' do
    it 'extracts name from git log' do
      allow(Open3).to receive(:capture3).and_return(['John Doe', '', double(success?: true)])

      name = service.extract_author_name(repo_path)

      expect(name).to eq('John Doe')
    end

    it 'falls back to email username when name not found' do
      allow(Open3).to receive(:capture3).and_return(['', '', double(success?: false)])

      name = service.extract_author_name(repo_path)

      expect(name).to eq('test')
    end

    it 'falls back to email username when output is empty' do
      allow(Open3).to receive(:capture3).and_return(['', '', double(success?: true)])

      name = service.extract_author_name(repo_path)

      expect(name).to eq('test')
    end
  end

  describe '#construct_commit_url' do
    it 'constructs GitHub URL from HTTPS remote' do
      allow(Open3).to receive(:capture3).and_return(['https://github.com/user/repo.git', '', double(success?: true)])

      url = service.send(:construct_commit_url, repo_path, 'abc123')

      expect(url).to eq('https://github.com/user/repo/commit/abc123')
    end

    it 'constructs GitHub URL from SSH remote' do
      allow(Open3).to receive(:capture3).and_return(['git@github.com:user/repo.git', '', double(success?: true)])

      url = service.send(:construct_commit_url, repo_path, 'abc123')

      expect(url).to eq('https://github.com/user/repo/commit/abc123')
    end

    it 'returns short hash for non-GitHub remote' do
      allow(Open3).to receive(:capture3).and_return(['https://gitlab.com/user/repo.git', '', double(success?: true)])

      url = service.send(:construct_commit_url, repo_path, 'abc1234567890')

      expect(url).to eq('abc1234')
    end

    it 'returns short hash when git command fails' do
      allow(Open3).to receive(:capture3).and_return(['', 'error', double(success?: false)])

      url = service.send(:construct_commit_url, repo_path, 'abc1234567890')

      expect(url).to eq('abc1234')
    end
  end

  describe 'Commit struct' do
    it 'creates commit with all required fields' do
      commit = GitService::Commit.new(
        number: 'abc1234',
        title: 'Test commit',
        html_url: 'https://github.com/user/repo/commit/abc1234',
        created_at: '2025-06-15T10:00:00Z',
        closed_at: nil
      )

      expect(commit.number).to eq('abc1234')
      expect(commit.title).to eq('Test commit')
      expect(commit.html_url).to eq('https://github.com/user/repo/commit/abc1234')
      expect(commit.created_at).to eq('2025-06-15T10:00:00Z')
      expect(commit.closed_at).to be_nil
    end

    it 'does not respond to assignees method' do
      commit = GitService::Commit.new(
        number: 'abc1234',
        title: 'Test',
        html_url: 'url',
        created_at: 'date',
        closed_at: nil
      )

      expect(commit).not_to respond_to(:assignees)
    end
  end
end
