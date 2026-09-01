def metadata(title, author_name)
  {
    Title: title,
    Author: author_name,
    Creator: "rekap",
    Producer: ""
  }
end

def ruler(size, pdf)
  pdf.line_width = size
  pdf.stroke_horizontal_rule
end

def truncate_text(pdf, text, available_width)
  text = text.split.join(" ")
  return text if pdf.width_of(text) <= available_width

  ellipsis = "..."
  budget = available_width - pdf.width_of(ellipsis)
  truncated = text
  truncated = truncated[0...-1] while truncated.length > 1 && pdf.width_of(truncated) > budget

  "#{truncated.rstrip}#{ellipsis}"
end

class Object
  def present?
    !nil? && !empty?
  end
end
