class Api::V1::UsersController < ApplicationController
  before_action :set_user, only: %i[show update github_auth destroy_all_records]
  before_action :check_owner, except: %i[create invite]

  # POST /api/v1/users
  # create user asd
  def create
    @company = Company.find_or_create_by(name: user_params[:company_name])
    @user = @company.users.new(user_params.except(:company_name))

    if @user.save && @company.valid?
      render json: UserSerializer.new(@user)
                                 .serializable_hash
                                 .merge(access_token: JsonWebToken.encode(user_id: @user.id))
                                 .to_json, status: :created
    else
      render json: { user: @user.errors, company: @company.errors }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /api/v1/users/1
  def update
    if @user.update(user_params)
      render json: UserSerializer.new(@user).serializable_hash.to_json, status: :ok
    else
      render json: @user.errors, status: :unprocessable_entity
    end
  end

  # POST /api/v1/users/invite
  # ask for first_name, last_name, company name, password, and profession
  def invite
    # Find invitation
    @invitation = Invitation.find_by(invitation_token: params[:user][:invitation_token])
    return head :forbidden unless @invitation

    # Check if the invitation is expired
    render json: { errors: ['Invitation expired'] }, status: :forbidden and return if @invitation.expired?

    # Create user
    @company = Company.find_or_create_by(name: user_params[:company_name])
    @user = @company.users.new(user_params.except(:company_name))

    if @user.save && @company.valid?
      # Add to repository
      UserRepository.create(
        repository: @invitation.repository,
        user: @user,
        role: Role.find_by(name: 'collaborator')
      )

      # Accept invitation
      @invitation.update(accepted: Time.zone.now)

      render json: UserSerializer.new(@user)
                                 .serializable_hash
                                 .merge(access_token: JsonWebToken.encode(user_id: @user.id))
                                 .to_json, status: :created
    else
      render json: { user: @user.errors, company: @company.errors }, status: :unprocessable_entity
    end
  end
end
