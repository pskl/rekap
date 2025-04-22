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

def truncate_text(text, max_length)
  text = text.split.join(" ")
  text.length > max_length ? "#{text[0..max_length-3]}..." : text
end

class Object
  def present?
    !nil? && !empty?
  end
end
