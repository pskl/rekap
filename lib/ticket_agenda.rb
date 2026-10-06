require 'date'
require_relative 'pdf_style'
require_relative 'utils'

class TicketAgenda
  include PdfStyle

  TICKET_ID_PATTERN = /\b[A-Z]+-\d+\b/

  ROW_HEIGHT = 21

  def initialize(data)
    @data = data
  end

  def present?
    evidence.any?
  end

  def render(pdf, business_days)
    rows = assignments(business_days)
    default_spacing = pdf.font_size / 2.2
    minimum_height = TITLE_FONT_SIZE + ROW_HEIGHT * 2 + default_spacing * 2.5

    if pdf.cursor < minimum_height + default_spacing
      pdf.start_new_page
    else
      pdf.move_down default_spacing
    end

    ruler(MAX_RULER_SIZE, pdf)
    pdf.move_down default_spacing * 1.5

    with_title_style(pdf) do
      pdf.text "> ticket agenda (#{ticket_count(rows)})", size: TITLE_FONT_SIZE
    end
    ruler(MAX_RULER_SIZE * 0.375, pdf)
    pdf.move_down pdf.font_size / 3

    pdf.font_size SUBTITLE_FONT_SIZE do
      render_header(pdf)

      rows.each do |row|
        if pdf.cursor < ROW_HEIGHT
          pdf.start_new_page
          render_header(pdf)
        end

        render_row(pdf, [
          row[:date].strftime('%d/%m/%Y'),
          row[:morning],
          row[:afternoon]
        ])
      end
    end
  end

  private

  def render_header(pdf)
    render_row(pdf, ['date', nil, nil], header: true)
  end

  def render_row(pdf, values, header: false)
    widths = [pdf.bounds.width * 0.20, pdf.bounds.width * 0.40, pdf.bounds.width * 0.40]
    x_position = 0
    top = pdf.cursor

    values.zip(widths).each_with_index do |(value, width), index|
      render_cell_background(pdf, x_position, top, width) if header
      render_cell_border(pdf, x_position, top, width, header)

      if header && index.positive?
        label, start_hour, end_hour = index == 1 ? ['morning', 8, 12] : ['afternoon', 13, 17]
        render_time_slot_header(pdf, x_position, top, width, label, start_hour, end_hour)
      else
        render_cell_text(pdf, value, x_position, top, width, bold: header)
      end

      x_position += width
    end

    pdf.move_down ROW_HEIGHT
  end

  def render_cell_background(pdf, x_position, top, width)
    pdf.save_graphics_state do
      pdf.fill_color 'F2F2F2'
      pdf.fill_rectangle([x_position, top], width, ROW_HEIGHT)
    end
  end

  def render_cell_border(pdf, x_position, top, width, header)
    old_line_width = pdf.line_width
    pdf.line_width = header ? 0.8 : 0.5
    pdf.stroke_rectangle([x_position, top], width, ROW_HEIGHT)
    pdf.line_width = old_line_width
  end

  def render_cell_text(pdf, value, x_position, top, width, bold: false)
    render = proc do
      pdf.text_box(value.to_s, at: [x_position + 4, top],
        width: width - 8, height: ROW_HEIGHT, align: :center, valign: :center,
        overflow: :shrink_to_fit, single_line: true)
    end

    bold ? with_bold_font(pdf, &render) : render.call
  end

  def render_time_slot_header(pdf, x_position, top, width, label, start_hour, end_hour)
    left_text = "#{label} (~#{start_hour}"
    right_text = "~#{end_hour})"
    arrow_width = 10
    arrow_gap = 4

    with_bold_font(pdf) do
      left_width = pdf.width_of(left_text)
      right_width = pdf.width_of(right_text)
      content_width = left_width + arrow_gap + arrow_width + arrow_gap + right_width
      content_x = x_position + (width - content_width) / 2
      text_y = top - (ROW_HEIGHT + pdf.font_size) / 2.0 + 1

      pdf.draw_text(left_text, at: [content_x, text_y])
      pdf.draw_text(right_text,
        at: [content_x + left_width + arrow_gap + arrow_width + arrow_gap, text_y])

      arrow_start = content_x + left_width + arrow_gap
      arrow_end = arrow_start + arrow_width
      arrow_y = top - ROW_HEIGHT / 2.0
      pdf.stroke_line([arrow_start, arrow_y], [arrow_end, arrow_y])
      pdf.stroke_line([arrow_end, arrow_y], [arrow_end - 3, arrow_y + 2])
      pdf.stroke_line([arrow_end, arrow_y], [arrow_end - 3, arrow_y - 2])
    end
  end

  def assignments(business_days)
    business_days.map do |date|
      {
        date: date,
        morning: tickets_for_half_day(date, :morning),
        afternoon: tickets_for_half_day(date, :afternoon)
      }
    end
  end

  def ticket_count(rows)
    rows
      .flat_map { |row| row.values_at(:morning, :afternoon) }
      .flat_map { |ticket_ids| ticket_ids.split(', ') }
      .uniq
      .count
  end

  def evidence
    return @evidence if defined?(@evidence)

    item_evidence = report_items.flat_map do |item|
      next [] unless item.respond_to?(:title) && item.respond_to?(:created_at)

      item.title.to_s.scan(TICKET_ID_PATTERN).uniq.map do |ticket_id|
        { ticket_id: ticket_id, occurred_at: item.created_at }
      end
    end

    @evidence = (item_evidence + Array(@data[:ticket_evidence])).filter_map do |entry|
      occurred_at = DateTime.parse(entry[:occurred_at].to_s)
      { ticket_id: entry[:ticket_id], occurred_at: occurred_at }
    rescue Date::Error
      nil
    end
  end

  def report_items
    if @data[:sections]
      @data[:sections].compact.flat_map { |section| section[:items] }
    else
      Array(@data[:pull_requests]) + Array(@data[:issues])
    end
  end

  def tickets_for_half_day(date, half_day)
    direct_ticket_ids = evidence.select do |entry|
      occurred_at = entry[:occurred_at]
      next false unless occurred_at.to_date == date

      is_morning = occurred_at.hour < 13
      (half_day == :morning && is_morning) || (half_day == :afternoon && !is_morning)
    end
      .sort_by { |entry| entry[:occurred_at] }
      .map { |entry| entry[:ticket_id] }
      .uniq

    return direct_ticket_ids.join(', ') if direct_ticket_ids.any?

    nearest_ticket(date, half_day == :morning ? 10 : 15)
  end

  def nearest_ticket(date, hour)
    return 'UNKNOWN' if evidence.empty?

    target = DateTime.new(date.year, date.month, date.day, hour)
    evidence.min_by { |entry| (entry[:occurred_at] - target).abs }[:ticket_id]
  end

end
