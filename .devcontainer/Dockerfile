ARG RUBY_VERSION=3.4.2
FROM ghcr.io/rails/devcontainer/images/ruby:$RUBY_VERSION

# OCR paketi za development
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    tesseract-ocr tesseract-ocr-slv tesseract-ocr-hun poppler-utils && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

ENV BINDING="0.0.0.0"
