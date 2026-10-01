# frozen_string_literal: true

require 'spec_helper'
require_relative '../lib/options'

RSpec.describe Options do
  describe '.parse' do
    around do |example|
      original_arguments = ARGV.dup
      example.run
    ensure
      ARGV.replace(original_arguments)
    end

    it 'accepts paths for a third and fourth local repository' do
      ARGV.replace([
        '--repo1=/path/to/repo1',
        '--repo2=/path/to/repo2',
        '--repo3=/path/to/repo3',
        '--repo4=/path/to/repo4',
        '--email-author=developer@example.com'
      ])

      options = described_class.parse

      expect(options).to include(
        mode: 'local',
        repo1: '/path/to/repo1',
        repo2: '/path/to/repo2',
        repo3: '/path/to/repo3',
        repo4: '/path/to/repo4'
      )
    end

    it 'accepts and normalizes comma-separated author emails' do
      ARGV.replace([
        '--repo1=/path/to/repo',
        '--email-author=work@example.com, personal@example.com'
      ])

      options = described_class.parse

      expect(options[:email_author]).to eq('work@example.com,personal@example.com')
    end
  end
end
