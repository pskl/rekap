module PdfStyle
  DEFAULT_FONT_SIZE = 12
  TITLE_FONT_SIZE = 13
  SUBTITLE_FONT_SIZE = 9
  MAX_RULER_SIZE = 3
  TITLE_COLOR = '333333'

  private

  def with_bold_font(pdf, &block)
    pdf.font('Helvetica', style: :bold, &block)
  end

  def with_title_style(pdf)
    pdf.save_graphics_state do
      pdf.fill_color TITLE_COLOR
      with_bold_font(pdf) { yield }
    end
  end
end
