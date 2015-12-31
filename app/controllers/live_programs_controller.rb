class LiveProgramsController < ApplicationController
  before_action :set_live_program, only: [:show, :edit, :update, :destroy]

  # GET /live_programs
  # GET /live_programs.json
  def index
    @live_programs = LiveProgram.all
  end

  # GET /live_programs/1
  # GET /live_programs/1.json
  def show
  end

  # GET /live_programs/new
  def new
    @live_program = LiveProgram.new
  end

  # GET /live_programs/1/edit
  def edit
  end

  # POST /live_programs
  # POST /live_programs.json
  def create
    @live_program = LiveProgram.new(live_program_params)

    respond_to do |format|
      if @live_program.save
        format.html { redirect_to @live_program, notice: 'Live program was successfully created.' }
        format.json { render :show, status: :created, location: @live_program }
      else
        format.html { render :new }
        format.json { render json: @live_program.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /live_programs/1
  # PATCH/PUT /live_programs/1.json
  def update
    respond_to do |format|
      if @live_program.update(live_program_params)
        format.html { redirect_to @live_program, notice: 'Live program was successfully updated.' }
        format.json { render :show, status: :ok, location: @live_program }
      else
        format.html { render :edit }
        format.json { render json: @live_program.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /live_programs/1
  # DELETE /live_programs/1.json
  def destroy
    @live_program.destroy
    respond_to do |format|
      format.html { redirect_to live_programs_url, notice: 'Live program was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_live_program
      @live_program = LiveProgram.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def live_program_params
      params.require(:live_program).permit(:live_id, :started_at, :user, :title, :desc, :url, :player_status)
    end
end
