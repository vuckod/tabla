# frozen_string_literal: true

require "rqrcode"

module QrHelper
  def qr_code_svg(url, size: 160)
    qr = RQRCode::QRCode.new(url, level: :m)
    svg = qr.as_svg(
      module_size: 4,
      standalone: true,
      use_path: true,
      viewbox: true,
      svg_attributes: {
        class: "qr-code",
        width: size,
        height: size
      }
    )
    svg.html_safe
  end
end
