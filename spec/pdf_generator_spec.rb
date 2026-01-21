# frozen_string_literal: true

require 'spec_helper'
require_relative '../lib/pdf_generator'

RSpec.describe PdfGenerator do
  let(:repo_name) { 'test/repo' }
  let(:contributor_name) { 'John Doe' }
  let(:output_path) { '/tmp' }
  let(:font_path) { nil }
  let(:days_off) { [] }
  let(:days_on) { [] }
  let(:month_num) { 6 }
  let(:mode) { 'github' }
  let(:data) do
    {
      pull_requests: [
        double('pr',
          number: 1,
          title: 'Test PR',
          html_url: 'https://github.com/test/repo/pull/1',
          created_at: '2025-06-01T10:00:00Z',
          closed_at: nil
        )
      ],
      issues: [
        double('issue',
          number: 2,
          title: 'Test Issue',
          html_url: 'https://github.com/test/repo/issues/2',
          state: 'open',
          assignees: []
        )
      ]
    }
  end

  subject(:generator) do
    described_class.new(
      repo_name, contributor_name, data, output_path,
      font_path, days_off, days_on, month_num, mode
    )
  end

  describe '#generate' do
    let(:pdf_double) do
      double('pdf').tap do |pdf|
        allow(pdf).to receive(:font)
        allow(pdf).to receive(:default_leading=)
        allow(pdf).to receive(:font_size).and_return(12)
        allow(pdf).to receive(:font_size=)
        allow(pdf).to receive(:text)
        allow(pdf).to receive(:move_down)
        allow(pdf).to receive(:cursor).and_return(500)
        allow(pdf).to receive(:bounds).and_return(double(width: 600))
        allow(pdf).to receive(:bounding_box)
        allow(pdf).to receive(:go_to_page)
        allow(pdf).to receive(:move_cursor_to)
        allow(pdf).to receive(:line_width=)
        allow(pdf).to receive(:stroke_horizontal_rule)
      end
    end

    before do
      allow(Prawn::Document).to receive(:generate).and_yield(pdf_double)
      allow(Histogram).to receive(:draw)
      allow(generator).to receive(:puts)
    end

    it 'generates a PDF with the correct filename' do
      expected_filename = 'test_repo_june_2026_John Doe_rekap.pdf'
      expected_filepath = File.join(output_path, expected_filename)

      expect(Prawn::Document).to receive(:generate).with(expected_filepath, info: anything)

      generator.generate
    end

    it 'prints confirmation message' do
      expected_filename = 'test_repo_june_2026_John Doe_rekap.pdf'

      expect(generator).to receive(:puts).with("-> rekap generated: #{expected_filename}")

      generator.generate
    end
  end

  describe '#calculate_business_days' do
    let(:start_date) { Date.new(2026, 6, 1) }
    let(:end_date) { Date.new(2026, 6, 30) }

    context 'when days_on is provided' do
      let(:days_on) { [Date.new(2026, 6, 5), Date.new(2026, 6, 10), Date.new(2026, 6, 15)] }

      it 'returns only the specified days within the month' do
        result = generator.send(:calculate_business_days, start_date, end_date)

        expect(result).to eq(days_on)
      end

      it 'filters out days outside the month range' do
        days_on_with_extras = days_on + [Date.new(2026, 5, 31), Date.new(2026, 7, 1)]
        generator = described_class.new(
          repo_name, contributor_name, data, output_path,
          font_path, days_off, days_on_with_extras, month_num, mode
        )

        result = generator.send(:calculate_business_days, start_date, end_date)

        expect(result).to eq(days_on)
        expect(result).not_to include(Date.new(2026, 5, 31))
        expect(result).not_to include(Date.new(2026, 7, 1))
      end
    end

    context 'when days_on is empty' do
      it 'calculates business days excluding weekends' do
        result = generator.send(:calculate_business_days, start_date, end_date)

        expect(result.length).to eq(22)
        result.each do |day|
          expect(day.wday).to be_between(1, 5)
        end
      end

      it 'excludes days_off from business days' do
        days_off_dates = [Date.new(2026, 6, 2), Date.new(2026, 6, 3)]
        generator = described_class.new(
          repo_name, contributor_name, data, output_path,
          font_path, days_off_dates, days_on, month_num, mode
        )

        result = generator.send(:calculate_business_days, start_date, end_date)

        expect(result).not_to include(Date.new(2026, 6, 2))
        expect(result).not_to include(Date.new(2026, 6, 3))
        expect(result.length).to eq(20)
      end
    end
  end

  describe '#github_mode?' do
    context 'when mode is github' do
      let(:mode) { 'github' }

      it 'returns true' do
        expect(generator.send(:github_mode?)).to be true
      end
    end

    context 'when mode is local' do
      let(:mode) { 'local' }

      it 'returns false' do
        expect(generator.send(:github_mode?)).to be false
      end
    end
  end

  describe '#local_mode?' do
    context 'when mode is local' do
      let(:mode) { 'local' }

      it 'returns true' do
        expect(generator.send(:local_mode?)).to be true
      end
    end

    context 'when mode is github' do
      let(:mode) { 'github' }

      it 'returns false' do
        expect(generator.send(:local_mode?)).to be false
      end
    end
  end

  describe '#render_issue_metadata' do
    let(:pdf) { double('pdf', text: nil) }

    context 'when issue has assignees' do
      let(:assignee1) { double('assignee', login: 'user1') }
      let(:assignee2) { double('assignee', login: 'user2') }
      let(:issue) { double('issue', state: 'open', assignees: [assignee1, assignee2]) }

      it 'renders state and assignees' do
        expect(pdf).to receive(:text).with('state: open')
        expect(pdf).to receive(:text).with('assignees: user1, user2')

        generator.send(:render_issue_metadata, pdf, issue)
      end
    end

    context 'when issue has no assignees' do
      let(:issue) { double('issue', state: 'closed', assignees: []) }

      it 'renders only state' do
        expect(pdf).to receive(:text).with('state: closed')
        expect(pdf).not_to receive(:text).with(/assignees/)

        generator.send(:render_issue_metadata, pdf, issue)
      end
    end
  end

  describe '#render_pr_or_commit_metadata' do
    let(:pdf) { double('pdf', text: nil) }

    context 'in github mode' do
      let(:mode) { 'github' }

      context 'when PR is open' do
        let(:pr) do
          double('pr',
            created_at: '2025-06-01T10:00:00Z',
            closed_at: nil
          )
        end

        it 'renders date of opening' do
          expect(pdf).to receive(:text).with('date of opening: 2025-06-01')

          generator.send(:render_pr_or_commit_metadata, pdf, pr)
        end
      end

      context 'when PR is closed' do
        let(:pr) do
          double('pr',
            created_at: '2025-06-01T10:00:00Z',
            closed_at: '2025-06-05T15:00:00Z'
          )
        end

        it 'renders opening date, closing date, and duration' do
          expect(pdf).to receive(:text).with('date of opening: 2025-06-01')
          expect(pdf).to receive(:text).with('date of closing: 2025-06-05')
          expect(pdf).to receive(:text).with('time stayed open: 4 days')

          generator.send(:render_pr_or_commit_metadata, pdf, pr)
        end
      end
    end

    context 'in local mode' do
      let(:mode) { 'local' }
      let(:commit) do
        double('commit',
          created_at: '2025-06-01T10:00:00Z',
          closed_at: nil
        )
      end

      it 'renders commit date label' do
        expect(pdf).to receive(:text).with('commit date: 2025-06-01')

        generator.send(:render_pr_or_commit_metadata, pdf, commit)
      end
    end
  end

  describe '#render_item_metadata' do
    let(:pdf) { double('pdf', text: nil) }

    context 'when item is an issue' do
      let(:assignee) { double('assignee', login: 'user1') }
      let(:issue) { double('issue', state: 'open', assignees: [assignee]) }

      it 'delegates to render_issue_metadata' do
        expect(generator).to receive(:render_issue_metadata).with(pdf, issue)

        generator.send(:render_item_metadata, pdf, issue)
      end
    end

    context 'when item is a PR or commit' do
      let(:pr) do
        double('pr').tap do |p|
          allow(p).to receive(:created_at).and_return('2025-06-01T10:00:00Z')
          allow(p).to receive(:closed_at).and_return(nil)
          allow(p).to receive(:respond_to?).and_return(false)
          allow(p).to receive(:respond_to?).with(:assignees).and_return(false)
        end
      end

      it 'delegates to render_pr_or_commit_metadata' do
        expect(generator).to receive(:render_pr_or_commit_metadata).with(pdf, pr)

        generator.send(:render_item_metadata, pdf, pr)
      end
    end
  end
end
