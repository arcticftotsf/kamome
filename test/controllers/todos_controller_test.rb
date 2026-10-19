require "test_helper"

class TodosControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    @todo = @user.todos.create!(title: "My task", done: false)
    @other = users(:two).todos.create!(title: "Not mine", done: false)
  end

  test "should require login" do
    delete session_url
    get todos_url
    assert_redirected_to new_session_url
  end

  test "should get index" do
    get todos_url
    assert_response :success
  end

  test "should not show other users todo in index" do
    get todos_url
    assert_no_match "Not mine", response.body
  end

  test "should create todo" do
    assert_difference("Todo.count", 1) do
      post todos_url, params: { todo: { title: "New task", done: false } }
    end
    assert_redirected_to todos_url
  end

  test "should get edit" do
    get edit_todo_url(@todo)
    assert_response :success
  end

  test "should update todo" do
    patch todo_url(@todo), params: { todo: { title: "Changed", done: true } }
    assert_redirected_to todos_url
    assert_equal "Changed", @todo.reload.title
  end

  test "should destroy todo" do
    assert_difference("Todo.count", -1) do
      delete todo_url(@todo)
    end
    assert_redirected_to todos_url
  end

  test "should not edit other users todo" do
    get edit_todo_url(@other)
    assert_response :not_found
  end

  test "should not update other users todo" do
    patch todo_url(@other), params: { todo: { title: "Hacked" } }
    assert_response :not_found
    assert_equal "Not mine", @other.reload.title
  end

  test "should not destroy other users todo" do
    assert_no_difference("Todo.count") do
      delete todo_url(@other)
    end
    assert_response :not_found
  end
end
