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

class Object
  def present?
    !nil? && !empty?
  end
end
