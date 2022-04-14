class Api::V1::RepositoriesController < ApplicationController
  before_action :set_repository, only: %i[update show]
  before_action :check_login, only: %i[index create branches]
  before_action :check_owner, only: %i[update show]

  def index
    render json: RepositorySerializer.new(current_user.repositories)
                                     .serializable_hash
                                     .to_json,
           status: 200
  end

  # GET /api/v1/repositories/:id
  def show
    # TODO: add check_login later, (collaborator for current repo)
    render json: RepositorySerializer.new(@repository, include: %i[folders user_repositories]).serializable_hash.to_json,
           status: :ok
    # render json: RepositorySerializer.new(@repository, include: %i[folders folders.repo_files folders.repo_files.code_units folders.repo_files.code_units.code_unit_doc ]).serializable_hash.to_json,
  end

  # POST /api/v1/repositories/
  def create
    temp_github_data = TempGithubAppInfo.find_by(installation_id: params[:repository][:installation_id])
    parsed_data = JSON.parse temp_github_data.info
    repository_data = parsed_data['repositories'].find { |repo| repo['full_name'] == params[:repository][:full_name] }

    repo_branches_data = Faraday.get(
      "https://api.github.com/repos/#{repository_data['full_name']}/branches"
    ) do |req|
      req.headers['authorization'] = "Bearer #{current_user.github_access_token}"
    end
    branch_names = JSON.parse(repo_branches_data.body).map { |branch| branch['name'] }

    @repository = Repository.new(
      name: repository_data['name'],
      full_name: repository_data['full_name'],
      github_id: repository_data['id'],
      private: repository_data['private'],
      branch_names: branch_names
    )

    if @repository.save
      # Associate user with repo, add owner role
      UserRepository.create(repository: @repository, user_id: current_user.id, role: Role.find_by(name: 'owner'))
      render json: RepositorySerializer.new(@repository).serializable_hash.to_json, status: :created
    else
      render json: @repository.errors, status: :unprocessable_entity
    end
  end

  # PATCH /api/v1/repositories/:id
  def update
    if @repository.update(repository_params.merge(token_count: @repository.count_tokens(repository_params[:branch])))
      render json: RepositorySerializer.new(@repository.reload, include: ['folders.repo_files']).serializable_hash.to_json,
             status: :ok
    else
      render json: @repository.errors, status: :unprocessable_entity
    end
  end

  # /POST /api/v1/branches
  def branches
    # make api call to get branches
    url = "https://api.github.com/repos/#{params[:repository][:full_name]}/branches"

    response = Faraday.get(url) do |req|
      req.headers['authorization'] = "Bearer #{current_user.github_access_token}"
    end

    parsed_response = JSON.parse(response.body)
    branch_names = parsed_response.map { |branch| branch['name'] }

    if branch_names.any?
      render json: { data: branch_names }, status: :ok
    else
      head :forbidden
    end
  end

  # answer from github webhooks
  def github_webhook
    # ! Add job to delete TempGithubAppInfo after some time
    repositories = params[:repositories]
    # get params with JSON.parse request.raw_post, action
    action = JSON.parse(request.raw_post)['action']

    # if github_webhook_params[:pull_request] && # merged
    #   # handle pull request(s) - check the state to react accordingly
    #   # trigger deploy only on merge
    # elsif github_webhook_params[:push]
    #   # handle only push to default branch

    if action == 'created' && github_webhook_params[:installation][:account][:login].present?

      # save github answer to db
      TempGithubAppInfo.create!(
        login: github_webhook_params[:installation][:account][:login],
        github_id: github_webhook_params[:installation][:account][:id],
        installation_id: github_webhook_params[:installation][:id],
        info: request.raw_post,
        multiple: params[:repositories].size > 1
      )
      # elsif github_webhook_params[:repository] - change
      # puts 'repository'
      # elsif action == 'deleted'
      #   # handle github app deletion
      #   puts 'deleted'
    end
  end

  private

  def repository_params
    params.require(:repository).permit(:branch)
  end

  def set_repository
    @repository = Repository.find(params[:id])
  end

  def github_webhook_params
    params.permit!
  end

  def check_owner
    return head :forbidden unless @repository.user_ids.include? current_user&.id

    render json: { errors: current_user[:errors] }, status: :forbidden if current_user[:errors].present?
  end
end
