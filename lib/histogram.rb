require 'date'

class Histogram
  def self.draw(pdf, business_days, month = Date.today.prev_month, default_spacing = 10)
    start_date = Date.new(month.year, month.month, 1)
    end_date = Date.new(month.year, month.month, -1)

    all_days = (start_date..end_date).to_a

    height = 40
    max_hours = 8
    bar_spacing = 2
    y_axis_width = 15

    available_width = pdf.bounds.width - y_axis_width
    bar_width = (available_width - (all_days.length - 1) * bar_spacing) / all_days.length

    current_y = pdf.cursor

    pdf.font_size 8 do
      (0..max_hours).step(2) do |hours|
        y_position = current_y - height + (height * (hours.to_f / max_hours))
        pdf.draw_text hours.to_s, at: [0, y_position]
      end
    end

    pdf.line_width = 0.05
    pdf.dash(2)
    (0..max_hours).step(2) do |hours|
      y_position = current_y - height + (height * (hours.to_f / max_hours))
      pdf.stroke_horizontal_line y_axis_width, pdf.bounds.width, at: y_position
    end
    pdf.undash
    pdf.line_width = 1

    all_days.each_with_index do |date, index|
      x_position = y_axis_width + (index * (bar_width + bar_spacing))

      if business_days.include?(date)
        bar_height = height * (8.0 / max_hours)
        pdf.fill_rectangle [x_position, current_y - height + bar_height], bar_width, bar_height
      end

      pdf.font_size 6 do
        date_label = date.strftime("%d.%m")
        label_width = pdf.width_of(date_label)
        pdf.draw_text date_label, at: [x_position + (bar_width - label_width)/2, current_y - height - 8]
      end
    end

    pdf.move_cursor_to(current_y - height - 15)
  end
end
