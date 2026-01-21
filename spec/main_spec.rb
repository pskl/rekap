# frozen_string_literal: true

require 'spec_helper'
require_relative '../main'

RSpec.describe 'main.rb' do
  let(:repo_name) { 'test/repo' }
  let(:contributor_name) { 'John Doe' }
  let(:output_path) { '/tmp' }
  let(:font_path) { nil }
  let(:days_off) { [] }
  let(:days_on) { [] }
  let(:month_num) { 6 }
  let(:data) do
    {
      pull_requests: [
        double('pr', number: 1, title: 'Test PR', html_url: 'https://github.com/test/repo/pull/1', created_at: '2025-06-01T10:00:00Z', closed_at: nil)
      ],
      issues: [
        double('issue', number: 2, title: 'Test Issue', html_url: 'https://github.com/test/repo/issues/2', state: 'open', assignees: [])
      ]
    }
  end

  describe '#generate_pdf' do
    let(:expected_filename) { 'test_repo_june_2026_John Doe_rekap.pdf' }
    let(:expected_filepath) { File.join(output_path, expected_filename) }

    before do
      allow(Prawn::Document).to receive(:generate)
      allow_any_instance_of(Object).to receive(:puts)
    end

    it 'generates PDF with correct filename' do
      expect(Prawn::Document).to receive(:generate).with(expected_filepath, info: anything)
      
      generate_pdf(repo_name, contributor_name, data, output_path, font_path, days_off, days_on, month_num)
    end

    it 'calculates business days for June 2025' do
      generate_pdf(repo_name, contributor_name, data, output_path, font_path, days_off, days_on, month_num)
    end

    it 'excludes days off from business days' do
      days_off_dates = [Date.new(2026, 6, 2), Date.new(2026, 6, 3)]
      
      generate_pdf(repo_name, contributor_name, data, output_path, font_path, days_off_dates, days_on, month_num)
    end

    it 'prints confirmation message' do
      expect_any_instance_of(Object).to receive(:puts).with("-> rekap generated: #{expected_filename}")
      
      generate_pdf(repo_name, contributor_name, data, output_path, font_path, days_off, days_on, month_num)
    end
  end
end