require 'prawn'
require 'date'
require_relative 'histogram'
require_relative 'utils'

class PdfGenerator
  MODE_GITHUB = "github"
  MODE_LOCAL = "local"

  DEFAULT_FONT_SIZE = 12
  DEFAULT_TITLE_SIZE = 13
  DEFAULT_SUBTITLE_SIZE = 9
  MAX_RULER_SIZE = 3
  MAX_TITLE_LENGTH = 46

  def initialize(repo_name, contributor_name, data, output_path, font_path, days_off, days_on, month_num, mode)
    @repo_name = repo_name
    @contributor_name = contributor_name
    @data = data
    @output_path = output_path
    @font_path = font_path
    @days_off = days_off
    @days_on = days_on
    @month_num = month_num
    @mode = mode
  end

  def generate
    current_year = Date.today.year
    month = Date.new(current_year, @month_num, 1)
    month_name = month.strftime('%B')
    start_date = Date.new(month.year, month.month, 1)
    end_date = Date.new(month.year, month.month, -1)

    business_days = calculate_business_days(start_date, end_date)

    file_name = "#{@repo_name.tr('/', '_')}_#{month_name.downcase}_#{month.year}_#{@contributor_name}_rekap.pdf"
    output_file = File.join(@output_path, file_name)

    title = "Activity summary for #{@contributor_name} on #{@repo_name} in #{month_name} #{month.year}"

    Prawn::Document.generate(output_file, info: metadata(title, @contributor_name), margin: 15) do |pdf|
      setup_document(pdf)
      render_header(pdf, title, business_days)
      render_histogram(pdf, business_days, month)
      render_columns(pdf)
    end

    puts "-> rekap generated: #{file_name}"
  end

  private

  def calculate_business_days(start_date, end_date)
    if @days_on.any?
      @days_on.select { |d| d >= start_date && d <= end_date }
    else
      (start_date..end_date).select { |d| (1..5).include?(d.wday) && !@days_off.include?(d) }
    end
  end

  def setup_document(pdf)
    pdf.font @font_path if @font_path
    pdf.default_leading = 0.5
    pdf.font_size DEFAULT_FONT_SIZE
  end

  def render_header(pdf, title, business_days)
    default_spacing = pdf.font_size / 2.2

    pdf.text "> #{title} (#{business_days.length} days):", size: DEFAULT_TITLE_SIZE
    pdf.move_down default_spacing * 0.6

    pdf.font_size DEFAULT_SUBTITLE_SIZE do
      generation_date = Time.now.strftime("%Y-%m-%d")
      if github_mode?
        pdf.text "Generated on #{generation_date}. All PR and ticket titles are clickable links to their respective GitHub pages."
      else
        pdf.text "Generated on #{generation_date}."
      end
    end

    pdf.move_down default_spacing * 2
  end

  def render_histogram(pdf, business_days, month)
    default_spacing = pdf.font_size / 2.2
    Histogram.draw(pdf, business_days, month, default_spacing)
    pdf.move_down default_spacing
    ruler(MAX_RULER_SIZE, pdf)
    pdf.move_down default_spacing * 1.5
  end

  def render_columns(pdf)
    default_spacing = pdf.font_size / 2.2
    half_width = pdf.bounds.width * 0.5
    top = pdf.cursor

    sections = [
      { title: @data[:pr_title] || "> pull requests opened (#{@data[:pull_requests].count})", items: @data[:pull_requests] },
      { title: @data[:issue_title] || "> tickets processed (#{@data[:issues].count})", items: @data[:issues] }
    ]

    sections = sections.sort_by { |section| -section[:items].length } if github_mode?

    left_data, right_data = sections

    render_column(pdf, left_data, 0, half_width, pdf.cursor, default_spacing)

    pdf.go_to_page(1)
    pdf.move_cursor_to(top)

    render_column(pdf, right_data, half_width + default_spacing * 2, half_width, pdf.cursor, default_spacing, true)
  end

  def render_column(pdf, column_data, x_position, width, top_position, default_spacing, is_right_column = false)
    offset = pdf.bounds.height - top_position
    margin_bottom = pdf.bounds.absolute_bottom
    pdf.bounding_box([x_position, pdf.bounds.height], width: width) do
      pdf.move_down offset
      pdf.text column_data[:title], size: pdf.font_size * 1.2
      ruler(MAX_RULER_SIZE * 0.375, pdf)
      pdf.move_down default_spacing / 2

      column_data[:items].sort_by { |item| item.number }.each do |item|
        pdf.bounds.move_past_bottom if pdf.y - margin_bottom < item_height(pdf, item, default_spacing)
        render_item(pdf, item, default_spacing, is_right_column)
      end
    end
  end

  def item_height(pdf, item, default_spacing)
    line_height = pdf.font_size + 4
    metadata_lines = if item.respond_to?(:assignees)
      item.assignees.any? ? 2 : 1
    else
      item.closed_at.present? ? 3 : 1
    end
    (1 + metadata_lines) * line_height + default_spacing * 3
  end

  def render_item(pdf, item, default_spacing, is_right_column)
    truncated_title = truncate_text(item.title, MAX_TITLE_LENGTH)
    separator = is_right_column ? " " : " - "
    pdf.text "<link href='#{item.html_url}'>##{item.number}#{separator}#{truncated_title}</link>",
      inline_format: true
    ruler(MAX_RULER_SIZE * 0.25, pdf)
    pdf.move_down default_spacing / 2

    render_item_metadata(pdf, item)

    spacing_multiplier = (is_right_column && github_mode?) ? 2.2 : 1.5
    pdf.move_down default_spacing * spacing_multiplier
  end

  def render_item_metadata(pdf, item)
    if item.respond_to?(:assignees)
      render_issue_metadata(pdf, item)
    else
      render_pr_or_commit_metadata(pdf, item)
    end
  end

  def render_issue_metadata(pdf, item)
    pdf.text "state: #{item.state}"
    if item.assignees.any?
      pdf.text "assignees: #{item.assignees.map(&:login).join(', ')}"
    end
  end

  def render_pr_or_commit_metadata(pdf, item)
    date_label = local_mode? ? "commit date" : "date of opening"
    pdf.text "#{date_label}: #{DateTime.parse(item.created_at).to_date}"

    if item.closed_at.present?
      pdf.text "date of closing: #{DateTime.parse(item.closed_at).to_date}"
      pdf.text "time stayed open: #{(DateTime.parse(item.closed_at) - DateTime.parse(item.created_at)).to_i} days"
    end
  end

  def github_mode?
    @mode == MODE_GITHUB
  end

  def local_mode?
    @mode == MODE_LOCAL
  end
end
