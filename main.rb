Bundler.require()
require 'date'
require 'optparse'
require_relative 'lib/histogram'
require_relative 'lib/options'
require_relative 'lib/utils'
require_relative 'lib/github_service'

def generate_pdf(repo_name, contributor_name, data, output_path, font_path, days_off = [], month_num)
  current_year = Date.today.year
  month = Date.new(current_year, month_num, 1)
  month_name = month.strftime('%B')
  start_date = Date.new(month.year, month.month, 1)
  end_date = Date.new(month.year, month.month, -1)
  business_days = (start_date..end_date).select { |d| (1..5).include?(d.wday) && !days_off.include?(d) }

  file_name = "#{repo_name.tr('/', '_')}_#{month_name.downcase}_#{month.year}_#{contributor_name}_rekap.pdf"
  output_file = File.join(output_path, file_name)

  title = "Activity summary for #{contributor_name} on #{repo_name} in #{month_name} #{month.year}"

  Prawn::Document.generate(output_file, info: metadata(title, contributor_name)) do |pdf|
    pdf.font font_path if font_path
    pdf.default_leading = 0.5
    pdf.font_size 12
    default_spacing = pdf.font_size / 2.2
    max_ruler_size = 3
    max_title_length = 46

    pdf.text "> #{title} (#{business_days.length} days):", size: 13
    pdf.move_down default_spacing * 0.6

    pdf.font_size 9 do
      generation_date = Time.now.strftime("%Y-%m-%d")
      pdf.text "Generated on #{generation_date}. All PR and ticket titles are clickable links to their respective GitHub pages."
    end

    pdf.move_down default_spacing * 2
    Histogram.draw(pdf, business_days, month, default_spacing)
    pdf.move_down default_spacing
    ruler(max_ruler_size, pdf)
    pdf.move_down default_spacing * 1.5

    half_width = pdf.bounds.width * 0.5
    top = pdf.cursor

    sections = [
      { title: "> pull requests opened (#{data[:pull_requests].count})", items: data[:pull_requests] },
      { title: "> tickets processed (#{data[:issues].count})", items: data[:issues] }
    ].sort_by { |section| -section[:items].length }

    left_data, right_data = sections

    pdf.bounding_box([0, pdf.cursor], width: half_width) do
      pdf.text left_data[:title], size: pdf.font_size * 1.2
      ruler(max_ruler_size * 0.375, pdf)
      pdf.move_down default_spacing/2

      left_data[:items].sort_by { |item| item.number }.each do |item|
        truncated_title = truncate_text(item.title, max_title_length)
        pdf.text "<link href='#{item.html_url}'>##{item.number} - #{truncated_title}</link>",
          inline_format: true
        ruler(max_ruler_size * 0.25, pdf)
        pdf.move_down default_spacing/2

        if item.respond_to?(:assignees)
          pdf.text "state: #{item.state}"
          if item.assignees.any?
            pdf.text "assignees: #{item.assignees.map(&:login).join(', ')}"
          end
        else
          pdf.text "date of opening: #{DateTime.parse(item.created_at).to_date}"
          if item.closed_at.present?
            pdf.text "date of closing: #{DateTime.parse(item.closed_at).to_date}"
            pdf.text "time stayed open: #{(DateTime.parse(item.closed_at) - DateTime.parse(item.created_at)).to_i} days"
          end
        end

        pdf.move_down default_spacing * 1.5
      end
    end

    pdf.go_to_page(1)
    pdf.move_cursor_to(top)

    pdf.bounding_box([half_width + default_spacing*2, pdf.cursor], width: half_width) do
      pdf.text right_data[:title], size: pdf.font_size * 1.2
      ruler(max_ruler_size * 0.375, pdf)
      pdf.move_down default_spacing/2

      right_data[:items].sort_by { |item| item.number }.each do |item|
        truncated_title = truncate_text(item.title, max_title_length)
        pdf.text "<link href='#{item.html_url}'>##{item.number} #{truncated_title}</link>",
          inline_format: true
        ruler(max_ruler_size * 0.25, pdf)
        pdf.move_down default_spacing/2

        if item.respond_to?(:assignees)
          pdf.text "state: #{item.state}"
          if item.assignees.any?
            pdf.text "assignees: #{item.assignees.map(&:login).join(', ')}"
          end
        else
          pdf.text "date of opening: #{DateTime.parse(item.created_at).to_date}"
          if item.closed_at.present?
            pdf.text "date of closing: #{DateTime.parse(item.closed_at).to_date}"
            pdf.text "time stayed open: #{(DateTime.parse(item.closed_at) - DateTime.parse(item.created_at)).to_i} days"
          end
        end

        pdf.move_down default_spacing * 2.2
      end
    end
  end
  puts "-> rekap generated: #{file_name}"
end

options = Options.parse

github = Github.new(oauth_token: options[:gh_token], auto_pagination: true)
authenticated_user = github.users.get

month = options[:month] || Date.today.prev_month.month

github_service = GithubService.new(github, authenticated_user)
data = github_service.fetch_repo_data(options[:project_name], month)

generate_pdf(options[:project_name], authenticated_user.name, data, options[:output_path] || '.', options[:font_path], options[:days_off] || [], month)
