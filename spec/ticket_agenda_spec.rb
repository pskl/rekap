# frozen_string_literal: true

require 'spec_helper'
require_relative '../lib/ticket_agenda'

RSpec.describe TicketAgenda do
  let(:days) { [Date.new(2026, 6, 10), Date.new(2026, 6, 11)] }
  let(:data) do
    {
      pull_requests: [
        GitService::Commit.new(
          number: 'abc1234',
          title: 'PROJECT-123 add export',
          html_url: 'abc1234',
          created_at: '2026-06-10T09:00:00Z',
          closed_at: nil
        )
      ],
      issues: [],
      ticket_evidence: [
        { ticket_id: 'SERVICE-456', occurred_at: '2026-06-11T16:00:00Z' }
      ]
    }
  end

  subject(:agenda) { described_class.new(data) }

  it 'assigns each half-day to direct or nearest ticket evidence' do
    rows = agenda.send(:assignments, days)

    expect(rows).to eq([
      { date: Date.new(2026, 6, 10), morning: 'PROJECT-123', afternoon: 'PROJECT-123' },
      { date: Date.new(2026, 6, 11), morning: 'SERVICE-456', afternoon: 'SERVICE-456' }
    ])
    expect(agenda.send(:ticket_count, rows)).to eq(2)
  end

  it 'is only present when a ticket ID is detected' do
    empty_agenda = described_class.new(pull_requests: [], issues: [])

    expect(agenda).to be_present
    expect(empty_agenda).not_to be_present
  end

  it 'lists multiple tickets evidenced in the same half-day' do
    data = {
      pull_requests: [
        GitService::Commit.new(
          number: 'abc1234', title: 'PROJECT-123 add export', html_url: 'abc1234',
          created_at: '2026-06-10T09:00:00Z', closed_at: nil
        ),
        GitService::Commit.new(
          number: 'def5678', title: 'SERVICE-456 update report', html_url: 'def5678',
          created_at: '2026-06-10T11:30:00Z', closed_at: nil
        )
      ],
      issues: []
    }
    agenda = described_class.new(data)

    row = agenda.send(:assignments, [Date.new(2026, 6, 10)]).first

    expect(row[:morning]).to eq('PROJECT-123, SERVICE-456')
    expect(row[:afternoon]).to eq('SERVICE-456')
    expect(agenda.send(:ticket_count, [row])).to eq(2)
  end
end
