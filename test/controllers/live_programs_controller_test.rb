require 'test_helper'

class LiveProgramsControllerTest < ActionController::TestCase
  setup do
    @live_program = live_programs(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:live_programs)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create live_program" do
    assert_difference('LiveProgram.count') do
      post :create, live_program: { desc: @live_program.desc, live_id: @live_program.live_id, player_status: @live_program.player_status, started_at: @live_program.started_at, title: @live_program.title, url: @live_program.url, user: @live_program.user }
    end

    assert_redirected_to live_program_path(assigns(:live_program))
  end

  test "should show live_program" do
    get :show, id: @live_program
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @live_program
    assert_response :success
  end

  test "should update live_program" do
    patch :update, id: @live_program, live_program: { desc: @live_program.desc, live_id: @live_program.live_id, player_status: @live_program.player_status, started_at: @live_program.started_at, title: @live_program.title, url: @live_program.url, user: @live_program.user }
    assert_redirected_to live_program_path(assigns(:live_program))
  end

  test "should destroy live_program" do
    assert_difference('LiveProgram.count', -1) do
      delete :destroy, id: @live_program
    end

    assert_redirected_to live_programs_path
  end
end
