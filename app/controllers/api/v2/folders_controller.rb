class Api::V2::FoldersController < ApplicationController
  before_action :set_folder, only: %i[show]
  before_action :check_owner, only: %i[show]

  def show
    render json: FolderSerializer.new(@folder, include: %i[repo_files]).serializable_hash.to_json,
           status: :ok
  end

  private

  def folder_params
    params.require(:folder).permit(:repository_id, :name, :full_path)
  end

  def set_folder
    @folder = Folder.find(params[:id])
  end

  def check_owner
    return head :forbidden unless @folder.repository.user_ids.include? current_user&.id

    render json: { errors: current_user[:errors] }, status: :forbidden if current_user[:errors].present?
  end
end
