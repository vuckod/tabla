# frozen_string_literal: true

class BookmarksController < ApplicationController
  before_action :require_login

  def create
    document = Document.visible_to(current_user).published.find(params[:document_id])
    current_user.bookmarks.find_or_create_by!(document: document)
    respond_to_toggle(document)
  end

  def destroy
    document = Document.visible_to(current_user).published.find(params[:document_id])
    current_user.bookmarks.where(document: document).destroy_all
    respond_to_toggle(document)
  end

  private

  def respond_to_toggle(document)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "bookmark_button_#{document.id}",
          partial: "bookmarks/button",
          locals: { document: document }
        )
      end
      format.html { redirect_back fallback_location: documents_path }
    end
  end
end
